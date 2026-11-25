import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../generated/remote_tester.pb.dart';
import '../project/artifact_finder.dart';
import '../project/build_profile.dart';
import '../store/project_store.dart';
import '../transfer/delta_cache.dart';
import 'artifact_registry.dart';
import 'command_runner.dart';
import 'log_redactor.dart';
import 'operation_log.dart';

/// Ile ostatnich buildów trzymamy w pamięci (log na żywo, `GetBuildStatus`).
const int _maxRememberedBuilds = 60;

/// Ile zbudowanych instalek trzymamy na projekt (kopie w `artifacts/`).
const int _artifactsPerProject = 3; // także bazy do delt dla telefonów, które ominęły build

/// Zlecający lokalny (`rt b`, agent AI na hoście).
const String localRequester = 'local';

/// Zlecający z okna aplikacji na tym komputerze.
const String desktopRequester = 'desktop';

/// Build uruchomiony sygnałem agenta AI (plik `.remoteapptester-signal`).
const String agentRequester = 'agent';

/// Nazwa „wariantu” w historii dla instalki dostarczonej przez agenta (`rt push`).
const String agentPushProfileName = 'agent-push';

class BuildRejectedException implements Exception {
  BuildRejectedException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _terminalPhases = {BuildPhase.DONE, BuildPhase.FAILED, BuildPhase.CANCELLED};

/// Stan jednego builda, niezależny od połączenia, które go zleciło — zerwany
/// telefon, zamknięte okno ani przerwane `rt b` nie przerywają budowania.
class BuildRecord {
  BuildRecord({
    required this.buildId,
    required this.project,
    required this.profile,
    required this.requester,
    this.targets,
    this.prebuilt = false,
  }) : startedAt = DateTime.now();

  final String buildId;

  /// Migawka projektu z chwili zlecenia (opcje dostawy, folder).
  final ProjectRecord project;
  final BuildProfile profile;

  /// `device_id` telefonu, [localRequester], [desktopRequester] albo [agentRequester].
  final String requester;

  /// Telefony wybrane dla TEGO builda; `null` = z opcji projektu.
  final Set<String>? targets;

  /// Gotowa instalka od agenta (`rt push`) — bez kroków budowania i bez kolejki.
  final bool prebuilt;
  final DateTime startedAt;
  final List<BuildEvent> events = [];
  final BuildCancellation cancellation = BuildCancellation();
  BuiltArtifact? artifact;
  DateTime? finishedAt;
  bool started = false;

  /// Urządzenia, którym zaproponowano ten build — tylko one (i zlecający)
  /// mogą go obserwować i pobrać.
  final Set<String> deliveredTo = {};

  Completer<void> _changed = Completer<void>();

  String get projectId => project.id;
  Directory get directory => project.directory;
  bool get isFinished => events.isNotEmpty && _terminalPhases.contains(events.last.phase);
  BuildPhase get phase => events.isEmpty ? BuildPhase.QUEUED : events.last.phase;
  int get progress => events.where((e) => e.progressPercent > 0).lastOrNull?.progressPercent ?? 0;

  bool canDownload(String deviceId) => requester == deviceId || deliveredTo.contains(deviceId);

  bool deliversTo(String deviceId) => targets?.contains(deviceId) ?? project.deliversTo(deviceId);

  void _emit(BuildEvent event) {
    events.add(event);
    if (_terminalPhases.contains(event.phase)) finishedAt = DateTime.now();
    final changed = _changed;
    _changed = Completer<void>();
    changed.complete();
  }

  /// Pełna historia zdarzeń od [from], potem nowe na bieżąco, do końca builda.
  Stream<BuildEvent> watch({int from = 0}) async* {
    var index = from;
    while (true) {
      while (index < events.length) {
        yield events[index++];
      }
      if (isFinished) return;
      await _changed.future;
    }
  }

  /// Czeka do [timeout] na zdarzenia nowsze niż [from] (long-poll).
  Future<void> waitForChange(int from, Duration timeout) async {
    if (events.length > from || isFinished) return;
    await _changed.future.timeout(timeout, onTimeout: () {});
  }
}

/// Wykonuje buildy w tle dla wszystkich wyzwalaczy (okno aplikacji, telefon,
/// `rt b`): do [maxParallel] różnych projektów naraz, ten sam projekt zawsze
/// pojedynczo (kolejka). Komendy — wyłącznie z profilu w bazie.
class BuildEngine {
  BuildEngine({
    required this.runner,
    required this.artifacts,
    required this.operationLog,
    required this.dataDir,
    this.store,
    int maxParallel = 2,
  }) : _maxParallel = maxParallel.clamp(1, 8);

