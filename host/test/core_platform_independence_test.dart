import 'dart:io';

import 'package:test/test.dart';

/// rdzeń agenta musi dać się skompilować bez Fluttera (`dart compile
/// exe bin/agent.dart` → headless agent na Linuxie/VPS). Flutter wolno
/// importować wyłącznie w obudowie GUI Windows: `lib/main.dart` i `lib/ui/`.
void main() {
  test('no file in the agent core imports package:flutter', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll(r'\', '/');
      if (normalized == 'lib/main.dart' || normalized.startsWith('lib/ui/')) continue;
      if (entity.readAsStringSync().contains("import 'package:flutter/")) {
        offenders.add(normalized);
      }
    }
    expect(offenders, isEmpty, reason: 'Rdzeń importuje Fluttera: $offenders');
  });
}
