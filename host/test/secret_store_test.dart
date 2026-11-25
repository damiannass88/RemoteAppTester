import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:remotetester_host/security/secret_store.dart';
import 'package:test/test.dart';

/// FileModeSecretStore — ochrona sekretów na Linuxie (VPS).
/// Uprawnienia plików mają sens tylko na POSIX, więc na Windows te testy są
/// pomijane (tam obowiązuje DPAPI, pokryte w dpapi_test/tls_identity_test).
void main() {
  final skip = Platform.isWindows ? 'POSIX-only (uprawnienia plików)' : null;
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('secret_store_test_'));
  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  int modeOf(FileSystemEntity e) => e.statSync().mode & 0x1FF;

  test('write() then read() round-trips the secret', () {
    final store = FileModeSecretStore();
    final file = File('${tempDir.path}/secret.bin');
    final secret = Uint8List.fromList(utf8.encode('pairing-secret-123'));

    store.write(file, secret);

    expect(store.read(file), secret);
  }, skip: skip);

  test('the written file is readable only by its owner (0600)', () {
    final file = File('${tempDir.path}/secret.bin');
    FileModeSecretStore().write(file, Uint8List.fromList([1, 2, 3]));

    expect(modeOf(file), 0x180); // 0600
  }, skip: skip);

  test('a newly created parent directory is 0700', () {
    final file = File('${tempDir.path}/config/secret.bin');
    FileModeSecretStore().write(file, Uint8List.fromList([1]));

    expect(modeOf(file.parent), 0x1C0); // 0700
  }, skip: skip);

  test('read() refuses a secret file readable by group/others', () {
    final file = File('${tempDir.path}/secret.bin')..writeAsStringSync('leaked');
    Process.runSync('chmod', ['644', file.path]);

    expect(() => FileModeSecretStore().read(file), throwsA(isA<SecretStoreException>()));
  }, skip: skip);

  test('overwriting keeps 0600 and leaves no temp file behind', () {
    final store = FileModeSecretStore();
    final file = File('${tempDir.path}/secret.bin');
    store.write(file, Uint8List.fromList([1]));
    store.write(file, Uint8List.fromList([2]));

    expect(store.read(file), [2]);
    expect(modeOf(file), 0x180);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  }, skip: skip);
}
