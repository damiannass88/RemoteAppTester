import 'dart:io';
import 'dart:typed_data';

import 'dpapi.dart';

/// Rzucany, gdy sekretu nie da się bezpiecznie odczytać — m.in. niezgodne
/// konto Windows (DPAPI) albo plik na Linuxie czytelny dla innych
/// użytkowników. Agent w takiej sytuacji odmawia startu zamiast po cichu
/// kontynuować na niezabezpieczonym sekrecie.
class SecretStoreException implements Exception {
  SecretStoreException(this.message);
  final String message;
  @override
  String toString() => 'SecretStoreException: $message';
}

/// Przechowywanie sekretów "at rest" (`pairing_secret` w rejestrze urządzeń,
/// klucz prywatny TLS) niezależne od platformy (docs/SECURITY.md):
/// - Windows: DPAPI — [DpapiSecretStore];
/// - Linux (VPS, headless): plik należący do użytkownika agenta z
///   uprawnieniami `0600` w katalogu `0700` — [FileModeSecretStore]. Na
///   serwerze bez sesji graficznej nie ma keyringa; to standardowa praktyka
///   dla usług (jak klucze SSH hosta).
abstract class SecretStore {
  factory SecretStore.forPlatform() =>
      Platform.isWindows ? DpapiSecretStore() : FileModeSecretStore();

  /// Odczytuje sekret z [file]. [isLegacyPlaintext] rozpoznaje plik zapisany
  /// jawnym tekstem sprzed wprowadzenia ochrony — taki plik jest akceptowany
  /// i od razu zapisywany ponownie już chroniony (transparentna migracja).
  Uint8List read(File file, {bool Function(Uint8List raw)? isLegacyPlaintext});

  void write(File file, Uint8List secret);
}

class DpapiSecretStore implements SecretStore {
  @override
  Uint8List read(File file, {bool Function(Uint8List raw)? isLegacyPlaintext}) {
    final bytes = file.readAsBytesSync();
    try {
      return dpapiUnprotect(bytes);
    } on DpapiException catch (e) {
      // Plik sprzed szyfrowania — jeśli faktycznie wygląda na plaintext,
      // migrujemy go zamiast tracić dane; każdy INNY błąd (inne konto
      // Windows, uszkodzony blob) propaguje się dalej.
      if (isLegacyPlaintext != null && isLegacyPlaintext(bytes)) {
        write(file, bytes);
        return bytes;
      }
      throw SecretStoreException(e.message);
    }
  }

  @override
  void write(File file, Uint8List secret) {
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(dpapiProtect(secret));
  }
}

/// Linux/POSIX: ochrona przez uprawnienia systemu plików. Dart nie ma API do
/// `chmod`/`umask`, więc używamy systemowego `chmod` z argumentami będącymi
/// wyłącznie naszymi własnymi ścieżkami (żadnych danych z sieci).
class FileModeSecretStore implements SecretStore {
  /// Bity "group" i "other" (`0077`) — żaden z nich nie może być ustawiony.
  static const int _groupOtherMask = 0x3F;

  @override
  Uint8List read(File file, {bool Function(Uint8List raw)? isLegacyPlaintext}) {
    final mode = file.statSync().mode;
    if (mode & _groupOtherMask != 0) {
      throw SecretStoreException(
        'Plik ${file.path} jest dostępny dla innych użytkowników '
        '(uprawnienia ${(mode & 0x1FF).toRadixString(8)}). '
        'Popraw poleceniem: chmod 600 "${file.path}"',
      );
    }
    return file.readAsBytesSync();
  }

  @override
  void write(File file, Uint8List secret) {
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      _chmod('700', dir.path);
    }
    // Najpierw pusty plik tymczasowy z uprawnieniami 0600, dopiero potem
    // treść, na końcu atomowa zamiana — sekret nigdy nie leży na dysku w
    // pliku czytelnym dla innych, nawet przez chwilę. `rename` zachowuje
    // uprawnienia pliku źródłowego.
    final tmp = File('${file.path}.tmp');
    tmp.writeAsBytesSync(const [], flush: true);
    _chmod('600', tmp.path);
    tmp.writeAsBytesSync(secret, flush: true);
    tmp.renameSync(file.path);
  }

  static void _chmod(String mode, String path) {
    final result = Process.runSync('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw SecretStoreException('chmod $mode "$path" nie powiódł się: ${result.stderr}');
    }
  }
}
