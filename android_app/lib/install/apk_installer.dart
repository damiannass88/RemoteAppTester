import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native/package_installer.dart';
import '../net/agent_client.dart';
import '../security/sensitive_action_gate.dart';
import '../transfer/delta_downloader.dart';
import '../i18n.dart';

/// Wywoływane, gdy APK ma inną nazwę pakietu niż poprzednio zainstalowana
/// dla tego projektu — UI pyta użytkownika, czy kontynuować.
typedef ConfirmPackageChange = Future<bool> Function(String previous, String current);

class InstallCancelledException implements Exception {
  @override
  String toString() => tr('Instalacja anulowana.');
}

class InstallFailedException implements Exception {
  InstallFailedException(this.message);
  final String message;
  @override
  String toString() => tr('Android nie zainstalował aplikacji: {0}', [message]);
}

/// Pobieranie, instalacja i uruchamianie aplikacji zbudowanej na hoście —
/// wspólne dla ręcznego builda z telefonu i automatycznego dostarczania.
///
/// Zabezpieczenia bez zmian od Faz 3/4: SHA-256 w [downloadArtifact],
/// porównanie `applicationId` z poprzednią instalacją tego projektu,
/// biometria/PIN przed instalacją.
class ApkInstaller {
  ApkInstaller({SensitiveActionGate? authGate}) : _authGate = authGate ?? SensitiveActionGate();

  final SensitiveActionGate _authGate;

  static String _packageKey(String projectId) => 'installed_package_for_$projectId';
  static String _buildKey(String projectId) => 'installed_build_for_$projectId';

  /// Nazwa pakietu ostatnio zainstalowanego przez pilota dla projektu.
  static Future<String?> installedPackageFor(String projectId) async =>
      (await SharedPreferences.getInstance()).getString(_packageKey(projectId));

  /// Build ostatnio zainstalowany przez pilota dla projektu (`null` = nieznany).
  static Future<String?> installedBuildFor(String projectId) async =>
      (await SharedPreferences.getInstance()).getString(_buildKey(projectId));

  /// Trwające pobieranie per projekt — kolejne czeka, bo wszystkie składają ten sam plik bazowy.
  static final Map<String, Future<void>> _downloading = {};

  /// Pobiera instalkę — przy kolejnych wersjach tylko różnicę względem
  /// poprzedniej pobranej (patrz [downloadApkVia]). Dla jednego projektu zawsze po kolei.
  Future<File> download({
    required AgentClient client,
    required String buildId,
    required String projectId,
    DownloadProgress? onProgress,
  }) async {
    while (_downloading[projectId] != null) {
      await _downloading[projectId];
    }
    final done = Completer<void>();
    _downloading[projectId] = done.future;
    try {
      return await downloadApkVia(
        deltaFn: client.downloadDelta,
        fullFn: client.downloadArtifact,
        projectId: projectId,
        buildId: buildId,
        cacheDir: await getTemporaryDirectory(),
        baseDir: Directory('${(await getApplicationSupportDirectory()).path}/apk'),
        onProgress: onProgress,
      );
    } finally {
      _downloading.remove(projectId);
      done.complete();
    }
  }

  /// Zwraca nazwę zainstalowanego pakietu — dopiero gdy Android potwierdzi
  /// instalację. [onNeedsConfirmation] — Android pokazał okno „Zainstalować?”
  /// (albo powiadomienie, gdy RemoteAppTester jest w tle). Rzuca
  /// [InstallFailedException], gdy Android odmówi.
  Future<String> install({
    required String projectId,
    required String projectName,
    required File apk,
    required ConfirmPackageChange confirmPackageChange,
    String? buildId,
    bool launchAfterInstall = false,
    // `false` tylko dla automatycznych dostaw z `install: auto` — patrz
    // `DeliveryService` (świadoma zgoda właściciela hosta w remoteapptester.yaml).
    bool requireAuth = true,
    void Function()? onNeedsConfirmation,
  }) async {
    final packageName = await PackageInstallerChannel.readPackageName(apk.path);
    if (packageName == null) {
      throw StateError(tr('Nie udało się odczytać nazwy pakietu z pobranego pliku.'));
    }
    final previous = await installedPackageFor(projectId);
    if (previous != null && previous != packageName && !await confirmPackageChange(previous, packageName)) {
      throw InstallCancelledException();
    }

    if (requireAuth) await _authGate.requireAuth(tr('Potwierdź instalację: {0}', [projectName]));
    final done = Completer<void>();
    final sub = PackageInstallerChannel.results.where((r) => r.path == apk.path).listen((r) {
      switch (r.status) {
        case 'pending':
          onNeedsConfirmation?.call();
        case 'success':
          if (!done.isCompleted) done.complete();
        default:
          if (!done.isCompleted) done.completeError(InstallFailedException(r.message ?? tr('nieznany błąd')));
      }
    });
    try {
      await PackageInstallerChannel.installApk(apk.path, launchPackage: launchAfterInstall ? packageName : null);
      // Czekamy na potwierdzenie użytkownika w oknie Androida — do skutku albo odmowy.
      await done.future.timeout(const Duration(minutes: 30));
    } on TimeoutException {
      throw InstallFailedException(tr('brak potwierdzenia instalacji przez 30 minut'));
    } finally {
      await sub.cancel();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_packageKey(projectId), packageName);
    if (buildId != null) await prefs.setString(_buildKey(projectId), buildId);
    return packageName;
  }

  /// `false`, gdy aplikacji nie ma na telefonie (np. instalacja nie została
  /// jeszcze potwierdzona w oknie systemowym).
  static Future<bool> launch(String projectId) async {
    var packageName = await installedPackageFor(projectId);
    if (packageName == null) {
      final safeId = projectId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final apk = File('${(await getApplicationSupportDirectory()).path}/apk/$safeId.apk');
      if (apk.existsSync()) packageName = await PackageInstallerChannel.readPackageName(apk.path);
      if (packageName != null) {
        await (await SharedPreferences.getInstance()).setString(_packageKey(projectId), packageName);
      }
    }
    if (packageName == null) return false;
    return PackageInstallerChannel.launchApp(packageName);
  }
}