  final CommandRunner runner;
  final ArtifactRegistry artifacts;
  final OperationLog operationLog;

  /// Katalog danych hosta (kopie instalek, logi buildów).
  final Directory dataDir;

  /// Zapis historii (opcjonalny — testy działają bez bazy).
  final ProjectStore? store;
  int _maxParallel;

  final List<BuildRecord> _builds = [];
  final Set<String> _runningProjects = {};
  final _finished = StreamController<BuildRecord>.broadcast(sync: true);
  final _changes = StreamController<BuildRecord>.broadcast();

  /// Zakończone buildy (każda faza terminalna) — źródło dostaw.
  Stream<BuildRecord> get onFinished => _finished.stream;

  /// Każda zmiana stanu builda (dla okna aplikacji).
  Stream<BuildRecord> get onChange => _changes.stream;

  int get maxParallel => _maxParallel;
  set maxParallel(int value) {
    _maxParallel = value.clamp(1, 8);
    _schedule();
  }

  List<BuildRecord> get recent => List.unmodifiable(_builds);

  BuildRecord? byId(String buildId) => _builds.where((b) => b.buildId == buildId).lastOrNull;

  /// Trwający albo czekający build projektu (najnowszy).
  BuildRecord? activeFor(String projectId) =>
      _builds.where((b) => b.projectId == projectId && !b.isFinished).lastOrNull;

  BuildRecord? lastFor(String projectId) => _builds.where((b) => b.projectId == projectId).lastOrNull;

  /// Ostatni udany build projektu w pamięci, który [deviceId] może pobrać.
  String? recentSuccessful(String projectId, String deviceId) => _builds
      .where((b) =>
          b.projectId == projectId &&
          b.phase == BuildPhase.DONE &&
          b.artifact != null &&
          (b.canDownload(deviceId) || b.deliversTo(deviceId)))
      .lastOrNull
      ?.buildId;

  int get runningCount => _runningProjects.length;
  int get queuedCount => _builds.where((b) => !b.started && !b.isFinished).length;

  /// Zleca build. Ten sam projekt i wariant czekający już w kolejce (jeszcze
  /// nie wystartował) = zwracamy tamten build zamiast dokładać kolejny.
  BuildRecord start({
    required ProjectRecord project,
    BuildProfile? profile,
    required String requester,
    Set<String>? targets,
  }) {
    final chosen = profile ?? project.profile();
    if (chosen == null) throw BuildRejectedException('Projekt nie ma żadnego wariantu budowania.');
    try {
      chosen.validate();
    } on ProfileException catch (e) {
      throw BuildRejectedException('Komendy budowania są niepoprawne: ${e.message}');
    }
    if (!project.directory.existsSync()) {
      throw BuildRejectedException('Folder projektu nie istnieje: ${project.path}');
    }
    final waiting = _builds
        .where((b) => b.projectId == project.id && b.profile.name == chosen.name && !b.started && !b.isFinished)
        .lastOrNull;
    if (waiting != null) return waiting;

    final record = BuildRecord(
      buildId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      project: project,
      profile: chosen,
      requester: requester,
      targets: targets,
    );
    _builds.add(record);
    while (_builds.length > _maxRememberedBuilds && _builds.first.isFinished) {
      _builds.removeAt(0);
    }
    operationLog.record(
      deviceId: requester,
      event: 'build_requested',
      details: {'build_id': record.buildId, 'project_id': project.id, 'profile': chosen.name},
    );
    _emit(record, BuildEvent(buildId: record.buildId, phase: BuildPhase.QUEUED, queuePosition: _queuePosition(record)));
    _schedule();
    return record;
  }

