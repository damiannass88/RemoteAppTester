import 'dart:convert';

import 'package:grpc/grpc.dart';

import '../build/operation_log.dart';
import 'device_registry.dart';
import 'hmac_auth.dart';
import 'nonce_store.dart';
import 'rate_limiter.dart';

/// Bramka "czy urządzenie jest sparowane i nieodwołane, i czy żądanie niesie
/// ważny podpis HMAC" na każde żądanie, plus rate limiting/lockout
/// (docs/SECURITY.md). Nagłówek `device-id` wskazuje, czyj
/// `pairing_secret` użyć, ale samo jego posiadanie już nie wystarcza —
/// żądanie musi też nieść świeży (`auth-timestamp` w oknie [authRequestValidityWindow]),
/// jednorazowy (`auth-nonce` niewidziany wcześniej) podpis
/// (`auth-hmac` = HMAC-SHA256 nad method||payload||timestamp||nonce, sekcja 6.4).
/// Rzuca [GrpcError.unauthenticated], jeśli którykolwiek z tych warunków nie
/// jest spełniony; [GrpcError.resourceExhausted] przy przekroczeniu limitu
/// żądań albo aktywnym lockoucie. Każde odrzucenie trafia do [operationLog]
/// (sekcja 6.6: "zapisuje zdarzenie w logu audytowym").
const String deviceIdMetadataKey = 'device-id';

