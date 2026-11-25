import 'dart:convert';
import 'dart:io';

import 'package:remotetester_host/security/dpapi.dart';
import 'package:remotetester_host/security/tls_identity.dart';
import 'package:test/test.dart';

/// DPAPI i migracja z plaintext dotyczą tylko Windows; na Linuxie sekrety chroni
/// FileModeSecretStore (test/secret_store_test.dart).
final String? windowsOnly = Platform.isWindows ? null : 'DPAPI — tylko Windows';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tls_identity_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('generates a real PEM certificate and private key on first run', () {
    final identity = TlsIdentity.loadOrGenerate(
      certFile: File('${tempDir.path}/cert.pem'),
      keyFile: File('${tempDir.path}/key.pem'),
    );

    expect(identity.certificatePem, contains('BEGIN CERTIFICATE'));
    expect(identity.privateKeyPem, contains('BEGIN PRIVATE KEY'));
    expect(identity.fingerprintSha256Hex, hasLength(64)); // 32 bajty sha256 -> 64 znaki hex
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(identity.fingerprintSha256Hex), isTrue);
  }, timeout: const Timeout(Duration(seconds: 30))); // generowanie klucza RSA 2048 nie jest natychmiastowe

  test('persists to disk and reuses the same identity on reload (does not regenerate)', () {
    final certFile = File('${tempDir.path}/cert.pem');
    final keyFile = File('${tempDir.path}/key.pem');

    final first = TlsIdentity.loadOrGenerate(certFile: certFile, keyFile: keyFile);
    final second = TlsIdentity.loadOrGenerate(certFile: certFile, keyFile: keyFile);

    expect(second.fingerprintSha256Hex, first.fingerprintSha256Hex);
    expect(second.certificatePem, first.certificatePem);
    expect(second.privateKeyPem, first.privateKeyPem);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('two different identities have different fingerprints', () {
    final a = TlsIdentity.loadOrGenerate(
      certFile: File('${tempDir.path}/a_cert.pem'),
      keyFile: File('${tempDir.path}/a_key.pem'),
    );
    final b = TlsIdentity.loadOrGenerate(
      certFile: File('${tempDir.path}/b_cert.pem'),
      keyFile: File('${tempDir.path}/b_key.pem'),
    );
    expect(a.fingerprintSha256Hex, isNot(b.fingerprintSha256Hex));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('the private key file on disk is DPAPI-protected, not plaintext PEM', () {
    final keyFile = File('${tempDir.path}/key.pem');
    final identity = TlsIdentity.loadOrGenerate(
      certFile: File('${tempDir.path}/cert.pem'),
      keyFile: keyFile,
    );

    final rawBytes = keyFile.readAsBytesSync();
    final rawAsText = utf8.decode(rawBytes, allowMalformed: true);
    expect(rawAsText.contains('BEGIN PRIVATE KEY'), isFalse);
    expect(dpapiUnprotect(rawBytes), utf8.encode(identity.privateKeyPem));
  }, timeout: const Timeout(Duration(seconds: 30)), skip: windowsOnly);

  test('migrates a legacy plaintext PEM key file transparently on load', () {
    // Symuluje klucz zapisany PRZED wprowadzeniem DPAPI w tej fazie.
    final certFile = File('${tempDir.path}/cert.pem');
    final keyFile = File('${tempDir.path}/key.pem');
    final generated = TlsIdentity.loadOrGenerate(certFile: certFile, keyFile: keyFile);
    // Nadpisz plik klucza jego WŁASNYM plaintext PEM, symulując stary format.
    keyFile.writeAsStringSync(generated.privateKeyPem);

    final migrated = TlsIdentity.loadOrGenerate(certFile: certFile, keyFile: keyFile);
    expect(migrated.privateKeyPem, generated.privateKeyPem);

    final rawBytes = keyFile.readAsBytesSync();
    expect(utf8.decode(rawBytes, allowMalformed: true).contains('BEGIN PRIVATE KEY'), isFalse,
        reason: 'plik powinien być już przepisany jako chroniony po pierwszym odczycie');

    final reloadedAgain = TlsIdentity.loadOrGenerate(certFile: certFile, keyFile: keyFile);
    expect(reloadedAgain.privateKeyPem, generated.privateKeyPem);
  }, timeout: const Timeout(Duration(seconds: 30)), skip: windowsOnly);
}
