import 'dart:convert';
import 'dart:io';

/// Log operacji lokalny, append-only, z adnotacją KTÓRE urządzenie co
/// zleciło (docs/architektura-remote-build.md, sekcja 4, punkt 7).
class OperationLog {
  OperationLog(this._file);

  final File _file;

  void record({
    required String deviceId,
    required String event,
    Map<String, Object?> details = const {},
  }) {
    _file.parent.createSync(recursive: true);
    final entry = {
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': deviceId,
      'event': event,
      ...details,
    };
    _file.writeAsStringSync('${jsonEncode(entry)}\n', mode: FileMode.append);
  }
}
