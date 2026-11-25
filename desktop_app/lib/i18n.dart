import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:remotetester_host/i18n.dart' show setHostLanguage;

import 'sound_player.dart';
import 'translations.dart';

/// Języki interfejsu. `system` = język Windows (jeśli obsługiwany, inaczej angielski).
enum AppLanguage { system, pl, en, de, cs }

const supportedLanguageCodes = ['pl', 'en', 'de', 'cs'];

/// Nazwy języków w ich własnym języku (lista wyboru).
const languageNames = {
  AppLanguage.pl: 'Polski',
  AppLanguage.en: 'English',
  AppLanguage.de: 'Deutsch',
  AppLanguage.cs: 'Čeština',
};

/// Ustawienia wyglądu okna (język, tryb ciemny) — `config/ui.json` w katalogu danych.
class UiSettings {
  static const _path = 'config/ui.json';

  static final language = ValueNotifier<AppLanguage>(AppLanguage.system);
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static void load() {
    try {
      final json = jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>;
      language.value = AppLanguage.values.where((l) => l.name == json['language']).firstOrNull ?? AppLanguage.system;
      themeMode.value = json['dark'] == true ? ThemeMode.dark : ThemeMode.light;
      SoundPlayer.enabled.value = json['sounds'] != false;
    } on Object {
      // Brak pliku albo uszkodzony — ustawienia domyślne.
    }
    setHostLanguage(code);
  }

  static void setLanguage(AppLanguage value) {
    language.value = value;
    setHostLanguage(code);
    _save();
  }

  static void setDark(bool dark) {
    themeMode.value = dark ? ThemeMode.dark : ThemeMode.light;
    _save();
  }

  static void _save() {
    try {
      // Inne ustawienia z pliku (np. dźwięki, też z `rt so`) zostają.
      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(File(_path).readAsStringSync()) as Map<String, dynamic>;
      } on Object {
        // Nowy plik.
      }
      json
        ..['language'] = language.value.name
        ..['dark'] = themeMode.value == ThemeMode.dark;
      File(_path)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(jsonEncode(json));
    } on FileSystemException {
      // Nie udało się zapisać — zmiana działa do zamknięcia aplikacji.
    }
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
  var text = switch (UiSettings.code) {
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

/// Motyw okna: jasny albo ciemny granatowy (ten sam co w aplikacji na telefonie).
class AppTheme {
  static const _navy = Color(0xFF1E3A8A);

  static ThemeData light() => ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: _navy, brightness: Brightness.dark).copyWith(
      surface: const Color(0xFF0B1426),
      surfaceContainerLowest: const Color(0xFF08101F),
      surfaceContainerLow: const Color(0xFF0E1A31),
      surfaceContainer: const Color(0xFF122039),
      surfaceContainerHigh: const Color(0xFF172742),
      surfaceContainerHighest: const Color(0xFF1C2E4D),
      primary: const Color(0xFF9DB4FF),
      onPrimary: const Color(0xFF0B1A4A),
      primaryContainer: const Color(0xFF2A4396),
      onPrimaryContainer: const Color(0xFFDCE3FF),
      secondaryContainer: const Color(0xFF263A63),
      outline: const Color(0xFF4A5E85),
      outlineVariant: const Color(0xFF2A3A5C),
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(color: scheme.surfaceContainer),
      navigationRailTheme: NavigationRailThemeData(backgroundColor: scheme.surface),
    );
  }
}
