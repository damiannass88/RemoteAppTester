import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../build/log_redactor.dart';
import '../build/operation_log.dart';
import '../generated/remote_tester.pb.dart';
import '../i18n.dart';
import '../net/tailscale_policy.dart';
import '../server/kill_switch.dart';
import '../store/project_store.dart';
import 'preview_proxy.dart';
import 'preview_recipe.dart';

/// Plik zgłoszeń z podglądu w folderze projektu — pisze RemoteAppTester, czyta agent AI.
const previewFeedbackFileName = '.remoteapptester-feedback.md';

/// Ustawienia podglądu z `host-config.yaml`.
class PreviewSettings {
  const PreviewSettings({
    this.firstPort = 47100,
    this.portCount = 10,
    this.tailscaleServe = true,
    this.idleTimeout = const Duration(minutes: 30),
    this.startTimeout = const Duration(minutes: 5),
  });

  /// Porty w sieci Tailscale: [firstPort] … [firstPort] + [portCount] - 1 (jeden na podgląd).
  final int firstPort;
  final int portCount;

  /// Najpierw `tailscale serve` (zwykły certyfikat HTTPS *.ts.net); bez niego — proxy
  /// hosta na adresie Tailscale z certyfikatem z parowania (telefon sprawdza odcisk).
  final bool tailscaleServe;
  final Duration idleTimeout;
  final Duration startTimeout;

  /// Zakres portów do reguły ACL Tailscale, np. `47100-47109`.
  String get portRange => portCount == 1 ? '$firstPort' : '$firstPort-${firstPort + portCount - 1}';
}

/// Komenda podglądu projektu: wpisana na komputerze albo z receptury hosta.
PreviewRecipe? previewRecipeFor(ProjectRecord project) {
  final custom = project.previewCommand?.trim();
  final detected = detectPreviewRecipe(project.directory);
  if (custom != null && custom.isNotEmpty) {
    return PreviewRecipe(kind: detected?.kind ?? tr('Własna komenda'), command: custom);
  }
  return detected;
}

/// Uruchomione w tym hoście podglądy aplikacji web (najwyżej jeden na projekt).
class PreviewManager {
  PreviewManager({
    required this.store,
    required this.killSwitch,
    required this.operationLog,
    required this.tailscaleAddress,
    this.settings = const PreviewSettings(),
    this.tls,
    Directory? scriptDir,
  }) : scriptDir = scriptDir ?? Directory.systemTemp {
    _idle = Timer.periodic(const Duration(minutes: 1), (_) => _stopIdle());
    killSwitch.addListener(_onKillSwitch);
  }

  final ProjectStore store;
  final KillSwitch killSwitch;
  final OperationLog operationLog;

  /// Adres hosta w sieci Tailscale (`null` = jeszcze brak połączenia).
  final InternetAddress? Function() tailscaleAddress;
  final PreviewSettings settings;

  /// Certyfikat hosta (ten sam co serwer dla telefonów) — dla proxy bez `tailscale serve`.
  final SecurityContext? tls;
  final Directory scriptDir;
  final _sessions = <String, _Session>{};
  late final Timer _idle;

  bool isRunning(String projectId) {
    final s = _sessions[projectId];
    return s != null && !s.finished;
  }

