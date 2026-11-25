import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:remotetester_host/config/host_config.dart';
import 'package:remotetester_host/security/secret_store.dart';
import 'package:remotetester_host/server/host_runtime.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'i18n.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';

/// Aplikacja okienkowa RemoteAppTester (Windows): zarządzanie projektami,
/// równoległe buildy w tle i serwer dla telefonów-pilotów — w jednym procesie.
/// Zamknięcie okna chowa ją do zasobnika; praca trwa dalej.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final startMinimized = args.contains('--minimized');

  // Katalog danych (konfiguracja, zaszyfrowana baza, logi) — wspólny z `rt`.
  final home = Directory(defaultHostHome())..createSync(recursive: true);
  Directory.current = home;
  UiSettings.load();

  await windowManager.ensureInitialized();
  await migrateLegacyAutostart();

  HostRuntime runtime;
  try {
    HostRuntime.ensureConfig();
    // Druga kopia aplikacji: poproś działającą o pokazanie okna i zakończ.
    if (await _showRunningInstance()) exit(0);
    runtime = await HostRuntime.start(onShow: _showWindow);
  } on Object catch (e) {
    await _showWindow();
    runApp(_StartupError(error: e.toString(), home: home.path));
    return;
  }

  final controller = AppController(runtime);
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'RemoteAppTester',
      size: Size(1280, 820),
      minimumSize: Size(960, 620),
      center: true,
    ),
    () async {
      await windowManager.setPreventClose(true);
      if (!startMinimized) await _showWindow();
    },
  );
  await _setupTray(controller);
  runApp(RemoteAppTesterApp(controller: controller));
}

Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

/// Czy działa już inna kopia (port lokalnego kanału zajęty) — jeśli tak,
/// prosi ją przez uwierzytelniony kanał 127.0.0.1 o pokazanie okna.
Future<bool> _showRunningInstance() async {
  final tokenFile = File(controlTokenPath);
  if (!tokenFile.existsSync()) return false;
  try {
    final config = HostConfig.load(hostConfigPath);
    final token = utf8.decode(SecretStore.forPlatform().read(tokenFile));
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.post('127.0.0.1', resolveControlPort(config), '/v1/show');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode == 200;
    } finally {
      client.close(force: true);
    }
  } on Object {
    return false;
  }
}

Future<void> _setupTray(AppController controller) async {
  await trayManager.setIcon('assets/tray_icon.ico');
  await trayManager.setToolTip('RemoteAppTester');
  Future<void> rebuildMenu() => trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: tr('Pokaż RemoteAppTester')),
        MenuItem(key: 'pause', label: controller.paused ? tr('Wznów przyjmowanie buildów') : tr('Wstrzymaj nowe buildy')),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: tr('Zakończ RemoteAppTester')),
      ]));
  await rebuildMenu();
  UiSettings.language.addListener(rebuildMenu);
  trayManager.addListener(_TrayHandler(controller, rebuildMenu));
}

class _TrayHandler with TrayListener {
  _TrayHandler(this.controller, this.rebuildMenu);
  final AppController controller;
  final Future<void> Function() rebuildMenu;

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await _showWindow();
      case 'pause':
        controller.togglePause();
        await rebuildMenu();
      case 'quit':
        await quitApp(controller);
    }
  }
}

/// Pełne zamknięcie: zatrzymanie buildów, serwera i bazy, potem okna.
Future<void> quitApp(AppController controller) async {
  await trayManager.destroy();
  await controller.runtime.shutdown();
  await windowManager.setPreventClose(false);
  await windowManager.destroy();
  exit(0);
}

class RemoteAppTesterApp extends StatefulWidget {
  const RemoteAppTesterApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<RemoteAppTesterApp> createState() => _RemoteAppTesterAppState();
}

class _RemoteAppTesterAppState extends State<RemoteAppTesterApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  /// Krzyżyk = schowaj do zasobnika (buildy i telefony działają dalej).
  @override
  void onWindowClose() => windowManager.hide();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([UiSettings.themeMode, UiSettings.language]),
      builder: (context, _) => MaterialApp(
        title: 'RemoteAppTester',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: UiSettings.themeMode.value,
        locale: UiSettings.locale,
        supportedLocales: [for (final code in supportedLanguageCodes) Locale(code)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Zmiana języka przebudowuje cały interfejs (teksty z tr()).
        builder: (context, child) => KeyedSubtree(key: ValueKey(UiSettings.code), child: child!),
        home: HomePage(controller: widget.controller),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error, required this.home});
  final String error;
  final String home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('RemoteAppTester nie mógł wystartować'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SelectableText(error),
              const SizedBox(height: 16),
              Text(tr('Katalog danych: {0}', [home])),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => exit(1), child: Text(tr('Zamknij'))),
            ],
          ),
        ),
      ),
    );
  }
}
