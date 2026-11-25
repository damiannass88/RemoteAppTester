import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:remotetester_host/sound/tones.dart';

typedef _PlaySoundNative = Int32 Function(Pointer<Utf16> sound, IntPtr module, Uint32 flags);
typedef _PlaySoundDart = int Function(Pointer<Utf16> sound, int module, int flags);

/// Krótkie tony okna (Windows, `winmm.dll` PlaySound) — wygenerowane przez
/// [toneWav], zapisane raz w `tmp/sounds`. Bez dźwięków, gdy ustawienie jest wyłączone.
class SoundPlayer {
  SoundPlayer._();

  /// Wczytywane w [UiSettings.load] (dopiero wtedy bieżący katalog = katalog danych).
  static final enabled = ValueNotifier<bool>(true);

  static void setEnabled(bool value) {
    enabled.value = value;
    saveSoundsEnabled(value);
  }

  static _PlaySoundDart? _playSound;
  static final Map<SoundEvent, Pointer<Utf16>> _paths = {};

  static void play(SoundEvent event) {
    if (!enabled.value || !Platform.isWindows) return;
    try {
      final file = File('tmp/sounds/${event.name}.wav');
      if (!file.existsSync()) {
        file
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(toneWav(event));
      }
      _playSound ??= DynamicLibrary.open('winmm.dll').lookupFunction<_PlaySoundNative, _PlaySoundDart>('PlaySoundW');
      const sndAsync = 0x0001, sndNoDefault = 0x0002, sndFilename = 0x00020000;
      // Ścieżka zostaje w pamięci na stałe (4 krótkie napisy) — odtwarzanie jest asynchroniczne.
      final path = _paths[event] ??= file.absolute.path.toNativeUtf16();
      _playSound!(path, 0, sndAsync | sndNoDefault | sndFilename);
    } on Object {
      // Brak dźwięku nie może przeszkadzać w pracy.
    }
  }
}
