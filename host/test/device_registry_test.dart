import 'dart:convert';
import 'dart:io';

import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:test/test.dart';

/// DPAPI i migracja z plaintext dotyczą tylko Windows; na Linuxie sekrety chroni
/// FileModeSecretStore (test/secret_store_test.dart).
final String? windowsOnly = Platform.isWindows ? null : 'DPAPI — tylko Windows';

void main() {
  late Directory tempDir;
  late File storeFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('device_registry_test_');
    storeFile = File('${tempDir.path}/paired_devices.json');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('register() creates a device with a unique id and secret', () {
    final registry = DeviceRegistry(storeFile);
    final a = registry.register('Telefon A');
    final b = registry.register('Telefon B');

    expect(a.deviceId, isNot(equals(b.deviceId)));
    expect(a.pairingSecret, isNot(equals(b.pairingSecret)));
    expect(a.revoked, isFalse);
  });

  test('authenticate() succeeds for a registered, non-revoked device', () {
    final registry = DeviceRegistry(storeFile);
    final device = registry.register('Telefon A');

    final result = registry.authenticate(device.deviceId);
    expect(result, isNotNull);
    expect(result!.deviceId, device.deviceId);
  });

  test('authenticate() fails for an unknown device_id', () {
    final registry = DeviceRegistry(storeFile);
    expect(registry.authenticate('nieznane'), isNull);
  });

  test('revoke() disables only the targeted device, others stay usable', () {
    final registry = DeviceRegistry(storeFile);
    final a = registry.register('Telefon A');
    final b = registry.register('Telefon B');

    final ok = registry.revoke(a.deviceId);
    expect(ok, isTrue);

    expect(registry.authenticate(a.deviceId), isNull, reason: 'Odwołane urządzenie musi stracić dostęp.');
    expect(registry.authenticate(b.deviceId), isNotNull, reason: 'Inne urządzenia nie mogą ucierpieć.');
  });

  test('persists across instances (survives process restart)', () {
    final device = DeviceRegistry(storeFile).register('Telefon A');

    final reloaded = DeviceRegistry(storeFile);
    expect(reloaded.authenticate(device.deviceId), isNotNull);
  });

  test('the store file on disk is DPAPI-protected, not plaintext JSON', () {
    final device = DeviceRegistry(storeFile).register('Telefon A');

    final rawBytes = storeFile.readAsBytesSync();
    final rawAsText = utf8.decode(rawBytes, allowMalformed: true);
    expect(rawAsText.contains(device.pairingSecret), isFalse);
    expect(rawAsText.trim().startsWith('['), isFalse);
  }, skip: windowsOnly);

  test('migrates a legacy plaintext JSON store transparently, without losing devices', () {
    // Symuluje plik zapisany PRZED wprowadzeniem DPAPI w tej fazie —
    // realny scenariusz dla użytkowników z istniejącymi sparowanymi
    // urządzeniami z wcześniejszych sesji.
    const legacyJson = '''
[
  {
    "device_id": "legacy-device-1",
    "display_name": "Stary telefon",
    "pairing_secret": "legacy-plaintext-secret",
    "created_at": "2026-01-01T00:00:00.000",
    "last_seen_at": "2026-01-01T00:00:00.000",
    "revoked": false
  }
]
''';
    storeFile.parent.createSync(recursive: true);
    storeFile.writeAsStringSync(legacyJson);

    final registry = DeviceRegistry(storeFile);
    expect(registry.authenticate('legacy-device-1'), isNotNull, reason: 'urządzenie sprzed migracji musi dalej działać');

    // Po pierwszym odczycie plik powinien być już przepisany jako chroniony.
    final rawBytes = storeFile.readAsBytesSync();
    final rawAsText = utf8.decode(rawBytes, allowMalformed: true);
    expect(rawAsText.contains('legacy-plaintext-secret'), isFalse);

    final reloaded = DeviceRegistry(storeFile);
    expect(reloaded.authenticate('legacy-device-1'), isNotNull);
  }, skip: windowsOnly);

  // usługa i lokalne CLI (`remoteapptester pair` / `remoteapptester revoke`)
  // to dwa osobne procesy z osobnymi instancjami rejestru nad tym samym plikiem.
  group('two registry instances over one file (service + CLI)', () {
    test('a device paired by the CLI is accepted by the running service', () {
      final service = DeviceRegistry(storeFile);
      final cli = DeviceRegistry(storeFile);

      final device = cli.register('Telefon z CLI');

      expect(service.authenticate(device.deviceId), isNotNull);
    });

    test('a device revoked by the CLI is rejected by the running service', () {
      final service = DeviceRegistry(storeFile);
      final device = service.register('Telefon A');
      expect(service.authenticate(device.deviceId), isNotNull);

      DeviceRegistry(storeFile).revoke(device.deviceId);

      expect(service.authenticate(device.deviceId), isNull);
    });

    test("the service's own writes do not drop a device added by the CLI", () {
      final service = DeviceRegistry(storeFile);
      final a = service.register('Telefon A');
      final b = DeviceRegistry(storeFile).register('Telefon B');

      // authenticate() zapisuje last_seen_at — nie może nadpisać wpisu B.
      service.authenticate(a.deviceId);

      final ids = DeviceRegistry(storeFile).all.map((d) => d.deviceId);
      expect(ids, containsAll([a.deviceId, b.deviceId]));
    });
  });
}
