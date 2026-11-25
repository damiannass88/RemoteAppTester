import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';

import '../build/artifact_registry.dart';
import '../build/build_engine.dart';
import '../build/operation_log.dart';
import '../generated/remote_tester.pbgrpc.dart';
import '../pairing/device_auth.dart';
import '../pairing/device_registry.dart';
import '../pairing/nonce_store.dart';
import '../pairing/rate_limiter.dart';
import '../preview/preview_manager.dart';
import '../project/build_profile.dart';
import '../project/project_creator.dart';
import '../store/project_store.dart';
import '../transfer/delta_cache.dart';
import '../version.dart';
import 'delivery_hub.dart';
import 'kill_switch.dart';

/// Rozmiar pojedynczego chunku przy transferze artefaktu.
const int _artifactChunkSizeBytes = 256 * 1024;

/// Implementacja `HostAgent` (proto/remote_tester.proto) — telefon jako pilot.
///
/// Każde żądanie musi nieść nagłówek `device-id` sparowanego, nieodwołanego
/// urządzenia ORAZ ważny podpis HMAC z nonce/timestamp (`pairing/device_auth.dart`).
/// Telefon wskazuje wyłącznie identyfikatory i nazwę wariantu z listy hosta —
/// komendy budowania są tylko w zaszyfrowanej bazie hosta.
class HostAgentService extends HostAgentServiceBase {
  HostAgentService({
    required this.store,
    required this.engine,
    required this.deliveries,
    required this.devices,
    required this.operationLog,
    required this.artifacts,
    required this.rateLimiter,
    required this.nonceStore,
    required this.killSwitch,
    this.creator,
    this.previews,
    DeltaCache? deltas,
  }) : deltas = deltas ?? DeltaCache();

  final ProjectStore store;
  final BuildEngine engine;
  final DeliveryHub deliveries;
  final DeviceRegistry devices;
  final OperationLog operationLog;
  final ArtifactRegistry artifacts;
  final RateLimiter rateLimiter;
  final NonceStore nonceStore;
  final KillSwitch killSwitch;
  final DeltaCache deltas;

  /// Dodawanie projektów z telefonu — `null`, gdy host na to nie pozwala
  /// (`phone_add_projects: false`).
  final ProjectCreator? creator;

  /// Podgląd aplikacji web — `null` w testach bez podglądu.
  final PreviewManager? previews;

  PairedDevice _auth(ServiceCall call, String method, List<int> payload) =>
      requireDevice(call, devices, rateLimiter, nonceStore, operationLog, method: method, requestPayload: payload);

  /// Problem z komendami, który blokuje budowanie (pokazywany na telefonie).
  String? blockingIssue(ProjectRecord project) {
    if (!project.directory.existsSync()) return 'Folder projektu nie istnieje na komputerze.';
    try {
      validateProfiles(project.profiles);
    } on ProfileException catch (e) {
      return 'Komendy budowania: ${e.message}';
    }
    return null;
  }

  Project toProto(ProjectRecord project, String deviceId) {
    final issue = blockingIssue(project);
    final active = engine.activeFor(project.id);
    final last = engine.lastFor(project.id);
    final history = last == null ? store.history(project.id, limit: 1).firstOrNull : null;
    final lastArtifact = _lastArtifactIdFor(project, deviceId);
    final preview = project.directory.existsSync() ? previewRecipeFor(project) : null;
    return Project(
      projectId: project.id,
      displayName: project.name,
      kind: project.kind,
      installableOnPhone: issue == null,
      profiles: [for (final p in project.profiles) p.name],
      defaultProfile: project.profile()?.name ?? '',
      specError: issue ?? '',
      phoneTriggerAllowed: project.phoneTrigger,
      launchAfterInstall: project.launch,
      building: active != null,
      lastPhase: last?.phase ?? (history == null ? BuildPhase.BUILD_PHASE_UNSPECIFIED : BuildPhase.valueOf(
          BuildPhase.values.firstWhere((p) => p.name == history.phase, orElse: () => BuildPhase.FAILED).value)),
      lastBuildUnixMs: fixnum.Int64((last?.finishedAt ?? last?.startedAt ?? history?.startedAt)?.millisecondsSinceEpoch ?? 0),
      activeBuildId: active != null && (active.canDownload(deviceId) || project.deliversTo(deviceId)) ? active.buildId : '',
      lastArtifactBuildId: lastArtifact ?? '',
      progressPercent: active?.progress ?? 0,
      changesPending: project.changesPending,
      agentNote: project.agentNote ?? '',
      agentNoteUnixMs: fixnum.Int64(project.agentNoteAt?.millisecondsSinceEpoch ?? 0),
      agentBuildAllowed: project.agentBuild,
      agentPushAllowed: project.agentPush,
      installMode: switch (project.install) {
        InstallPolicy.auto => InstallMode.AUTO,
        InstallPolicy.ask => InstallMode.ASK,
        InstallPolicy.off => InstallMode.OFF,
      },
      deliversToThisPhone: project.deliversTo(deviceId),
      previewAvailable: previews != null && project.preview && preview != null,
      previewKind: preview?.kind ?? '',
      previewRunning: previews?.isRunning(project.id) ?? false,
    );
  }

