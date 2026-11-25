import 'dart:io';

import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/generated/remote_tester.pb.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late TestHost host;

  setUp(() => host = TestHost());
  tearDown(() => host.dispose());

  test('runs the commands from the database, copies the APK and records history', () async {
    final project = host.addProject('apka');
    final record = host.engine.start(project: project, requester: desktopRequester);
    await record.watch().drain<void>();

    expect(record.phase, BuildPhase.DONE, reason: record.events.map((e) => e.logLine).join('\n'));
    expect(record.artifact, isNotNull);
    expect(record.artifact!.filePath, startsWith(host.home.path));
    expect(File(record.artifact!.filePath).existsSync(), isTrue);
    expect(host.store.history(project.id).single.phase, 'DONE');
    expect(File('${host.home.path}/logs/builds/${record.buildId}.log').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('different projects build in parallel, the same project waits', () async {
    final slow = [BuildStep('Czekaj', longRunningCommand)];
    final a = host.addProject('a', profiles: [fakeProfile(steps: slow)]);
    final b = host.addProject('b', profiles: [fakeProfile(steps: slow)]);

    final ra = host.engine.start(project: a, requester: desktopRequester);
    final rb = host.engine.start(project: b, requester: desktopRequester);
    final ra2 = host.engine.start(project: a, profile: fakeProfile(name: 'Inny'), requester: desktopRequester);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(ra.started && rb.started, isTrue, reason: 'dwa projekty naraz (limit 2)');
    expect(ra2.started, isFalse, reason: 'ten sam projekt czeka na swój poprzedni build');
    expect(host.engine.runningCount, 2);

    for (final r in [ra, rb, ra2]) {
      host.engine.cancel(r);
    }
    for (final r in [ra, rb, ra2]) {
      await r.watch().drain<void>().timeout(const Duration(seconds: 15));
    }
    expect([ra.phase, rb.phase, ra2.phase], everyElement(BuildPhase.CANCELLED));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('repeated requests for a queued build of the same project return the same build', () async {
    final slow = [BuildStep('Czekaj', longRunningCommand)];
    final a = host.addProject('a', profiles: [fakeProfile(steps: slow)]);
    final first = host.engine.start(project: a, requester: localRequester);
    final queued = host.engine.start(project: a, requester: localRequester);
    final again = host.engine.start(project: a, requester: localRequester);
    expect(identical(queued, again), isTrue);
    expect(identical(first, queued), isFalse);
    host.engine.cancel(queued);
    host.engine.cancel(first);
    await first.watch().drain<void>().timeout(const Duration(seconds: 15));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('a missing artifact fails the build with a hint', () async {
    final project = host.addProject('apka',
        profiles: [BuildProfile(name: 'X', steps: const [BuildStep('nic', 'echo nic')], artifact: 'brak/*.apk')]);
    final record = host.engine.start(project: project, requester: desktopRequester);
    await record.watch().drain<void>();
    expect(record.phase, BuildPhase.FAILED);
    expect(record.events.last.logLine, contains('nie znaleziono instalki'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}
