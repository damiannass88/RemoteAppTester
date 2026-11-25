import 'dart:io';

import 'package:remotetester_host/build/operation_log.dart';
import 'package:remotetester_host/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester_host/pairing/device_auth.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/hmac_auth.dart';
import 'package:remotetester_host/pairing/nonce_store.dart';
import 'package:remotetester_host/pairing/rate_limiter.dart';
import 'package:test/test.dart';
import 'package:grpc/grpc.dart';

/// Minimalny double [ServiceCall] — testujemy tylko odczyt `clientMetadata`
/// i `remoteAddress`, więc reszta interfejsu jest nieużywana w tych testach.
class FakeServiceCall implements ServiceCall {
  FakeServiceCall(this.clientMetadata, {InternetAddress? remoteAddress})
      : remoteAddress = remoteAddress ?? InternetAddress('100.111.210.37');

  @override
  final Map<String, String>? clientMetadata;

  @override
  Map<String, String>? get headers => null;
  @override
  Map<String, String>? get trailers => null;
  @override
  DateTime? get deadline => null;
  @override
  bool get isTimedOut => false;
  @override
  bool get isCanceled => false;
  @override
  X509Certificate? get clientCertificate => null;
  @override
  final InternetAddress? remoteAddress;
  @override
  void sendHeaders() {}
  @override
  void sendTrailers({int? status, String? message}) {}
}

const _method = 'Ping';
final _payload = Empty().writeToBuffer();

/// Buduje metadane niosące ważny (albo świadomie zepsuty) podpis HMAC dla
/// danego urządzenia — mirror tego, co realnie robi android_app/lib/net/agent_client.dart.
Map<String, String> _authMetadata(
  PairedDevice device, {
  String method = _method,
  List<int>? payload,
  DateTime? at,
  String? nonceOverride,
  String? hmacOverride,
}) {
  final timestamp = (at ?? DateTime.now()).millisecondsSinceEpoch.toString();
  final nonce = nonceOverride ?? generateNonceHex();
  final hmac = hmacOverride ??
      computeRequestHmac(
        pairingSecret: device.pairingSecret,
        method: method,
        payload: payload ?? _payload,
        timestampUnixMs: timestamp,
        nonceHex: nonce,
      );
  return {
    deviceIdMetadataKey: device.deviceId,
    authTimestampMetadataKey: timestamp,
    authNonceMetadataKey: nonce,
    authHmacMetadataKey: hmac,
  };
}

