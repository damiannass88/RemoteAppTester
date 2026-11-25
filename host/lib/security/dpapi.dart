import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Rzucany, gdy `CryptUnprotectData` się nie powiedzie — najczęstsza
/// przyczyna to dane zaszyfrowane pod innym kontem użytkownika/na innej
/// maszynie (DPAPI wiąże klucz z kontem Windows), nie uszkodzenie pliku.
class DpapiException implements Exception {
  DpapiException(this.message);
  final String message;
  @override
  String toString() => 'DpapiException: $message';
}

/// Szyfrowanie "at rest" sekretów na dysku przez Windows DPAPI
/// (`CryptProtectData`/`CryptUnprotectData`, `crypt32.dll`) — klucz wiązany
/// jest z kontem Windows użytkownika uruchamiającego agenta, nie trzeba
/// samemu zarządzać żadnym master-key (docs/SECURITY.md: "Sekrety w
/// bezpiecznym magazynie"). Zastępuje plaintext JSON/PEM na dysku —
/// `pairing_secret` w `paired_devices.json` i klucz prywatny TLS.
///
/// `CRYPTPROTECT_UI_FORBIDDEN` (0x1) — agent działa bez interakcji
/// użytkownika przy każdym odczycie pliku, więc DPAPI nie może próbować
/// pokazać żadnego promptu.
const int _cryptprotectUiForbidden = 0x1;

Uint8List dpapiProtect(Uint8List plaintext) {
  return using((arena) {
    final inBlob = arena<CRYPT_INTEGER_BLOB>();
    final inBuffer = arena<Uint8>(plaintext.length);
    inBuffer.asTypedList(plaintext.length).setAll(0, plaintext);
    inBlob.ref
      ..cbData = plaintext.length
      ..pbData = inBuffer;

    final outBlob = arena<CRYPT_INTEGER_BLOB>();
    final result = CryptProtectData(
      inBlob,
      null,
      null,
      null,
      _cryptprotectUiForbidden,
      outBlob,
    );
    if (!result.value) {
      throw DpapiException('CryptProtectData nie powiodło się (Win32 error ${result.error}).');
    }
    try {
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      LocalFree(HLOCAL(outBlob.ref.pbData));
    }
  });
}

Uint8List dpapiUnprotect(Uint8List blob) {
  return using((arena) {
    final inBlob = arena<CRYPT_INTEGER_BLOB>();
    final inBuffer = arena<Uint8>(blob.length);
    inBuffer.asTypedList(blob.length).setAll(0, blob);
    inBlob.ref
      ..cbData = blob.length
      ..pbData = inBuffer;

    final outBlob = arena<CRYPT_INTEGER_BLOB>();
    final result = CryptUnprotectData(
      inBlob,
      nullptr,
      nullptr,
      nullptr,
      _cryptprotectUiForbidden,
      outBlob,
    );
    if (!result.value) {
      throw DpapiException('CryptUnprotectData nie powiodło się (Win32 error ${result.error}).');
    }
    try {
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      LocalFree(HLOCAL(outBlob.ref.pbData));
    }
  });
}
