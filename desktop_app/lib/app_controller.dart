import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/server/host_runtime.dart';
import 'package:remotetester_host/generated/remote_tester.pbenum.dart';
import 'package:remotetester_host/sound/tones.dart';
import 'package:remotetester_host/store/project_store.dart';

import 'sound_player.dart';

/// Stan aplikacji okienkowej nad [HostRuntime]: projekty, buildy na żywo,
/// propozycje agentów w REMOTEAPPTESTER.md, telefony.
class AppController extends ChangeNotifier {
  AppController(this.runtime) {
    _subs.add(runtime.engine.onChange.listen((_) => _scheduleNotify()));
    _subs.add(runtime.onStateChange.listen((_) => notifyListeners()));
    _subs.add(runtime.engine.onFinished.listen((record) {
      reload();
      if (record.phase == BuildPhase.DONE) SoundPlayer.play(SoundEvent.buildDone);
      if (record.phase == BuildPhase.FAILED) SoundPlayer.play(SoundEvent.buildFailed);
    }));
    _subs.add(runtime.signals.onSignal.listen((_) {
      reload();
      SoundPlayer.play(SoundEvent.newVersion);
    }));
    // Telefon potwierdził obsłużenie nowej wersji (zainstalowana albo odrzucona).
    _subs.add(runtime.deliveries.onAck.listen((_) => SoundPlayer.play(SoundEvent.installed)));
    _subs.add(runtime.onOptionsChanged.listen((_) => reload()));
    // REMOTEAPPTESTER.md może zmienić agent AI, a projekty i komendy — `rt` w terminalu
    // (inny proces, ta sama baza) — sprawdzamy co kilka sekund.
    _guideTimer = Timer.periodic(const Duration(seconds: 4), (_) => _refreshFromDisk());
    reload();
  }

  final HostRuntime runtime;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _guideTimer;
  Timer? _notifyTimer;

  List<ProjectRecord> projects = [];
  final Map<String, GuideState> guides = {};
  String? selectedId;

  ProjectStore get store => runtime.store;
  BuildEngine get engine => runtime.engine;

  ProjectRecord? get selected => projects.where((p) => p.id == selectedId).firstOrNull;

  /// Log na żywo odświeżamy najwyżej ~10 razy na sekundę — Gradle potrafi
  /// wypisać tysiące linii, a każda to zdarzenie silnika.
  void _scheduleNotify() {
    if (_notifyTimer?.isActive ?? false) return;
    _notifyTimer = Timer(const Duration(milliseconds: 100), notifyListeners);
  }

  void reload() {
    projects = store.projects();
    if (selectedId != null && !projects.any((p) => p.id == selectedId)) selectedId = null;
    selectedId ??= projects.firstOrNull?.id;
    _refreshGuides(notify: false);
    notifyListeners();
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  void _refreshFromDisk() {
    var fresh = store.projects();
    if (fresh.map(store.redetectKind).toList().any((c) => c)) fresh = store.projects();
    final changed = fresh.length != projects.length ||
        [for (var i = 0; i < fresh.length; i++) _fingerprint(fresh[i]) != _fingerprint(projects[i])].any((d) => d);
    if (changed) {
      reload();
    } else {
      _refreshGuides();
    }
  }

  static String _fingerprint(ProjectRecord p) =>
      '${p.id}|${p.name}|${encodeProfiles(p.profiles)}|${p.defaultProfile}|${p.install.name}|${p.launch}|'
      '${p.targets.join(',')}|${p.phoneTrigger}|${p.localTrigger}|${p.guideHandledHash}|${p.agentBuild}|${p.agentPush}|'
      '${p.changesAt}|${p.agentNoteAt}|${p.kind}';

  void _refreshGuides({bool notify = true}) {
    var changed = false;
    for (final project in projects) {
      final state = store.guideState(project);
      final previous = guides[project.id];
      if (previous?.status != state.status || previous?.hash != state.hash) changed = true;
      guides[project.id] = state;
    }
    if (changed && notify) notifyListeners();
  }

  int get pendingProposals => guides.values.where((g) => g.status == GuideStatus.proposal).length;

  // ---------------------------------------------------------------- projekty

  ProjectRecord addFolder(Directory dir, {String? name}) {
    final record = store.add(dir, name: name);
    selectedId = record.id;
    reload();
    return record;
  }

  void removeProject(ProjectRecord project) {
    store.remove(project.id);
    reload();
  }

  void saveOptions(ProjectRecord project) {
    store.saveOptions(project);
    reload();
  }

  void saveProfiles(ProjectRecord project, List<BuildProfile> profiles, {String? defaultProfile}) {
    store.saveProfiles(project.id, profiles);
    if (defaultProfile != null) {
      final fresh = store.byId(project.id)!..defaultProfile = defaultProfile;
      store.saveOptions(fresh);
    }
    reload();
  }

  void importGuide(ProjectRecord project) {
    final state = guides[project.id];
    if (state == null) return;
    store.importGuide(project.id, state);
    reload();
  }

  void dismissGuide(ProjectRecord project) {
    final state = guides[project.id];
    if (state == null) return;
    store.dismissGuide(project.id, state);
    reload();
  }

  void writeGuide(ProjectRecord project) {
    store.writeAgentGuide(project);
    reload();
  }

  // ---------------------------------------------------------------- buildy

  /// [targets]: `null` = telefony z opcji projektu, pusty zbiór = tylko zbuduj.
  BuildRecord build(ProjectRecord project, {BuildProfile? profile, Set<String>? targets}) {
    final record = engine.start(project: project, profile: profile, requester: desktopRequester, targets: targets);
    notifyListeners();
    return record;
  }

  void cancel(BuildRecord record) {
    engine.cancel(record);
    notifyListeners();
  }

  List<BuildHistoryEntry> history(String projectId) => store.history(projectId, limit: 30);

  List<String> buildLog(String buildId) {
    final live = engine.byId(buildId);
    if (live != null) return [for (final e in live.events) if (e.logLine.isNotEmpty) e.logLine];
    final file = File('logs/builds/$buildId.log');
    return file.existsSync() ? file.readAsLinesSync() : const [];
  }

  // ---------------------------------------------------------------- telefony

  /// Bez odwołanych i bez niewykorzystanych kodów po terminie.
  List<PairedDevice> get devices =>
      runtime.devices.all.where((d) => !d.revoked && runtime.devices.status(d.deviceId) != DeviceStatus.expired).toList();

  bool isOnline(String deviceId) => runtime.deliveries.isOnline(deviceId);

  (PairedDevice, String) pair(String name) {
    final result = runtime.pair(name);
    notifyListeners();
    return result;
  }

  void revoke(String deviceId) {
    runtime.devices.revoke(deviceId);
    notifyListeners();
  }

  bool get paused => runtime.killSwitch.isPaused;

  void togglePause() {
    runtime.killSwitch.toggle();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _guideTimer?.cancel();
    _notifyTimer?.cancel();
    super.dispose();
  }
}