  /// Ostatni udany build projektu, jeśli ten telefon może go pobrać.
  String? _lastArtifactIdFor(ProjectRecord project, String deviceId) {
    final mem = engine.recentSuccessful(project.id, deviceId);
    if (mem != null) return mem;
    if (!project.deliversTo(deviceId)) return null;
    for (final e in store.history(project.id, limit: 10)) {
      if (e.phase == BuildPhase.DONE.name && e.artifactPath != null && File(e.artifactPath!).existsSync()) return e.buildId;
    }
    return null;
  }

  @override
  Future<Pong> ping(ServiceCall call, Empty request) async {
    _auth(call, 'Ping', request.writeToBuffer());
    return Pong(serverTimeUnixMs: fixnum.Int64(DateTime.now().millisecondsSinceEpoch), hostVersion: hostVersion);
  }

  @override
  Future<ProjectList> listProjects(ServiceCall call, Empty request) async {
    final device = _auth(call, 'ListProjects', request.writeToBuffer());
    return ProjectList(projects: [for (final p in store.projects()) toProto(p, device.deviceId)]);
  }

  @override
  Stream<BuildEvent> startBuild(ServiceCall call, BuildRequest request) async* {
    final device = _auth(call, 'StartBuild', request.writeToBuffer());
    if (killSwitch.isPaused) {
      throw GrpcError.unavailable('Komputer aktualnie nie przyjmuje nowych zleceń (wstrzymany).');
    }
    final project = store.byId(request.projectId);
    if (project == null) throw GrpcError.notFound('Nieznany projekt.');
    if (!project.phoneTrigger) {
      throw GrpcError.permissionDenied('Budowanie z telefonu jest wyłączone w opcjach projektu.');
    }
    final issue = blockingIssue(project);
    if (issue != null) throw GrpcError.failedPrecondition(issue);
    BuildProfile? profile;
    if (request.profile.isNotEmpty) {
      profile = project.profiles.where((p) => p.name == request.profile).firstOrNull;
      if (profile == null) throw GrpcError.invalidArgument('Nieznany wariant budowania: ${request.profile}');
    }

    final BuildRecord record;
    try {
      record = engine.start(project: project, profile: profile, requester: device.deviceId);
    } on BuildRejectedException catch (e) {
      throw GrpcError.failedPrecondition(e.message);
    }
    // Ten sam build zlecony wcześniej z innego źródła i czekający w kolejce —
    // telefon może go obserwować i pobrać (i tak dostałby go jako dostawę).
    if (record.requester != device.deviceId) record.deliveredTo.add(device.deviceId);
    yield* record.watch();
  }

  @override
  Stream<BuildEvent> getBuildStatus(ServiceCall call, BuildId request) async* {
    final device = _auth(call, 'GetBuildStatus', request.writeToBuffer());
    final build = engine.byId(request.buildId);
    if (build == null) {
      throw GrpcError.notFound('Nieznany build (albo komputer został zrestartowany): ${request.buildId}');
    }
    // Izolacja per urządzenie: tylko zlecający, adresaci dostawy albo telefony
    // z opcji projektu (pilot widzi postęp buildów zleconych z komputera).
    if (!build.canDownload(device.deviceId) && !build.deliversTo(device.deviceId)) {
      throw GrpcError.permissionDenied('Ten build nie jest przeznaczony dla tego telefonu.');
    }
    yield* build.watch();
  }