  /// Dostawa instalki zbudowanej przez agenta: bez uruchamiania czegokolwiek,
  /// poza kolejką buildów. Plik ([apk] — już sprawdzony, w folderze projektu)
  /// trafia do kopii w katalogu danych tak jak instalka z builda, więc dostawy,
  /// delty i „zainstaluj ostatnią” działają bez zmian.
  BuildRecord deliverPrebuilt({required ProjectRecord project, required File apk, required String requester}) {
    final record = BuildRecord(
      buildId: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      project: project,
      profile: BuildProfile(name: agentPushProfileName, steps: const [], artifact: p.basename(apk.path)),
      requester: requester,
      prebuilt: true,
    )..started = true;
    _builds.add(record);
    while (_builds.length > _maxRememberedBuilds && _builds.first.isFinished) {
      _builds.removeAt(0);
    }
    operationLog.record(
      deviceId: requester,
      event: 'push_requested',
      details: {'build_id': record.buildId, 'project_id': project.id},
    );
    _emit(record, BuildEvent(buildId: record.buildId, phase: BuildPhase.PACKAGING, progressPercent: 50,
        logLine: 'Instalka od agenta AI: ${p.relative(apk.path, from: project.directory.resolveSymbolicLinksSync())}'));
    unawaited(() async {
      try {
        await _storeArtifact(record, apk);
        _finish(record, BuildEvent(buildId: record.buildId, phase: BuildPhase.DONE, progressPercent: 100));
        operationLog.record(deviceId: requester, event: 'push_done', details: {'build_id': record.buildId});
      } catch (e) {
        _finish(record, BuildEvent(buildId: record.buildId, phase: BuildPhase.FAILED, logLine: redactSecrets(e.toString())));
        operationLog.record(deviceId: requester, event: 'push_failed', details: {'build_id': record.buildId, 'error': e.toString()});
      }
    }());
    return record;
  }

  bool cancel(BuildRecord record) {
    if (record.isFinished) return false;
    record.cancellation.cancel();
    operationLog.record(deviceId: record.requester, event: 'build_cancel_requested', details: {'build_id': record.buildId});
    if (!record.started) {
      // Czekający w kolejce — kończymy od razu, bez uruchamiania czegokolwiek.
      _finish(record, BuildEvent(buildId: record.buildId, phase: BuildPhase.CANCELLED, logLine: 'Build anulowany.'));
    }
    return true;
  }

  int _queuePosition(BuildRecord record) {
    final waiting = _builds.where((b) => !b.started && !b.isFinished).toList();
    final index = waiting.indexOf(record);
    return _runningProjects.length < _maxParallel && !_runningProjects.contains(record.projectId) && index == 0
        ? 0
        : index + 1;
  }

  void _schedule() {
    for (final record in List.of(_builds)) {
      if (_runningProjects.length >= _maxParallel) return;
      if (record.started || record.isFinished || _runningProjects.contains(record.projectId)) continue;
      record.started = true;
      _runningProjects.add(record.projectId);
      unawaited(_run(record));
    }
  }

  void _emit(BuildRecord record, BuildEvent event) {
    record._emit(event);
    if (event.logLine.isNotEmpty) _appendLog(record, event.logLine);
    if (!_changes.isClosed) _changes.add(record);
  }

  Future<void> _run(BuildRecord record) async {
    final id = record.buildId;
    final steps = record.profile.steps;
    try {
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i];
        final phase = i == steps.length - 1 ? BuildPhase.BUILDING : BuildPhase.PREPARE;
        _emit(record, BuildEvent(buildId: id, phase: phase, progressPercent: 10 + (80 * i ~/ steps.length)));
        _emit(record, BuildEvent(buildId: id, phase: phase, logLine: '==> ${step.name}: ${redactSecrets(step.run)}'));
        await for (final line in runner.runShell(
          step.run,
          workingDirectory: record.directory.path,
          cancellation: record.cancellation,
        )) {
          _emit(record, BuildEvent(buildId: id, phase: phase, logLine: redactSecrets(line)));
        }
      }

