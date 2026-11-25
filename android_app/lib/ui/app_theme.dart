import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Motyw aplikacji: jasny albo ciemny granatowy. Wybór zapamiętany na telefonie.
class AppTheme {
  static const _key = 'dark_mode';

  /// Aktualny tryb — `MaterialApp` przebudowuje się po zmianie.
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> load() async {
    final dark = (await SharedPreferences.getInstance()).getBool(_key) ?? false;
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDark(bool dark) async {
    mode.value = dark ? ThemeMode.dark : ThemeMode.light;
    await (await SharedPreferences.getInstance()).setBool(_key, dark);
  }

  static const _navy = Color(0xFF1E3A8A);

  static ThemeData light() => ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));

  /// Ciemny granat: tła w odcieniach granatu zamiast szarości.
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
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(color: scheme.surfaceContainer),
    );
  }

  /// Tło paska informacyjnego w danym kolorze — czytelne w obu motywach.
  static Color tint(BuildContext context, Color base) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? Color.alphaBlend(base.withValues(alpha: 0.22), theme.colorScheme.surface)
        : Color.alphaBlend(base.withValues(alpha: 0.12), Colors.white);
  }
}
