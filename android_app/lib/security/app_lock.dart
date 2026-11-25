import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i18n.dart';

/// Czym telefon potrafi potwierdzić właściciela.
enum LockCapability {
  /// Jest zapisany odcisk palca (albo inna biometria) — przycisk „Odblokuj odciskiem”.
  biometric,

  /// Jest tylko PIN / wzór / hasło ekranu — działa, ale warto dodać odcisk palca.
  credentialOnly,

  /// Brak jakiejkolwiek blokady ekranu — nie ma czym uwierzytelnić; aplikacja
  /// prowadzi do ustawień Androida, żeby dodać odcisk palca (i PIN, który
  /// Android wtedy wymusza).
  none,
}

/// Wynik próby uwierzytelnienia.
enum AuthOutcome { ok, cancelled, lockedOut, notEnrolled, failed }

/// Blokada całej aplikacji odciskiem palca (z zapasowym PIN-em telefonu) —
/// na wzór blokady w aplikacjach mobilnych do zdalnej pracy z kodem:
///   - przy każdym uruchomieniu aplikacji,
///   - po powrocie z tła, jeśli aplikacja była w tle dłużej niż [backgroundTimeout],
///   - po [idleLimit] bez dotknięcia ekranu (np. telefon odłożony na biurko
///     z otwartym logiem builda).
///
/// Domyślnie WŁĄCZONA. Wyłączenie albo wydłużenie czasu wymaga potwierdzenia
/// odciskiem — ktoś, kto przejął odblokowany telefon, nie wyłączy blokady
/// jednym przełącznikiem.
///
/// To dodatkowa bramka nad [SensitiveActionGate] (build / instalacja), nie
/// zamiast niej. Połączenie z komputerem i dostawy w tle działają dalej, gdy
/// ekran jest zablokowany — blokada tylko zasłania interfejs.
class AppLock {
  AppLock._();

  static const _keyEnabled = 'app_lock_enabled';
  static const _keyTimeout = 'app_lock_background_seconds';

  /// Dozwolone czasy w tle (sekundy) przed ponowną blokadą. 0 = od razu.
  static const timeoutOptions = [0, 60, 300, 900];
  static const defaultTimeout = 60;

  /// Bez dotknięcia ekranu przez tyle czasu aplikacja blokuje się także na wierzchu.
  static const idleLimit = Duration(minutes: 15);

  /// Świeże uwierzytelnienie zwalnia z kolejnego pytania przez tyle czasu
  /// (żeby po odblokowaniu nie pytać od razu drugi raz przy starcie builda).
  static const reuseWindow = Duration(seconds: 30);

  static final enabled = ValueNotifier<bool>(true);
  static final backgroundTimeout = ValueNotifier<int>(defaultTimeout);
  static final locked = ValueNotifier<bool>(false);

  static LocalAuthentication _auth = LocalAuthentication();
  static const _channel = MethodChannel('com.damiannass.remoteapptester/package_installer');

  static DateTime? _lastAuthAt;
  static DateTime _lastActivity = DateTime.now();
  static bool _authInProgress = false;

  /// Na czas jednej sesji (do zamknięcia aplikacji): użytkownik bez blokady
  /// ekranu wybrał „Kontynuuj bez zabezpieczenia”.
  static bool _skippedThisSession = false;

  /// Prompt biometrii bywa osobnym oknem — Android wtedy pauzuje aktywność.
  /// Taka pauza nie jest „wyjściem do tła”.
  static bool get authInProgress => _authInProgress;

  @visibleForTesting
  static set authForTesting(LocalAuthentication auth) => _auth = auth;