  @override
  Stream<Chunk> downloadArtifact(ServiceCall call, ArtifactRequest request) async* {
    final device = _auth(call, 'DownloadArtifact', request.writeToBuffer());
    final (artifact, _) = _artifactFor(request.buildId, device.deviceId);

    final startOffset = request.resumeFromByteOffset.toInt();
    if (startOffset < 0 || startOffset > artifact.sizeBytes) {
      throw GrpcError.invalidArgument('Nieprawidłowy resume_from_byte_offset.');
    }
    final raf = await File(artifact.filePath).open();
    try {
      if (startOffset > 0) await raf.setPosition(startOffset);
      var offset = startOffset;
      // Klient mógł już mieć CAŁY plik — i tak musi dostać ostatni chunk z sumą SHA-256.
      if (offset == artifact.sizeBytes) {
        yield Chunk(data: const [], offset: fixnum.Int64(offset), isLast: true, sha256FullFile: artifact.sha256Hex);
      }
      while (offset < artifact.sizeBytes) {
        final remaining = artifact.sizeBytes - offset;
        final data = await raf.read(remaining < _artifactChunkSizeBytes ? remaining : _artifactChunkSizeBytes);
        offset += data.length;
        final isLast = offset >= artifact.sizeBytes;
        yield Chunk(
          data: data,
          offset: fixnum.Int64(offset - data.length),
          isLast: isLast,
          sha256FullFile: isLast ? artifact.sha256Hex : '',
        );
      }
    } finally {
      await raf.close();
    }
  }

  /// Artefakt, który ten telefon może pobrać: build z pamięci (zlecający /
  /// adresat) albo ostatnia instalka z historii projektu, jeśli telefon jest
  /// wśród jego docelowych telefonów.
  (BuiltArtifact, String projectId) _artifactFor(String buildId, String deviceId) {
    final build = engine.byId(buildId);
    if (build != null) {
      final artifact = artifacts[buildId];
      if (artifact == null) throw GrpcError.notFound('Build jeszcze nie ma gotowej instalki.');
      if (!build.canDownload(deviceId) && !build.deliversTo(deviceId)) {
        throw GrpcError.permissionDenied('Ten build nie był przeznaczony dla tego telefonu.');
      }
      return (artifact, build.projectId);
    }
    for (final project in store.projects()) {
      final entry = store.history(project.id, limit: 50).where((e) => e.buildId == buildId).firstOrNull;
      if (entry == null) continue;
      if (!project.deliversTo(deviceId)) {
        throw GrpcError.permissionDenied('Ten build nie był przeznaczony dla tego telefonu.');
      }
      if (entry.phase != BuildPhase.DONE.name || entry.artifactPath == null || !File(entry.artifactPath!).existsSync()) {
        break;
      }
      return (BuiltArtifact(filePath: entry.artifactPath!, sha256Hex: entry.sha256!, sizeBytes: entry.sizeBytes!), project.id);
    }
    throw GrpcError.notFound('Instalka niedostępna (usunięta albo nieznany build).');
  }

  /// Instalka projektu o danej sumie, która wciąż leży na dysku (baza delty).
  String? _basePath(String projectId, String sha) {
    for (final e in store.history(projectId, limit: 50)) {
      if (e.sha256 == sha && e.artifactPath != null && File(e.artifactPath!).existsSync()) return e.artifactPath;
    }
    return null;
  }

