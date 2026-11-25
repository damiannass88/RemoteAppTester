import 'package:local_auth/local_auth.dart';
import '../i18n.dart';
import 'app_lock.dart';

/// Rzucany, gdy użytkownik odrzuci/anuluje prompt biometrii/PIN, albo
/// uwierzytelnienie zawiedzie z innego powodu — UI powinien po prostu
/// przerwać wrażliwą akcję, nie traktować tego jak błąd sieci/agenta.
class SensitiveActionAuthException implements Exception {
  SensitiveActionAuthException(this.message);
  final String message;
  @override
  String toString() => tr('SensitiveActionAuthException: {0}', [message]);
}

/// Bramka biometria/PIN przed każdą wrażliwą akcją w apce — start builda,
/// instalacja APK (docs/architektura-remote-build.md, sekcja 6.5).
/// Utrata telefonu z odblokowanym ekranem systemowym (np. ktoś przejął
/// telefon po tym, jak właściciel go odblokował) nie powinna od razu dawać
/// dostępu do zdalnego builda/instalacji — to DODATKOWA bramka wewnątrz
/// samej apki, niezależna od blokady ekranu systemu.
class SensitiveActionGate {
  SensitiveActionGate([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Jeśli urządzenie nie ma skonfigurowanej ŻADNEJ blokady (biometria, PIN,
  /// wzór, hasło) — nie ma wobec czego uwierzytelnić, więc przepuszczamy bez
  /// blokowania używalności apki (to ograniczenie samego urządzenia, nie coś,
  /// co ta bramka może naprawić).
  Future<void> requireAuth(String reason) async {
    final supported = await _auth.isDeviceSupported();
    if (!supported) return;
    // Odcisk sprzed chwili (np. odblokowanie aplikacji) — nie pytamy drugi raz.
    if (AppLock.recentlyAuthenticated()) return;

    bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      // Jeden typ wyjątku dla UI niezależnie od tego, czy to zwykłe odrzucenie
      // przez authenticate() zwracające false, czy błąd platformy (lockout,
      // brak sprzętu, timeout) — patrz LocalAuthExceptionCode.
      throw SensitiveActionAuthException(tr('Uwierzytelnienie nieudane: {0}', [e.description ?? e.code.name]));
    }
    if (!ok) {
      throw SensitiveActionAuthException(tr('Uwierzytelnienie odrzucone lub anulowane.'));
    }
    AppLock.recordAuthentication();
  }
}
