import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/pairing_uri.dart';
import 'package:test/test.dart';

void main() {
  test('buildPairingUri encodes host/port/device_id/secret/cert_fp/name as query params', () {
    final device = PairedDevice(
      deviceId: 'abc123',
      displayName: 'Telefon Testowy',
      pairingSecret: 'topsecret==',
      createdAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    final uriString = buildPairingUri(
      host: '100.81.17.106',
      port: 50051,
      device: device,
      certFingerprintSha256Hex: 'deadbeef' * 8,
    );
    final uri = Uri.parse(uriString);

    expect(uri.scheme, 'remoteapptester');
    expect(uri.host, 'pair');
    expect(uri.queryParameters['host'], '100.81.17.106');
    expect(uri.queryParameters['port'], '50051');
    expect(uri.queryParameters['device_id'], 'abc123');
    expect(uri.queryParameters['secret'], 'topsecret==');
    expect(uri.queryParameters['cert_fp'], 'deadbeef' * 8);
    expect(uri.queryParameters['name'], 'Telefon Testowy');
  });

  test('special characters in the device name survive the URI round trip', () {
    final device = PairedDevice(
      deviceId: 'x',
      displayName: 'Telefon Damiana & żółw #1',
      pairingSecret: 'y',
      createdAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

    final uri = Uri.parse(
      buildPairingUri(host: 'h', port: 1, device: device, certFingerprintSha256Hex: 'fp'),
    );
    expect(uri.queryParameters['name'], 'Telefon Damiana & żółw #1');
  });
}