  @visibleForTesting
  static void debugForgetRecentAuth() => _lastAuthAt = null;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_keyEnabled) ?? true;
    final saved = prefs.getInt(_keyTimeout) ?? defaultTimeout;
    backgroundTimeout.value = timeoutOptions.contains(saved) ? saved : defaultTimeout;
    // Zimny start = zawsze zablokowane (jak po uruchomieniu telefonu).
    locked.value = enabled.value;
  }

  static Future<LockCapability> capability() async {
    try {
      if (!await _auth.isDeviceSupported()) return LockCapability.none;
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.isEmpty ? LockCapability.credentialOnly : LockCapability.biometric;
    } on Object {
      return LockCapability.none;
    }
  }

  /// Uwierzytelnia odciskiem (PIN telefonu jako zapas — bez niego blokada
  /// czujnika po kilku nieudanych próbach odcięłaby właściciela od aplikacji).
  static Future<AuthOutcome> authenticate(String reason) async {
    if (_authInProgress) return AuthOutcome.cancelled;
    _authInProgress = true;
    try {
      final ok = await _auth.authenticate(localizedReason: reason);
      if (!ok) return AuthOutcome.cancelled;
      _lastAuthAt = DateTime.now();
      touch();
      return AuthOutcome.ok;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.uiUnavailable => AuthOutcome.cancelled,
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => AuthOutcome.lockedOut,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware => AuthOutcome.notEnrolled,
        _ => AuthOutcome.failed,
      };
    } on PlatformException {
      return AuthOutcome.failed;
    } finally {
      _authInProgress = false;
    }
  }

  /// Ekran blokady: odcisk → odblokowanie.
  static Future<AuthOutcome> unlock() async {
    final outcome = await authenticate(tr('Odblokuj RemoteAppTester'));
    if (outcome == AuthOutcome.ok) locked.value = false;
    return outcome;
  }

  /// Telefon bez żadnej blokady ekranu: nie ma czym uwierzytelnić, więc
  /// użytkownik może wejść — ale tylko do zamknięcia aplikacji.
  static Future<void> continueWithoutProtection() async {
    if (await capability() != LockCapability.none) return;
    _skippedThisSession = true;
    locked.value = false;
    touch();
  }

  /// Potwierdzenie zmiany ustawień blokady. Bez blokady ekranu w telefonie
  /// nie ma czego wymagać — wtedy zmiana przechodzi.
  static Future<bool> confirmChange() async {
    if (await capability() == LockCapability.none) return true;
    return await authenticate(tr('Potwierdź zmianę blokady aplikacji')) == AuthOutcome.ok;
  }

  static Future<bool> setEnabled(bool value) async {
    if (value == enabled.value) return true;
    // Włączenie nic nie osłabia — bez pytania. Wyłączenie — tylko odciskiem.
    if (!value && !await confirmChange()) return false;
    enabled.value = value;
    await (await SharedPreferences.getInstance()).setBool(_keyEnabled, value);
    return true;
  }

  static Future<bool> setBackgroundTimeout(int seconds) async {
    if (!timeoutOptions.contains(seconds) || seconds == backgroundTimeout.value) return true;
    // Krótszy czas = bezpieczniej, bez pytania. Dłuższy — tylko odciskiem.
    if (seconds > backgroundTimeout.value && !await confirmChange()) return false;
    backgroundTimeout.value = seconds;
    await (await SharedPreferences.getInstance()).setInt(_keyTimeout, seconds);
    return true;
  }

  /// Dotknięcie ekranu — liczy się jako aktywność.
  static void touch() => _lastActivity = DateTime.now();

  /// Czy niedawno było udane uwierzytelnienie (odblokowanie albo bramka akcji).
  static bool recentlyAuthenticated() {
    final at = _lastAuthAt;
    return at != null && DateTime.now().difference(at) < reuseWindow;
  }

  static void recordAuthentication() {
    _lastAuthAt = DateTime.now();
    touch();
  }

  /// Wywoływane po powrocie z tła.
  static void onResumedAfter(Duration away) {
    if (!enabled.value || locked.value || _skippedThisSession) return;
    // Okno odcisku z bramki akcji (build / instalacja) też potrafi „wyjść do tła”.
    if (recentlyAuthenticated()) return;
    if (away >=Duration(seconds: backgroundTimeout.value)) _lock();
  }

  /// Wywoływane co jakiś czas, gdy aplikacja jest na wierzchu.
  static void checkIdle() {
    if (!enabled.value || locked.value || _skippedThisSession || _authInProgress) return;
    if (DateTime.now().difference(_lastActivity) >= idleLimit) _lock();
  }

  /// „Zablokuj teraz”.
  static void lockNow() {
    if (enabled.value) _lock();
  }

  static void _lock() {
    // Klawiatura ani zaznaczone pole nie mogą zostać nad ekranem blokady.
    FocusManager.instance.primaryFocus?.unfocus();
    locked.value = true;
  }

  /// Otwiera ustawienia Androida, w których dodaje się odcisk palca (Android
  /// sam poprosi o PIN, jeśli telefon jeszcze go nie ma). Na starszych
  /// Androidach albo nakładkach bez tego ekranu — ustawienia zabezpieczeń.
  static Future<void> openEnrollment() async {
    try {
      await _channel.invokeMethod<void>('openBiometricEnroll');
    } on PlatformException {
      // Brak ekranu ustawień — UI i tak pokazuje instrukcję słowną.
    } on MissingPluginException {
      // Testy / platforma bez kanału.
    }
  }
}
