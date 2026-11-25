import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations.dart';

/// Języki interfejsu. `system` = język telefonu (jeśli obsługiwany, inaczej angielski).
enum AppLanguage { system, pl, en, de, cs }

const supportedLanguageCodes = ['pl', 'en', 'de', 'cs'];

/// Nazwy języków w ich własnym języku (lista wyboru).
const languageNames = {
  AppLanguage.pl: 'Polski',
  AppLanguage.en: 'English',
  AppLanguage.de: 'Deutsch',
  AppLanguage.cs: 'Čeština',
};

class I18n {
  static const _key = 'language';

  /// Wybrany język — `MaterialApp` przebudowuje się po zmianie.
  static final language = ValueNotifier<AppLanguage>(AppLanguage.system);

  static Future<void> load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    language.value = AppLanguage.values.where((l) => l.name == saved).firstOrNull ?? AppLanguage.system;
  }

  static Future<void> set(AppLanguage value) async {
    language.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }

  /// Kod języka faktycznie używanego (pl / en / de / cs).
  static String get code {
    final chosen = language.value;
    if (chosen != AppLanguage.system) return chosen.name;
    final system = PlatformDispatcher.instance.locale.languageCode;
    return supportedLanguageCodes.contains(system) ? system : 'en';
  }

  static Locale get locale => Locale(code);
}

/// Tłumaczy tekst interfejsu. Kluczem jest tekst polski; `{0}`, `{1}`… —
/// wartości z [args]. Brak tłumaczenia = tekst polski.
String tr(String pl, [List<Object?> args = const []]) {
  var text = switch (I18n.code) {
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
