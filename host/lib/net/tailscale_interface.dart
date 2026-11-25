import 'dart:io';

/// Znajduje adres IPv4 interfejsu Tailscale na tej maszynie, żeby serwer
/// gRPC mógł nasłuchiwać WYŁĄCZNIE na nim, nigdy na `0.0.0.0`
/// (docs/architektura-remote-build.md, sekcja 4, punkt 1; docs/SECURITY.md).
///
/// Tailscale przydziela adresy z zakresu CGNAT `100.64.0.0/10`
/// (100.64.0.0 - 100.127.255.255), więc identyfikacja po zakresie adresu
/// jest wystarczająca i nie wymaga zależności od nazwy interfejsu (może się
/// różnić między wersjami Windows/sterowników).
class TailscaleInterfaceNotFoundException implements Exception {
  const TailscaleInterfaceNotFoundException();
  @override
  String toString() =>
      'Nie znaleziono aktywnego interfejsu Tailscale (adres 100.64.0.0/10). '
      'Sprawdź "tailscale status" — czy usługa jest uruchomiona i połączona.';
}

Future<InternetAddress> findTailscaleAddress() async {
  final interfaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );

  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      if (_isTailscaleCgnatRange(addr)) {
        return addr;
      }
    }
  }

  throw const TailscaleInterfaceNotFoundException();
}

bool _isTailscaleCgnatRange(InternetAddress addr) {
  final parts = addr.address.split('.').map(int.parse).toList();
  if (parts.length != 4) return false;
  // 100.64.0.0/10 == pierwszy oktet 100, drugi oktet w zakresie 64-127.
  return parts[0] == 100 && parts[1] >= 64 && parts[1] <= 127;
}
