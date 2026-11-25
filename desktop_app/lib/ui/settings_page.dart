import 'dart:io';

import 'package:flutter/material.dart';
import 'package:remotetester_host/cli/doctor.dart';
import 'package:remotetester_host/server/host_runtime.dart';

import 'package:remotetester_host/sound/tones.dart';

import '../app_controller.dart';
import '../sound_player.dart';
import 'widgets.dart';
import '../i18n.dart';

const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

/// Autostart przy logowaniu: wpis w HKCU\...\Run (bieżący użytkownik, bez
/// uprawnień administratora; nigdy usługa SYSTEM). Start schowany w zasobniku.
Future<bool> autostartEnabled() async {
  final r = await Process.run('reg', ['query', _runKey, '/v', 'RemoteAppTester']);
  return r.exitCode == 0;
}

/// Wpis autostartu sprzed zmiany nazwy aplikacji zamieniamy na nowy.
Future<void> migrateLegacyAutostart() async {
  // Wersja 0.3 startowała z Harmonogramu zadań: pętla PowerShell co 10 s uruchamiała
  // ...\Programs\RemoteTester\remotetester.exe, którego po zmianie nazwy już nie ma —
  // po każdym logowaniu sypała błędami. Usuwamy tylko zadanie wskazujące na stary katalog.
  final task = await Process.run('schtasks', ['/query', '/tn', 'RemoteTester', '/xml']);
  if (task.exitCode == 0 && '${task.stdout}'.toLowerCase().contains(r'\programs\remotetester\remotetester.exe')) {
    await Process.run('schtasks', ['/end', '/tn', 'RemoteTester']);
    await Process.run('schtasks', ['/delete', '/tn', 'RemoteTester', '/f']);
  }
  final legacy = await Process.run('reg', ['query', _runKey, '/v', 'RemoteTester']);
  if (legacy.exitCode != 0) return;
  await Process.run('reg', ['delete', _runKey, '/v', 'RemoteTester', '/f']);
  await setAutostart(true);
}