      _emit(record, BuildEvent(buildId: id, phase: BuildPhase.PACKAGING, progressPercent: 95));
      final apk = findArtifact(record.directory, record.profile.artifact);
      if (apk == null) {
        throw StateError('Build się udał, ale nie znaleziono instalki pasującej do "${record.profile.artifact}" — '
            'popraw ścieżkę instalki w komendach projektu.');
      }
      final artifact = await _storeArtifact(record, apk);
      _emit(record, BuildEvent(buildId: id, phase: BuildPhase.PACKAGING,
          logLine: 'Instalka: ${p.relative(apk.path, from: record.directory.path)} (${(artifact.sizeBytes / 1048576).toStringAsFixed(1)} MB)'));
      _finish(record, BuildEvent(buildId: id, phase: BuildPhase.DONE, progressPercent: 100));
      operationLog.record(deviceId: record.requester, event: 'build_done', details: {'build_id': id});
    } catch (e) {
      final cancelled = e is BuildCancelledException || record.cancellation.isCancelled;
      _finish(record, BuildEvent(
        buildId: id,
        phase: cancelled ? BuildPhase.CANCELLED : BuildPhase.FAILED,
        logLine: cancelled ? 'Build anulowany.' : redactSecrets(e.toString()),
      ));
      operationLog.record(
        deviceId: record.requester,
        event: cancelled ? 'build_cancelled' : 'build_failed',
        details: {'build_id': id, if (!cancelled) 'error': e.toString()},
      );
    }
  }

  /// Kopia w katalogu danych: kolejny build nie podmieni pliku, który telefon
  /// właśnie pobiera, a "zainstaluj ostatnią wersję" działa po restarcie hosta.
  Future<BuiltArtifact> _storeArtifact(BuildRecord record, File apk) async {
    final copy = File(p.join(dataDir.path, 'artifacts', record.projectId, '${record.buildId}.apk'));
    copy.parent.createSync(recursive: true);
    apk.copySync(copy.path);
    _pruneArtifacts(copy.parent);
    final digest = await sha256.bind(copy.openRead()).single;
    final artifact = BuiltArtifact(filePath: copy.path, sha256Hex: digest.toString(), sizeBytes: copy.lengthSync());
    artifacts.register(record.buildId, artifact);
    record.artifact = artifact;
    return artifact;
  }

  void _finish(BuildRecord record, BuildEvent event) {
    if (record.isFinished) return;
    _emit(record, event);
    // Tylko build z kolejki zwalnia miejsce projektu — anulowany czekający ani
    // dostawa od agenta nie mogą „odblokować” trwającego builda tego projektu.
    final wasRunning = record.started && !record.prebuilt && _runningProjects.remove(record.projectId);
    try {
      store?.recordBuild(BuildHistoryEntry(
        buildId: record.buildId,
        projectId: record.projectId,
        profile: record.profile.name,
        requester: record.requester,
        startedAt: record.startedAt,
        finishedAt: record.finishedAt,
        phase: record.phase.name,
        artifactPath: record.artifact?.filePath,
        sha256: record.artifact?.sha256Hex,
        sizeBytes: record.artifact?.sizeBytes,
      ));
      // Zmiany zgłoszone przez agenta przed startem tego builda są już w instalce.
      if (record.phase == BuildPhase.DONE) store?.clearChanges(record.projectId, before: record.startedAt);
    } on Object {
      // Projekt mógł zostać usunięty w trakcie — historia nie jest krytyczna.
    }
    _finished.add(record);
    if (wasRunning || !record.started) _schedule();
  }

  void _appendLog(BuildRecord record, String line) {
    try {
      final file = File(p.join(dataDir.path, 'logs', 'builds', '${record.buildId}.log'));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    } on FileSystemException {
      // Log na dysku to dodatek — log w pamięci i na telefonie działa dalej.
    }
  }

  void _pruneArtifacts(Directory dir) {
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.apk')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final old in files.skip(_artifactsPerProject)) {
      try {
        old.deleteSync();
      } on FileSystemException {
        // Plik może być akurat pobierany — usuniemy go przy następnym buildzie.
      }
    }
    pruneDeltas(dir);
  }

  /// Ostatnia instalka projektu z historii (także sprzed restartu hosta), jeśli plik istnieje.
  BuiltArtifact? lastArtifact(String projectId) {
    for (final entry in store?.history(projectId, limit: 10) ?? const <BuildHistoryEntry>[]) {
      if (entry.phase != BuildPhase.DONE.name || entry.artifactPath == null) continue;
      final file = File(entry.artifactPath!);
      if (!file.existsSync()) continue;
      return BuiltArtifact(filePath: file.path, sha256Hex: entry.sha256!, sizeBytes: entry.sizeBytes!);
    }
    return null;
  }

  /// Wyłącznie dla testów: zakończony build z gotowym artefaktem, bez procesów.
  void addFinishedForTest(BuildRecord record, BuiltArtifact artifact) {
    artifacts.register(record.buildId, artifact);
    record
      ..artifact = artifact
      ..started = true;
    _builds.add(record);
    record._emit(BuildEvent(buildId: record.buildId, phase: BuildPhase.DONE, progressPercent: 100));
    _finished.add(record);
  }

  Future<void> close() async {
    for (final b in _builds.where((b) => !b.isFinished)) {
      b.cancellation.cancel();
    }
    await _changes.close();
  }
}
