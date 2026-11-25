import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../config/host_config.dart';
import '../net/tailscale_interface.dart';
import '../pairing/device_registry.dart';
import '../pairing/pairing_uri.dart';
import '../project/agent_guide.dart';
import '../project/agent_signal.dart';
import '../project/artifact_finder.dart';
import '../project/build_profile.dart';
import '../project/templates.dart';
import '../generated/remote_tester.pbenum.dart';
import '../i18n.dart';
import '../security/secret_store.dart';
import '../security/tls_identity.dart';
import '../preview/preview_manager.dart';
import '../server/host_runtime.dart';
import '../store/project_store.dart';
import 'command_history.dart';
import 'doctor.dart';
import 'guide_content.dart';
import 'terminal_qr.dart';
import '../net/tailscale_policy.dart';
import '../sound/tones.dart';
import '../version.dart';

export '../version.dart';

class _Command {
  const _Command(this.name, this.alias, this.usage, this.summary);
  final String name;
  final String alias;
  final String usage;
  final String summary;
}

/// Polecenia z krótkimi aliasami (`rt b` = `remoteapptester build`).
final _commands = [
  _Command('init', 'i', tr('init --projects-root <katalog> [--port 47051]'), tr('tworzy config/host-config.yaml')),
  _Command('serve', 's', 'serve', tr('serwer bez okna (Linux / usługa)')),
  _Command('tunnel', 't', tr('tunnel ["nazwa"]'), tr('paruje telefon; gdy serwer nie działa — uruchamia go tutaj')),
  _Command('pair', 'p', tr('pair ["nazwa"]'), tr('paruje nowy telefon (kod QR + link)')),
  _Command('devices', 'dv', 'devices', tr('lista sparowanych telefonów')),
  _Command('tailscale-acl', 'acl', tr('tailscale-acl [--with <komputer>]...'), tr('reguły dostępu Tailscale (JSON) dla telefonów')),
  _Command('revoke', 'rv', tr('revoke <device_id>'), tr('odwołuje jeden telefon')),
  _Command('projects', 'ls', 'projects', tr('projekty RemoteAppTester i ich stan')),
  _Command('add', 'a', tr('add [folder] [--name "nazwa"]'), tr('przypisuje folder (wykrywa komendy, tworzy REMOTEAPPTESTER.md)')),
  _Command('remove', 'rm', tr('remove <folder|nazwa>'), tr('odpina projekt (pliki zostają)')),
  _Command('project', 'pr', tr('project [folder] | pr guide | pr import'), tr('komendy projektu, REMOTEAPPTESTER.md, propozycje agenta')),
  _Command('new', 'n', tr('new <nazwa> [--flutter]'), tr('nowy folder projektu (pusty albo projekt Flutter) i przypisanie')),
  _Command('options', 'o', tr('options [folder] [--install auto|ask|off] [--launch on|off] [--agent-build on|off] [--agent-push on|off] [--phone-build on|off] [--terminal on|off] [--preview on|off] [--preview-cmd "<komenda {port}>"|auto]'), tr('opcje projektu (bez przełączników: pokaż)')),
  _Command('log', 'lg', tr('log [folder]'), tr('historia buildów i log ostatniego')),
  _Command('methods', 'm', 'methods', tr('szablony komend dla rozpoznawanych technologii')),
  _Command('build', 'b', tr('build [folder] [--no-wait]'), tr('buduje projekt i wysyła na telefony')),
  _Command('signal', 'sg', tr('signal [-m "notatka"] [--build] [--wait] [--json]'), tr('agent AI: „skończyłem, są zmiany” (bez dostępu do RemoteAppTestera)')),
  _Command('push', 'pu', tr('push [plik.apk] [-m "notatka"] [--wait] [--installed] [--json]'), tr('agent AI: wysyła na telefony instalkę zbudowaną samodzielnie')),
  _Command('status', 'st', tr('status [folder] [--json]'), tr('agent AI: wynik ostatniego sygnału lub wysyłki')),
  _Command('history', 'h', tr('history [liczba]'), tr('ostatnio używane polecenia')),
  _Command('info', 'in', 'info', tr('przewodnik: bezpieczeństwo, agenci AI, sandbox, publikacja')),
  _Command('sound', 'so', tr('sound [on|off]'), tr('dźwięki (sygnał terminala po buildzie; to samo ustawienie co w oknie)')),
  _Command('language', 'la', tr('language [auto|pl|en|de|cs]'), tr('język poleceń (bez argumentu: pokaż)')),
  _Command('doctor', 'dr', 'doctor', tr('sprawdza, czy wszystko jest gotowe')),
  _Command('version', 'v', 'version', 'wersja'),
];

String? _resolveCommand(String word) =>
    _commands.where((c) => c.name == word || c.alias == word).firstOrNull?.name;

String _usage(CommandHistory history) {
  final width = _commands.map((c) => c.usage.length).reduce((a, b) => a > b ? a : b);
  final buffer = StringBuffer()
    ..writeln(tr('RemoteAppTester {0} — buduje aplikacje i dostarcza je na telefon testowy.', [hostVersion]))
    ..writeln(Platform.isWindows ? tr('Na Windows główna jest aplikacja okienkowa RemoteAppTester; rt to narzędzie dla terminala i agentów AI.') : '')
    ..writeln(tr('Użycie: rt [--home <katalog>] <polecenie> [opcje]      (rt = remoteapptester)'))
    ..writeln()
    ..writeln('  Skrót  ${tr('Polecenie').padRight(width)}  Opis')
    ..writeln('  ─────  ${'─' * width}  ${'─' * 40}');
  for (final c in _commands) {
    buffer.writeln('  ${c.alias.padRight(5)}  ${c.usage.padRight(width)}  ${c.summary}');
  }
  buffer
    ..writeln()
    ..writeln(tr('Dane hosta: --home <katalog> / REMOTEAPPTESTER_HOME (domyślnie {0}).', [defaultHostHome()]))
    ..writeln(tr('Agent AI po skończonej pracy: rt sg -m "co zmieniono" [--build]   (w folderze projektu).'))
    ..writeln(tr('Agent AI z własną instalką: rt push <plik.apk> -m "co zmieniono" --wait   (kody wyjścia: rt push --help).'));
  final table = history.renderTable();
  if (table != null) {
    buffer
      ..writeln()
      ..writeln(tr('Ostatnio używane:'))
      ..write(table);
  }
  return buffer.toString();
}

