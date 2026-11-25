import 'device_registry.dart';

/// Format URI zakodowanego w kodzie QR do parowania — jedno zeskanowanie
/// niesie WSZYSTKO potrzebne (adres agenta + dane parowania + odcisk
/// certyfikatu TLS do przypięcia), więc telefon nie musi niczego przepisywać
/// ręcznie. Ten sam format jest niezależnie zaimplementowany po stronie
/// `android_app` (`android_app/lib/pairing/pairing_uri.dart`) — zmiana tutaj
/// wymaga odpowiedniej zmiany tam.
///
/// Parowanie WCIĄŻ jest wyłącznie lokalne — kod QR jest generowany na
/// ekranie tego komputera i wymaga fizycznej obecności przy nim, żeby go
/// zeskanować (docs/architektura-remote-build.md, sekcja 4a). Zamiana
/// ręcznego przepisywania na skan nie zmienia tej własności, tylko usuwa
/// ryzyko błędu przy przepisywaniu.
///
/// `remoteapptester://pair?host=<ip>&port=<port>&device_id=<id>&secret=<secret>&cert_fp=<sha256hex>&name=<nazwa>`
String buildPairingUri({
  required String host,
  required int port,
  required PairedDevice device,
  required String certFingerprintSha256Hex,
}) {
  final uri = Uri(
    scheme: 'remoteapptester',
    host: 'pair',
    queryParameters: {
      'host': host,
      'port': port.toString(),
      'device_id': device.deviceId,
      'secret': device.pairingSecret,
      'cert_fp': certFingerprintSha256Hex,
      'name': device.displayName,
    },
  );
  return uri.toString();
}
