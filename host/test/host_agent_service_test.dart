import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';
import 'package:remotetester_host/build/artifact_registry.dart';
import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/nonce_store.dart';
import 'package:remotetester_host/pairing/rate_limiter.dart';
import 'package:remotetester_host/server/delivery_hub.dart';
import 'package:remotetester_host/server/host_agent_service.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/store/project_store.dart';
import 'package:test/test.dart';

import 'device_auth_test.dart' show FakeServiceCall;
import 'support.dart';

void main() {
  late TestHost host;
  late HostAgentService service;
  late DeliveryHub deliveries;
  late KillSwitch killSwitch;
  late PairedDevice phone;
  late ProjectRecord project;

  FakeServiceCall call(PairedDevice device, String method, List<int> payload) =>
      FakeServiceCall(authMetadata(device, method, payload));

  setUp(() {
    host = TestHost();
    deliveries = DeliveryHub(finished: host.engine.onFinished, devices: host.devices);
    service = HostAgentService(
      store: host.store,
      engine: host.engine,
      deliveries: deliveries,
      devices: host.devices,
      operationLog: host.operationLog,
      artifacts: host.artifacts,
      rateLimiter: RateLimiter(maxRequestsPerMinutePerDevice: 1000),
      nonceStore: NonceStore(),
      killSwitch: killSwitch = KillSwitch(),
    );
    phone = host.devices.register('Telefon testowy');
    project = host.addProject('apka');
  });

  tearDown(() async {
    await deliveries.close();
    await host.dispose();
  });

  Future<List<BuildEvent>> build(PairedDevice who, {String profile = ''}) {
    final request = BuildRequest(projectId: project.id, profile: profile);
    return service.startBuild(call(who, 'StartBuild', request.writeToBuffer()), request).toList();
  }

  Future<Project> listed(PairedDevice who) async =>
      (await service.listProjects(call(who, 'ListProjects', Empty().writeToBuffer()), Empty())).projects.single;

  group('uwierzytelnienie', () {
    test('unpaired callers are rejected everywhere', () async {
      final anon = FakeServiceCall(const {});
      await expectLater(service.listProjects(anon, Empty()), throwsA(isA<GrpcError>()));
      await expectLater(service.startBuild(anon, BuildRequest(projectId: project.id)), emitsError(isA<GrpcError>()));
      await expectLater(service.watchDeliveries(anon, Empty()), emitsError(isA<GrpcError>()));
    });
  });

  group('pilot: lista i budowanie', () {
    test('ListProjects shows name, variants and no paths', () async {
      final p = await listed(phone);
      expect(p.displayName, 'apka');
      expect(p.profiles, ['Debug']);
      expect(p.installableOnPhone, isTrue);
      expect(p.writeToJson(), isNot(contains(host.home.path.replaceAll(r'\', r'\\'))));
    });

    test('a phone build runs the stored commands and then shows status and the last APK', () async {
      final events = await build(phone);
      expect(events.last.phase, BuildPhase.DONE, reason: events.map((e) => e.logLine).join('\n'));
      final p = await listed(phone);
      expect(p.building, isFalse);
      expect(p.lastPhase, BuildPhase.DONE);
      expect(p.lastArtifactBuildId, events.first.buildId);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the phone can only pick variants by name from the host list', () async {
      final request = BuildRequest(projectId: project.id, profile: 'rm -rf /');
      await expectLater(
        service.startBuild(call(phone, 'StartBuild', request.writeToBuffer()), request),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.invalidArgument)),
      );
    });

    test('phone builds can be disabled per project', () async {
      project.phoneTrigger = false;
      host.store.saveOptions(project);
      final request = BuildRequest(projectId: project.id);
      await expectLater(
        service.startBuild(call(phone, 'StartBuild', request.writeToBuffer()), request),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.permissionDenied)),
      );
    });

    test('kill-switch rejects new builds', () async {
      killSwitch.pause();
      final request = BuildRequest(projectId: project.id);
      await expectLater(
        service.startBuild(call(phone, 'StartBuild', request.writeToBuffer()), request),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unavailable)),
      );
    });
  });

  group('izolacja telefonów', () {
    test('only the requester may cancel; a phone outside the project targets cannot watch or download', () async {
      final other = host.devices.register('Obcy');
      project.targets = [phone.deviceId];
      host.store.saveOptions(project);
      final events = await build(phone);
      final id = BuildId(buildId: events.first.buildId);

      await expectLater(
        service.cancelBuild(call(other, 'CancelBuild', id.writeToBuffer()), id),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.permissionDenied)),
      );
      await expectLater(
        service.getBuildStatus(call(other, 'GetBuildStatus', id.writeToBuffer()), id),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.permissionDenied)),
      );
      final dl = ArtifactRequest(buildId: id.buildId);
      await expectLater(
        service.downloadArtifact(call(other, 'DownloadArtifact', dl.writeToBuffer()), dl),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.permissionDenied)),
      );
      expect((await listed(other)).lastArtifactBuildId, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('dostawy', () {
    test('a build from the desktop is delivered to the project phones, downloaded and acknowledged', () async {
      final events = <DeliveryEvent>[];
      final sub = service
          .watchDeliveries(call(phone, 'WatchDeliveries', Empty().writeToBuffer()), Empty())
          .listen(events.add);
      final record = host.engine.start(project: project, requester: desktopRequester);
      await record.watch().drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final delivery = events.where((e) => e.hasDelivery()).single.delivery;
      expect(delivery.buildId, record.buildId);
      expect(delivery.install, InstallMode.ASK, reason: 'nowe projekty domyślnie pytają na telefonie');
      expect(delivery.launch, isTrue);

      final dl = ArtifactRequest(buildId: record.buildId);
      final chunks = await service.downloadArtifact(call(phone, 'DownloadArtifact', dl.writeToBuffer()), dl).toList();
      final bytes = chunks.expand((c) => c.data).toList();
      expect(sha256.convert(bytes).toString(), delivery.sha256);

      final ack = BuildId(buildId: record.buildId);
      expect((await service.ackDelivery(call(phone, 'AckDelivery', ack.writeToBuffer()), ack)).success, isTrue);
      await sub.cancel();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('install: off means no delivery unless phones were chosen for this build', () async {
      project.install = InstallPolicy.off;
      host.store.saveOptions(project);
      final record = host.engine.start(project: project, requester: desktopRequester);
      await record.watch().drain<void>();
      expect(record.deliveredTo, isEmpty);

      final chosen = host.engine.start(project: project, requester: desktopRequester, targets: {phone.deviceId});
      await chosen.watch().drain<void>();
      expect(chosen.deliveredTo, {phone.deviceId});
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('transfer', () {
    void addFinished(String id, List<int> bytes) {
      final file = File('${host.home.path}/$id.apk')..writeAsBytesSync(bytes);
      host.engine.addFinishedForTest(
        BuildRecord(buildId: id, project: project, profile: project.profile()!, requester: phone.deviceId),
        BuiltArtifact(filePath: file.path, sha256Hex: sha256.convert(bytes).toString(), sizeBytes: bytes.length),
      );
    }

    test('streams exact bytes across chunks with SHA-256 on the last chunk, and resumes', () async {
      final bytes = List<int>.generate(300 * 1024, (i) => i % 256);
      addFinished('b1', bytes);
      final full = ArtifactRequest(buildId: 'b1');
      final chunks = await service.downloadArtifact(call(phone, 'DownloadArtifact', full.writeToBuffer()), full).toList();
      expect(chunks.length, greaterThan(1));
      expect(chunks.expand((c) => c.data).toList(), bytes);
      expect(chunks.last.sha256FullFile, sha256.convert(bytes).toString());

      final resume = ArtifactRequest(buildId: 'b1', resumeFromByteOffset: fixnum.Int64(200 * 1024));
      final rest = await service.downloadArtifact(call(phone, 'DownloadArtifact', resume.writeToBuffer()), resume).toList();
      expect(rest.expand((c) => c.data).toList(), bytes.sublist(200 * 1024));

      final atEnd = ArtifactRequest(buildId: 'b1', resumeFromByteOffset: fixnum.Int64(bytes.length));
      final last = await service.downloadArtifact(call(phone, 'DownloadArtifact', atEnd.writeToBuffer()), atEnd).toList();
      expect(last.single.isLast, isTrue);
      expect(last.single.sha256FullFile, isNotEmpty);
    });

    test('unknown builds are reported as not found', () async {
      final request = ArtifactRequest(buildId: 'nie-ma');
      await expectLater(
        service.downloadArtifact(call(phone, 'DownloadArtifact', request.writeToBuffer()), request),
        emitsError(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.notFound)),
      );
    });
  });

  group('opcje z telefonu', () {
    Future<Project> update(PairedDevice who, ProjectOptionsUpdate u) =>
        service.updateProjectOptions(call(who, 'UpdateProjectOptions', u.writeToBuffer()), u);

    test('the phone changes delivery and agent options; unset fields stay', () async {
      final p = await update(phone, ProjectOptionsUpdate(
        projectId: project.id,
        launchAfterInstall: false,
        installMode: InstallMode.ASK,
        agentBuildAllowed: false,
      ));
      expect((p.launchAfterInstall, p.installMode, p.agentBuildAllowed), (false, InstallMode.ASK, false));
      final stored = host.store.byId(project.id)!;
      expect((stored.launch, stored.install, stored.agentBuild, stored.phoneTrigger), (false, InstallPolicy.ask, false, true));
      final again = await update(phone, ProjectOptionsUpdate(projectId: project.id, launchAfterInstall: true));
      expect((again.launchAfterInstall, again.installMode), (true, InstallMode.ASK));
    });

    test('a phone can opt itself out of deliveries without affecting other phones', () async {
      final other = host.devices.register('Drugi');
      final p = await update(phone, ProjectOptionsUpdate(projectId: project.id, deliverToThisPhone: false));
      expect(p.deliversToThisPhone, isFalse);
      var stored = host.store.byId(project.id)!;
      expect((stored.deliversTo(phone.deviceId), stored.deliversTo(other.deviceId)), (false, true));

      await update(other, ProjectOptionsUpdate(projectId: project.id, deliverToThisPhone: false));
      stored = host.store.byId(project.id)!;
      expect(stored.targets, [noPhonesTarget], reason: 'żaden telefon — nie „wszystkie”');
      expect((stored.deliversTo(phone.deviceId), stored.deliversTo(other.deviceId)), (false, false));

      expect((await update(phone, ProjectOptionsUpdate(projectId: project.id, deliverToThisPhone: true))).deliversToThisPhone, isTrue);
      expect(host.store.byId(project.id)!.targets, [phone.deviceId]);
    });

    test('unknown projects and unpaired callers are rejected', () async {
      await expectLater(update(phone, ProjectOptionsUpdate(projectId: 'brak')), throwsA(isA<GrpcError>()));
      await expectLater(
          service.updateProjectOptions(FakeServiceCall(const {}), ProjectOptionsUpdate(projectId: project.id)),
          throwsA(isA<GrpcError>()));
    });
  });
}