/// Punkt wejścia CLI (`bin/remoteapptester.dart`, `bin/rt.dart`). Zwraca kod wyjścia.
///
/// Parowanie pozostaje wyłącznie lokalne (docs/architektura-remote-build.md,
/// sekcja 4a): `pair`/`tunnel` działają tylko w terminalu na tej maszynie.
Future<int> runCli(List<String> rawArgs) async {
  final args = List.of(rawArgs);
  // Katalog wywołania — `--home` zmienia bieżący katalog procesu, a `rt b` bez
  // argumentu buduje folder wywołującego (wrapper Linux podaje go przez `--cwd`).
  final cwd = Directory(_takeOption(args, '--cwd') ?? Directory.current.path).absolute.path;
  final home = _takeOption(args, '--home') ?? defaultHostHome();
  final invertQr = args.remove('--invert-qr');
  if (args.isNotEmpty && const {'v', 'version', '--version'}.contains(args.first)) return _version();
  // Polecenia agenta nie dotykają danych RemoteAppTestera — tylko plików w folderze projektu.
  if (args.isNotEmpty) {
    switch (args.first) {
      case 'signal' || 'sg':
        return _signal(args.sublist(1), cwd);
      case 'push' || 'pu':
        return _push(args.sublist(1), cwd);
      case 'status' || 'st':
        return _status(args.sublist(1), cwd);
    }
  }
  final homeDir = Directory(home);
  if (!homeDir.existsSync()) {
    if (args.isNotEmpty && (args.first == 'init' || args.first == 'i')) {
      homeDir.createSync(recursive: true);
    } else {
      stderr.writeln(tr('Katalog danych RemoteAppTester nie istnieje: {0}\nUruchom aplikację RemoteAppTester albo: rt i --projects-root <katalog>', [home]));
      return 64;
    }
  }
  Directory.current = homeDir;
  loadHostLanguage();
  final history = CommandHistory(File('logs/cli_history.json'));

  if (args.isEmpty || const {'help', '--help', '-h'}.contains(args.first)) {
    stdout.write(_usage(history));
    return args.isEmpty ? 64 : 0;
  }
  if (args.first == '--version') args[0] = 'version';

  final word = args.removeAt(0);
  final command = _resolveCommand(word);
  if (command == null) {
    stderr.writeln(tr('Nieznane polecenie: {0}\n', [word]));
    stderr.write(_usage(history));
    return 64;
  }

  final ctx = _Context(cwd: cwd, invertQr: invertQr);
  final recorded = List.of(args); // polecenia niżej zużywają argumenty z listy
  int code;
  try {
    code = switch (command) {
      'init' => _init(args),
      'serve' => await _serve(),
      'tunnel' => await _tunnel(args, ctx),
      'pair' => await _pair(args, ctx),
      'devices' => _devices(),
      'tailscale-acl' => await _tailscaleAcl(args),
      'revoke' => _revoke(args),
      'projects' => _withStore(_projects),
      'add' => _withStore((s) => _add(s, args, ctx)),
      'remove' => _withStore((s) => _remove(s, args, ctx)),
      'project' => _withStore((s) => _project(s, args, ctx)),
      'new' => await _new(args, ctx),
      'options' => _withStore((s) => _options(s, args, ctx)),
      'log' => _withStore((s) => _log(s, args, ctx)),
      'info' => _info(),
      'language' => _language(args),
      'sound' => _sound(args),
      'methods' => _methods(),
      'build' => await _build(args, ctx),
      'signal' => await _signal(args, cwd),
      'push' => await _push(args, cwd),
      'status' => _status(args, cwd),
      'history' => _history(args, history),
      'doctor' => await _doctor(),
      'version' => _version(),
      _ => 64,
    };
  } on StateError catch (e) {
    stderr.writeln(e.message);
    code = 1;
  } on ProjectStoreException catch (e) {
    stderr.writeln(e.message);
    code = 1;
  } on ProfileException catch (e) {
    stderr.writeln(e.message);
    code = 1;
  } on TailscaleInterfaceNotFoundException catch (e) {
    stderr.writeln(e);
    code = 1;
  }
  if (command != 'history' && command != 'version') {
    final alias = _commands.firstWhere((c) => c.name == command).alias;
    history.record(['rt', alias, ...recorded.map(_quoteIfNeeded)].join(' '), code);
  }
  return code;
}

String _quoteIfNeeded(String arg) => arg.contains(' ') ? '"$arg"' : arg;

class _Context {
  const _Context({required this.cwd, required this.invertQr});
  final String cwd;
  final bool invertQr;

  /// Ścieżka z argumentu względem katalogu wywołania (domyślnie sam katalog).
  String resolve(String? path) => p.normalize(path == null ? cwd : p.absolute(cwd, path));
}

String? _takeOption(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  final value = args[i + 1];
  args.removeRange(i, i + 2);
  return value;
}

int _withStore(int Function(ProjectStore store) action) {
  final store = ProjectStore.open();
  try {
    return action(store);
  } finally {
    store.close();
  }
}

String? _withStorePath(String name) {
  final store = ProjectStore.open();
  try {
    return store.projects().where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull?.path;
  } finally {
    store.close();
  }
}

int _version() {
  stdout.writeln(hostVersion);
  return 0;
}

int _init(List<String> args) {
  final root = _takeOption(args, '--projects-root');
  final port = int.tryParse(_takeOption(args, '--port') ?? '$defaultListenPort');
  if (root == null || port == null || port <= 0 || port >= 65535) {
    stderr.writeln(tr('Użycie: rt i --projects-root <katalog> [--port 47051]'));
    return 64;
  }
  final configFile = File(hostConfigPath);
  if (configFile.existsSync()) {
    stdout.writeln(tr('Konfiguracja już istnieje ({0}) — bez zmian.', [configFile.path]));
    return 0;
  }
  Directory(root).createSync(recursive: true);
  configFile.parent.createSync(recursive: true);
  configFile.writeAsStringSync(HostConfig.render(projectsRoot: root, port: port));
  stdout.writeln(tr('Utworzono {0} (nowe projekty: {1}, port: {2}).', [configFile.path, root, port]));
  return 0;
}

