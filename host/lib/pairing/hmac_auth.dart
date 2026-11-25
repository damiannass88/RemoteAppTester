import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// HMAC z nonce/timestamp na każdym żądaniu (docs/architektura-remote-build.md
/// sekcja 6.4) — ochrona przed atakiem powtórzeniowym, niezależna od TLS. Ten plik
/// jest CELOWO identyczny w host i android_app (jak pairing_uri.dart) —
/// obie strony muszą liczyć dokładnie to samo, więc nie ma między nimi żadnej
/// współdzielonej zależności pakietowej do zsynchronizowania.
const String authTimestampMetadataKey = 'auth-timestamp';
const String authNonceMetadataKey = 'auth-nonce';
const String authHmacMetadataKey = 'auth-hmac';

/// Żądania starsze (albo z zegara w przyszłości) niż to okno są odrzucane —
/// wymaga zsynchronizowanego zegara (NTP domyślnie w Windows/Android
/// wystarcza), patrz sekcja 6.4.
const Duration authRequestValidityWindow = Duration(seconds: 60);

/// Losowy nonce 16 bajtów, zakodowany jako hex (metadane gRPC muszą być
/// tekstowe — hex zamiast base64 unika znaków spoza [A-Za-z0-9-_], które
/// niektóre implementacje HTTP/2 traktują nieufnie w nagłówkach).
String generateNonceHex([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  final buffer = StringBuffer();
  for (final b in bytes) {
    buffer.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// `hmac = HMAC-SHA256(pairing_secret, method || payload || timestamp || nonce)`
/// — `method` to nazwa RPC (np. "StartBuild", nie pełna ścieżka gRPC — obie
/// strony muszą użyć tej samej stałej listy nazw), `payload` to surowe bajty
/// żądania (`GeneratedMessage.writeToBuffer()`), `timestamp` to unix ms jako
/// string dziesiętny, `nonce` to hex string z [generateNonceHex].
///
/// Uwaga: to zwykła konkatenacja bez separatora/prefiksu długości, więc
/// granica `method`/`payload` jest formalnie niejednoznaczna (inny podział
/// tych samych bajtów dałby ten sam podpis). Nie jest to wykorzystywalne
/// tutaj: `method` po stronie serwera to zawsze jeden ze stałej, zaszytej w
/// kodzie zbioru literałów (patrz wywołania `requireDevice` w
/// host_agent_service.dart) — nigdy wartość z sieci — więc klient nie ma
/// jak wymusić na serwerze policzenie HMAC dla innej nazwy metody.
String computeRequestHmac({
  required String pairingSecret,
  required String method,
  required List<int> payload,
  required String timestampUnixMs,
  required String nonceHex,
}) {
  final bytesToSign = <int>[
    ...utf8.encode(method),
    ...payload,
    ...utf8.encode(timestampUnixMs),
    ...utf8.encode(nonceHex),
  ];
  final mac = Hmac(sha256, utf8.encode(pairingSecret));
  return mac.convert(bytesToSign).toString();
}
