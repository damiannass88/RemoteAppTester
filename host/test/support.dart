import 'dart:io';

import 'package:remotetester_host/build/artifact_registry.dart';
import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/build/command_runner.dart';
import 'package:remotetester_host/build/operation_log.dart';
import 'package:remotetester_host/pairing/device_registry.dart';
import 'package:remotetester_host/pairing/hmac_auth.dart';
import 'package:remotetester_host/pairing/device_auth.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/store/project_store.dart';

/// Polecenie, które „buduje” instalkę `out.apk` (cmd i bash rozumieją je tak samo).
const fakeApkStep = BuildStep('Zbuduj', 'echo apk> out.apk');

/// Długo działające polecenie (anulowanie).
String get longRunningCommand => Platform.isWindows ? 'ping -n 30 127.0.0.1 >nul' : 'sleep 30';

BuildProfile fakeProfile({String name = 'Debug', List<BuildStep> steps = const [fakeApkStep]}) =>
    BuildProfile(name: name, steps: steps, artifact: 'out.apk');

/// Środowisko testowe: katalog danych z zaszyfrowaną bazą, rejestr urządzeń i silnik.
class TestHost {
  TestHost() : home = Directory.systemTemp.createTempSync('rt_test_') {
    store = ProjectStore.open(home: home.path);
    devices = DeviceRegistry(File('${home.path}/config/paired_devices.json'));
    operationLog = OperationLog(File('${home.path}/logs/operations.log'));
    engine = BuildEngine(
      runner: CommandRunner(scriptDir: Directory('${home.path}/tmp')),
      artifacts: artifacts,
      operationLog: operationLog,
      dataDir: home,
      store: store,
    );
  }

  final Directory home;
  late ProjectStore store;
  late final DeviceRegistry devices;
  late final OperationLog operationLog;
  final ArtifactRegistry artifacts = ArtifactRegistry();
  late final BuildEngine engine;

  /// Nowy folder projektu (Flutter) przypisany do RemoteAppTestera z komendą [fakeProfile].
  ProjectRecord addProject(String name, {List<BuildProfile>? profiles}) {
    final dir = Directory('${home.path}/projects/$name')..createSync(recursive: true);
    File('${dir.path}/pubspec.yaml').writeAsStringSync('name: $name\nflutter:\n');
    final record = store.add(dir);
    store.saveProfiles(record.id, profiles ?? [fakeProfile()]);
    return store.byId(record.id)!;
  }

  Future<void> dispose() async {
    await engine.close();
    store.close();
    for (var i = 0; i < 50 && home.existsSync(); i++) {
      try {
        home.deleteSync(recursive: true);
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 100)); // proces mógł jeszcze trzymać plik
      }
    }
  }
}

/// Metadane z ważnym podpisem HMAC dla danego urządzenia/RPC.
Map<String, String> authMetadata(PairedDevice device, String method, List<int> payload) {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final nonce = generateNonceHex();
  return {
    deviceIdMetadataKey: device.deviceId,
    authTimestampMetadataKey: timestamp,
    authNonceMetadataKey: nonce,
    authHmacMetadataKey: computeRequestHmac(
      pairingSecret: device.pairingSecret,
      method: method,
      payload: payload,
      timestampUnixMs: timestamp,
      nonceHex: nonce,
    ),
  };
}