Future<int> _serve() async {
  final runtime = await HostRuntime.start();
  stdout.writeln(tr('RemoteAppTester działa. {0}', [runtime.phoneServerMessage ?? '']));
  final sub = runtime.onStateChange.listen((_) => stdout.writeln(runtime.phoneServerMessage));
  stdout.writeln(tr('Lokalny wyzwalacz: 127.0.0.1:{0} (rt b w folderze projektu). Projekty: {1}.', [runtime.controlPort, runtime.store.projects().length]));
  await _waitForShutdownSignal();
  stdout.writeln(tr('Zatrzymywanie...'));
  await sub.cancel();
  await runtime.shutdown();
  return 0;
}

Future<int> _tunnel(List<String> args, _Context ctx) async {
  final config = HostConfig.load(hostConfigPath);
  final address = await findTailscaleAddress();
  final alreadyServing = await _isListening(address, config.listenPort);

  final pairCode = await _pair(args, ctx);
  if (pairCode != 0) return pairCode;

  if (alreadyServing) {
    stdout.writeln(tr('RemoteAppTester już działa (aplikacja albo usługa) — telefon połączy się od razu.'));
    return 0;
  }
  stdout.writeln(tr('Uruchamiam RemoteAppTester w tym oknie (Ctrl+C kończy).'));
  return _serve();
}

Future<int> _pair(List<String> args, _Context ctx) async {
  final config = HostConfig.load(hostConfigPath);
  final address = await findTailscaleAddress();
  // Ten sam certyfikat, którego używa serwer — odcisk w QR zgadza się z tym, co zobaczy telefon.
  final tls = TlsIdentity.loadOrGenerate(certFile: File('config/tls_cert.pem'), keyFile: File('config/tls_key.pem'));
  final name = args.isNotEmpty ? args.first : tr('Telefon {0}', [DateTime.now().toIso8601String().substring(0, 10)]);
  final device = DeviceRegistry(File('config/paired_devices.json')).register(name);
  final uri = buildPairingUri(
    host: address.address,
    port: config.listenPort,
    device: device,
    certFingerprintSha256Hex: tls.fingerprintSha256Hex,
  );

  stdout
    ..writeln()
    ..writeln(tr('Zeskanuj ten kod w aplikacji RemoteAppTester na telefonie (Skanuj kod QR):'))
    ..writeln()
    ..write(renderQrForTerminal(uri, invert: ctx.invertQr))
    ..writeln()
    ..writeln(tr('Nie da się zeskanować? W aplikacji wybierz "Wklej ze schowka" i wklej ten link:'))
    ..writeln(uri)
    ..writeln()
    ..writeln(tr('Telefon "{0}" sparowany (id: {1}).', [name, device.deviceId]))
    ..writeln(tr('Kod jest jednorazowy i ważny przez {0} min; telefon od razu wymienia go na własny sekret.', [pairingCodeValidity.inMinutes]))
    ..writeln(tr('Odwołanie telefonu: rt rv {0}', [device.deviceId]))
    ..writeln(tr('Uwaga: do czasu użycia kod daje dostęp do tego komputera — nie udostępniaj go nikomu.'));
  return 0;
}

int _devices() {
  final devices = DeviceRegistry(File('config/paired_devices.json')).all;
  if (devices.isEmpty) {
    stdout.writeln(tr('Brak sparowanych telefonów. Sparuj: rt p "nazwa"'));
    return 0;
  }
  for (final d in devices) {
    final status = d.revoked
        ? tr('ODWOŁANY')
        : d.pairingCodeExpired && d.pendingSecret == null
            ? tr('KOD WYGASŁ')
            : d.awaitingFirstUse
                ? tr('czeka na zeskanowanie')
                : tr('aktywny');
    stdout.writeln(tr('{0}  "{1}"  [{2}]  ostatnio: {3}', [d.deviceId, d.displayName, status, d.lastSeenAt.toLocal()]));
  }
  return 0;
}

/// Polityka dostępu dla panelu Tailscale: wszystkie telefony z sieci → ten komputer
/// (i komputery z `--with`), tylko na porcie RemoteAppTestera. JSON na stdout, wskazówki na stderr.
Future<int> _tailscaleAcl(List<String> args) async {
  final extra = <String>[];
  for (String? name; (name = _takeOption(args, '--with')) != null;) {
    extra.add(name!);
  }
  final Tailnet tailnet;
  try {
    tailnet = await readTailnet();
  } on TailscaleStatusException catch (e) {
    stderr.writeln(e.message);
    return 1;
  }
  final computers = [tailnet.self];
  for (final name in extra) {
    final match = tailnet.peers.where((d) => d.name.toLowerCase() == name.toLowerCase() || d.ip == name).firstOrNull;
    if (match == null) {
      stderr.writeln(tr('Nie ma takiego urządzenia w Tailscale: {0}. Dostępne komputery: {1}', [name, tailnet.computers.map((d) => d.name).join(', ')]));
      return 64;
    }
    computers.add(match);
  }
  final phones = tailnet.phones;
  final config = HostConfig.load(hostConfigPath);
  final port = config.listenPort;
  stdout.writeln(buildTailscalePolicy(phones: phones, computers: computers, port: port, previewPorts: config.preview.portRange));
  stderr
    ..writeln()
    ..writeln(tr('Telefony: {0}. Komputery: {1}. Port: {2}.', [phones.isEmpty ? '—' : phones.map((d) => d.name).join(', '), computers.map((d) => d.name).join(', '), port]))
    ..writeln(tr('Wklej w panelu Tailscale: Access controls → JSON editor. To zastępuje całą politykę — inne reguły dopisz ręcznie.'))
    ..writeln(tr('RemoteAppTester działa też na innym komputerze? Dodaj go: rt acl --with <nazwa>'));
  if (phones.isEmpty) stderr.writeln(tr('Brak telefonów w Tailscale — zaloguj Tailscale na telefonie tym samym kontem.'));
  return 0;
}

