import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/protobuf.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../pairing/hmac_auth.dart';
import '../settings/agent_settings.dart';

/// Rzucany, gdy certyfikat agenta nie zgadza się z odciskiem przypiętym
/// przy parowaniu — źródło zaufania niezależne od Tailscale
/// (docs/architektura-remote-build.md, sekcja 6.3). Odróżnione od zwykłego
/// błędu połączenia, żeby UI mogło pokazać jednoznaczny komunikat zamiast
/// generycznego "nie udało się połączyć".
class CertificatePinningException implements Exception {
  CertificatePinningException(this.expectedFingerprint, this.actualFingerprint);
  final String expectedFingerprint;
  final String actualFingerprint;
  @override
  String toString() =>
      'CertificatePinningException: certyfikat agenta się zmienił '
      '(oczekiwano $expectedFingerprint, otrzymano $actualFingerprint) — '
      'możliwy man-in-the-middle albo agent został przeinstalowany i wymaga ponownego parowania.';
}

/// Klient HostAgent — TLS z przypiętym certyfikatem (sekcja 6.3) +
/// HMAC z nonce/timestamp na każdym żądaniu (sekcja 6.4). Każde
/// żądanie niesie nagłówek `device-id` (sekcja 4a) oraz `auth-timestamp`/
/// `auth-nonce`/`auth-hmac` policzone świeżo dla TEGO konkretnego wywołania —
/// stąd wszystkie RPC idą przez metody tej klasy, a nie bezpośrednio przez
/// [client], żeby nie dało się przypadkiem ominąć podpisu.
class AgentClient {
  AgentClient._(this._channel, this.client, this._device);

  final ClientChannel _channel;
  final HostAgentClient client;
  DeviceCredentials _device;

  static Future<AgentClient> connect(
    AgentAddress address,
    DeviceCredentials device,
    PinnedCertificate certificate,
  ) async {
    CertificatePinningException? pinningFailure;

    final channel = ClientChannel(
      address.host,
      port: address.port,
      options: ChannelOptions(
        // Ping co ~25 s: zerwane połączenie (zmiana sieci WiFi↔LTE) wykrywamy
        // szybko, a kolejne wywołanie zestawia nowe — przez ten sam TLS z
        // przypiętym certyfikatem. Host akceptuje pingi nie częściej niż co 10 s.
        keepAlive: const ClientKeepAliveOptions(
          pingInterval: Duration(seconds: 25),
          timeout: Duration(seconds: 10),
          permitWithoutCalls: true,
        ),
        credentials: ChannelCredentials.secure(
          onBadCertificate: (X509Certificate cert, String host) {
            // Certyfikat jest samopodpisany, więc domyślna walidacja
            // łańcucha zaufania ZAWSZE tu trafi — to nasz właściwy punkt
            // weryfikacji: akceptujemy WYŁĄCZNIE jeśli odcisk zgadza się z
            // tym przypiętym przy parowaniu, nigdy "ufaj bo się nie da
            // zweryfikować".
            final actual = sha256.convert(cert.der).toString();
            if (actual == certificate.fingerprintSha256Hex) return true;
            pinningFailure = CertificatePinningException(
              certificate.fingerprintSha256Hex,
              actual,
            );
            return false;
          },
        ),
      ),
    );
    final client = HostAgentClient(
      channel,
      options: CallOptions(metadata: {'device-id': device.deviceId}),
    );
    final agentClient = AgentClient._(channel, client, device);

    // Wymuszamy handshake teraz (Ping), żeby błąd pinningu ujawnił się od
    // razu przy próbie połączenia, a nie dopiero przy pierwszym realnym
    // wywołaniu gdzieś głęboko w UI.
    try {
      await agentClient.ping();
    } on GrpcError {
      // Błąd na poziomie RPC (np. unauthenticated) oznacza, że TLS handshake
      // się powiódł — to nie jest błąd pinningu, tylko normalny wynik
      // wywołania Ping bez ważnych danych parowania; UI i tak zrobi
      // właściwy Ping z prawdziwym device-id zaraz potem.
    } catch (_) {
      if (pinningFailure != null) throw pinningFailure!;
      rethrow;
    }

    return agentClient;
  }

