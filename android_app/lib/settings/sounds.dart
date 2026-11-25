import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../native/package_installer.dart';

/// Zdarzenia z charakterystycznym, krótkim dźwiękiem (te same nuty co w oknie Windows,
/// host/lib/sound/tones.dart).
enum SoundEvent { buildDone, buildFailed, installed, newVersion }

const Map<SoundEvent, List<(double, int)>> _notes = {
  SoundEvent.buildDone: [(1046.5, 90), (1318.5, 140)],
  SoundEvent.buildFailed: [(440.0, 160), (329.6, 220)],
  SoundEvent.installed: [(784.0, 70), (987.8, 70), (1174.7, 150)],
  SoundEvent.newVersion: [(1568.0, 60), (0, 50), (1568.0, 90)],
};

/// „Odtwarzaj dźwięki” — ustawienie telefonu, domyślnie włączone.
class Sounds {
  Sounds._();

  static const _key = 'sounds_enabled';
  static final enabled = ValueNotifier<bool>(true);

  static Future<void> load() async {
    enabled.value = (await SharedPreferences.getInstance()).getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    await (await SharedPreferences.getInstance()).setBool(_key, value);
  }

  static Future<void> play(SoundEvent event) async {
    if (enabled.value) await PackageInstallerChannel.playNotes(_notes[event]!);
  }
}
