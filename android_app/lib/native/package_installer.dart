import 'dart:async';

import 'package:flutter/services.dart';

/// Wynik instalacji zgłoszony przez Androida (identyfikator: ścieżka pliku).
class InstallResult {
  const InstallResult(this.path, this.status, this.message);
  final String path;

  /// `success`, `pending` (czeka na potwierdzenie w oknie Androida) albo `failure`.
  final String status;
  final String? message;
}

/// Cienki `MethodChannel` do `PackageInstaller.Session` po stronie Kotlin
/// (docs/architektura-remote-build.md, sekcja 5: "własny, mały MethodChannel"
/// zamiast pakietów instalacyjnych trzecich stron).
class PackageInstallerChannel {
  static const MethodChannel _channel = MethodChannel('com.damiannass.remoteapptester/package_installer');
  static final _results = StreamController<InstallResult>.broadcast();
  static bool _listening = false;

  /// Wyniki instalacji z `InstallResultReceiver` (Kotlin).
  static Stream<InstallResult> get results {
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'installResult') return;
        final args = Map<String, Object?>.from(call.arguments as Map);
        _results.add(InstallResult(args['path'] as String, args['status'] as String, args['message'] as String?));
      });
    }
    return _results.stream;
  }

  /// Zwraca `applicationId` z pliku APK bez jego instalowania — używane do
  /// weryfikacji nazwy pakietu przed wywołaniem instalatora
  /// (docs/architektura-remote-build.md, sekcja 6.7).
  static Future<String?> readPackageName(String apkPath) {
    return _channel.invokeMethod<String>('readPackageName', {'path': apkPath});
  }

  /// Uruchamia sesję `PackageInstaller` i commituje ją — od tego momentu
  /// dalszy przebieg (systemowy prompt zgody na instalację z nieznanego
  /// źródła, potem właściwe potwierdzenie instalacji) jest obsługiwany przez
  /// natywny UI Androida, nie przez tę apkę. Zwraca się od razu po
  /// pomyślnym zacommitowaniu sesji, nie po faktycznym zakończeniu instalacji.
  ///
  /// [launchPackage] — jeśli podane, aplikacja zostanie uruchomiona zaraz po
  /// udanej instalacji, o ile system zgłosi dokładnie ten pakiet.
  static Future<void> installApk(String apkPath, {String? launchPackage}) {
    return _channel.invokeMethod<void>('installApk', {
      'path': apkPath,
      'launchPackage': ?launchPackage,
    });
  }

  /// Uruchamia zainstalowaną aplikację (przycisk "Uruchom"). `false`,
  /// gdy pakietu nie ma na telefonie albo nie został zainstalowany przez pilota
  /// (Android 11+ pokazuje nam tylko pakiety, które sami zainstalowaliśmy).
  static Future<bool> launchApp(String packageName) async {
    return await _channel.invokeMethod<bool>('launchApp', {'packageName': packageName}) ?? false;
  }

  /// Czy użytkownik dał już RemoteAppTesterowi jednorazową zgodę „Instalowanie
  /// nieznanych aplikacji” (bez niej każda instalacja zatrzyma się na
  /// ekranie ustawień Androida).
  static Future<bool> canRequestPackageInstalls() async {
    return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
  }

  /// Krótkie tony: lista (częstotliwość Hz, czas ms).
  static Future<void> playNotes(List<(double, int)> notes) async {
    try {
      await _channel.invokeMethod<void>('playNotes', {
        'notes': [for (final (f, ms) in notes) [f, ms]],
      });
    } on PlatformException {
      // Dźwięk to dodatek.
    }
  }

  /// Powiadomienie otwierające aplikację — tylko gdy jest w tle.
  static Future<void> notifyIfInBackground(String title, String text) async {
    try {
      await _channel.invokeMethod<void>('notifyIfInBackground', {'title': title, 'text': text});
    } on PlatformException {
      // Powiadomienie to dodatek — pasek w aplikacji i tak czeka.
    }
  }

  /// Otwiera ekran ustawień tej zgody dla RemoteAppTestera.
  static Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }
}