void main() {
  late Directory tempDir;
  late DeviceRegistry registry;
  late RateLimiter rateLimiter;
  late NonceStore nonceStore;
  late OperationLog operationLog;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('device_auth_test_');
    registry = DeviceRegistry(File('${tempDir.path}/paired_devices.json'));
    rateLimiter = RateLimiter(maxRequestsPerMinutePerDevice: 30);
    nonceStore = NonceStore();
    operationLog = OperationLog(File('${tempDir.path}/logs/operations.log'));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('rejects a call with no device-id header', () {
    final call = FakeServiceCall(const {});
    expect(
      () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
          method: _method, requestPayload: _payload),
      throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
    );
  });

  test('rejects a call from an unregistered device_id', () {
    final call = FakeServiceCall(const {deviceIdMetadataKey: 'nigdy-nie-sparowane'});
    expect(
      () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
          method: _method, requestPayload: _payload),
      throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
    );
  });

  test('rejects a call from a revoked device_id', () {
    final device = registry.register('Telefon A');
    registry.revoke(device.deviceId);
    final call = FakeServiceCall({deviceIdMetadataKey: device.deviceId});
    expect(
      () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
          method: _method, requestPayload: _payload),
      throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
    );
  });

  test('accepts a call carrying a valid HMAC from a registered, non-revoked device_id', () {
    final device = registry.register('Telefon A');
    final call = FakeServiceCall(_authMetadata(device));
    final result = requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
        method: _method, requestPayload: _payload);
    expect(result.deviceId, device.deviceId);
  });

  test('one revoked device does not affect another paired device', () {
    final a = registry.register('Telefon A');
    final b = registry.register('Telefon B');
    registry.revoke(a.deviceId);

    expect(
      () => requireDevice(
        FakeServiceCall(_authMetadata(a), remoteAddress: InternetAddress('1.1.1.1')),
        registry,
        rateLimiter,
        nonceStore, operationLog,
        method: _method,
        requestPayload: _payload,
      ),
      throwsA(isA<GrpcError>()),
    );
    expect(
      requireDevice(
        FakeServiceCall(_authMetadata(b), remoteAddress: InternetAddress('2.2.2.2')),
        registry,
        rateLimiter,
        nonceStore, operationLog,
        method: _method,
        requestPayload: _payload,
      ).deviceId,
      b.deviceId,
    );
  });

  group('HMAC z nonce/timestamp (sekcja 6.4)', () {
    test('rejects a call missing the auth-* headers even with a valid device-id', () {
      final device = registry.register('Telefon A');
      final call = FakeServiceCall({deviceIdMetadataKey: device.deviceId});
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('rejects a request signed with the wrong pairing_secret', () {
      final device = registry.register('Telefon A');
      final other = registry.register('Telefon B');
      // Podpisane sekretem INNEGO urządzenia, ale wysłane z device-id `device`.
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final nonce = generateNonceHex();
      final badHmac = computeRequestHmac(
        pairingSecret: other.pairingSecret,
        method: _method,
        payload: _payload,
        timestampUnixMs: timestamp,
        nonceHex: nonce,
      );
      final call = FakeServiceCall({
        deviceIdMetadataKey: device.deviceId,
        authTimestampMetadataKey: timestamp,
        authNonceMetadataKey: nonce,
        authHmacMetadataKey: badHmac,
      });
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('rejects a request whose payload does not match the signed payload (tampering)', () {
      final device = registry.register('Telefon A');
      // HMAC policzony nad INNYM payloadem niż ten faktycznie zweryfikowany.
      final tamperedPayload = BuildId(buildId: 'inny-build').writeToBuffer();
      final call = FakeServiceCall(_authMetadata(device, payload: tamperedPayload));
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('rejects a request whose method name does not match the signed method', () {
      final device = registry.register('Telefon A');
      final call = FakeServiceCall(_authMetadata(device, method: 'CancelBuild'));
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('rejects a request older than the validity window', () {
      final device = registry.register('Telefon A');
      final call = FakeServiceCall(
        _authMetadata(device, at: DateTime.now().subtract(const Duration(seconds: 90))),
      );
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('rejects a request timestamped in the future beyond the validity window', () {
      final device = registry.register('Telefon A');
      final call = FakeServiceCall(
        _authMetadata(device, at: DateTime.now().add(const Duration(seconds: 90))),
      );
      expect(
        () => requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('accepts a request just inside the validity window', () {
      final device = registry.register('Telefon A');
      final call = FakeServiceCall(
        _authMetadata(device, at: DateTime.now().subtract(const Duration(seconds: 45))),
      );
      expect(
        requireDevice(call, registry, rateLimiter, nonceStore, operationLog,
                method: _method, requestPayload: _payload)
            .deviceId,
        device.deviceId,
      );
    });

    test('rejects a replayed request (same device_id + nonce twice)', () {
      final device = registry.register('Telefon A');
      final metadata = _authMetadata(device);

      expect(
        requireDevice(FakeServiceCall(metadata), registry, rateLimiter, nonceStore, operationLog,
                method: _method, requestPayload: _payload)
            .deviceId,
        device.deviceId,
      );

      // Dokładnie te same metadane drugi raz — musi zostać odrzucone jako replay.
      expect(
        () => requireDevice(FakeServiceCall(metadata), registry, rateLimiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });

    test('two different devices may reuse the same nonce value independently', () {
      final a = registry.register('Telefon A');
      final b = registry.register('Telefon B');
      const sharedNonce = '00112233445566778899aabbccddeeff';

      expect(
        requireDevice(
          FakeServiceCall(_authMetadata(a, nonceOverride: sharedNonce)),
          registry,
          rateLimiter,
          nonceStore, operationLog,
          method: _method,
          requestPayload: _payload,
        ).deviceId,
        a.deviceId,
      );
      expect(
        requireDevice(
          FakeServiceCall(_authMetadata(b, nonceOverride: sharedNonce)),
          registry,
          rateLimiter,
          nonceStore, operationLog,
          method: _method,
          requestPayload: _payload,
        ).deviceId,
        b.deviceId,
      );
    });
  });

  group('rate limiting + lockout', () {
    test('exceeding the per-device request limit is rejected as resourceExhausted', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 3);
      final device = registry.register('Telefon A');

      for (var i = 0; i < 3; i++) {
        requireDevice(FakeServiceCall(_authMetadata(device)), registry, limiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload);
      }
      expect(
        () => requireDevice(FakeServiceCall(_authMetadata(device)), registry, limiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.resourceExhausted)),
      );
    });

    test('repeated auth failures from the same source lock it out', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 30, maxFailuresBeforeLockout: 3);
      final badCall = FakeServiceCall(const {}, remoteAddress: InternetAddress('9.9.9.9'));

      for (var i = 0; i < 3; i++) {
        expect(
          () => requireDevice(badCall, registry, limiter, nonceStore, operationLog,
              method: _method, requestPayload: _payload),
          throwsA(isA<GrpcError>()),
        );
      }

      // Kolejne zgadywanie z tego adresu jest blokowane...
      expect(
        () => requireDevice(FakeServiceCall(const {deviceIdMetadataKey: 'zgadywany'}, remoteAddress: InternetAddress('9.9.9.9')),
            registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.resourceExhausted)),
      );
      // ...ale sparowany telefon z poprawnym podpisem działa (np. ten sam telefon
      // sparowany na nowo po tym, jak jego stara kopia zablokowała adres).
      final device = registry.register('Telefon A');
      final goodCall = FakeServiceCall(_authMetadata(device), remoteAddress: InternetAddress('9.9.9.9'));
      expect(
        requireDevice(goodCall, registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload)
            .deviceId,
        device.deviceId,
      );
    });

    test('a revoked phone that keeps retrying never locks out its address', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 1000, maxFailuresBeforeLockout: 3);
      final old = registry.register('Stary');
      registry.revoke(old.deviceId);
      for (var i = 0; i < 20; i++) {
        expect(
          () => requireDevice(FakeServiceCall(_authMetadata(old), remoteAddress: InternetAddress('9.9.9.9')),
              registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload),
          throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
        );
      }
      expect(() => limiter.checkNotLockedOut('9.9.9.9'), returnsNormally);
    });

    test('bad signatures for an active phone lock that phone id, not the address', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 1000, maxFailuresBeforeLockout: 3);
      final device = registry.register('Telefon A');
      for (var i = 0; i < 3; i++) {
        expect(
          () => requireDevice(
              FakeServiceCall(_authMetadata(device, hmacOverride: 'f' * 64), remoteAddress: InternetAddress('9.9.9.9')),
              registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload),
          throwsA(isA<GrpcError>()),
        );
      }
      expect(
        () => requireDevice(FakeServiceCall(_authMetadata(device), remoteAddress: InternetAddress('9.9.9.9')),
            registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.resourceExhausted)),
      );
      final other = registry.register('Telefon B');
      expect(
        requireDevice(FakeServiceCall(_authMetadata(other), remoteAddress: InternetAddress('9.9.9.9')),
                registry, limiter, nonceStore, operationLog, method: _method, requestPayload: _payload)
            .deviceId,
        other.deviceId,
      );
    });

    test('lockout on one source does not affect another source', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 30, maxFailuresBeforeLockout: 3);
      final attacker = FakeServiceCall(const {}, remoteAddress: InternetAddress('9.9.9.9'));
      for (var i = 0; i < 3; i++) {
        expect(
          () => requireDevice(attacker, registry, limiter, nonceStore, operationLog,
              method: _method, requestPayload: _payload),
          throwsA(isA<GrpcError>()),
        );
      }

      final device = registry.register('Telefon A');
      final legit = FakeServiceCall(
        _authMetadata(device),
        remoteAddress: InternetAddress('8.8.8.8'),
      );
      expect(
        requireDevice(legit, registry, limiter, nonceStore, operationLog,
                method: _method, requestPayload: _payload)
            .deviceId,
        device.deviceId,
      );
    });

    test('lockout expires after lockoutDuration', () {
      var now = DateTime(2026, 1, 1, 12);
      final limiter = RateLimiter(
        maxRequestsPerMinutePerDevice: 30,
        maxFailuresBeforeLockout: 2,
        lockoutDuration: const Duration(minutes: 5),
        now: () => now,
      );
      final badCall = FakeServiceCall(const {}, remoteAddress: InternetAddress('9.9.9.9'));

      for (var i = 0; i < 2; i++) {
        expect(
          () => requireDevice(badCall, registry, limiter, nonceStore, operationLog,
              method: _method, requestPayload: _payload),
          throwsA(isA<GrpcError>()),
        );
      }

      final guess = FakeServiceCall(const {deviceIdMetadataKey: 'zgadywany'}, remoteAddress: InternetAddress('9.9.9.9'));
      expect(
        () => requireDevice(guess, registry, limiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.resourceExhausted)),
      );

      now = now.add(const Duration(minutes: 6));
      // Po wygaśnięciu: zwykłe odrzucenie (nieznane urządzenie), już nie blokada.
      expect(
        () => requireDevice(guess, registry, limiter, nonceStore, operationLog,
            method: _method, requestPayload: _payload),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
      );
    });
  });

  group('kod parowania i wymiana sekretu', () {
    PairedDevice call(PairedDevice d, {String? secret, RateLimiter? limiter}) {
      final signed = PairedDevice(
        deviceId: d.deviceId,
        displayName: d.displayName,
        pairingSecret: secret ?? d.pairingSecret,
        createdAt: d.createdAt,
        lastSeenAt: d.lastSeenAt,
      );
      return requireDevice(FakeServiceCall(_authMetadata(signed)), registry,
          limiter ?? RateLimiter(maxRequestsPerMinutePerDevice: 100), nonceStore, operationLog,
          method: _method, requestPayload: _payload);
    }

    test('the QR code works until the phone switches to its own secret, then never again', () {
      final d = registry.register('Telefon');
      final qrSecret = d.pairingSecret;
      expect(d.awaitingFirstUse, isTrue);
      expect(call(d).deviceId, d.deviceId);

      final fresh = registry.beginRotation(d.deviceId);
      expect(fresh, isNot(qrSecret));
      expect(registry.beginRotation(d.deviceId), fresh, reason: 'utracona odpowiedź: ten sam sekret');
      expect(call(d, secret: qrSecret).deviceId, d.deviceId, reason: 'do użycia nowego stary jeszcze działa');

      expect(call(d, secret: fresh).awaitingFirstUse, isFalse);
      expect(() => call(d, secret: qrSecret), throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)));
      expect(call(d, secret: fresh).deviceId, d.deviceId);
      expect(registry.all.firstWhere((x) => x.deviceId == d.deviceId).pendingSecret, isNull);
    });

    test('an unused code expires and does not lock the address', () {
      final limiter = RateLimiter(maxRequestsPerMinutePerDevice: 1000, maxFailuresBeforeLockout: 2);
      final d = registry.register('Telefon')..pairingExpiresAt = DateTime.now().subtract(const Duration(minutes: 1));
      expect(registry.status(d.deviceId), DeviceStatus.expired);
      for (var i = 0; i < 5; i++) {
        expect(() => call(d, limiter: limiter), throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)));
      }
      expect(() => limiter.checkNotLockedOut('unknown'), returnsNormally);
    });

    test('after the deadline only the already issued secret finishes the exchange', () {
      final d = registry.register('Telefon');
      final qrSecret = d.pairingSecret;
      final fresh = registry.beginRotation(d.deviceId);
      d.pairingExpiresAt = DateTime.now().subtract(const Duration(minutes: 1));
      expect(() => call(d, secret: qrSecret), throwsA(isA<GrpcError>()));
      expect(call(d, secret: fresh).awaitingFirstUse, isFalse);
    });

    test('state survives a reload and old registries without the new fields keep working', () {
      final d = registry.register('Telefon');
      final fresh = registry.beginRotation(d.deviceId);
      final json = d.toJson();
      expect(json['pending_secret'], fresh);
      final legacy = PairedDevice.fromJson({
        'device_id': 'x',
        'display_name': 'stary',
        'pairing_secret': 's',
        'created_at': DateTime.now().toIso8601String(),
        'last_seen_at': DateTime.now().toIso8601String(),
      });
      expect((legacy.awaitingFirstUse, legacy.pairingCodeExpired), (false, false));
    });
  });
}