  /// Uruchamia podgląd (albo dołącza do trwającego) i zwraca jego zdarzenia: najpierw
  /// stan i ostatnie linie logu, potem bieżące — aż do zakończenia podglądu albo
  /// anulowania strumienia (to drugie podglądu nie zatrzymuje).
  Stream<PreviewEvent> watch(ProjectRecord project, {required String requester}) {
    var session = _sessions[project.id];
    if (session == null || session.finished) {
      if (killSwitch.isPaused) throw StateError(tr('Komputer aktualnie nie przyjmuje nowych zleceń (wstrzymany).'));
      final recipe = previewRecipeFor(project);
      if (recipe == null) throw StateError(tr('Nie rozpoznano aplikacji web w tym projekcie — wpisz komendę podglądu na komputerze.'));
      final port = _freePublicPort();
      if (port == null) throw StateError(tr('Działa już maksymalna liczba podglądów — zatrzymaj któryś.'));
      session = _Session(project, recipe, port);
      _sessions[project.id] = session;
      operationLog.record(deviceId: requester, event: 'preview_started', details: {'project_id': project.id, 'kind': recipe.kind});
      unawaited(_run(session));
    }
    final s = session;
    late final StreamController<PreviewEvent> controller;
    StreamSubscription<PreviewEvent>? sub;
    controller = StreamController<PreviewEvent>(
      onListen: () {
        s.watchers++;
        s.touch();
        sub = s.events.stream.listen((e) {
          controller.add(e);
          if (_terminal(e.state)) controller.close();
        });
        for (final line in s.log) {
          controller.add(PreviewEvent(logLine: line));
        }
        controller.add(s.snapshot());
        if (s.finished) controller.close();
      },
      onCancel: () async {
        s.watchers--;
        s.touch();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Zatrzymuje podgląd projektu. `false`, gdy żaden nie działał.
  Future<bool> stop(String projectId, {String reason = ''}) async {
    final s = _sessions[projectId];
    if (s == null || s.finished) return false;
    await _shutdown(s, PreviewState.PREVIEW_STOPPED, reason.isEmpty ? tr('Podgląd zatrzymany.') : reason);
    return true;
  }

  /// Zmiany w projekcie (sygnał agenta, `rt sg`/`rt push`): restart serwera aplikacji —
  /// hot reload (np. Blazor Server) działa tylko częściowo, więc nie polegamy na nim — a gdy
  /// nowy serwer odpowiada, telefon odświeża stronę. Strona statyczna: samo odświeżenie.
  Future<void> reload(String projectId) async {
    final s = _sessions[projectId];
    if (s == null || s.state != PreviewState.PREVIEW_RUNNING || s.restarting) return;
    if (!s.recipe.isStatic) {
      s.restarting = true;
      try {
        s.emit(PreviewEvent(message: tr('Zmiany w projekcie — restart serwera…')));
        s.generation++; // stary proces kończy się celowo — to nie jest awaria
        final old = s.process;
        if (old != null) {
          await _killTree(old);
          await old.exitCode.timeout(const Duration(seconds: 10), onTimeout: () => -1);
        }
        if (s.finished) return;
        final port = await _startServer(s);
        s.proxy?.targetPort = port;
        await _waitForServer(s, port);
      } on Object catch (e) {
        if (!s.finished) await _shutdown(s, PreviewState.PREVIEW_FAILED, e is StateError ? e.message : describePreviewError(e));
        return;
      } finally {
        s.restarting = false;
      }
    }
    if (!s.finished) s.emit(PreviewEvent(state: s.state, reload: true, message: tr('Zmiany w projekcie — odświeżam.')));
  }

  /// Uruchamia serwer aplikacji na nowym porcie; jego nieoczekiwane zakończenie = FAILED.
  Future<int> _startServer(_Session s) async {
    final port = await freeLocalPort();
    s.appPort = port;
    final generation = s.generation;
    final command = s.recipe.command.replaceAll(previewPortPlaceholder, '$port');
    s.line('> $command');
    unawaited(_spawn(s, command, keep: true, port: port).then((code) {
      if (!s.finished && generation == s.generation) {
        unawaited(_shutdown(s, PreviewState.PREVIEW_FAILED, tr('Serwer aplikacji zakończył działanie (kod {0}) — szczegóły w logu.', [code])));
      }
    }));
    return port;
  }

  Future<void> _waitForServer(_Session s, int port) async {
    final deadline = DateTime.now().add(settings.startTimeout);
    while (!await previewServerResponds(port)) {
      if (s.finished) return;
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(tr('Serwer nie odpowiedział w ciągu {0} min.', [settings.startTimeout.inMinutes]));
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  /// Dopisuje zgłoszenie z telefonu do [previewFeedbackFileName] (najnowsze na górze).
  File reportIssue(ProjectRecord project, PreviewIssue issue, {required String deviceName, DateTime? now}) {
    final file = File(p.join(project.directory.path, previewFeedbackFileName));
    if (FileSystemEntity.typeSync(file.path, followLinks: false) == FileSystemEntityType.link) {
      throw StateError(tr('Plik zgłoszeń w projekcie jest dowiązaniem — pomijam.'));
    }
    String clean(String s, int max) {
      final t = s.replaceAll(RegExp(r'[\x00-\x08\x0B-\x1F\x7F]'), '').trim();
      return t.length > max ? '${t.substring(0, max)}…' : t;
    }

    final url = clean(issue.pageUrl.replaceAll(RegExp('[?&]$previewTokenParam=[0-9a-f]*'), ''), 500);
    final console = [for (final line in issue.console.take(100)) clean(redactSecrets(line), 500)];
    final stamp = (now ?? DateTime.now()).toIso8601String().substring(0, 19).replaceFirst('T', ' ');
    final entry = StringBuffer()
      ..writeln('## $stamp — ${clean(deviceName, 80)}')
      ..writeln()
      ..writeln(clean(issue.note, 4000).isEmpty ? '_(bez opisu)_' : clean(issue.note, 4000))
      ..writeln()
      ..writeln('- Strona: `${url.isEmpty ? '/' : url}`')
      ..writeln('- Ekran: ${issue.viewportWidth}×${issue.viewportHeight}, ${clean(issue.userAgent, 300)}');
    if (console.isNotEmpty) {
      entry
        ..writeln()
        ..writeln('Konsola strony (ostatnie komunikaty):')
        ..writeln()
        ..writeln('```')
        ..writeln(console.join('\n').replaceAll('```', "'''"))
        ..writeln('```');
    }
    // Log serwera: w aplikacjach serwerowych (np. Blazor Server) tam są prawdziwe błędy.
    final session = _sessions[project.id];
    final serverLog = session == null ? const <String>[] : session.log.skip(session.log.length > 80 ? session.log.length - 80 : 0).toList();
    if (serverLog.isNotEmpty) {
      entry
        ..writeln()
        ..writeln('Log serwera (ostatnie ${serverLog.length} linii):')
        ..writeln()
        ..writeln('```')
        ..writeln([for (final l in serverLog) clean(l, 500)].join('\n').replaceAll('```', "'''"))
        ..writeln('```');
    }
    entry.writeln();

    const header = '# Zgłoszenia z podglądu na telefonie (RemoteAppTester)\n\n'
        'Najnowsze na górze. Po poprawce możesz usunąć obsłużone wpisy. Dodaj ten plik do `.gitignore`.\n\n';
    var previous = '';
    if (file.existsSync()) {
      previous = file.readAsStringSync();
      if (previous.startsWith(header)) previous = previous.substring(header.length);
    }
    var body = '$entry$previous';
    // Najwyżej ~200 KB — najstarsze wpisy odpadają.
    while (body.length > 200 * 1024) {
      final cut = body.lastIndexOf('\n## ');
      if (cut <= 0) break;
      body = body.substring(0, cut + 1);
    }
    file.writeAsStringSync('$header$body');
    return file;
  }

  Future<void> close() async {
    _idle.cancel();
    killSwitch.removeListener(_onKillSwitch);
    await Future.wait([
      for (final s in _sessions.values.where((s) => !s.finished))
        _shutdown(s, PreviewState.PREVIEW_STOPPED, tr('RemoteAppTester kończy pracę.')),
    ]);
  }

  // ------------------------------------------------------------------ przebieg

  Future<void> _run(_Session s) async {
    try {
      s.emit(PreviewEvent(state: PreviewState.PREVIEW_STARTING, message: tr('Uruchamiam podgląd ({0})…', [s.recipe.kind])));
      final prepare = s.recipe.prepare;
      final unless = s.recipe.prepareUnless;
      if (prepare != null && (unless == null || !FileSystemEntity.isDirectorySync(p.join(s.dir.path, unless)))) {
        s.line('> $prepare');
        final code = await _spawn(s, prepare, keep: false);
        if (s.finished) return;
        if (code != 0) throw StateError(tr('Przygotowanie zakończone kodem {0}.', [code]));
      }

      Directory? staticRoot;
      if (s.recipe.isStatic) {
        staticRoot = Directory(p.normalize(p.join(s.dir.path, s.recipe.staticFolder)));
        if (!p.isWithin(s.dir.path, staticRoot.path) && !p.equals(s.dir.path, staticRoot.path)) {
          throw StateError(tr('Folder strony musi leżeć w folderze projektu.'));
        }
        if (!staticRoot.existsSync()) throw StateError(tr('Brak folderu strony: {0}', [s.recipe.staticFolder]));
        s.line(tr('Strona statyczna z folderu „{0}”.', [s.recipe.staticFolder]));
      } else {
        await _waitForServer(s, await _startServer(s));
      }
      if (s.finished) return;
      await _expose(s, staticRoot);
      if (s.finished) return;
      s.state = PreviewState.PREVIEW_RUNNING;
      s.emit(s.snapshot(message: tr('Podgląd gotowy.')));
    } on Object catch (e) {
      if (!s.finished) await _shutdown(s, PreviewState.PREVIEW_FAILED, e is StateError ? e.message : describePreviewError(e));
    }
  }

  /// Proxy z tokenem + udostępnienie w Tailscale. Najpierw `tailscale serve` (HTTPS
  /// z certyfikatem *.ts.net), w razie niepowodzenia proxy na adresie Tailscale.
  Future<void> _expose(_Session s, Directory? staticRoot) async {
    if (settings.tailscaleServe) {
      final local = await PreviewProxy.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        token: s.token,
        targetPort: s.appPort,
        staticRoot: staticRoot,
        onActivity: s.touch,
      );
      s.proxy = local;
      final served = await _tailscaleServe(s, local.port);
      if (served != null) {
        s.servedPort = s.publicPort;
        s.url = 'https://$served:${s.publicPort}/?$previewTokenParam=${s.token}';
        s.pinnedTls = false;
        return;
      }
      await local.close();
      s.proxy = null;
    }
    final address = tailscaleAddress();
    if (address == null) throw StateError(tr('Brak połączenia z Tailscale.'));
    if (tls == null) throw StateError(tr('Brak certyfikatu hosta dla podglądu.'));
    s.proxy = await PreviewProxy.start(
      address: address,
      port: s.publicPort,
      token: s.token,
      targetPort: s.appPort,
      staticRoot: staticRoot,
      tls: tls,
      onActivity: s.touch,
    );
    s.url = 'https://${address.address}:${s.publicPort}/?$previewTokenParam=${s.token}';
    s.pinnedTls = true;
  }

  /// `tailscale serve --bg --https=<port> http://127.0.0.1:<proxy>`; zwraca nazwę
  /// MagicDNS hosta albo `null`, gdy się nie da (HTTPS wyłączone w sieci, brak uprawnień).
  Future<String?> _tailscaleServe(_Session s, int localPort) async {
    final cli = tailscaleCli();
    try {
      final dns = await _magicDnsName(cli);
      if (dns == null) return null;
      final process = await Process.start(cli, ['serve', '--bg', '--https=${s.publicPort}', 'http://127.0.0.1:$localPort']);
      final output = StringBuffer();
      final out = process.stdout.transform(previewLines).listen(output.writeln);
      final err = process.stderr.transform(previewLines).listen(output.writeln);
      final code = await process.exitCode.timeout(const Duration(seconds: 20), onTimeout: () {
        process.kill();
        return -1;
      });
      await out.cancel();
      await err.cancel();
      if (code == 0) return dns;
      final hint = output.toString().trim();
      s.line(tr('tailscale serve niedostępne — używam certyfikatu hosta.{0}', [hint.isEmpty ? '' : ' ($hint)']));
      return null;
    } on Object {
      return null;
    }
  }

  static Future<String?> _magicDnsName(String cli) async {
    final result = await Process.run(cli, ['status', '--json'], stdoutEncoding: utf8).timeout(const Duration(seconds: 10));
    if (result.exitCode != 0) return null;
    final self = (jsonDecode(result.stdout as String) as Map<String, Object?>)['Self'] as Map<String, Object?>?;
    final dns = (self?['DNSName'] as String? ?? '').replaceFirst(RegExp(r'\.$'), '');
    return dns.contains('.') ? dns : null;
  }

  /// Uruchamia komendę powłoki w folderze projektu. [keep] = serwer (proces zostaje
  /// w sesji, żeby dało się go zatrzymać razem z procesami potomnymi).
  Future<int> _spawn(_Session s, String command, {required bool keep, int? port}) async {
    final env = <String, String>{
      'BROWSER': 'none',
      'DOTNET_WATCH_SUPPRESS_LAUNCH_BROWSER': '1',
      'DOTNET_CLI_TELEMETRY_OPTOUT': '1',
      'CI': 'false',
      if (port != null) ...{'PORT': '$port', 'HOST': '127.0.0.1', 'HOSTNAME': '127.0.0.1'},
      if (!Platform.environment.containsKey('ASPNETCORE_ENVIRONMENT')) 'ASPNETCORE_ENVIRONMENT': 'Development',
    };
    final Process process;
    File? script;
    if (Platform.isWindows) {
      scriptDir.createSync(recursive: true);
      script = File(p.join(scriptDir.path, 'preview-${DateTime.now().microsecondsSinceEpoch}.cmd'));
      script.writeAsStringSync('@echo off\r\nchcp 65001 >nul\r\ncall $command\r\nexit /b %ERRORLEVEL%\r\n');
      process = await Process.start('cmd.exe', ['/d', '/c', script.path], workingDirectory: s.dir.path, environment: env);
    } else {
      // Własna grupa procesów — zatrzymanie zabija też procesy potomne (dotnet, node).
      try {
        process = await Process.start('setsid', ['bash', '-c', command], workingDirectory: s.dir.path, environment: env);
      } on ProcessException {
        return _spawnPlain(s, command, env, keep);
      }
    }
    return _follow(s, process, keep, script);
  }

  Future<int> _spawnPlain(_Session s, String command, Map<String, String> env, bool keep) async {
    final process = await Process.start('bash', ['-c', command], workingDirectory: s.dir.path, environment: env);
    return _follow(s, process, keep, null);
  }

  Future<int> _follow(_Session s, Process process, bool keep, File? script) async {
    if (keep) s.process = process;
    final out = process.stdout.transform(previewLines).listen(s.line);
    final err = process.stderr.transform(previewLines).listen(s.line);
    if (!keep) unawaited(process.stdin.close());
    s.running.add(process);
    final code = await process.exitCode;
    s.running.remove(process);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await out.cancel();
    await err.cancel();
    try {
      script?.deleteSync();
    } on FileSystemException {
      // plik tymczasowy
    }
    return code;
  }

  Future<void> _shutdown(_Session s, PreviewState state, String message) async {
    if (s.finished) return;
    s.finished = true;
    s.state = state;
    s.url = null;
    for (final process in s.running.toList()) {
      await _killTree(process);
    }
    final served = s.servedPort;
    if (served != null) {
      try {
        await Process.run(tailscaleCli(), ['serve', '--https=$served', 'off']).timeout(const Duration(seconds: 10));
      } on Object {
        // tailscale niedostępny — wpis i tak wskazuje już nieaktywny port.
      }
    }
    await s.proxy?.close();
    s.proxy = null;
    operationLog.record(deviceId: 'host', event: 'preview_stopped', details: {'project_id': s.projectId, 'state': state.name});
    s.emit(PreviewEvent(state: state, message: message));
    await s.events.close();
  }

  static Future<void> _killTree(Process process) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      } else {
        final group = await Process.run('kill', ['-TERM', '--', '-${process.pid}']);
        if (group.exitCode != 0) process.kill(ProcessSignal.sigterm);
        final exited = await process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
        if (exited == -1) {
          await Process.run('kill', ['-KILL', '--', '-${process.pid}']);
          process.kill(ProcessSignal.sigkill);
        }
      }
    } on Object {
      process.kill();
    }
  }

  int? _freePublicPort() {
    final used = {for (final s in _sessions.values) if (!s.finished) s.publicPort};
    for (var i = 0; i < settings.portCount; i++) {
      if (!used.contains(settings.firstPort + i)) return settings.firstPort + i;
    }
    return null;
  }

  void _stopIdle() {
    final now = DateTime.now();
    for (final s in _sessions.values.toList()) {
      if (!s.finished && s.watchers <= 0 && now.difference(s.lastActivity) > settings.idleTimeout) {
        unawaited(_shutdown(s, PreviewState.PREVIEW_STOPPED, tr('Podgląd zatrzymany po {0} min bezczynności.', [settings.idleTimeout.inMinutes])));
      }
    }
  }

  void _onKillSwitch() {
    if (!killSwitch.isPaused) return;
    for (final s in _sessions.values.where((s) => !s.finished).toList()) {
      unawaited(_shutdown(s, PreviewState.PREVIEW_STOPPED, tr('RemoteAppTester wstrzymany — podgląd zatrzymany.')));
    }
  }

  static bool _terminal(PreviewState state) => state == PreviewState.PREVIEW_STOPPED || state == PreviewState.PREVIEW_FAILED;
}

class _Session {
  _Session(ProjectRecord project, this.recipe, this.publicPort)
      : projectId = project.id,
        dir = project.directory;

