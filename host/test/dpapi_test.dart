// DPAPI istnieje tylko na Windows — na Linuxie (VPS) ten plik jest pomijany.
@TestOn('windows')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:remotetester_host/security/dpapi.dart';
import 'package:test/test.dart';

void main() {
  test('dpapiUnprotect(dpapiProtect(x)) round-trips arbitrary bytes', () {
    final original = Uint8List.fromList(List<int>.generate(500, (i) => i % 256));
    final protected = dpapiProtect(original);
    final recovered = dpapiUnprotect(protected);
    expect(recovered, original);
  });

  test('the protected blob does not contain the plaintext secret', () {
    final secret = utf8.encode('to-jest-bardzo-tajny-pairing-secret-12345');
    final protected = dpapiProtect(Uint8List.fromList(secret));
    final protectedAsString = String.fromCharCodes(protected);
    expect(protectedAsString.contains('bardzo-tajny'), isFalse);
  });

  test('round-trips real UTF-8 text (a PEM-shaped private key)', () {
    const pem = '-----BEGIN PRIVATE KEY-----\nMIIEvQ...\n-----END PRIVATE KEY-----\n';
    final protected = dpapiProtect(Uint8List.fromList(utf8.encode(pem)));
    final recovered = utf8.decode(dpapiUnprotect(protected));
    expect(recovered, pem);
  });

  test('unprotecting garbage (not a real DPAPI blob) throws DpapiException', () {
    expect(
      () => dpapiUnprotect(Uint8List.fromList(utf8.encode('to nie jest prawdziwy blob DPAPI'))),
      throwsA(isA<DpapiException>()),
    );
  });

  test('two calls to dpapiProtect on the same input produce different ciphertext', () {
    // DPAPI dodaje losowość (IV/salt) przy każdym wywołaniu — nawet ten sam
    // plaintext nie powinien dawać identycznego blobu za każdym razem.
    final input = Uint8List.fromList(utf8.encode('sekret'));
    final a = dpapiProtect(input);
    final b = dpapiProtect(input);
    expect(a, isNot(b));
    expect(dpapiUnprotect(a), input);
    expect(dpapiUnprotect(b), input);
  });
}
