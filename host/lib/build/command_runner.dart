import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Rzucany zamiast [ProcessException], gdy niezerowy kod wyjścia jest
/// skutkiem [BuildCancellation.cancel] (proces zabity celowo) — pozwala
/// odróżnić `CANCELLED` od `FAILED`.
class BuildCancelledException implements Exception {
  @override
  String toString() => 'Build anulowany.';
}

/// Token anulowania współdzielony między krokami jednego builda. `cancel()`
/// zabija AKTUALNIE trwający proces razem z procesami potomnymi (Gradle,
/// Flutter uruchamiają własne) i oznacza kolejne kroki jako anulowane.
class BuildCancellation {
  bool _cancelled = false;
  Process? _process;

  bool get isCancelled => _cancelled;

  void attachProcess(Process process) {
    _process = process;
    if (_cancelled) _killTree(process);
  }

  void cancel() {
    _cancelled = true;
    final process = _process;
    if (process != null) _killTree(process);
  }

  static void _killTree(Process process) {
    if (Platform.isWindows) {
      // `Process.kill` na Windows zabija tylko cmd.exe — Gradle/Dart żyłyby dalej.
      Process.runSync('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
    } else {
      process.kill(ProcessSignal.sigterm);
    }
  }
}

/// Uruchamianie kroków budowania (docs/SECURITY.md).
///
/// Komendy pochodzą WYŁĄCZNIE z zaszyfrowanej bazy RemoteAppTestera (wpisane albo
/// zatwierdzone lokalnie przez użytkownika) — nigdy z żądania telefonu ani
/// prosto z pliku w folderze projektu. Każdy krok to jedna linia powłoki:
/// na Windows zapisywana do tymczasowego skryptu `.cmd` (bez problemów z
/// cytowaniem argumentów cmd.exe), na Linuxie przekazywana do `bash -c`.
class CommandRunner {
  CommandRunner({Directory? scriptDir}) : scriptDir = scriptDir ?? Directory.systemTemp;

  /// Katalog na tymczasowe skrypty kroków (Windows).
  final Directory scriptDir;

  Stream<String> runShell(
    String command, {
    required String workingDirectory,
    BuildCancellation? cancellation,
  }) {
    final controller = StreamController<String>();

    () async {
      File? script;
      try {
        if (cancellation?.isCancelled ?? false) throw BuildCancelledException();
        final String executable;
        final List<String> arguments;
        if (Platform.isWindows) {
          scriptDir.createSync(recursive: true);
          script = File(p.join(scriptDir.path, 'step-${DateTime.now().microsecondsSinceEpoch}.cmd'));
          // `call` — wywołanie pliku .bat (flutter, gradlew) bez `call` kończyłoby skrypt.
          script.writeAsStringSync('@echo off\r\nchcp 65001 >nul\r\ncall $command\r\nexit /b %ERRORLEVEL%\r\n');
          executable = 'cmd.exe';
          arguments = ['/d', '/c', script.path];
        } else {
          executable = 'bash';
          arguments = ['-c', command];
        }
        final exitCode = await _run(executable, arguments, workingDirectory, cancellation, controller.add);
        if (exitCode != 0) {
          if (cancellation?.isCancelled ?? false) throw BuildCancelledException();
          throw ProcessException(command, const [], 'Krok zakończony kodem $exitCode', exitCode);
        }
      } catch (e, st) {
        controller.addError(e, st);
      } finally {
        try {
          script?.deleteSync();
        } on FileSystemException {
          // Plik tymczasowy — brak usunięcia nie jest błędem builda.
        }
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Uruchamia proces i przekazuje połączone stdout/stderr linia po linii.
  ///
  /// NIE czekamy na zamknięcie strumieni stdout/stderr jako sygnał końca —
  /// zweryfikowane empirycznie, że na Windows potrafią nigdy nie wysłać "done"
  /// po zakończeniu procesu bez wyjścia, co zawieszało build. `exitCode` jest
  /// jedynym wiarygodnym sygnałem; dane z pipe'ów są już wtedy dostarczone.
  static Future<int> _run(
    String executable,
    List<String> arguments,
    String workingDirectory,
    BuildCancellation? cancellation,
    void Function(String) onLine,
  ) async {
    final process = await Process.start(executable, arguments, workingDirectory: workingDirectory);
    cancellation?.attachProcess(process);
    unawaited(process.stdin.close());
    final out = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(onLine);
    final err = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(onLine);
    final code = await process.exitCode;
    await out.cancel();
    await err.cancel();
    return code;
  }
}
