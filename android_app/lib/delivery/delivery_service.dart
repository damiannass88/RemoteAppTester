import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../install/apk_installer.dart';
import '../native/package_installer.dart';
import '../settings/sounds.dart';
import '../net/agent_client.dart';
import '../net/friendly_errors.dart';
import '../i18n.dart';

/// Brak jakiegokolwiek zdarzenia (także heartbeatu hosta, co ~20 s) przez
/// ten czas = połączenie martwe (np. telefon zmienił sieć, a TCP tego nie
/// zauważył) — zrywamy i łączymy się od nowa.
const Duration _silenceTimeout = Duration(seconds: 70);

const List<Duration> _backoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 10),
  Duration(seconds: 20),
  Duration(seconds: 30),
];

const String _handledKey = 'handled_delivery_builds';
const int _handledToKeep = 50;

enum DeliveryStage { idle, downloading, installing, waitingForUser, done, failed }

/// Bieżąca (albo ostatnia) dostawa do pokazania w UI.
class DeliveryStatus {
  const DeliveryStatus(this.delivery, this.stage, {this.bytes = 0, this.totalBytes = 0, this.bytesPerSecond = 0, this.message});
  final Delivery delivery;
  final DeliveryStage stage;
  final int bytes;

  /// Rozmiar transferu (delta albo skompresowana całość); 0 = nieznany.
  final int totalBytes;

  /// Prędkość z ostatnich kilku sekund pobierania (0 = jeszcze nieznana).
  final int bytesPerSecond;
  final String? message;
}

/// Automatyczne dostawy (docs/PROJECT_ASSUMPTIONS.md, sekcja 6): stały,
/// uwierzytelniony strumień `WatchDeliveries`, który sam się odnawia —
/// backoff po błędzie, zerwanie po ciszy dłuższej niż [_silenceTimeout],
/// natychmiastowa próba po powrocie sieci (każda kolejna próba idzie przez
/// ten sam [AgentClient]: TLS z przypiętym certyfikatem + HMAC, nigdy przez
/// słabszy kanał).
///
/// Bezpieczeństwo instalacji: SHA-256 (w [ApkInstaller.download]) i kontrola
/// `applicationId` jak przy ręcznym buildzie. Biometria: `install: auto` w
/// `remoteapptester.yaml` oznacza świadomą zgodę właściciela hosta na
/// automatyczne aktualizacje, więc bez pytania o biometrię; `install: ask`
/// i zmiana nazwy pakietu zawsze czekają na decyzję użytkownika.
class DeliveryService extends ChangeNotifier {
  DeliveryService(this._client, {ApkInstaller? installer}) : _installer = installer ?? ApkInstaller();

  static DeliveryService? _active;

  /// Jedna usługa dostaw na całą aplikację: nowe połączenie (np. ponowne
  /// parowanie w Ustawieniach) zatrzymuje poprzednią, zamiast działać obok niej.
  static DeliveryService startFor(AgentClient client) {
    _active?.stop();
    return _active = DeliveryService(client)..start();
  }

  final AgentClient _client;
  final ApkInstaller _installer;

  bool _running = false;
  bool connected = false;
  DeliveryStatus? status;
  StreamSubscription<DeliveryEvent>? _sub;
  Timer? _silence;
  Completer<void>? _streamEnded;
  final List<Delivery> _queue = [];
  bool _processing = false;

  /// Dostawa czekająca na decyzję użytkownika (`install: ask` / zmiana pakietu).
  Delivery? _awaiting;
  File? _awaitingFile;

  /// Buildy zlecone ręcznie na telefonie („Zainstaluj ostatnią”, „Zbuduj i
  /// zainstaluj”) — instalacja po potwierdzeniu biometrią.
  final Set<String> _manual = {};

  /// Stan dostawy dla projektu — `null`, gdy nic się dla niego nie dzieje.
  DeliveryStatus? statusFor(String projectId) {
    final s = status;
    return s != null && s.delivery.projectId == projectId ? s : null;
  }

  bool _inProgress(String buildId) {
    final s = status;
    return s != null &&
        s.delivery.buildId == buildId &&
        (s.stage == DeliveryStage.downloading || s.stage == DeliveryStage.installing || s.stage == DeliveryStage.waitingForUser);
  }

  /// Czy wersja projektu jest właśnie pobierana, instalowana albo czeka na decyzję.
  bool isBusyFor(String projectId) {
    final stage = statusFor(projectId)?.stage;
    return stage == DeliveryStage.downloading || stage == DeliveryStage.installing || stage == DeliveryStage.waitingForUser;
  }

