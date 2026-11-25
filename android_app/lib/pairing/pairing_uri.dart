import '../settings/agent_settings.dart';

/// Odczyt kodu QR wygenerowanego na hoście (`host/lib/pairing/pairing_uri.dart`
/// — ten sam format URI, zaimplementowany niezależnie po obu stronach; zmiana
/// jednego wymaga odpowiedniej zmiany drugiego).
///
/// `remoteapptester://pair?host=<ip>&port=<port>&device_id=<id>&secret=<secret>&cert_fp=<sha256hex>&name=<nazwa>`
class ParsedPairing {
  const ParsedPairing({
    required this.address,
    required this.device,
    required this.certificate,
    required this.displayName,
  });

  final AgentAddress address;
  final DeviceCredentials device;
  final PinnedCertificate certificate;
  final String displayName;
}

/// Zwraca `null` jeśli tekst nie jest poprawnym URI parowania (w tym: brak
/// `cert_fp` — stare QR-y bez odcisku certyfikatu nie wystarczą, trzeba sparować ponownie,
/// świadomie, żeby nie dało się po cichu ominąć TLS pinning). Używane
/// zarówno przez skaner QR, jak i przycisk "Wklej ze schowka" (skan
/// zewnętrzną apką + wklejenie skopiowanego tekstu daje identyczny efekt,
/// bez potrzeby uprawnienia do kamery w tej apce).
ParsedPairing? tryParsePairingUri(String text) {
  final Uri uri;
  try {
    uri = Uri.parse(text.trim());
  } catch (_) {
    return null;
  }

  if (uri.scheme != 'remoteapptester' || uri.host != 'pair') return null;

  final host = uri.queryParameters['host'];
  final portStr = uri.queryParameters['port'];
  final deviceId = uri.queryParameters['device_id'];
  final secret = uri.queryParameters['secret'];
  final certFingerprint = uri.queryParameters['cert_fp'];
  final name = uri.queryParameters['name'];
  if (host == null ||
      portStr == null ||
      deviceId == null ||
      secret == null ||
      certFingerprint == null ||
      certFingerprint.isEmpty) {
    return null;
  }
  final port = int.tryParse(portStr);
  if (port == null) return null;

  return ParsedPairing(
    address: AgentAddress(host: host, port: port),
    device: DeviceCredentials(deviceId: deviceId, pairingSecret: secret),
    certificate: PinnedCertificate(fingerprintSha256Hex: certFingerprint),
    displayName: name ?? '',
  );
}
