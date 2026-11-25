import 'dart:io';

import 'package:remotetester_host/build/command_runner.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Testy uruchamiające PRAWDZIWE procesy przez powłokę (cmd / bash). Regresja z
/// realnego testu end-to-end: proces bez żadnego wyjścia wieszał pipeline na
/// Windows, bo strumienie stdout/stderr nie zawsze sygnalizują "done".
void main() {
  late Directory dir;
  late CommandRunner runner;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('command_runner_exec_test_');
    runner = CommandRunner(scriptDir: Directory('${dir.path}/tmp'));
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('runs a shell command in the project folder and streams its output', () async {
    final lines = await runner.runShell('echo hello', workingDirectory: dir.path).toList();
    expect(lines.map((l) => l.trim()), contains('hello'));
  });

  test('a .bat-style chain works (call keeps the script going)', () async {
    await runner.runShell('echo apk> out.apk', workingDirectory: dir.path).drain<void>();
    expect(File('${dir.path}/out.apk').existsSync(), isTrue);
  });

  test('a step with zero output completes promptly', () async {
    final lines = await runner
        .runShell(Platform.isWindows ? 'rem cisza' : 'true', workingDirectory: dir.path)
        .toList()
        .timeout(const Duration(seconds: 10), onTimeout: () => fail('step hung'));
    expect(lines.where((l) => l.trim().isNotEmpty), isEmpty);
  });

  test('a failing step surfaces ProcessException with its exit code', () async {
    await expectLater(
      runner.runShell('exit 3', workingDirectory: dir.path).toList(),
      throwsA(isA<ProcessException>().having((e) => e.errorCode, 'code', 3)),
    );
  });

  test('temporary step scripts are removed', () async {
    await runner.runShell('echo x', workingDirectory: dir.path).drain<void>();
    final tmp = Directory('${dir.path}/tmp');
    expect(!tmp.existsSync() || tmp.listSync().isEmpty, isTrue);
  });

  group('BuildCancellation', () {
    test('cancel() kills a running step (with its child processes) quickly', () async {
      final cancellation = BuildCancellation();
      final run = runner.runShell(longRunningCommand, workingDirectory: dir.path, cancellation: cancellation).toList();
      await Future<void>.delayed(const Duration(seconds: 1));
      cancellation.cancel();
      await expectLater(
        run.timeout(const Duration(seconds: 10), onTimeout: () => fail('cancel() did not stop the step')),
        throwsA(isA<BuildCancelledException>()),
      );
    });

    test('a step started with an already-cancelled token never runs', () async {
      final cancellation = BuildCancellation()..cancel();
      await expectLater(
        runner.runShell('echo apk> out.apk', workingDirectory: dir.path, cancellation: cancellation).toList(),
        throwsA(isA<BuildCancelledException>()),
      );
      expect(File('${dir.path}/out.apk').existsSync(), isFalse);
    });
  });
}