int _revoke(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(tr('Użycie: rt rv <device_id>   (lista: rt dv)'));
    return 64;
  }
  final ok = DeviceRegistry(File('config/paired_devices.json')).revoke(args.first);
  stdout.writeln(ok ? tr('Odwołano telefon {0}.', [args.first]) : tr('Nie znaleziono telefonu {0}.', [args.first]));
  return ok ? 0 : 1;
}

/// `rt n` — to samo co „Nowy pusty folder” / „Nowy projekt Flutter” w oknie.
Future<int> _new(List<String> args, _Context ctx) async {
  final flutter = args.remove('--flutter');
  if (args.isEmpty || !RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,79}$').hasMatch(args.first)) {
    stderr.writeln(tr('Użycie: rt n <nazwa> [--flutter]  (litery, cyfry, spacje, _ . -)'));
    return 64;
  }
  final name = args.first;
  final dir = Directory(p.join(HostConfig.load(hostConfigPath).projectsRoot.path, name));
  if (dir.existsSync()) {
    stderr.writeln(tr('Folder już istnieje: {0}', [dir.path]));
    return 1;
  }
  if (flutter) {
    final package = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceFirst(RegExp(r'^[0-9_]+'), '');
    final r = await Process.run('flutter', ['create', '--project-name', package.isEmpty ? 'app' : package, dir.path],
        runInShell: Platform.isWindows);
    if (r.exitCode != 0) {
      stderr.writeln(tr('flutter create nie powiódł się: {0}', [r.stderr]));
      return 1;
    }
  } else {
    dir.createSync(recursive: true);
  }
  return _withStore((s) => _add(s, [dir.path], ctx));
}

bool? _onOff(String? value, String flag) {
  if (value == null) return null;
  if (value != 'on' && value != 'off') throw StateError(tr('{0}: on albo off.', [flag]));
  return value == 'on';
}

/// `rt o` — opcje projektu: te same co w oknie i na telefonie.
int _options(ProjectStore store, List<String> args, _Context ctx) {
  final install = _takeOption(args, '--install');
  final launch = _onOff(_takeOption(args, '--launch'), '--launch');
  final agent = _onOff(_takeOption(args, '--agent-build'), '--agent-build');
  final push = _onOff(_takeOption(args, '--agent-push'), '--agent-push');
  final phone = _onOff(_takeOption(args, '--phone-build'), '--phone-build');
  final terminal = _onOff(_takeOption(args, '--terminal'), '--terminal');
  final preview = _onOff(_takeOption(args, '--preview'), '--preview');
  final previewCmd = _takeOption(args, '--preview-cmd');
  final project = _findProject(store, args.isEmpty ? null : args.first, ctx);
  if (project == null) {
    stderr.writeln(tr('To nie jest projekt RemoteAppTester. Lista: rt ls'));
    return 1;
  }
  if (install != null) {
    project.install = InstallPolicy.values.where((v) => v.name == install).firstOrNull ??
        (throw StateError(tr('--install: auto, ask albo off.')));
  }
  if (launch != null) project.launch = launch;
  if (agent != null) project.agentBuild = agent;
  if (push != null) project.agentPush = push;
  if (phone != null) project.phoneTrigger = phone;
  if (terminal != null) project.localTrigger = terminal;
  if (preview != null) project.preview = preview;
  if (previewCmd != null) project.previewCommand = previewCmd.trim() == 'auto' ? null : previewCmd;
  store.saveOptions(project);
  final recipe = previewRecipeFor(project);
  String word(bool v) => v ? 'on' : 'off';
  stdout
    ..writeln(project.name)
    ..writeln(tr('  --install      {0}', [project.install.name]))
    ..writeln(tr('  --launch       {0}', [word(project.launch)]))
    ..writeln(tr('  --agent-build  {0}', [word(project.agentBuild)]))
    ..writeln(tr('  --agent-push   {0}', [word(project.agentPush)]))
    ..writeln(tr('  --phone-build  {0}', [word(project.phoneTrigger)]))
    ..writeln(tr('  --terminal     {0}', [word(project.localTrigger)]))
    ..writeln(tr('  --preview      {0}', [word(project.preview)]))
    ..writeln(tr('  --preview-cmd  {0}', [
      recipe == null
          ? tr('(nie rozpoznano aplikacji web)')
          : '${recipe.command}${project.previewCommand == null ? tr('  (auto: {0})', [recipe.kind]) : ''}',
    ]));
  return 0;
}

/// `rt lg` — ostatnie buildy projektu i log najnowszego.
int _log(ProjectStore store, List<String> args, _Context ctx) {
  final project = _findProject(store, args.isEmpty ? null : args.first, ctx);
  if (project == null) {
    stderr.writeln(tr('To nie jest projekt RemoteAppTester. Lista: rt ls'));
    return 1;
  }
  final history = store.history(project.id, limit: 10);
  if (history.isEmpty) {
    stdout.writeln(tr('Jeszcze nic nie zbudowano.'));
    return 0;
  }
  for (final e in history) {
    stdout.writeln('${e.startedAt.toString().substring(0, 16)}  ${e.phase.padRight(9)}  ${e.profile.padRight(12)}  ${e.buildId}');
  }
  final file = File(p.join('logs', 'builds', '${history.first.buildId}.log'));
  if (file.existsSync()) {
    stdout
      ..writeln()
      ..write(file.readAsStringSync());
  }
  return 0;
}

/// `rt info` — przewodnik z zakładki Informacje.
int _info() {
  final guide = guides[hostLanguageCode] ?? guides['en']!;
  stdout
    ..writeln(guide.intro)
    ..writeln();
  for (final section in guide.sections) {
    stdout
      ..writeln('== ${section.title} ==')
      ..writeln();
    for (final item in section.items) {
      final tags = [if (item.important) guide.importantLabel, if (item.advanced) guide.advancedLabel];
      stdout
        ..writeln('* ${item.question}${tags.isEmpty ? '' : '  [${tags.join(', ')}]'}')
        ..writeln(item.answer.split('\n').map((l) => '  $l').join('\n'))
        ..writeln();
    }
  }
  return 0;
}

