import 'dart:io';

import 'package:remotetester_host/i18n.dart';
import 'package:remotetester_host/translations.dart';
import 'package:test/test.dart';

/// Każdy tekst `rt` z tr('...') ma tłumaczenie EN / DE / CS z tymi samymi {0}, {1}…
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
      final value = key.replaceAll(r'\n', '\n').replaceAll(r"\'", "'");
      for (final (name, map) in [('en', translationsEn), ('de', translationsDe), ('cs', translationsCs)]) {
        final t = map[value];
        if (t == null) {
          problems.add('$name: brak "$key"');
        } else if (holes(t).length != holes(value).length || !holes(t).containsAll(holes(value))) {
          problems.add('$name: inne {n} w "$key"');
        }
      }
    }
    expect(problems, isEmpty);
  });

  test('tr() fills values in the chosen language', () {
    setHostLanguage('en');
    expect(tr('Telefon {0}', ['A']), 'Phone A');
    setHostLanguage('pl');
    expect(tr('Telefon {0}', ['A']), 'Telefon A');
  });
}
