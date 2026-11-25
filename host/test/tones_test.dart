import 'dart:io';
import 'dart:typed_data';

import 'package:remotetester_host/i18n.dart';
import 'package:remotetester_host/sound/tones.dart';
import 'package:test/test.dart';

void main() {
  test('every event is a short, valid PCM WAV with its own melody', () {
    final seen = <String>{};
    for (final event in SoundEvent.values) {
      final wav = toneWav(event);
      final h = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(h.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(h.getUint32(40, Endian.little), wav.length - 44);
      final ms = soundNotes[event]!.fold<int>(0, (a, n) => a + n.$2);
      expect(ms, inInclusiveRange(150, 500), reason: 'krótki ton: $event');
      expect(seen.add(soundNotes[event].toString()), isTrue, reason: 'każde zdarzenie brzmi inaczej');
    }
  });

  test('the sounds setting is on by default and keeps other settings', () {
    final dir = Directory.systemTemp.createTempSync('rt_sound_');
    final previous = Directory.current;
    Directory.current = dir;
    addTearDown(() {
      Directory.current = previous;
      dir.deleteSync(recursive: true);
    });
    expect(soundsEnabled(), isTrue);
    saveHostLanguage('de');
    saveSoundsEnabled(false);
    expect(soundsEnabled(), isFalse);
    expect(File(uiSettingsPath).readAsStringSync(), contains('"language":"de"'));
    setHostLanguage('pl');
  });
}