/// `rt la` — język poleceń; zapisany w katalogu danych.
int _sound(List<String> args) {
  if (args.isNotEmpty) {
    final on = _onOff(args.first, 'sound');
    if (on == null) return 64;
    saveSoundsEnabled(on);
  }
  stdout
    ..writeln(soundsEnabled() ? 'on' : 'off')
    ..writeln(soundEventsHelp());
  return 0;
}

int _language(List<String> args) {
  if (args.isNotEmpty) {
    final code = args.first == 'auto' ? 'system' : args.first;
    if (code != 'system' && !supportedLanguageCodes.contains(code)) {
      stderr.writeln(tr('Użycie: rt la [auto|pl|en|de|cs]'));
      return 64;
    }
    saveHostLanguage(code);
  }
  stdout.writeln(hostLanguageCode);
  return 0;
}

int _projects(ProjectStore store) {
  final projects = store.projects();
  if (projects.isEmpty) {
    stdout.writeln(tr('Brak projektów. Przypisz folder: rt a <folder>  (albo w aplikacji RemoteAppTester)'));
    return 0;
  }
  final nameWidth = projects.map((p) => p.name.length).fold(7, (a, b) => a > b ? a : b).clamp(7, 32);
  stdout
    ..writeln('  ${tr('Projekt').padRight(nameWidth)}  ${tr('Typ').padRight(16)}  ${tr('Wariant').padRight(12)}  REMOTEAPPTESTER.md')
    ..writeln('  ${'─' * nameWidth}  ${'─' * 16}  ${'─' * 12}  ${'─' * 22}');
  for (final pr in projects) {
    final guide = switch (store.guideState(pr).status) {
      GuideStatus.inSync => tr('aktualny'),
      GuideStatus.proposal => tr('PROPOZYCJA (rt pr import)'),
      GuideStatus.missing => tr('brak (rt pr guide)'),
      GuideStatus.invalid => tr('błąd w bloku komend'),
    };
    final name = pr.name.length > nameWidth ? '${pr.name.substring(0, nameWidth - 1)}…' : pr.name;
    stdout.writeln('  ${name.padRight(nameWidth)}  ${tr(kindName(pr.kind)).padRight(16)}  ${(pr.profile()?.name ?? '—').padRight(12)}  $guide');
  }
  return 0;
}

int _add(ProjectStore store, List<String> args, _Context ctx) {
  final name = _takeOption(args, '--name');
  final folder = Directory(ctx.resolve(args.isEmpty ? null : args.first));
  final record = store.add(folder, name: name);
  stdout
    ..writeln(tr('Przypisano: {0} ({1}) — {2}', [record.name, tr(kindName(record.kind)), record.path]))
    ..writeln(tr('Komendy (wykryte, wariant {0}):', [record.profile()?.name]));
  _printProfile(record.profile()!);
  stdout.writeln(tr('Instrukcja dla agentów AI: {0}', [agentGuideFile(record.directory).path]));
  return 0;
}

ProjectRecord? _findProject(ProjectStore store, String? arg, _Context ctx) {
  if (arg != null) {
    final byName = store.projects().where((p) => p.name.toLowerCase() == arg.toLowerCase() || p.id == arg).firstOrNull;
    if (byName != null) return byName;
  }
  return store.byPath(ctx.resolve(arg));
}

int _remove(ProjectStore store, List<String> args, _Context ctx) {
  final project = _findProject(store, args.isEmpty ? null : args.first, ctx);
  if (project == null) {
    stderr.writeln(tr('Nie znaleziono projektu. Lista: rt ls'));
    return 1;
  }
  store.remove(project.id);
  stdout.writeln(tr('Odpięto projekt {0} (pliki i REMOTEAPPTESTER.md zostają na dysku).', [project.name]));
  return 0;
}

int _project(ProjectStore store, List<String> args, _Context ctx) {
  final sub = args.isNotEmpty && const {'guide', 'g', 'import', 'im'}.contains(args.first) ? args.removeAt(0) : 'show';
  final project = _findProject(store, args.isEmpty ? null : args.first, ctx);
  if (project == null) {
    stderr.writeln(tr('Ten folder nie jest projektem RemoteAppTester. Przypisz go: rt a <folder>'));
    return 1;
  }
  switch (sub) {
    case 'guide' || 'g':
      store.writeAgentGuide(project);
      stdout.writeln(tr('Zapisano {0} z aktualnymi komendami.', [agentGuideFile(project.directory).path]));
      return 0;
    case 'import' || 'im':
      final state = store.guideState(project);
      if (state.status != GuideStatus.proposal) {
        stdout.writeln(state.status == GuideStatus.invalid
            ? tr('Blok komend w REMOTEAPPTESTER.md jest niepoprawny: {0}', [state.error])
            : tr('Brak nowej propozycji komend w REMOTEAPPTESTER.md.'));
        return state.status == GuideStatus.invalid ? 1 : 0;
      }
      // Agent AI uruchamia polecenia bez interaktywnej konsoli — gdyby zgodę dało się
      // podać przez potok (`echo t | rt pr import`), agent zatwierdziłby własne komendy.
      if (!stdin.hasTerminal) {
        stderr.writeln(tr('Nowe komendy z REMOTEAPPTESTER.md zatwierdza człowiek: w aplikacji RemoteAppTester (projekt → Komendy → Przejrzyj) albo w interaktywnym terminalu. Odmowa bez konsoli.'));
        return 1;
      }
      stdout.writeln(tr('Propozycja z REMOTEAPPTESTER.md (zastąpi obecne komendy):'));
      for (final pr in state.profiles) {
        _printProfile(pr);
      }
      stdout.write(tr('Zatwierdzić i zapisać w bazie RemoteAppTester? [t/N] '));
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (!const {'t', 'tak', 'y', 'yes', 'j', 'ja', 'a', 'ano'}.contains(answer)) {
        stdout.writeln(tr('Bez zmian.'));
        return 1;
      }
      store.importGuide(project.id, state);
      stdout.writeln(tr('Zapisano. Kolejne buildy użyją nowych komend.'));
      return 0;
    default:
      stdout.writeln('${project.name} — ${tr(kindName(project.kind))} — ${project.path}');
      stdout.writeln(tr('Instalacja: {0}, uruchom po instalacji: {1}, telefony: {2}', [project.install.name, project.launch ? tr('tak') : tr('nie'), project.targets.isEmpty ? tr('wszystkie') : project.targets.join(', ')]));
      for (final pr in project.profiles) {
        _printProfile(pr, isDefault: pr.name == project.profile()?.name);
      }
      final state = store.guideState(project);
      if (state.status == GuideStatus.proposal) {
        stdout.writeln(tr('\nREMOTEAPPTESTER.md zawiera NOWĄ propozycję komend — przejrzyj: rt pr import'));
      }
      return 0;
  }
}