PairedDevice requireDevice(
  ServiceCall call,
  DeviceRegistry registry,
  RateLimiter rateLimiter,
  NonceStore nonceStore,
  OperationLog operationLog, {
  required String method,
  required List<int> requestPayload,
}) {
  final sourceKey = call.remoteAddress?.address ?? 'unknown';

  Never fail(String event, String message, {String? deviceIdForLog}) {
    operationLog.record(
      deviceId: deviceIdForLog ?? 'unknown',
      event: event,
      details: {'source_ip': sourceKey, 'method': method, 'message': message},
    );
    throw GrpcError.unauthenticated(message);
  }

  final metadata = call.clientMetadata;
  final claimedId = metadata?[deviceIdMetadataKey];
  final status = claimedId == null || claimedId.isEmpty ? DeviceStatus.unknown : registry.status(claimedId);

  // Blokada adresu chroni przed ZGADYWANIEM device_id. Żądanie z identyfikatorem
  // aktywnego, sparowanego telefonu nie jest zgadywaniem — sprawdzamy je w pełni
  // (HMAC), a jego błędne podpisy blokują osobno ten identyfikator. Dzięki temu
  // telefon sparowany na nowo działa od razu, nawet gdy wcześniej ten sam adres
  // zablokowała jego stara, odwołana kopia.
  final lockKey = status == DeviceStatus.active ? 'device:$claimedId' : sourceKey;
  try {
    rateLimiter.checkNotLockedOut(lockKey);
  } on LockedOutException catch (e) {
    if (rateLimiter.shouldLog('lockout:$lockKey')) {
      operationLog.record(
        deviceId: claimedId ?? 'unknown',
        event: 'security_request_blocked_lockout',
        details: {'source_ip': sourceKey, 'method': method, 'message': e.message},
      );
    }
    throw GrpcError.resourceExhausted(e.message);
  }

  final deviceId = claimedId;
  if (deviceId == null || deviceId.isEmpty) {
    rateLimiter.recordAuthFailure(sourceKey);
    fail('security_auth_failure', 'Brak nagłówka "$deviceIdMetadataKey" — urządzenie niesparowane.');
  }
  if (status == DeviceStatus.revoked) {
    // Znany, odwołany telefon to nie atak zgadywania — nie blokujemy przez niego
    // adresu (inaczej ponawiająca aplikacja przedłużałaby blokadę bez końca);
    // ma za to zwykły limit żądań i jeden wpis w logu na kilka minut.
    try {
      rateLimiter.checkRequestAllowed('revoked:$deviceId');
    } on RateLimitExceededException catch (e) {
      throw GrpcError.resourceExhausted(e.message);
    }
    const message = 'Parowanie tego telefonu zostało odwołane na komputerze — sparuj go ponownie.';
    if (rateLimiter.shouldLog('revoked:$deviceId')) {
      fail('security_revoked_device', message, deviceIdForLog: deviceId);
    }
    throw GrpcError.unauthenticated(message);
  }
  if (status == DeviceStatus.expired) {
    // Kod QR nieużyty w terminie: nie atak, tylko nowe parowanie do zrobienia.
    try {
      rateLimiter.checkRequestAllowed('expired:$deviceId');
    } on RateLimitExceededException catch (e) {
      throw GrpcError.resourceExhausted(e.message);
    }
    const message = 'Kod parowania wygasł — wygeneruj nowy na komputerze.';
    if (rateLimiter.shouldLog('expired:$deviceId')) {
      fail('security_pairing_code_expired', message, deviceIdForLog: deviceId);
    }
    throw GrpcError.unauthenticated(message);
  }
  var device = registry.authenticate(deviceId);
  if (device == null) {
    rateLimiter.recordAuthFailure(sourceKey);
    fail('security_auth_failure', 'Nieznane urządzenie: $deviceId', deviceIdForLog: deviceId);
  }
  // Dalsze błędy (podpis, nonce, czas) dotyczą konkretnego, aktywnego telefonu.
  final failureKey = lockKey;

  final timestampStr = metadata?[authTimestampMetadataKey];
  final nonceHex = metadata?[authNonceMetadataKey];
  final hmac = metadata?[authHmacMetadataKey];
  if (timestampStr == null || nonceHex == null || hmac == null) {
    rateLimiter.recordAuthFailure(failureKey);
    fail(
      'security_auth_failure',
      'Brak nagłówków uwierzytelniających (auth-timestamp/auth-nonce/auth-hmac).',
      deviceIdForLog: device.deviceId,
    );
  }

  final timestampMs = int.tryParse(timestampStr);
  if (timestampMs == null) {
    rateLimiter.recordAuthFailure(failureKey);
    fail('security_auth_failure', 'Nieprawidłowy format auth-timestamp.', deviceIdForLog: device.deviceId);
  }
  final requestTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final drift = DateTime.now().difference(requestTime).abs();
  if (drift > authRequestValidityWindow) {
    rateLimiter.recordAuthFailure(failureKey);
    fail(
      'security_auth_failure',
      'Żądanie spoza okna ważności (auth-timestamp zbyt stary/z przyszłości).',
      deviceIdForLog: device.deviceId,
    );
  }

  String expectedWith(String secret) => computeRequestHmac(
        pairingSecret: secret,
        method: method,
        payload: requestPayload,
        timestampUnixMs: timestampStr,
        nonceHex: nonceHex,
      );
  final signedWithCurrent = _constantTimeEquals(hmac, expectedWith(device.pairingSecret));
  final pending = device.pendingSecret;
  final signedWithPending = !signedWithCurrent && pending != null && _constantTimeEquals(hmac, expectedWith(pending));
  // Po terminie kod z QR nie działa, nawet gdy sekret był już wydany.
  if (signedWithCurrent && device.pairingCodeExpired) {
    fail('security_pairing_code_expired', 'Kod parowania wygasł — wygeneruj nowy na komputerze.',
        deviceIdForLog: device.deviceId);
  }
  if (!signedWithCurrent && !signedWithPending) {
    rateLimiter.recordAuthFailure(failureKey);
    fail('security_auth_failure', 'Nieprawidłowy podpis HMAC — żądanie odrzucone.', deviceIdForLog: device.deviceId);
  }

  if (!nonceStore.checkAndRecord(device.deviceId, nonceHex)) {
    rateLimiter.recordAuthFailure(failureKey);
    fail(
      'security_auth_failure',
      'Wykryto powtórzenie żądania (nonce już użyty).',
      deviceIdForLog: device.deviceId,
    );
  }

  // Pierwsze żądanie nowym sekretem kończy wymianę: stary przestaje działać.
  if (signedWithPending) device = registry.completeRotation(device.deviceId);

  try {
    rateLimiter.checkRequestAllowed(device.deviceId);
  } on RateLimitExceededException catch (e) {
    throw GrpcError.resourceExhausted(e.message);
  }

  return device;
}

/// Porównanie w czasie stałym — HMAC-y to hex stringi o tej samej,
/// ustalonej długości (SHA-256 = 64 znaki), ale porównujemy bajt po bajcie
/// niezależnie od tego, żeby nie zdradzać przez timing, na którym znaku
/// nastąpiła pierwsza rozbieżność.
bool _constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  // Różna długość to od razu `false` — SHA-256 w hex ma zawsze 64 znaki,
  // więc to możliwe tylko przy zniekształconym/złośliwym nagłówku, nie przy
  // legalnym prawie-trafieniu, gdzie timing miałby znaczenie.
  if (aBytes.length != bBytes.length) return false;
  var diff = 0;
  for (var i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff == 0;
}