  /// Metadane `auth-timestamp`/`auth-nonce`/`auth-hmac` świeżo policzone dla
  /// TEGO wywołania — `method` musi być tą samą nazwą, której agent użyje
  /// przy weryfikacji (patrz host/lib/server/host_agent_service.dart).
  CallOptions _authOptions(String method, GeneratedMessage request) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = generateNonceHex();
    final hmac = computeRequestHmac(
      pairingSecret: _device.pairingSecret,
      method: method,
      payload: request.writeToBuffer(),
      timestampUnixMs: timestamp,
      nonceHex: nonce,
    );
    return CallOptions(metadata: {
      authTimestampMetadataKey: timestamp,
      authNonceMetadataKey: nonce,
      authHmacMetadataKey: hmac,
    });
  }

  /// Co ile telefon wymienia sekret na nowy (oraz od razu po parowaniu, bo kod
  /// z QR jest jednorazowy). Na tyle rzadko, żeby nie przeszkadzać, i na tyle
  /// często, żeby stary sekret szybko przestawał mieć znaczenie.
  static const secretRotationInterval = Duration(days: 30);

  /// Wymienia sekret, jeśli czas. Nowy zapisujemy przed pierwszym użyciem, a
  /// komputer przełącza się dopiero przy pierwszym żądaniu nim podpisanym —
  /// zerwane połączenie w dowolnym momencie niczego nie psuje.
  Future<void> rotateSecretIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'secret_rotated_at_${_device.deviceId}';
    final last = prefs.getInt(key);
    if (last != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < secretRotationInterval) {
      return;
    }
    try {
      final request = Empty();
      final rotation = await client.rotateSecret(request, options: _authOptions('RotateSecret', request));
      final updated = DeviceCredentials(deviceId: _device.deviceId, pairingSecret: rotation.newSecret);
      await updated.save();
      _device = updated;
      await ping();
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } on GrpcError catch (e) {
      // Chwilowy brak sieci albo starszy komputer — spróbujemy przy kolejnym połączeniu.
      if (e.code == StatusCode.unauthenticated) rethrow;
    }
  }

  Future<Pong> ping() {
    final request = Empty();
    return client.ping(request, options: _authOptions('Ping', request));
  }

  Future<ProjectList> listProjects() {
    final request = Empty();
    return client.listProjects(request, options: _authOptions('ListProjects', request));
  }

  ResponseStream<BuildEvent> startBuild(BuildRequest request) =>
      client.startBuild(request, options: _authOptions('StartBuild', request));

  ResponseStream<BuildEvent> getBuildStatus(BuildId request) =>
      client.getBuildStatus(request, options: _authOptions('GetBuildStatus', request));

  ResponseStream<Chunk> downloadArtifact(ArtifactRequest request) =>
      client.downloadArtifact(request, options: _authOptions('DownloadArtifact', request));

  ResponseStream<Chunk> downloadDelta(DeltaRequest request) =>
      client.downloadDelta(request, options: _authOptions('DownloadDelta', request));

  Future<Project> updateProjectOptions(ProjectOptionsUpdate request) =>
      client.updateProjectOptions(request, options: _authOptions('UpdateProjectOptions', request));

  Future<FolderList> listAvailableFolders() {
    final request = Empty();
    return client.listAvailableFolders(request, options: _authOptions('ListAvailableFolders', request));
  }

  /// Nowy projekt na komputerze — sama nazwa folderu w jego katalogu projektów.
  Future<Project> createProject(CreateProjectRequest request) =>
      client.createProject(request, options: _authOptions('CreateProject', request));

  Future<Ack> cancelBuild(BuildId request) =>
      client.cancelBuild(request, options: _authOptions('CancelBuild', request));

  /// Stały strumień dostaw (heartbeat co ~20 s) — patrz `DeliveryService`.
  ResponseStream<DeliveryEvent> watchDeliveries() {
    final request = Empty();
    return client.watchDeliveries(request, options: _authOptions('WatchDeliveries', request));
  }

  Future<Ack> ackDelivery(BuildId request) =>
      client.ackDelivery(request, options: _authOptions('AckDelivery', request));

  /// Podgląd aplikacji web: stan, log serwera i sygnał „odśwież” (do anulowania).
  ResponseStream<PreviewEvent> startPreview(PreviewRequest request) =>
      client.startPreview(request, options: _authOptions('StartPreview', request));

  Future<Ack> stopPreview(PreviewRequest request) =>
      client.stopPreview(request, options: _authOptions('StopPreview', request));

  Future<Ack> reportPreviewIssue(PreviewIssue request) =>
      client.reportPreviewIssue(request, options: _authOptions('ReportPreviewIssue', request));

  Future<void> close() => _channel.shutdown();
}