void _printProfile(BuildProfile profile, {bool isDefault = false}) {
  stdout.writeln('  [${profile.name}]${isDefault ? tr(' (domyślny)') : ''}');
  for (final s in profile.steps) {
    stdout.writeln('    ${s.name}: ${s.run}');
  }
  stdout.writeln(tr('    instalka: {0}', [profile.artifact]));
}

int _methods() {
  for (final kind in [ProjectKind.FLUTTER, ProjectKind.ANDROID_GRADLE, ProjectKind.REACT_NATIVE, ProjectKind.CAPACITOR]) {
    stdout.writeln('${tr(kindName(kind))}:');
    for (final profile in templateProfiles(kind)) {
      _printProfile(profile);
    }
  }
  stdout.writeln(tr('\nTe komendy są wpisywane przy przypisaniu folderu; zmienisz je w aplikacji albo przez REMOTEAPPTESTER.md.'));
  return 0;
}

/// `rt b [folder]` — zleca build działającemu RemoteAppTesterowi przez lokalny kanał
/// (127.0.0.1 + token) i pokazuje postęp. Kod wyjścia = wynik builda.
Future<int> _build(List<String> args, _Context ctx) async {
  final noWait = args.remove('--no-wait');
  // Folder albo nazwa projektu, jak w `rt o` i `rt lg`.
  var folder = ctx.resolve(args.isEmpty ? null : args.first);
  if (args.isNotEmpty && !Directory(folder).existsSync()) {
    final byName = _withStorePath(args.first);
    if (byName != null) folder = byName;
  }
  final config = HostConfig.load(hostConfigPath);
  final tokenFile = File(controlTokenPath);
  if (!tokenFile.existsSync()) {
    stderr.writeln(tr('RemoteAppTester nie był jeszcze uruchomiony. Uruchom aplikację RemoteAppTester (albo: rt s).'));
    return 1;
  }
  final token = utf8.decode(SecretStore.forPlatform().read(tokenFile));
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  final controlPort = resolveControlPort(config);
  final base = Uri.parse('http://127.0.0.1:$controlPort');
  try {
    final start = await _call(client, 'POST', base.resolve('/v1/build'), token, body: {'path': folder});
    if (start.$1 != 200) {
      stderr.writeln(tr('Odrzucone: {0}', [start.$2['error']]));
      return 1;
    }
    final buildId = start.$2['build_id'] as String;
    stdout.writeln('Build ${start.$2['project']} (${start.$2['method']}) — id $buildId');
    if (noWait) return 0;

    var next = 0;
    var lastPhase = '';
    while (true) {
      final r = await _call(client, 'GET', base.resolve('/v1/builds/$buildId/events?from=$next'), token);
      if (r.$1 != 200) {
        stderr.writeln('Błąd podglądu: ${r.$2['error']}');
        return 1;
      }
      for (final e in (r.$2['events'] as List).cast<Map<String, dynamic>>()) {
        final phase = e['phase'] as String;
        if (phase != lastPhase) {
          stdout.writeln('==> $phase${(e['progress'] as int) > 0 ? ' ${e['progress']}%' : ''}${(e['queue'] as int) > 0 ? ' (kolejka: ${e['queue']})' : ''}');
          lastPhase = phase;
        }
        final log = e['log'] as String;
        if (log.isNotEmpty) stdout.writeln('    $log');
      }
      next = r.$2['next'] as int;
      if (r.$2['finished'] == true) {
        final phase = r.$2['phase'];
        stdout.writeln(phase == 'DONE' ? tr('Gotowe — wybrane telefony dostaną nową wersję.') : tr('Build zakończony: {0}', [phase]));
        terminalBell(phase == 'DONE' ? SoundEvent.buildDone : SoundEvent.buildFailed);
        return phase == 'DONE' ? 0 : 1;
      }
    }
  } on SocketException {
    stderr.writeln(tr('RemoteAppTester nie działa (127.0.0.1:{0}). Uruchom aplikację RemoteAppTester (albo: rt s).', [controlPort]));
    return 1;
  } finally {
    client.close(force: true);
  }
}

Future<(int, Map<String, dynamic>)> _call(HttpClient client, String method, Uri uri, String token,
    {Map<String, Object?>? body}) async {
  final request = await client.openUrl(method, uri);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  final json = text.isEmpty ? <String, dynamic>{} : jsonDecode(text) as Map<String, dynamic>;
  return (response.statusCode, json);
}

