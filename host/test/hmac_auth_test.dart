import 'package:remotetester_host/pairing/hmac_auth.dart';
import 'package:test/test.dart';

void main() {
  test('generateNonceHex produces 32 hex characters (16 bytes)', () {
    final nonce = generateNonceHex();
    expect(nonce.length, 32);
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(nonce), isTrue);
  });

  test('generateNonceHex is not deterministic across calls', () {
    final a = generateNonceHex();
    final b = generateNonceHex();
    expect(a, isNot(b));
  });

  test('computeRequestHmac is deterministic for identical inputs', () {
    final a = computeRequestHmac(
      pairingSecret: 'sekret',
      method: 'Ping',
      payload: [1, 2, 3],
      timestampUnixMs: '1000',
      nonceHex: 'aabbcc',
    );
    final b = computeRequestHmac(
      pairingSecret: 'sekret',
      method: 'Ping',
      payload: [1, 2, 3],
      timestampUnixMs: '1000',
      nonceHex: 'aabbcc',
    );
    expect(a, b);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a), isTrue);
  });

  test('changing any single input changes the HMAC (method, payload, timestamp, nonce, secret)', () {
    final base = computeRequestHmac(
      pairingSecret: 'sekret',
      method: 'Ping',
      payload: [1, 2, 3],
      timestampUnixMs: '1000',
      nonceHex: 'aabbcc',
    );
    expect(
      computeRequestHmac(pairingSecret: 'INNY', method: 'Ping', payload: [1, 2, 3], timestampUnixMs: '1000', nonceHex: 'aabbcc'),
      isNot(base),
    );
    expect(
      computeRequestHmac(pairingSecret: 'sekret', method: 'INNY', payload: [1, 2, 3], timestampUnixMs: '1000', nonceHex: 'aabbcc'),
      isNot(base),
    );
    expect(
      computeRequestHmac(pairingSecret: 'sekret', method: 'Ping', payload: [9, 9, 9], timestampUnixMs: '1000', nonceHex: 'aabbcc'),
      isNot(base),
    );
    expect(
      computeRequestHmac(pairingSecret: 'sekret', method: 'Ping', payload: [1, 2, 3], timestampUnixMs: '2000', nonceHex: 'aabbcc'),
      isNot(base),
    );
    expect(
      computeRequestHmac(pairingSecret: 'sekret', method: 'Ping', payload: [1, 2, 3], timestampUnixMs: '1000', nonceHex: 'ddeeff'),
      isNot(base),
    );
  });
}
