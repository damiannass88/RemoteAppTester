import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../i18n.dart';

/// Zdarzenia z charakterystycznym, krótkim dźwiękiem.
enum SoundEvent {
  /// Build zakończony — dwa rosnące tony.
  buildDone,

  /// Build nieudany — dwa niskie, opadające tony.
  buildFailed,

  /// Wersja zainstalowana na telefonie — trzy szybkie, rosnące tony.
  installed,

  /// Nowa wersja / agent AI zgłosił zmiany — podwójny wysoki „ping”.
  newVersion,
}

/// Nuty (Hz, ms) każdego zdarzenia — te same na Windows i w aplikacji na telefon.
const Map<SoundEvent, List<(double, int)>> soundNotes = {
  SoundEvent.buildDone: [(1046.5, 90), (1318.5, 140)],
  SoundEvent.buildFailed: [(440.0, 160), (329.6, 220)],
  SoundEvent.installed: [(784.0, 70), (987.8, 70), (1174.7, 150)],
  SoundEvent.newVersion: [(1568.0, 60), (0, 50), (1568.0, 90)],
};

/// Krótki plik WAV (PCM 16-bit, mono) z nutami zdarzenia — bez plików dźwiękowych w paczce.
Uint8List toneWav(SoundEvent event, {int sampleRate = 22050, double volume = 0.35}) {
  final samples = <int>[];
  for (final (freq, ms) in soundNotes[event]!) {
    final n = sampleRate * ms ~/ 1000;
    final fade = min(n ~/ 4, sampleRate ~/ 200); // ~5 ms łagodnego wejścia i wyjścia — bez trzasków
    for (var i = 0; i < n; i++) {
      final envelope = min(1.0, min(i, n - 1 - i) / max(fade, 1));
      final v = freq == 0 ? 0.0 : sin(2 * pi * freq * i / sampleRate) * volume * envelope;
      samples.add((v * 32767).round());
    }
  }
  final data = ByteData(44 + samples.length * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(44 + i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

/// „Odtwarzaj dźwięki” — wspólne ustawienie okna i `rt` w `config/ui.json`; domyślnie włączone.
bool soundsEnabled() {
  try {
    return (jsonDecode(File(uiSettingsPath).readAsStringSync()) as Map<String, dynamic>)['sounds'] != false;
  } on Object {
    return true;
  }
}

/// Zapisuje ustawienie dźwięków; inne ustawienia w pliku zostają.
void saveSoundsEnabled(bool enabled) {
  Map<String, dynamic> json = {};
  final file = File(uiSettingsPath);
  try {
    json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } on Object {
    // Nowy plik.
  }
  json['sounds'] = enabled;
  file
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode(json));
}

/// Sygnał w terminalu (`rt` na serwerze bez głośników): dzwonek terminala, 1–3 razy.
void terminalBell(SoundEvent event) {
  if (!soundsEnabled() || !stdout.hasTerminal) return;
  final times = switch (event) {
    SoundEvent.buildDone || SoundEvent.newVersion => 1,
    SoundEvent.installed => 2,
    SoundEvent.buildFailed => 3,
  };
  stdout.write('\x07' * times);
}

/// Opis zdarzeń do pomocy `rt sound`.
String soundEventsHelp() => tr('Dźwięki: koniec builda (1 sygnał), instalacja na telefonie (2), błąd builda (3).');
