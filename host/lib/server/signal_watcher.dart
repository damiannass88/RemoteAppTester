import 'dart:async';
import 'dart:io';

import '../build/build_engine.dart';
import '../build/operation_log.dart';
import '../generated/remote_tester.pbenum.dart';
import '../i18n.dart';
import '../pairing/device_registry.dart';
import '../project/agent_signal.dart';
import '../project/artifact_finder.dart';
import '../project/build_profile.dart';
import '../store/project_store.dart';
import 'delivery_hub.dart';
import 'kill_switch.dart';

/// Ile ostatnich linii logu dostaje agent w wyniku nieudanego builda.
const _logTailLines = 40;

/// Co kilka sekund sprawdza foldery projektów w poszukiwaniu sygnału agenta
/// (`.remoteapptester-signal`), zapisuje go w bazie („są zmiany” + notatka) i —
/// jeśli agent poprosił o build albo przysłał własną instalkę (`deliver`), a
/// opcje projektu na to pozwalają — uruchamia build domyślnego wariantu
/// komendami z bazy albo dostawę tej instalki.
///
/// Wynik każdego sygnału trafia do `.remoteapptester-status.json` w folderze
/// projektu: agent czyta go (`rt st`, `rt push --wait`) bez dostępu do
/// RemoteAppTestera.
class SignalWatcher {
  SignalWatcher({
    required this.store,
    required this.engine,
    required this.killSwitch,
    required this.operationLog,
    this.deliveries,
    this.devices,
    Duration interval = const Duration(seconds: 3),
    this.settle = const Duration(seconds: 1),
  }) {
    _timer = Timer.periodic(interval, (_) => scan());
    // Rejestrowane po DeliveryHub — przy zakończeniu builda lista odbiorców jest już znana.
    _subs
      ..add(engine.onFinished.listen(_onFinished))
      ..add(engine.onChange.listen(_onChange));
    if (deliveries != null) _subs.add(deliveries!.onAck.listen(_onAck));
  }

  final ProjectStore store;
  final BuildEngine engine;
  final KillSwitch killSwitch;
  final OperationLog operationLog;
  final DeliveryHub? deliveries;
  final DeviceRegistry? devices;
  final Duration settle;
  late final Timer _timer;
  final _subs = <StreamSubscription<Object?>>[];
  final _changes = StreamController<String>.broadcast();

  /// build_id -> zlecenie agenta, którego wynik zapisujemy w folderze projektu.
  final Map<String, _AgentRequest> _requests = {};

  /// Id projektu, dla którego przyszedł sygnał.
  Stream<String> get onSignal => _changes.stream;

  void scan() {
    for (final project in store.projects()) {
      final AgentSignal? signal;
      try {
        signal = consumeAgentSignal(project.directory, settle: settle);
      } on Object {
        continue;
      }
      if (signal == null) continue;
      store.recordSignal(project.id, note: signal.message);
      operationLog.record(deviceId: agentRequester, event: 'agent_signal', details: {
        'project_id': project.id,
        'build': signal.build,
        'deliver': signal.deliver != null,
      });
      if (signal.deliver != null) {
        _maybePush(project, signal);
      } else if (signal.build) {
        _maybeBuild(project, signal);
      } else {
        _status(project, signal, 'note', 'done', tr('Notatka przyjęta (bez builda).'));
      }
      if (!_changes.isClosed) _changes.add(project.id);
    }
  }

  void _maybeBuild(ProjectRecord project, AgentSignal signal) {
    final refusal = !project.agentBuild
        ? tr('Opcja projektu „Sygnał agenta uruchamia build” jest wyłączona — zmiany oznaczone, bez builda.')
        : _refusal(project);
    if (refusal != null) {
      _status(project, signal, 'build', 'rejected', refusal);
      return;
    }
    try {
      validateProfiles(project.profiles);
      _track(engine.start(project: project, requester: agentRequester), project, signal, 'build');
    } on Object catch (e) {
      operationLog.record(deviceId: agentRequester, event: 'agent_build_rejected', details: {
        'project_id': project.id,
        'error': e.toString(),
      });
      _status(project, signal, 'build', 'rejected', e.toString());
    }
  }

