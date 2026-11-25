import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/pairing/hmac_auth.dart';

void main() {
  test('generateNonceHex produces 32 hex characters (16 bytes)', () {
    final nonce = generateNonceHex();
    expect(nonce.length, 32);
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nonce), isTrue);
  });

  test('computeRequestHmac is deterministic and changes with any input', () {
    final base = computeRequestHmac(
      pairingSecret: 'sekret',
      method: 'Ping',
      payload: [1, 2, 3],
      timestampUnixMs: '1000',
      nonceHex: 'aabbcc',
    );
    expect(
      computeRequestHmac(pairingSecret: 'sekret', method: 'Ping', payload: [1, 2, 3], timestampUnixMs: '1000', nonceHex: 'aabbcc'),
      base,
    );
    expect(
      computeRequestHmac(pairingSecret: 'INNY', method: 'Ping', payload: [1, 2, 3], timestampUnixMs: '1000', nonceHex: 'aabbcc'),
      isNot(base),
    );
  });

  test('matches a real HMAC produced by the host\'s implementation (cross-project vector)', () {
    // Wygenerowane naprawdę przez `dart run` na kopii computeRequestHmac w
    // hosta (nie ręcznie wymyślone) — sprawdza, że dwie niezależne
    // kopie tego samego pliku (patrz hmac_auth.dart w obu projektach)
    // faktycznie liczą identyczne bajty do podpisania.
    final hmac = computeRequestHmac(
      pairingSecret: 'cross-project-test-secret',
      method: 'StartBuild',
      payload: [1, 2, 3, 4, 5],
      timestampUnixMs: '1735689600000',
      nonceHex: '00112233445566778899aabbccddeeff',
    );
    expect(
      hmac,
      '8fdedb82d43ef8fb04a698f262eb5e1e9caee620322369c70282dfac22c3ce72',
    );
  });
}