/// `rt sg` — zostawia w folderze projektu plik `.remoteapptester-signal`.
/// Nie czyta tokenu ani bazy: RemoteAppTester sam zauważy plik, oznaczy projekt
/// („nowe zmiany”) i — jeśli opcje projektu na to pozwalają — zbuduje i wyśle.
Future<int> _signal(List<String> args, String cwd) async {
  final message = _takeOption(args, '-m') ?? _takeOption(args, '--message');
  final build = args.remove('--build');
  final wait = _AgentWait.take(args, defaultTimeout: const Duration(hours: 1));
  if (wait == null) return 64;
  final start = Directory(args.isEmpty ? cwd : p.absolute(cwd, args.first));
  final root = start.existsSync() ? findProjectRoot(start) : null;
  if (root == null) {
    stderr.writeln(tr('To nie jest folder projektu RemoteAppTester (brak {0} w {1} i wyżej).', [agentGuideFileName, start.path]));
    return 1;
  }
  final request = _newRequestId();
  writeAgentSignal(root, build: build, message: message, request: request);
  if (wait.enabled) return _waitForResult(root, request, wait);
  if (wait.json) {
    stdout.writeln(jsonEncode({'request': request, 'state': 'sent', 'project_dir': root.path}));
    return 0;
  }
  stdout.writeln(build
      ? tr('Sygnał wysłany: zmiany gotowe, prośba o build ({0}). RemoteAppTester zbuduje i wyśle, jeśli opcja projektu „Sygnał agenta uruchamia build” jest włączona.', [root.path])
      : tr('Sygnał wysłany: zmiany gotowe do zbudowania ({0}).', [root.path]));
  stdout.writeln(tr('Wynik: rt st   (albo następnym razem dodaj --wait).'));
  return 0;
}

/// Pomoc `rt push --help` (także kody wyjścia `--wait` dla `rt sg`).
String _pushHelp() => [
      'rt push [plik.apk] [-m "notatka"] [--wait] [--installed] [--timeout <s>] [--json]',
      '',
      tr('Wysyła na sparowane telefony instalkę APK zbudowaną przez agenta (bez sudo i bez dostępu do RemoteAppTestera: przez plik .remoteapptester-signal w folderze projektu).'),
      tr('  plik.apk     domyślnie najnowszy build/**/*.apk w projekcie; plik spoza folderu projektu jest kopiowany do .remoteapptester-push.apk'),
      tr('  --wait       czeka na wynik (domyślnie do 600 s, --timeout zmienia)'),
      tr('  --installed  czeka też, aż telefony potwierdzą instalację'),
      tr('  --json       wynik jako jedna linia JSON (dla agentów i skryptów)'),
      tr('Kody wyjścia: 0 wysłane (z --installed: także potwierdzone), 1 odrzucone lub błąd, 2 przekroczony czas, 3 RemoteAppTester nie odebrał sygnału (nie działa?), 4 gotowe, ale żaden telefon nie dostał wersji, 64 złe użycie.'),
      '',
    ].join('\n');

/// `rt push` — agent zbudował instalkę sam i chce ją dostać na telefony testowe.
Future<int> _push(List<String> args, String cwd) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(_pushHelp());
    return 0;
  }
  final message = _takeOption(args, '-m') ?? _takeOption(args, '--message');
  final wait = _AgentWait.take(args, defaultTimeout: const Duration(minutes: 10));
  if (wait == null || args.length > 1) {
    stderr.write(_pushHelp());
    return 64;
  }
  final given = args.isEmpty ? null : File(p.absolute(cwd, args.first));
  final root = findProjectRoot(Directory(cwd)) ?? (given == null ? null : findProjectRoot(given.parent));
  if (root == null) {
    stderr.writeln(tr('To nie jest folder projektu RemoteAppTester (brak {0} w {1} i wyżej).', [agentGuideFileName, cwd]));
    return 1;
  }
  final apk = given ?? _newestApk(root);
  if (apk == null || !apk.existsSync()) {
    stderr.writeln(apk == null
        ? tr('Nie znaleziono instalki (build/**/*.apk) w {0} — podaj plik: rt push <plik.apk>', [root.path])
        : tr('Nie ma takiego pliku: {0}', [apk.path]));
    return 1;
  }
  final String relative;
  try {
    final rootReal = p.normalize(root.resolveSymbolicLinksSync());
    final real = p.normalize(apk.resolveSymbolicLinksSync());
    if (p.isWithin(rootReal, real)) {
      relative = p.relative(real, from: rootReal).replaceAll(r'\', '/');
    } else {
      // RemoteAppTester czyta tylko folder projektu — kopia obok sygnału.
      apk.copySync(p.join(root.path, agentPushFileName));
      relative = agentPushFileName;
    }
    resolvePushedArtifact(root, relative); // od razu czytelny błąd dla agenta
  } on ProfileException catch (e) {
    stderr.writeln(e.message);
    return 1;
  } on FileSystemException catch (e) {
    stderr.writeln(tr('Nie można odczytać instalki: {0}', [e.message]));
    return 1;
  }
  final request = _newRequestId();
  writeAgentSignal(root, message: message, deliver: relative, request: request);
  if (wait.enabled) return _waitForResult(root, request, wait);
  if (wait.json) {
    stdout.writeln(jsonEncode({'request': request, 'state': 'sent', 'project_dir': root.path, 'deliver': relative}));
  } else {
    stdout
      ..writeln(tr('Instalka zgłoszona: {0} ({1}).', [relative, root.path]))
      ..writeln(tr('Wynik: rt st   (albo następnym razem dodaj --wait).'));
  }
  return 0;
}

/// `rt st` — ostatni wynik zapisany przez RemoteAppTester w folderze projektu.
int _status(List<String> args, String cwd) {
  final json = args.remove('--json');
  final start = Directory(args.isEmpty ? cwd : p.absolute(cwd, args.first));
  final root = start.existsSync() ? findProjectRoot(start) : null;
  if (root == null) {
    stderr.writeln(tr('To nie jest folder projektu RemoteAppTester (brak {0} w {1} i wyżej).', [agentGuideFileName, start.path]));
    return 1;
  }
  final status = readAgentStatus(root);
  if (status == null) {
    if (json) stdout.writeln(jsonEncode({'state': 'none'}));
    stderr.writeln(tr('Brak wyniku — RemoteAppTester nie odebrał jeszcze żadnego sygnału z tego folderu.'));
    return 1;
  }
  json ? stdout.writeln(jsonEncode(status)) : _printStatus(status);
  return const {'done', 'queued', 'running'}.contains(status['state']) ? 0 : 1;
}