  void _maybePush(ProjectRecord project, AgentSignal signal) {
    final refusal = !project.agentPush
        ? tr('Opcja projektu „Agent może wysłać własną instalkę” jest wyłączona (rt o --agent-push on).')
        : _refusal(project);
    if (refusal != null) {
      _status(project, signal, 'push', 'rejected', refusal);
      return;
    }
    try {
      final apk = resolvePushedArtifact(project.directory, signal.deliver!);
      _track(engine.deliverPrebuilt(project: project, apk: apk, requester: agentRequester), project, signal, 'push');
    } on Object catch (e) {
      operationLog.record(deviceId: agentRequester, event: 'agent_push_rejected', details: {
        'project_id': project.id,
        'error': e.toString(),
      });
      _status(project, signal, 'push', 'rejected', e is ProfileException ? e.message : e.toString());
    }
  }

  String? _refusal(ProjectRecord project) {
    if (killSwitch.isPaused) return tr('RemoteAppTester jest wstrzymany (kill-switch) — spróbuj później.');
    if (!project.directory.existsSync()) return tr('Folder projektu nie istnieje.');
    return null;
  }

  void _track(BuildRecord record, ProjectRecord project, AgentSignal signal, String action) {
    final request = _AgentRequest(project.directory, project.name, signal, action);
    _requests[record.buildId] = request;
    while (_requests.length > 20) {
      _requests.remove(_requests.keys.first);
    }
    request.phase = record.phase;
    _write(request, record);
  }

  void _onChange(BuildRecord record) {
    final request = _requests[record.buildId];
    if (request == null || record.isFinished || request.phase == record.phase) return;
    request.phase = record.phase;
    _write(request, record);
  }

  void _onFinished(BuildRecord record) {
    final request = _requests[record.buildId];
    if (request == null) return;
    request.phase = record.phase;
    _write(request, record);
  }

  void _onAck((String, String) ack) {
    final request = _requests[ack.$2];
    final record = engine.byId(ack.$2);
    if (request == null || record == null) return;
    request.handled.add(ack.$1);
    _write(request, record);
  }

  void _write(_AgentRequest request, BuildRecord record) {
    final finished = record.isFinished;
    final done = record.phase == BuildPhase.DONE;
    final targets = record.deliveredTo.toList()..sort();
    final String state;
    final String message;
    if (!finished) {
      state = record.started ? 'running' : 'queued';
      message = record.prebuilt ? tr('Przyjmuję instalkę od agenta.') : tr('Build w toku.');
    } else if (done) {
      state = 'done';
      message = targets.isEmpty
          ? (record.project.install == InstallPolicy.off
              ? tr('Gotowe, ale instalacja jest wyłączona w opcjach projektu — nikomu nie wysłano.')
              : tr('Gotowe, ale żaden sparowany telefon nie jest wybrany dla tego projektu.'))
          : tr('Gotowe — wysłano na telefony: {0}; potwierdziło: {1}.', [targets.length, request.handled.length]);
    } else {
      state = record.phase == BuildPhase.CANCELLED ? 'cancelled' : 'failed';
      message = record.events.lastOrNull?.logLine ?? record.phase.name;
    }
    _writeStatus(request.dir, request.projectName, request.signal, request.action, state, message, extra: {
      'build_id': record.buildId,
      'phase': record.phase.name,
      if (record.artifact != null) 'sha256': record.artifact!.sha256Hex,
      if (record.artifact != null) 'size_bytes': record.artifact!.sizeBytes,
      'install': record.project.install.name,
      'devices': [
        for (final id in targets)
          {
            'id': id,
            'name': devices?.all.where((d) => d.deviceId == id).firstOrNull?.displayName,
            'online': deliveries?.isOnline(id),
            'handled': request.handled.contains(id),
          },
      ],
      if (finished && !done)
        'log_tail': [
          for (final e in record.events.where((e) => e.logLine.isNotEmpty).toList().reversed.take(_logTailLines).toList().reversed)
            e.logLine,
        ],
    });
  }

  void _status(ProjectRecord project, AgentSignal signal, String action, String state, String message) =>
      _writeStatus(project.directory, project.name, signal, action, state, message);

  void _writeStatus(Directory dir, String projectName, AgentSignal signal, String action, String state, String message,
      {Map<String, Object?> extra = const {}}) {
    writeAgentStatus(dir, {
      'request': signal.request,
      'action': action,
      'state': state,
      'message': message,
      'project': projectName,
      ...extra,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void close() {
    _timer.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _changes.close();
  }
}

class _AgentRequest {
  _AgentRequest(this.dir, this.projectName, this.signal, this.action);
  final Directory dir;
  final String projectName;
  final AgentSignal signal;
  final String action;
  final Set<String> handled = {};
  BuildPhase? phase;
}
