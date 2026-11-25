import 'dart:convert';
import 'dart:io';

import 'translations.dart';

const supportedLanguageCodes = ['pl', 'en', 'de', 'cs'];

/// Plik ustawień wyglądu w katalogu danych — ten sam, którego używa okno Windows.
const uiSettingsPath = 'config/ui.json';

String? _code;

/// Język tekstów rdzenia i `rt` (aplikacja okienkowa ustawia go przy wyborze języka).
void setHostLanguage(String code) => _code = supportedLanguageCodes.contains(code) ? code : 'en';

/// Język z ustawień (`rt lang`), a bez nich z systemu; inny niż obsługiwane = angielski.
String get hostLanguageCode => _code ??= _systemLanguage();

/// Wczytuje wybór z `config/ui.json` (bieżący katalog = katalog danych).
void loadHostLanguage() {
  try {
    final saved = (jsonDecode(File(uiSettingsPath).readAsStringSync()) as Map<String, dynamic>)['language'];
    if (saved is String && supportedLanguageCodes.contains(saved)) _code = saved;
  } on Object {
    // Brak pliku albo uszkodzony — język systemu.
  }
}

/// Zapisuje wybór; `system` (albo `auto`) wraca do języka systemu. Inne ustawienia w pliku zostają.
void saveHostLanguage(String code) {
  Map<String, dynamic> json = {};
  final file = File(uiSettingsPath);
  try {
    json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on Object {
    // Nowy plik.
  }
  json['language'] = code;
  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(json));
  _code = supportedLanguageCodes.contains(code) ? code : _systemLanguage();
}

String _systemLanguage() {
  final env = Platform.environment;
  final locale = [env['LC_ALL'], env['LC_MESSAGES'], env['LANG'], Platform.localeName]
      .firstWhere((v) => v != null && v.length >= 2 && v != 'C' && v != 'POSIX', orElse: () => 'en')!;
  final code = locale.substring(0, 2).toLowerCase();
  return supportedLanguageCodes.contains(code) ? code : 'en';
}

/// Tłumaczy tekst. Kluczem jest tekst polski; `{0}`, `{1}`… — wartości z [args].
String tr(String pl, [List<Object?> args = const []]) {
  var text = switch (hostLanguageCode) {
    'en' => translationsEn[pl],
    'de' => translationsDe[pl],
    'cs' => translationsCs[pl],
    _ => null,
  } ??
      pl;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}