  final String projectId;
  final Directory dir;
  final PreviewRecipe recipe;
  final int publicPort;
  final String token = randomPreviewToken();
  final events = StreamController<PreviewEvent>.broadcast();
  final log = <String>[];
  final running = <Process>{};
  PreviewState state = PreviewState.PREVIEW_STARTING;
  String? url;
  bool pinnedTls = false;
  bool finished = false;
  bool restarting = false;

  /// Numer kolejnego uruchomienia serwera (restart po zmianach agenta).
  int generation = 0;
  int? appPort;
  int? servedPort;
  Process? process;
  PreviewProxy? proxy;
  int watchers = 0;
  DateTime lastActivity = DateTime.now();

  void touch() => lastActivity = DateTime.now();

  void line(String raw) {
    final text = redactSecrets(raw);
    log.add(text);
    if (log.length > 200) log.removeRange(0, log.length - 200);
    emit(PreviewEvent(logLine: text));
  }

  void emit(PreviewEvent e) {
    if (e.state != PreviewState.PREVIEW_STATE_UNSPECIFIED) state = e.state;
    if (!events.isClosed) events.add(e);
  }

  PreviewEvent snapshot({String message = ''}) => PreviewEvent(
        state: state,
        url: state == PreviewState.PREVIEW_RUNNING ? url : null,
        pinnedTls: pinnedTls,
        message: message,
      );
}
