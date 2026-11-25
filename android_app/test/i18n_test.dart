import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/translations.dart';

/// Każdy tekst z tr('...') ma tłumaczenie EN / DE / CS z tymi samymi {0}, {1}…
/// (tłumaczenia: tool/i18n/translations.py → python tool/i18n/generate.py).
void main() {
  test('every tr() key is translated with the same placeholders', () {
    final call = RegExp(r"\btr\('((?:[^'\\]|\\.)*)'");
    final keys = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('generated') || f.path.endsWith('translations.dart')) continue;
      keys.addAll(call.allMatches(f.readAsStringSync()).map((m) => m.group(1)!));
    }
    expect(keys, isNotEmpty);
    Set<String> holes(String s) => RegExp(r'\{\d+\}').allMatches(s).map((m) => m.group(0)!).toSet();
    final problems = <String>[];
    for (final key in keys) {
      // Klucze w kodzie są w postaci źródłowej (np. \n jako dwa znaki) — mapy są już rozwinięte.
      final value = key.replaceAll(r'\n', '\n').replaceAll(r"\'", "'");
      for (final (name, map) in [('en', translationsEn), ('de', translationsDe), ('cs', translationsCs)]) {
        final t = map[value];
        if (t == null) {
          problems.add('$name: brak „$key”');
        } else if (!setEquals(holes(t), holes(value))) {
          problems.add('$name: inne {n} w „$key”');
        }
      }
    }
    expect(problems, isEmpty);
  });
}