Future<void> setAutostart(bool enabled) async {
  final r = enabled
      ? await Process.run('reg', ['add', _runKey, '/v', 'RemoteAppTester', '/t', 'REG_SZ', '/d',
          '"${Platform.resolvedExecutable}" --minimized', '/f'])
      : await Process.run('reg', ['delete', _runKey, '/v', 'RemoteAppTester', '/f']);
  if (r.exitCode != 0) throw StateError(tr('Nie udało się zmienić autostartu: {0}', [r.stderr]));
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _autostart;
  List<CheckResult>? _doctor;

  @override
  void initState() {
    super.initState();
    autostartEnabled().then((v) => mounted ? setState(() => _autostart = v) : null);
  }

  Future<void> _setParallel(int value) async {
    final c = widget.controller;
    c.engine.maxParallel = value;
    // Zapis w konfiguracji, żeby przetrwał restart.
    final file = File(hostConfigPath);
    var text = file.readAsStringSync();
    final rx = RegExp(r'^max_parallel_builds:.*$', multiLine: true);
    text = rx.hasMatch(text) ? text.replaceFirst(rx, 'max_parallel_builds: $value') : '${text.trimRight()}\nmax_parallel_builds: $value\n';
    file.writeAsStringSync(text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final config = c.runtime.config;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(tr('Ustawienia'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SectionTitle(tr('Praca w tle')),
        SwitchListTile(
          title: Text(tr('Uruchamiaj przy logowaniu do Windows')),
          subtitle: Text(tr('Start schowany w zasobniku — telefony i agenci AI mogą zlecać buildy od razu.')),
          value: _autostart ?? false,
          onChanged: _autostart == null
              ? null
              : (v) async {
                  try {
                    await setAutostart(v);
                    setState(() => _autostart = v);
                  } on Object catch (e) {
                    if (context.mounted) showError(context, e.toString());
                  }
                },
        ),
        SwitchListTile(
          title: Text(tr('Wstrzymaj nowe buildy')),
          subtitle: Text(tr('Trwające buildy kończą się normalnie; nowe zlecenia (telefon, rt b) są odrzucane.')),
          value: c.paused,
          onChanged: (_) => c.togglePause(),
        ),
        ListTile(
          title: Text(tr('Ile projektów może budować się naraz')),
          subtitle: Text(tr('Ten sam projekt zawsze buduje się pojedynczo. Gradle zużywa dużo pamięci — 2 to bezpieczny wybór.')),
          trailing: DropdownButton<int>(
            value: c.engine.maxParallel,
            items: [for (var i = 1; i <= 4; i++) DropdownMenuItem(value: i, child: Text('$i'))],
            onChanged: (v) => v == null ? null : _setParallel(v),
          ),
        ),
        SectionTitle(tr('Wygląd')),
        ValueListenableBuilder<ThemeMode>(
          valueListenable: UiSettings.themeMode,
          builder: (context, mode, _) => SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(tr('Tryb ciemny')),
            subtitle: Text(tr('Ciemny granatowy motyw aplikacji.')),
            value: mode == ThemeMode.dark,
            onChanged: UiSettings.setDark,
          ),
        ),
        ValueListenableBuilder<AppLanguage>(
          valueListenable: UiSettings.language,
          builder: (context, language, _) => ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr('Język')),
            trailing: DropdownButton<AppLanguage>(
                  value: language,
                  items: [
                    DropdownMenuItem(value: AppLanguage.system, child: Text(tr('Jak w systemie'))),
                    for (final entry in languageNames.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (v) => v == null ? null : UiSettings.setLanguage(v),
                ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: SoundPlayer.enabled,
          builder: (context, on, _) => SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(tr('Odtwarzaj dźwięki')),
            subtitle: Text(tr('Krótkie tony: koniec builda, instalacja na telefonie, zgłoszenie agenta AI.')),
            value: on,
            onChanged: (v) {
              SoundPlayer.setEnabled(v);
              if (v) SoundPlayer.play(SoundEvent.installed);
            },
          ),
        ),
        SectionTitle(tr('Połączenie z telefonami')),
        ListTile(
          leading: const Icon(Icons.lan),
          title: Text(c.runtime.phoneServerMessage ?? ''),
          subtitle: Text(tr('Port {0} (tylko Tailscale) · lokalny kanał 127.0.0.1:{1}', [config.listenPort, c.runtime.controlPort ?? config.controlPort])),
        ),
        SectionTitle(tr('Pliki')),
        ListTile(
          leading: const Icon(Icons.folder_special),
          title: Text(tr('Domyślne miejsce na nowe projekty')),
          subtitle: Text(config.projectsRoot.path),
        ),
        ListTile(
          leading: const Icon(Icons.storage),
          title: Text(tr('Dane RemoteAppTester (zaszyfrowana baza, logi, instalki)')),
          subtitle: Text(Directory.current.path),
          trailing: TextButton(
            onPressed: () => Process.start('explorer.exe', [Directory.current.path]),
            child: Text(tr('Otwórz')),
          ),
        ),
        SectionTitle(tr('Diagnostyka')),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              setState(() => _doctor = null);
              final results = await Doctor(configPath: hostConfigPath).runAll();
              if (mounted) setState(() => _doctor = results);
            },
            icon: const Icon(Icons.health_and_safety),
            label: Text(tr('Sprawdź, czy wszystko jest gotowe')),
          ),
        ),
        for (final r in _doctor ?? const <CheckResult>[])
          ListTile(
            dense: true,
            leading: Icon(
              switch (r.status) {
                CheckStatus.ok => Icons.check_circle,
                CheckStatus.warning => Icons.warning_amber,
                CheckStatus.failed => Icons.error,
              },
              color: switch (r.status) {
                CheckStatus.ok => Colors.green,
                CheckStatus.warning => Colors.orange,
                CheckStatus.failed => Colors.red,
              },
            ),
            title: Text(r.name),
            subtitle: SelectableText(r.message),
          ),
      ],
    );
  }
}