File? _newestApk(Directory root) {
  for (final pattern in const ['build/**/*.apk', '**/*.apk']) {
    final found = findArtifact(root, pattern);
    if (found != null && p.basename(found.path) != agentPushFileName) return found;
  }
  return null;
}

String _newRequestId() {
  final random = Random.secure();
  return List.generate(8, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// `--wait`, `--installed`, `--timeout <s>`, `--json` poleceń agenta.
class _AgentWait {
  const _AgentWait({required this.enabled, required this.installed, required this.json, required this.timeout});
  final bool enabled;
  final bool installed;
  final bool json;
  final Duration timeout;

  static _AgentWait? take(List<String> args, {required Duration defaultTimeout}) {
    final installed = args.remove('--installed');
    final enabled = args.remove('--wait') || installed;
    final json = args.remove('--json');
    final raw = _takeOption(args, '--timeout');
    final seconds = raw == null ? defaultTimeout.inSeconds : int.tryParse(raw);
    if (seconds == null || seconds <= 0) {
      stderr.writeln(tr('--timeout: liczba sekund większa od zera.'));
      return null;
    }
    return _AgentWait(enabled: enabled, installed: installed, json: json, timeout: Duration(seconds: seconds));
  }
}

/// Ile czekamy, aż RemoteAppTester odbierze sygnał (zwykle kilka sekund).
Duration agentPickupTimeout = const Duration(seconds: 30);

/// Czeka na wynik zlecenia [request] w pliku statusu. Kody wyjścia — [_pushHelp].
Future<int> _waitForResult(Directory root, String request, _AgentWait wait) async {
  final started = DateTime.now();
  String? lastState;
  while (true) {
    final elapsed = DateTime.now().difference(started);
    final status = readAgentStatus(root);
    final mine = status != null && status['request'] == request;
    if (mine) {
      final state = status['state'] as String?;
      final devices = (status['devices'] as List? ?? const []).cast<Map<String, Object?>>();
      final finished = switch (state) {
        'done' => !wait.installed || devices.every((d) => d['handled'] == true),
        'rejected' || 'failed' || 'cancelled' => true,
        _ => false,
      };
      if (!wait.json && state != lastState) {
        stdout.writeln('==> $state: ${status['message']}');
        lastState = state;
      }
      if (finished) {
        wait.json ? stdout.writeln(jsonEncode(status)) : _printStatus(status, header: false);
        if (state != 'done') return 1;
        return devices.isEmpty ? 4 : 0;
      }
    } else if (elapsed > agentPickupTimeout && !agentSignalConsumed(root, request)) {
      final text = tr('RemoteAppTester nie odebrał sygnału w {0} s — czy działa? (Linux: systemctl status remoteapptester; Windows: aplikacja RemoteAppTester)', [agentPickupTimeout.inSeconds]);
      wait.json ? stdout.writeln(jsonEncode({'request': request, 'state': 'not_picked_up', 'message': text})) : stderr.writeln(text);
      return 3;
    }
    if (elapsed > wait.timeout) {
      final text = tr('Przekroczony czas oczekiwania ({0} s). Wynik później: rt st', [wait.timeout.inSeconds]);
      wait.json
          ? stdout.writeln(jsonEncode({if (mine) ...status, 'request': request, 'state': 'timeout', 'message': text}))
          : stderr.writeln(text);
      return 2;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
}

void _printStatus(Map<String, Object?> status, {bool header = true}) {
  if (header) {
    stdout
      ..writeln('${status['project'] ?? ''}  ${status['action'] ?? ''}  ${status['state'] ?? ''}  ${status['updated_at'] ?? ''}')
      ..writeln('  ${status['message'] ?? ''}');
  }
  for (final d in (status['devices'] as List? ?? const []).cast<Map<String, Object?>>()) {
    final online = switch (d['online']) { true => ', online', false => tr(', offline — dostanie po połączeniu'), _ => '' };
    stdout.writeln(tr('  telefon {0} ({1}): {2}{3}', [d['name'] ?? d['id'], d['id'], d['handled'] == true ? tr('potwierdził') : tr('wysłano'), online]));
  }
  final tail = (status['log_tail'] as List? ?? const []).cast<String>();
  if (tail.isNotEmpty) {
    stdout.writeln(tr('  Końcówka logu:'));
    for (final line in tail) {
      stdout.writeln('    $line');
    }
  }
}

int _history(List<String> args, CommandHistory history) {
  final count = int.tryParse(args.isEmpty ? '' : args.first) ?? 20;
  final table = history.renderTable(count: count.clamp(1, 50));
  stdout.write(table ?? tr('Brak historii poleceń.\n'));
  return 0;
}

Future<int> _doctor() async {
  final results = await Doctor(configPath: hostConfigPath).runAll();
  for (final r in results) {
    final mark = switch (r.status) {
      CheckStatus.ok => '[OK]  ',
      CheckStatus.warning => tr('[UWAGA]'),
      CheckStatus.failed => tr('[BŁĄD]'),
    };
    stdout.writeln('$mark ${r.name}: ${r.message}');
  }
  final failed = results.where((r) => r.status == CheckStatus.failed).length;
  stdout.writeln(failed == 0 ? tr('\nWszystko gotowe.') : tr('\nDo poprawienia: {0}. Po poprawkach uruchom ponownie: rt dr', [failed]));
  return failed == 0 ? 0 : 1;
}

Future<bool> _isListening(InternetAddress address, int port) async {
  try {
    final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 2));
    socket.destroy();
    return true;
  } on SocketException {
    return false;
  }
}

/// SIGINT (Ctrl+C) wszędzie; SIGTERM (systemd stop) tylko na POSIX.
Future<void> _waitForShutdownSignal() {
  final done = Completer<void>();
  final subs = <StreamSubscription<ProcessSignal>>[];
  void finish(ProcessSignal _) {
    if (done.isCompleted) return;
    for (final s in subs) {
      s.cancel();
    }
    done.complete();
  }

  subs.add(ProcessSignal.sigint.watch().listen(finish));
  if (!Platform.isWindows) subs.add(ProcessSignal.sigterm.watch().listen(finish));
  return done.future;
}
