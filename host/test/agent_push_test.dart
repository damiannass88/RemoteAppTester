import 'dart:async';
import 'dart:io';

import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/cli/remotetester_cli.dart';
import 'package:remotetester_host/generated/remote_tester.pbenum.dart';
import 'package:remotetester_host/project/agent_signal.dart';
import 'package:remotetester_host/project/artifact_finder.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/server/signal_watcher.dart';
import 'package:remotetester_host/store/project_store.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Najmniejszy plik, który wygląda jak APK (nagłówek ZIP).
File fakeApk(String path) => File(path)
  ..parent.createSync(recursive: true)
  ..writeAsBytesSync([0x50, 0x4B, 0x03, 0x04, ...List.filled(64, 7)]);

Future<Map<String, Object?>> waitForState(Directory dir, Set<String> states) async {
  for (var i = 0; i < 200; i++) {
    final status = readAgentStatus(dir);
    if (status != null && states.contains(status['state'])) return status;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Brak stanu $states w $agentStatusFileName: ${readAgentStatus(dir)}');
}

void main() {
  test('only a signed .apk inside the project folder is accepted', () {
    final dir = Directory.systemTemp.createTempSync('rt_push_');
    addTearDown(() => dir.deleteSync(recursive: true));
    fakeApk('${dir.path}/build/app-debug.apk');
    expect(resolvePushedArtifact(dir, 'build/app-debug.apk').existsSync(), isTrue);
    File('${dir.path}/fake.apk').writeAsStringSync('not a zip');
    fakeApk('${dir.path}/app-release-unsigned.apk');
    fakeApk('${dir.path}/notes.txt');
    for (final bad in ['../x.apk', '/etc/x.apk', 'C:/x.apk', 'brak.apk', 'fake.apk', 'app-release-unsigned.apk', 'notes.txt']) {
      expect(() => resolvePushedArtifact(dir, bad), throwsA(isA<ProfileException>()), reason: bad);
    }
    final outside = Directory.systemTemp.createTempSync('rt_push_out_');
    addTearDown(() => outside.deleteSync(recursive: true));
    fakeApk('${outside.path}/evil.apk');
    try {
      Link('${dir.path}/link.apk').createSync('${outside.path}/evil.apk');
      expect(() => resolvePushedArtifact(dir, 'link.apk'), throwsA(isA<ProfileException>()));
    } on FileSystemException {
      // Windows bez uprawnień do dowiązań — reszta sprawdzona wyżej.
    }
  });

  test('the signal carries deliver and request; a template without them is not a push', () {
    final s = parseAgentSignal('build: false\nmessage: "x"\ndeliver: "build/a.apk"\nrequest: "ab12"\n');
    expect((s.deliver, s.request), ('build/a.apk', 'ab12'));
    expect(parseAgentSignal('deliver: "a.apk"\nrequest: "zła wartość!"').request, isNull);
    expect(parseAgentSignal(agentSignalTemplate()).isSignal, isFalse);
  });

  group('SignalWatcher', () {
    late TestHost host;
    late KillSwitch killSwitch;
    late SignalWatcher watcher;

    setUp(() {
      host = TestHost();
      killSwitch = KillSwitch();
      watcher = SignalWatcher(
        store: host.store,
        engine: host.engine,
        killSwitch: killSwitch,
        operationLog: host.operationLog,
        interval: const Duration(milliseconds: 100),
        settle: Duration.zero,
      );
    });

    tearDown(() async {
      watcher.close();
      await host.dispose();
    });

    test('a pushed APK becomes a delivered build with a status for the agent', () async {
      final project = host.addProject('apka');
      expect(project.agentPush, isTrue, reason: 'domyślnie włączone');
      fakeApk('${project.path}/build/app-debug.apk');
      writeAgentSignal(project.directory, message: 'Nowy ekran', deliver: 'build/app-debug.apk', request: 'r1');
      watcher.scan();
      final status = await waitForState(project.directory, {'done', 'failed', 'rejected'});
      expect(status['request'], 'r1');
      expect(status['action'], 'push');
      expect(status['state'], 'done');
      expect(status['size_bytes'], 68);
      final record = host.engine.lastFor(project.id)!;
      expect((record.prebuilt, record.phase, record.requester), (true, BuildPhase.DONE, agentRequester));
      expect(host.engine.lastArtifact(project.id), isNotNull, reason: '„zainstaluj ostatnią” działa');
      expect(host.store.history(project.id).first.profile, agentPushProfileName);
      expect(host.store.byId(project.id)!.agentNote, 'Nowy ekran');
    });

    test('a push is rejected with a reason when the option is off or the file is bad', () async {
      final project = host.addProject('apka');
      host.store.saveOptions(host.store.byId(project.id)!..agentPush = false);
      fakeApk('${project.path}/app.apk');
      writeAgentSignal(project.directory, deliver: 'app.apk', request: 'r2');
      watcher.scan();
      var status = readAgentStatus(project.directory)!;
      expect((status['request'], status['state']), ('r2', 'rejected'));
      expect(status['message'], contains('--agent-push'));
      expect(host.engine.lastFor(project.id), isNull);

      host.store.saveOptions(host.store.byId(project.id)!..agentPush = true);
      writeAgentSignal(project.directory, deliver: '../poza.apk', request: 'r3');
      watcher.scan();
      status = readAgentStatus(project.directory)!;
      expect((status['request'], status['state']), ('r3', 'rejected'));
    });

    test('a build signal reports its result too', () async {
      final project = host.addProject('apka');
      writeAgentSignal(project.directory, build: true, message: 'zmiany', request: 'b1');
      watcher.scan();
      final status = await waitForState(project.directory, {'done', 'failed'});
      expect((status['request'], status['action'], status['state']), ('b1', 'build', 'done'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a failed build gives the agent the end of the log', () async {
      final project = host.addProject('apka', profiles: [fakeProfile(steps: const [BuildStep('Zepsuty', 'exit 3')])]);
      writeAgentSignal(project.directory, build: true, request: 'b2');
      watcher.scan();
      final status = await waitForState(project.directory, {'done', 'failed'});
      expect(status['state'], 'failed');
      expect(status['log_tail'], isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('rt push --wait sends a file from outside the project and returns the result', () async {
      final project = host.addProject('apka');
      final outside = Directory.systemTemp.createTempSync('rt_push_cli_');
      addTearDown(() => outside.deleteSync(recursive: true));
      fakeApk('${outside.path}/app.apk');
      final previous = Directory.current;
      addTearDown(() => Directory.current = previous);
      // Brak sparowanych telefonów: gotowe, ale nikt nie dostał wersji = kod 4.
      final code = await runCli(['--cwd', project.path, 'push', '${outside.path}/app.apk', '-m', 'z CI', '--wait', '--json']);
      expect(code, 4);
      expect(File('${project.path}/$agentPushFileName').existsSync(), isTrue);
      expect(host.engine.lastFor(project.id)!.prebuilt, isTrue);
      expect(await runCli(['--cwd', project.path, 'st', '--json']), 0);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('rt push outside a project, or without a file to send, fails clearly', () async {
      final empty = Directory.systemTemp.createTempSync('rt_push_none_');
      addTearDown(() => empty.deleteSync(recursive: true));
      expect(await runCli(['--cwd', empty.path, 'push']), 1);
      final project = host.addProject('apka');
      expect(await runCli(['--cwd', project.path, 'push']), 1, reason: 'brak build/**/*.apk');
      expect(await runCli(['--cwd', project.path, 'push', '--timeout', 'x', '--wait']), 64);
    });
  });

  test('without a running RemoteAppTester rt push --wait ends with code 3', () async {
    final host = TestHost();
    addTearDown(host.dispose);
    final project = host.addProject('apka');
    fakeApk('${project.path}/build/app.apk');
    final previous = agentPickupTimeout;
    agentPickupTimeout = const Duration(seconds: 1);
    addTearDown(() => agentPickupTimeout = previous);
    expect(await runCli(['--cwd', project.path, 'push', '--wait']), 3);
    expect(project.install, InstallPolicy.ask);
  });
}
