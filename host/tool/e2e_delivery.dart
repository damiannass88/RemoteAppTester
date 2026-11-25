// Test end-to-end dostaw BEZ telefonu: ten skrypt udaje aplikację Android —
// łączy się z działającym `rt s` przez Tailscale, z TLS przypiętym do odcisku
// certyfikatu hosta i HMAC na każdym żądaniu (jak `android_app/lib/net/agent_client.dart`),
// czeka na dostawę, pobiera artefakt, sprawdza SHA-256 i potwierdza dostawę.
//
// Użycie (na hoście, przy działającej usłudze):
//   rt --home <dane> p "e2e"                      # wypisze device_id
//   dart run tool/e2e_delivery.dart --home <dane> --device <device_id> [--timeout 900]
//   (w innym terminalu) rt --home <dane> b <folder projektu>
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';
import 'package:protobuf/protobuf.dart';
import 'package:remotetester_host/transfer/apk_delta.dart';
import 'package:remotetester_host/config/host_config.dart';
import 'package:remotetester_host/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester_host/net/tailscale_interface.dart';
import 'package:remotetester_host/pairing/device_auth.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/hmac_auth.dart';
import 'package:remotetester_host/security/tls_identity.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final home = opt('--home');
  final deviceId = opt('--device');
  final timeout = Duration(seconds: int.tryParse(opt('--timeout') ?? '') ?? 900);
  if (home == null || deviceId == null) {
    stderr.writeln('Użycie: dart run tool/e2e_delivery.dart --home <dane> --device <device_id>');
    exitCode = 64;
    return;
  }
  Directory.current = home;
  final config = HostConfig.load('config/host-config.yaml');
  final device = DeviceRegistry(File('config/paired_devices.json')).all.firstWhere((d) => d.deviceId == deviceId);
  final pinned = TlsIdentity.loadOrGenerate(
    certFile: File('config/tls_cert.pem'),
    keyFile: File('config/tls_key.pem'),
  ).fingerprintSha256Hex;
  final address = await findTailscaleAddress();

  final channel = ClientChannel(
    address.address,
    port: config.listenPort,
    options: ChannelOptions(
      keepAlive: const ClientKeepAliveOptions(pingInterval: Duration(seconds: 25), permitWithoutCalls: true),
      credentials: ChannelCredentials.secure(
        onBadCertificate: (cert, host) => sha256.convert(cert.der).toString() == pinned,
      ),
    ),
  );
  final client = HostAgentClient(channel, options: CallOptions(metadata: {deviceIdMetadataKey: device.deviceId}));

  var secret = device.pairingSecret;
  CallOptions auth(String method, GeneratedMessage request) {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = generateNonceHex();
    return CallOptions(metadata: {
      authTimestampMetadataKey: ts,
      authNonceMetadataKey: nonce,
      authHmacMetadataKey: computeRequestHmac(
        pairingSecret: secret,
        method: method,
        payload: request.writeToBuffer(),
        timestampUnixMs: ts,
        nonceHex: nonce,
      ),
    });
  }

  // Zły odcisk certyfikatu musi zostać odrzucony (pinning naprawdę działa).
  final evil = ClientChannel(address.address,
      port: config.listenPort,
      options: ChannelOptions(credentials: ChannelCredentials.secure(onBadCertificate: (_, _) => false)));
  try {
    await HostAgentClient(evil).ping(Empty(), options: auth('Ping', Empty()));
    stderr.writeln('BŁĄD: połączenie bez zgodnego certyfikatu przeszło!');
    exitCode = 1;
    return;
  } on GrpcError {
    stdout.writeln('[OK] połączenie z niezgodnym certyfikatem odrzucone');
  } finally {
    await evil.shutdown();
  }

  // Bez podpisu HMAC host odmawia.
  try {
    await client.ping(Empty());
    stderr.writeln('BŁĄD: żądanie bez HMAC przeszło!');
    exitCode = 1;
    return;
  } on GrpcError catch (e) {
    stdout.writeln('[OK] żądanie bez HMAC odrzucone (${e.codeName})');
  }

  await client.ping(Empty(), options: auth('Ping', Empty()));
  stdout.writeln('[OK] Ping z TLS pinning + HMAC przez ${address.address}:${config.listenPort}');

  final empty = Empty();
  final stream = client.watchDeliveries(empty, options: auth('WatchDeliveries', empty));
  stdout.writeln('Czekam na dostawę (zleć build: rt b <folder>)...');
  final delivery = await stream
      .where((e) {
        if (e.hasHeartbeatUnixMs()) stdout.writeln('  heartbeat');
        return e.hasDelivery();
      })
      .map((e) => e.delivery)
      .first
      .timeout(timeout);
  stdout.writeln('[OK] dostawa: ${delivery.projectName} ${delivery.methodId} ${delivery.sizeBytes} B '
      'install=${delivery.install.name} launch=${delivery.launch}');

  final bytes = BytesBuilder(copy: false);
  var sha = '';
  final request = ArtifactRequest(buildId: delivery.buildId, resumeFromByteOffset: fixnum.Int64(0));
  await for (final chunk in client.downloadArtifact(request, options: auth('DownloadArtifact', request))) {
    bytes.add(chunk.data);
    if (chunk.isLast) sha = chunk.sha256FullFile;
  }
  final data = bytes.takeBytes();
  final actual = sha256.convert(data).toString();
  if (actual != sha || actual != delivery.sha256 || data.length != delivery.sizeBytes.toInt()) {
    stderr.writeln('BŁĄD: suma/rozmiar się nie zgadza ($actual vs $sha / ${delivery.sha256})');
    exitCode = 1;
    return;
  }
  stdout.writeln('[OK] pobrano ${data.length} B, SHA-256 zgodny');

  // Oszczędny transfer: całość skompresowana, potem delta względem samej siebie.
  for (final base in ['', delivery.sha256]) {
    final dr = DeltaRequest(buildId: delivery.buildId, baseSha256: base);
    final packed = <int>[];
    Chunk? last;
    await for (final chunk in client.downloadDelta(dr, options: auth('DownloadDelta', dr))) {
      packed.addAll(chunk.data);
      if (chunk.isLast) last = chunk;
    }
    final rebuilt = applyDelta(Uint8List.fromList(data), Uint8List.fromList(gzip.decode(packed)));
    if (last == null || sha256.convert(rebuilt).toString() != delivery.sha256 || last.targetSha256 != delivery.sha256) {
      stderr.writeln('BŁĄD: delta (baza "${base.isEmpty ? 'brak' : 'ta sama'}") nie odtwarza instalki');
      exitCode = 1;
      return;
    }
    stdout.writeln('[OK] DownloadDelta (baza: ${base.isEmpty ? 'brak' : 'poprzednia'}): ${packed.length} B zamiast ${data.length} B');
  }

  final ack = BuildId(buildId: delivery.buildId);
  final result = await client.ackDelivery(ack, options: auth('AckDelivery', ack));
  stdout.writeln(result.success ? '[OK] dostawa potwierdzona' : 'BŁĄD: ack nieudany: ${result.message}');

  // Wymiana sekretu: kod z QR przestaje działać po pierwszym żądaniu nowym sekretem.
  final oldSecret = secret;
  final rotation = await client.rotateSecret(empty, options: auth('RotateSecret', empty));
  secret = rotation.newSecret;
  await client.ping(empty, options: auth('Ping', empty));
  stdout.writeln('[OK] nowy sekret działa');
  secret = oldSecret;
  try {
    await client.ping(empty, options: auth('Ping', empty));
    stderr.writeln('BŁĄD: kod z QR nadal działa po wymianie');
    exit(1);
  } on GrpcError {
    stdout.writeln('[OK] kod z QR po wymianie odrzucony');
  }
  await channel.shutdown();
  exit(result.success ? 0 : 1);
}
