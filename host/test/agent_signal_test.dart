import 'dart:io';

import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/cli/remotetester_cli.dart';
import 'package:remotetester_host/generated/remote_tester.pbenum.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/agent_signal.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/server/signal_watcher.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Agent zmienia wzór tak, jak opisuje to sam plik.
void editSignal(Directory dir, {required bool build, required String message}) {
  final file = agentSignalFile(dir);
  file.writeAsStringSync(file
      .readAsStringSync()
      .replaceFirst('build: false', 'build: $build')
      .replaceFirst('message: ""', 'message: "$message"'));
}

void main() {
  group('plik sygnału', () {
    test('YAML, JSON and plain text are parsed; the untouched template is not a signal', () {
      final yaml = parseAgentSignal('# komentarz\nbuild: true\nmessage: "Nowy\\nekran\\u202E logowania"\n');
      expect((yaml.build, yaml.message), (true, 'Nowy ekran logowania'));
      final json = parseAgentSignal('{"build": true, "message": "ok"}');
      expect((json.build, json.message), (true, 'ok'));
      final text = parseAgentSignal('﻿gotowe\r\n');
      expect((text.build, text.message), (false, 'gotowe'));
      expect(parseAgentSignal('build: "yes"\nmessage: ""').isSignal, isFalse);
      expect(parseAgentSignal(agentSignalTemplate()).isSignal, isFalse);
      expect(parseAgentSignal(agentSignalTemplate(lastReceived: DateTime.now())).isSignal, isFalse);
      expect(sanitizeAgentNote('x' * 1000)!.length, maxAgentNoteLength);
    });

    test('the template is always there; an edited one is read once and restored', () {
      final dir = Directory.systemTemp.createTempSync('rt_sig_');
      addTearDown(() => dir.deleteSync(recursive: true));
      expect(consumeAgentSignal(dir, settle: Duration.zero), isNull);
      final file = agentSignalFile(dir);
      expect(file.readAsStringSync(), agentSignalTemplate(), reason: 'brakujący plik odtworzony jako wzór');
      expect(consumeAgentSignal(dir, settle: Duration.zero), isNull, reason: 'wzór bez zmian to nie sygnał');

      editSignal(dir, build: true, message: 'zrobione');
      expect(consumeAgentSignal(dir, settle: const Duration(minutes: 1)), isNull, reason: 'świeżo zapisany — czekamy');
      final s = consumeAgentSignal(dir, settle: Duration.zero)!;
      expect((s.build, s.message), (true, 'zrobione'));
      expect(file.readAsStringSync(), contains('Ostatni przyjęty sygnał'));
      expect(consumeAgentSignal(dir, settle: Duration.zero), isNull, reason: 'odczytany tylko raz');

      file.writeAsStringSync('message: "${'a' * 5000}"');
      expect(consumeAgentSignal(dir, settle: Duration.zero)!.build, isFalse, reason: 'za duży: bez builda');
      expect(parseAgentSignal(file.readAsStringSync()).isSignal, isFalse);
    });
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
        interval: const Duration(hours: 1),
        settle: Duration.zero,
      );
    });

    tearDown(() async {
      watcher.close();
      await host.dispose();
    });

    test('a new project gets the signal template and agent hints; builds on signal by default', () async {
      final project = host.addProject('apka');
      expect(project.agentBuild, isTrue, reason: 'domyślnie włączone');
      for (final name in agentInstructionFiles) {
        expect(File('${project.path}/$name').readAsStringSync(), contains('.remoteapptester-signal'));
      }
      editSignal(project.directory, build: true, message: 'Dodano logowanie');
      watcher.scan();
      final record = host.engine.activeFor(project.id)!;
      expect(record.requester, agentRequester);
      expect(host.store.byId(project.id)!.agentNote, 'Dodano logowanie');
      await record.watch().drain<void>();
      expect(record.phase, BuildPhase.DONE);
      final fresh = host.store.byId(project.id)!;
      expect(fresh.changesPending, isFalse, reason: 'udany build obejmuje zgłoszone zmiany');
      expect(fresh.agentNote, 'Dodano logowanie', reason: 'notatka zostaje do podglądu');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('with the option off a signal only marks changes; no build while paused', () async {
      final project = host.addProject('apka');
      host.store.saveOptions(host.store.byId(project.id)!..agentBuild = false);
      editSignal(project.directory, build: true, message: 'zmiany');
      watcher.scan();
      expect(host.store.byId(project.id)!.changesPending, isTrue);
      expect(host.engine.activeFor(project.id), isNull);

      host.store.saveOptions(host.store.byId(project.id)!..agentBuild = true);
      killSwitch.toggle();
      editSignal(project.directory, build: true, message: 'jeszcze');
      watcher.scan();
      expect(host.engine.activeFor(project.id), isNull);
      killSwitch.toggle();

      host.store.clearChanges(project.id, before: DateTime.now().subtract(const Duration(minutes: 1)));
      expect(host.store.byId(project.id)!.changesPending, isTrue, reason: 'zmiany zgłoszone po starcie builda zostają');
    });
  });

  test('agent hints are added to existing CLAUDE.md / AGENTS.md once and kept up to date', () {
    final dir = Directory.systemTemp.createTempSync('rt_ptr_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/CLAUDE.md').writeAsStringSync('# Mój projekt\n\nZasady zespołu.\n');
    ensureAgentPointers(dir);
    ensureAgentPointers(dir);
    final text = File('${dir.path}/CLAUDE.md').readAsStringSync();
    expect(text, startsWith('# Mój projekt\n\nZasady zespołu.\n'));
    expect('remoteapptester:agents:begin'.allMatches(text).length, 1);
    expect(File('${dir.path}/AGENTS.md').readAsStringSync(), contains('rt sg'));
  });

  test('rt sg writes the signal in the nearest project folder without touching host data', () async {
    final dir = Directory.systemTemp.createTempSync('rt_sig_cli_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/REMOTEAPPTESTER.md').writeAsStringSync('# x');
    final sub = Directory('${dir.path}/lib/src')..createSync(recursive: true);
    final previous = Directory.current;
    addTearDown(() => Directory.current = previous);
    final code = await runCli(['--home', '${dir.path}/brak-danych', '--cwd', sub.path, 'sg', '-m', 'gotowe', '--build']);
    expect(code, 0);
    final signal = consumeAgentSignal(dir, settle: Duration.zero)!;
    expect((signal.build, signal.message), (true, 'gotowe'));
    expect(Directory('${dir.path}/brak-danych').existsSync(), isFalse);
    expect(await runCli(['--cwd', sub.path, 'sg']), 0);
    expect(consumeAgentSignal(dir, settle: Duration.zero)!.message, 'Zmiany gotowe');
    expect(await runCli(['--cwd', Directory.systemTemp.path, 'sg']), 1);
  });

  test('old REMOTEAPPTESTER.md gets new instructions; the command block and a pending proposal stay', () {
    final host = TestHost();
    addTearDown(host.dispose);
    final project = host.addProject('apka');
    final file = agentGuideFile(project.directory);
    final original = file.readAsStringSync();
    final block = original.substring(original.indexOf('<!-- remoteapptester:begin -->'));
    final proposal = block.replaceFirst('echo apk> out.apk', 'echo inna> out.apk');
    file.writeAsStringSync('# Stare wytyczne\nrt b\n\n$proposal');
    expect(refreshGuideInstructions(project.directory, project.name), isTrue);
    final text = file.readAsStringSync();
    expect(text, contains('.remoteapptester-signal'));
    expect(text, isNot(contains('Stare wytyczne')));
    expect(text, endsWith(proposal));
    expect(host.store.guideState(host.store.byId(project.id)!).status, GuideStatus.proposal);
    expect(refreshGuideInstructions(project.directory, project.name), isFalse);
  });
}