  @override
  Stream<Chunk> downloadDelta(ServiceCall call, DeltaRequest request) async* {
    final device = _auth(call, 'DownloadDelta', request.writeToBuffer());
    final (artifact, projectId) = _artifactFor(request.buildId, device.deviceId);
    String? basePath;
    if (request.baseSha256.isNotEmpty) {
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(request.baseSha256)) {
        throw GrpcError.invalidArgument('Nieprawidłowa suma bazy.');
      }
      // Baza wyłącznie spośród instalek TEGO projektu — telefon podaje tylko sumę.
      basePath = _basePath(projectId, request.baseSha256);
      if (basePath == null) throw GrpcError.failedPrecondition('Komputer nie ma już tej wersji — pobierz całość.');
    }
    final delta = await deltas.get(
      buildId: request.buildId,
      targetPath: artifact.filePath,
      basePath: basePath,
      baseSha256: basePath == null ? null : request.baseSha256,
    );
    final startOffset = request.resumeFromByteOffset.toInt();
    if (startOffset < 0 || startOffset > delta.sizeBytes) {
      throw GrpcError.invalidArgument('Nieprawidłowy resume_from_byte_offset.');
    }
    operationLog.record(deviceId: device.deviceId, event: 'delta_download', details: {
      'build_id': request.buildId,
      'base': basePath == null ? 'none' : request.baseSha256.substring(0, 16),
      'bytes': delta.sizeBytes,
      'full_bytes': artifact.sizeBytes,
    });
    Chunk last() => Chunk(
          data: const [],
          offset: fixnum.Int64(delta.sizeBytes),
          isLast: true,
          sha256FullFile: delta.sha256Hex,
          totalSize: fixnum.Int64(delta.sizeBytes),
          targetSha256: artifact.sha256Hex,
          targetSize: fixnum.Int64(artifact.sizeBytes),
        );
    final raf = await File(delta.path).open();
    try {
      await raf.setPosition(startOffset);
      var offset = startOffset;
      while (offset < delta.sizeBytes) {
        final remaining = delta.sizeBytes - offset;
        final data = await raf.read(remaining < _artifactChunkSizeBytes ? remaining : _artifactChunkSizeBytes);
        if (data.isEmpty) break;
        yield Chunk(data: data, offset: fixnum.Int64(offset), totalSize: fixnum.Int64(delta.sizeBytes));
        offset += data.length;
      }
    } finally {
      await raf.close();
    }
    yield last();
  }

  @override
  Future<Project> updateProjectOptions(ServiceCall call, ProjectOptionsUpdate request) async {
    final device = _auth(call, 'UpdateProjectOptions', request.writeToBuffer());
    final project = store.byId(request.projectId);
    if (project == null) throw GrpcError.notFound('Nieznany projekt.');
    // Telefon zmienia wyłącznie opcje dostawy i sygnału agenta. Komendy oraz
    // „budowanie z telefonu” (zabezpieczenie ustawiane na komputerze) — nie.
    if (request.hasLaunchAfterInstall()) project.launch = request.launchAfterInstall;
    if (request.hasAgentBuildAllowed()) project.agentBuild = request.agentBuildAllowed;
    if (request.hasAgentPushAllowed()) project.agentPush = request.agentPushAllowed;
    if (request.hasInstallMode()) {
      project.install = switch (request.installMode) {
        InstallMode.AUTO => InstallPolicy.auto,
        InstallMode.ASK => InstallPolicy.ask,
        InstallMode.OFF => InstallPolicy.off,
        _ => throw GrpcError.invalidArgument('Nieznany tryb instalacji.'),
      };
    }
    if (request.hasDeliverToThisPhone()) {
      project.setDeliversTo(device.deviceId, request.deliverToThisPhone,
          devices.all.where((d) => !d.revoked).map((d) => d.deviceId));
    }
    store.saveOptions(project);
    operationLog.record(deviceId: device.deviceId, event: 'project_options_changed', details: {
      'project_id': project.id,
      'changes': request.toProto3Json(),
    });
    _optionsChanged.add(project.id);
    return toProto(store.byId(project.id)!, device.deviceId);
  }

  @override
  Future<SecretRotation> rotateSecret(ServiceCall call, Empty request) async {
    final device = _auth(call, 'RotateSecret', request.writeToBuffer());
    final secret = devices.beginRotation(device.deviceId);
    operationLog.record(deviceId: device.deviceId, event: 'secret_rotation', details: const {});
    return SecretRotation(newSecret: secret);
  }

  @override
  Future<FolderList> listAvailableFolders(ServiceCall call, Empty request) async {
    _auth(call, 'ListAvailableFolders', request.writeToBuffer());
    final creator = this.creator;
    if (creator == null) return FolderList(addingAllowed: false);
    return FolderList(
      addingAllowed: true,
      folders: [for (final (name, kind) in creator.availableFolders()) AvailableFolder(name: name, kind: kind)],
    );
  }

  @override
  Future<Project> createProject(ServiceCall call, CreateProjectRequest request) async {
    final device = _auth(call, 'CreateProject', request.writeToBuffer());
    final creator = this.creator;
    if (creator == null) {
      throw GrpcError.permissionDenied('Dodawanie projektów z telefonu jest wyłączone na komputerze (phone_add_projects).');
    }
    if (killSwitch.isPaused) {
      throw GrpcError.unavailable('Komputer aktualnie nie przyjmuje nowych zleceń (wstrzymany).');
    }
    final ProjectRecord record;
    try {
      record = await creator.create(request.folderName, request.template);
    } on ProjectCreationException catch (e) {
      throw e.alreadyExists ? GrpcError.alreadyExists(e.message) : GrpcError.invalidArgument(e.message);
    }
    operationLog.record(deviceId: device.deviceId, event: 'project_created', details: {
      'project_id': record.id,
      'template': request.template.name,
    });
    _optionsChanged.add(record.id);
    return toProto(record, device.deviceId);
  }

  final _optionsChanged = StreamController<String>.broadcast();

  /// Id projektu, którego opcje zmienił telefon (okno odświeża widok).
  Stream<String> get onOptionsChanged => _optionsChanged.stream;

  @override
  Future<Ack> cancelBuild(ServiceCall call, BuildId request) async {
    final device = _auth(call, 'CancelBuild', request.writeToBuffer());
    final build = engine.byId(request.buildId);
    if (build == null) return Ack(success: false, message: 'Nieznany lub już zakończony build.');
    if (build.requester != device.deviceId) {
      throw GrpcError.permissionDenied('Tylko telefon, który zlecił build, może go anulować.');
    }
    if (!engine.cancel(build)) return Ack(success: false, message: 'Build już zakończony.');
    return Ack(success: true, message: 'Żądanie anulowania wysłane.');
  }

  @override
  Stream<DeliveryEvent> watchDeliveries(ServiceCall call, Empty request) async* {
    final device = _auth(call, 'WatchDeliveries', request.writeToBuffer());
    yield* deliveries.watch(device.deviceId);
  }

  @override
  Future<Ack> ackDelivery(ServiceCall call, BuildId request) async {
    final device = _auth(call, 'AckDelivery', request.writeToBuffer());
    final ok = deliveries.ack(device.deviceId, request.buildId);
    if (ok) {
      operationLog.record(deviceId: device.deviceId, event: 'delivery_acked', details: {'build_id': request.buildId});
    }
    return Ack(success: ok, message: ok ? 'OK' : 'Brak takiej dostawy.');
  }

  // ------------------------------------------------------------------ podgląd web

  ProjectRecord _previewProject(String projectId) {
    final project = store.byId(projectId);
    if (project == null) throw GrpcError.notFound('Nieznany projekt.');
    if (previews == null) throw GrpcError.unimplemented('Podgląd aplikacji web jest niedostępny na tym komputerze.');
    return project;
  }

  @override
  Stream<PreviewEvent> startPreview(ServiceCall call, PreviewRequest request) async* {
    final device = _auth(call, 'StartPreview', request.writeToBuffer());
    final project = _previewProject(request.projectId);
    if (!project.preview) {
      throw GrpcError.permissionDenied('Podgląd z telefonu jest wyłączony w opcjach projektu na komputerze.');
    }
    if (!project.directory.existsSync()) throw GrpcError.failedPrecondition('Folder projektu nie istnieje na komputerze.');
    if (killSwitch.isPaused) {
      throw GrpcError.unavailable('Komputer aktualnie nie przyjmuje nowych zleceń (wstrzymany).');
    }
    final Stream<PreviewEvent> events;
    try {
      events = previews!.watch(project, requester: device.deviceId);
    } on StateError catch (e) {
      throw GrpcError.failedPrecondition(e.message);
    }
    yield* events;
  }

  @override
  Future<Ack> stopPreview(ServiceCall call, PreviewRequest request) async {
    final device = _auth(call, 'StopPreview', request.writeToBuffer());
    _previewProject(request.projectId);
    final stopped = await previews!.stop(request.projectId);
    if (stopped) {
      operationLog.record(deviceId: device.deviceId, event: 'preview_stop_requested', details: {'project_id': request.projectId});
    }
    return Ack(success: stopped, message: stopped ? 'Podgląd zatrzymany.' : 'Podgląd nie działał.');
  }

  @override
  Future<Ack> reportPreviewIssue(ServiceCall call, PreviewIssue request) async {
    final device = _auth(call, 'ReportPreviewIssue', request.writeToBuffer());
    final project = _previewProject(request.projectId);
    if (!project.preview) {
      throw GrpcError.permissionDenied('Podgląd z telefonu jest wyłączony w opcjach projektu na komputerze.');
    }
    try {
      previews!.reportIssue(project, request, deviceName: device.displayName);
    } on Object catch (e) {
      throw GrpcError.failedPrecondition(e is StateError ? e.message : 'Nie udało się zapisać zgłoszenia.');
    }
    operationLog.record(deviceId: device.deviceId, event: 'preview_issue', details: {'project_id': project.id});
    return Ack(success: true, message: 'Zgłoszenie zapisane w projekcie ($previewFeedbackFileName).');
  }
}