  /// Jedyna droga ręcznej instalacji: ta sama kolejka co dostawy w tle, więc ta
  /// sama wersja nigdy nie jest pobierana ani instalowana dwa razy. Już trwająca
  /// dostawa tego builda jest po prostu kontynuowana.
  Future<void> installBuild({
    required String projectId,
    required String projectName,
    required String buildId,
    required bool launch,
  }) async {
    final current = status;
    if (current != null && current.delivery.buildId == buildId) {
      switch (current.stage) {
        case DeliveryStage.downloading || DeliveryStage.installing:
          return;
        case DeliveryStage.waitingForUser:
          return installAwaiting();
        default:
          break;
      }
    }
    if (_queue.any((d) => d.buildId == buildId)) return;
    _manual.add(buildId);
    _queue
      ..removeWhere((d) => d.projectId == projectId)
      ..insert(0, Delivery(projectId: projectId, projectName: projectName, buildId: buildId, install: InstallMode.AUTO, launch: launch));
    unawaited(_drain());
  }

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_loop());
  }

  /// Zatrzymuje strumień dostaw (obiekt zostaje — usuwa go właściciel widżetu).
  void stop() {
    _running = false;
    _queue.clear();
    _silence?.cancel();
    _sub?.cancel();
    final ended = _streamEnded;
    if (ended != null && !ended.isCompleted) ended.complete();
  }

  bool _disposed = false;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stop();
    if (identical(_active, this)) _active = null;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> _loop() async {
    var attempt = 0;
    while (_running) {
      final ended = _streamEnded = Completer<void>();
      try {
        _sub = _client.watchDeliveries().listen(
          (event) {
            attempt = 0;
            _setConnected(true);
            _armSilenceTimer();
            if (event.hasDelivery()) _enqueue(event.delivery);
          },
          onError: (Object e) {
            if (!ended.isCompleted) ended.complete();
          },
          onDone: () {
            if (!ended.isCompleted) ended.complete();
          },
          cancelOnError: true,
        );
        _armSilenceTimer();
        await ended.future;
      } catch (_) {
        // Błąd przy otwieraniu strumienia — jak każde inne zerwanie.
      }
      _silence?.cancel();
      await _sub?.cancel();
      _setConnected(false);
      if (!_running) return;
      await Future<void>.delayed(_backoff[attempt.clamp(0, _backoff.length - 1)]);
      attempt++;
    }
  }

  void _armSilenceTimer() {
    _silence?.cancel();
    _silence = Timer(_silenceTimeout, () {
      final ended = _streamEnded;
      if (ended != null && !ended.isCompleted) ended.complete();
    });
  }

  void _setConnected(bool value) {
    if (connected == value) return;
    connected = value;
    notifyListeners();
  }

  void _setStatus(DeliveryStatus value) {
    status = value;
    notifyListeners();
  }

  Future<void> _enqueue(Delivery delivery) async {
    // Host wysyła zaległą dostawę ponownie po każdym połączeniu — ta sama, już trwająca, nie wchodzi drugi raz.
    if (_inProgress(delivery.buildId) || _queue.any((d) => d.buildId == delivery.buildId)) return;
    if (await _isHandled(delivery.buildId) || await ApkInstaller.installedBuildFor(delivery.projectId) == delivery.buildId) {
      unawaited(_ack(delivery.buildId));
      return;
    }
    // Starsza, jeszcze nieobsłużona wersja tego samego projektu jest zbędna.
    _queue
      ..removeWhere((d) => d.projectId == delivery.projectId)
      ..add(delivery);
    unawaited(Sounds.play(SoundEvent.newVersion));
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_processing) return;
    _processing = true;
    try {
      while (_queue.isNotEmpty && _running) {
        final next = _queue.removeAt(0);
        // Mogła zostać obsłużona, kiedy czekała w kolejce.
        if (!_manual.contains(next.buildId) &&
            (await _isHandled(next.buildId) || await ApkInstaller.installedBuildFor(next.projectId) == next.buildId)) {
          continue;
        }
        await _handle(next);
      }
    } finally {
      _processing = false;
    }
  }

  int _rateRetries = 0;

  Future<void> _handle(Delivery d) async {
    try {
      _setStatus(DeliveryStatus(d, DeliveryStage.downloading));
      final clock = Stopwatch()..start();
      var windowStartMs = 0, windowStartBytes = 0, speed = 0;
      final file = await _installer.download(
        client: _client,
        buildId: d.buildId,
        projectId: d.projectId,
        onProgress: (bytes, total) {
          // Prędkość z okna ~3 s — widać, gdy pobieranie zwalnia (np. pod koniec).
          final now = clock.elapsedMilliseconds;
          if (now - windowStartMs >= 3000) {
            speed = (bytes - windowStartBytes) * 1000 ~/ (now - windowStartMs);
            windowStartMs = now;
            windowStartBytes = bytes;
          }
          _setStatus(DeliveryStatus(d, DeliveryStage.downloading, bytes: bytes, totalBytes: total, bytesPerSecond: speed));
        },
      );
      if (d.install == InstallMode.ASK && !_manual.contains(d.buildId)) {
        _waitForUser(d, file, tr('Nowa wersja gotowa do instalacji.'));
        return;
      }
      await _install(d, file, allowPackageChange: false, requireAuth: _manual.contains(d.buildId));
      _rateRetries = 0;
    } on InstallCancelledException {
      // Zmiana nazwy pakietu przy automacie — decyzja należy do użytkownika.
      _waitForUser(d, _awaitingFile, tr('Aplikacja ma inną nazwę pakietu niż poprzednio — sprawdź i potwierdź.'));
    } on GrpcError catch (e) {
      // Chwilowy limit żądań na komputerze — ponawiamy sami, bez klikania „Ponów”.
      if (e.code == StatusCode.resourceExhausted && _rateRetries < 5) {
        _rateRetries++;
        _setStatus(DeliveryStatus(d, DeliveryStage.downloading, message: tr('Komputer chwilowo zajęty — ponawiam…')));
        await Future<void>.delayed(const Duration(seconds: 20));
        return _handle(d);
      }
      _setStatus(DeliveryStatus(d, DeliveryStage.failed, message: friendlyErrorMessage(e)));
      // notFound = host zrestartowany, artefakt zniknął — nie ma po co ponawiać.
      if (e.code == StatusCode.notFound || e.code == StatusCode.permissionDenied) await _markHandled(d.buildId);
    } catch (e) {
      _setStatus(DeliveryStatus(d, DeliveryStage.failed, message: e.toString()));
    }
  }

  Future<void> _install(Delivery d, File file, {required bool allowPackageChange, bool requireAuth = false}) async {
    _awaitingFile = file;
    _setStatus(DeliveryStatus(d, DeliveryStage.installing));
    await _installer.install(
      projectId: d.projectId,
      projectName: d.projectName,
      buildId: d.buildId,
      apk: file,
      confirmPackageChange: (_, _) async => allowPackageChange,
      launchAfterInstall: d.launch,
      requireAuth: requireAuth,
      onNeedsConfirmation: () => _setStatus(DeliveryStatus(d, DeliveryStage.installing,
          message: tr('Potwierdź instalację w oknie Androida (albo w powiadomieniu).'))),
    );
    _manual.remove(d.buildId);
    await _markHandled(d.buildId);
    _setStatus(DeliveryStatus(d, DeliveryStage.done));
    unawaited(Sounds.play(SoundEvent.installed));
  }

  void _waitForUser(Delivery d, File? file, String message) {
    _awaiting = d;
    _awaitingFile = file;
    _setStatus(DeliveryStatus(d, DeliveryStage.waitingForUser, message: message));
    // W tle paska nie widać — powiadomienie otworzy aplikację.
    unawaited(PackageInstallerChannel.notifyIfInBackground(d.projectName, message));
  }

  /// Użytkownik potwierdził instalację czekającej dostawy (z biometrią).
  Future<void> installAwaiting() async {
    final d = _awaiting;
    final file = _awaitingFile;
    if (d == null || file == null) return;
    _awaiting = null;
    try {
      await _install(d, file, allowPackageChange: true, requireAuth: true);
    } catch (e) {
      _setStatus(DeliveryStatus(d, DeliveryStage.failed, message: e.toString()));
    }
  }

  /// Użytkownik odrzucił dostawę — host przestaje ją proponować.
  Future<void> dismissAwaiting() async {
    final d = _awaiting;
    if (d == null) return;
    _awaiting = null;
    await _markHandled(d.buildId);
    status = null;
    notifyListeners();
  }

  /// Ponowna próba nieudanej dostawy.
  void retry() {
    final d = status?.delivery;
    if (d == null) return;
    unawaited(_enqueue(d));
  }

  Future<void> launch() async {
    final d = status?.delivery;
    if (d != null) await ApkInstaller.launch(d.projectId);
  }

  Future<bool> _isHandled(String buildId) async =>
      ((await SharedPreferences.getInstance()).getStringList(_handledKey) ?? const []).contains(buildId);

  Future<void> _markHandled(String buildId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = [...(prefs.getStringList(_handledKey) ?? const <String>[]), buildId];
    await prefs.setStringList(_handledKey, list.length > _handledToKeep ? list.sublist(list.length - _handledToKeep) : list);
    await _ack(buildId);
  }

  Future<void> _ack(String buildId) async {
    try {
      await _client.ackDelivery(BuildId(buildId: buildId));
    } catch (_) {
      // Brak potwierdzenia = host wyśle dostawę ponownie, a lista obsłużonych ją pominie.
    }
  }

  /// Czy Android pozwala RemoteAppTesterowi instalować aplikacje (jednorazowa zgoda).
  static Future<bool> canInstallPackages() => PackageInstallerChannel.canRequestPackageInstalls();
}
