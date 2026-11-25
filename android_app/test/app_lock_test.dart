import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:remotetester/security/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends LocalAuthentication {
  bool secure = true;
  bool fingerprint = true;
  bool approve = true;
  int prompts = 0;

  @override
  Future<bool> isDeviceSupported() async => secure;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => fingerprint ? [BiometricType.strong] : [];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object?> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    return approve;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAuth auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuth();
    AppLock.authForTesting = auth;
    await AppLock.load();
  });

  test('is on by default and locked on cold start', () {
    expect(AppLock.enabled.value, isTrue);
    expect(AppLock.locked.value, isTrue);
    expect(AppLock.backgroundTimeout.value, AppLock.defaultTimeout);
  });

  test('unlock needs a successful fingerprint', () async {
    auth.approve = false;
    expect(await AppLock.unlock(), AuthOutcome.cancelled);
    expect(AppLock.locked.value, isTrue);
    auth.approve = true;
    expect(await AppLock.unlock(), AuthOutcome.ok);
    expect(AppLock.locked.value, isFalse);
  });

  test('turning the lock off requires authentication, turning it on does not', () async {
    auth.approve = false;
    expect(await AppLock.setEnabled(false), isFalse);
    expect(AppLock.enabled.value, isTrue);

    auth.approve = true;
    expect(await AppLock.setEnabled(false), isTrue);
    expect(AppLock.enabled.value, isFalse);

    final before = auth.prompts;
    auth.approve = false;
    expect(await AppLock.setEnabled(true), isTrue);
    expect(auth.prompts, before);
  });

  test('a longer timeout requires authentication, a shorter one does not', () async {
    auth.approve = false;
    expect(await AppLock.setBackgroundTimeout(900), isFalse);
    expect(AppLock.backgroundTimeout.value, AppLock.defaultTimeout);
    expect(await AppLock.setBackgroundTimeout(0), isTrue);
    expect(AppLock.backgroundTimeout.value, 0);
  });

  test('phone without any screen lock cannot authenticate — changes pass, skip allowed', () async {
    auth.secure = false;
    expect(await AppLock.capability(), LockCapability.none);
    expect(await AppLock.setEnabled(false), isTrue);
    expect(auth.prompts, 0);
  });

  test('relocks after the background timeout', () async {
    await AppLock.unlock();
    AppLock.onResumedAfter(const Duration(seconds: 10));
    expect(AppLock.locked.value, isFalse);
    // Poza oknem „świeżego” odcisku.
    AppLock.debugForgetRecentAuth();
    AppLock.onResumedAfter(const Duration(minutes: 2));
    expect(AppLock.locked.value, isTrue);
  });
}
