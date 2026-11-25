import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';
import 'package:remotetester_host/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/nonce_store.dart';
import 'package:remotetester_host/pairing/rate_limiter.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/server/delivery_hub.dart';
import 'package:remotetester_host/server/host_agent_service.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/transfer/apk_delta.dart';
import 'package:test/test.dart';

import 'device_auth_test.dart' show FakeServiceCall;
import 'support.dart';

Uint8List _random(int length, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
}

void main() {
  group('delta RTD1', () {
    test('rebuilds the target exactly and sends only what changed', () {
      final base = _random(400 * 1024, 1);
      // Nowa wersja: kawałek podmieniony, kawałek wstawiony (przesunięcie), koniec ucięty.
      final target = Uint8List.fromList([
        ...base.sublist(0, 100000),
        ..._random(5000, 2),
        ...base.sublist(100000, 300000),
        ..._random(300, 3),
        ...base.sublist(310000, 390000),
      ]);
      final delta = computeDelta(base, target);
      expect(applyDelta(base, delta), target);
      expect(delta.length, lessThan(20 * 1024), reason: 'delta ${delta.length} B');
    });

    test('works without a base (whole file) and for tiny or empty files', () {
      for (final target in [Uint8List(0), Uint8List.fromList([1, 2, 3]), _random(10000, 4)]) {
        expect(applyDelta(Uint8List(0), computeDelta(Uint8List(0), target)), target);
        expect(applyDelta(_random(5000, 5), computeDelta(_random(5000, 5), target)), target);
      }
    });

    test('identical files compress to a few bytes', () {
      final base = _random(100000, 6);
      expect(computeDelta(base, base).length, lessThan(20));
    });

    test('rejects data that is not a delta', () {
      expect(() => applyDelta(Uint8List(0), Uint8List.fromList([1, 2, 3, 4, 0])), throwsFormatException);
    });
  });

  group('DownloadDelta', () {
    late TestHost host;
    late HostAgentService service;
    late DeliveryHub deliveries;
    late PairedDevice phone;

    FakeServiceCall call(String method, List<int> payload) => FakeServiceCall(authMetadata(phone, method, payload));

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
        killSwitch: KillSwitch(),
      );
      phone = host.devices.register('Telefon');
    });

    tearDown(() async {
      await deliveries.close();
      await host.dispose();
    });

    Future<String> buildWith(String projectId, String content) async {
      host.store.saveProfiles(projectId, [fakeProfile(steps: [BuildStep('Zbuduj', 'echo $content> out.apk')])]);
      final request = BuildRequest(projectId: projectId);
      final events = await service.startBuild(call('StartBuild', request.writeToBuffer()), request).toList();
      expect(events.last.phase, BuildPhase.DONE, reason: events.map((e) => e.logLine).join('\n'));
      return events.first.buildId;
    }

    Future<List<Chunk>> download(String buildId, {String base = '', int from = 0}) {
      final r = DeltaRequest(buildId: buildId, baseSha256: base, resumeFromByteOffset: fixnum.Int64(from));
      return service.downloadDelta(call('DownloadDelta', r.writeToBuffer()), r).toList();
    }

    test('phone with the previous APK gets a delta that rebuilds the new one; resume works', () async {
      final project = host.addProject('apka');
      final first = await buildWith(project.id, 'pierwsza');
      final firstApk = File(host.artifacts[first]!.filePath).readAsBytesSync();
      final second = await buildWith(project.id, 'druga');
      final secondArtifact = host.artifacts[second]!;

      final chunks = await download(second, base: sha256.convert(firstApk).toString());
      final last = chunks.last;
      expect(last.isLast, isTrue);
      expect(last.targetSha256, secondArtifact.sha256Hex);
      expect(last.targetSize.toInt(), secondArtifact.sizeBytes);
      final packed = [for (final c in chunks) ...c.data];
      expect(sha256.convert(packed).toString(), last.sha256FullFile);
      final rebuilt = applyDelta(firstApk, Uint8List.fromList(gzip.decode(packed)));
      expect(sha256.convert(rebuilt).toString(), secondArtifact.sha256Hex);

      final rest = await download(second, base: sha256.convert(firstApk).toString(), from: 5);
      expect([...packed.sublist(0, 5), for (final c in rest) ...c.data], packed);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('without a base the whole APK comes compressed; unknown or foreign bases are refused', () async {
      final project = host.addProject('apka');
      final other = host.addProject('inna');
      final foreign = await buildWith(other.id, 'obca');
      final foreignSha = host.artifacts[foreign]!.sha256Hex;
      final build = await buildWith(project.id, 'nasza');

      final chunks = await download(build);
      final rebuilt = applyDelta(Uint8List(0), Uint8List.fromList(gzip.decode([for (final c in chunks) ...c.data])));
      expect(sha256.convert(rebuilt).toString(), host.artifacts[build]!.sha256Hex);

      for (final base in [foreignSha, 'a' * 64]) {
        await expectLater(download(build, base: base),
            throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.failedPrecondition)));
      }
      await expectLater(download(build, base: '../x'),
          throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.invalidArgument)));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
