import 'package:grpc/grpc.dart';

import 'agent_client.dart';
import '../i18n.dart';

/// Zamienia błąd połączenia/wywołania na komunikat zrozumiały bez wiedzy
/// technicznej (priorytet "prostota", docs/PROJECT_ASSUMPTIONS.md). Surowy
/// tekst błędu nadal jest dostępny w UI jako "szczegóły techniczne".
String friendlyErrorMessage(Object error) {
  if (error is CertificatePinningException) {
    return tr('Komputer przedstawił się innym certyfikatem niż przy parowaniu. Ze względów bezpieczeństwa połączenie przerwano. Jeśli RemoteAppTester był reinstalowany na komputerze, sparuj telefon ponownie (Ustawienia → Skanuj kod QR).');
  }
  if (error is GrpcError) {
    switch (error.code) {
      case StatusCode.unavailable:
      case StatusCode.deadlineExceeded:
        return tr('Nie można połączyć się z komputerem/serwerem.\n\nSprawdź po kolei:\n• czy RemoteAppTester na komputerze jest uruchomiony (remoteapptester serve),\n• czy Tailscale jest włączony na telefonie i na komputerze,\n• czy zapora na komputerze przepuszcza połączenie (port RemoteAppTester),\n• czy reguły dostępu (ACL) Tailscale pozwalają temu telefonowi na ten port (domyślnie 47051).');
      case StatusCode.unauthenticated:
        return tr('Komputer nie rozpoznaje tego telefonu — parowanie mogło zostać odwołane. Sparuj telefon ponownie (Ustawienia → Skanuj kod QR).');
      case StatusCode.resourceExhausted:
        return tr('Zbyt wiele prób w krótkim czasie. Odczekaj minutę i spróbuj ponownie.');
      case StatusCode.permissionDenied:
        return tr('Ten telefon nie ma dostępu do tej operacji.');
      case StatusCode.unimplemented:
        return tr('Komputer/serwer ma starszą wersję RemoteAppTester, która nie obsługuje tej funkcji. Zaktualizuj RemoteAppTester na komputerze/serwerze.');
    }
  }
  return tr('Wystąpił nieoczekiwany błąd. Spróbuj ponownie.');
}
