import 'package:remotetester_host/project/agent_signal.dart';
import 'package:remotetester_host/server/delivery_hub.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/server/signal_watcher.dart';
import 'package:test/test.dart';

import 'agent_push_test.dart' show fakeApk, waitForState;
import 'support.dart';

void main() {
  test('the status lists the phones and marks the ones that confirmed the install', () async {
    final host = TestHost();
    addTearDown(host.dispose);
    final deliveries = DeliveryHub(finished: host.engine.onFinished, devices: host.devices);
    addTearDown(deliveries.close);
    final watcher = SignalWatcher(
      store: host.store,
      engine: host.engine,
      killSwitch: KillSwitch(),
      operationLog: host.operationLog,
      deliveries: deliveries,
      devices: host.devices,
      interval: const Duration(hours: 1),
      settle: Duration.zero,
    );
    addTearDown(watcher.close);
    final phone = host.devices.register('Pixel');
    final project = host.addProject('apka');
    fakeApk('${project.path}/build/app.apk');
    writeAgentSignal(project.directory, deliver: 'build/app.apk', request: 'd1');
    watcher.scan();
    var status = await waitForState(project.directory, {'done', 'failed', 'rejected'});
    var devices = (status['devices'] as List).cast<Map<String, Object?>>();
    expect(devices.single['id'], phone.deviceId);
    expect(devices.single['name'], 'Pixel');
    expect(devices.single['online'], isFalse);
    expect(devices.single['handled'], isFalse);

    expect(deliveries.ack(phone.deviceId, status['build_id'] as String), isTrue);
    status = readAgentStatus(project.directory)!;
    devices = (status['devices'] as List).cast<Map<String, Object?>>();
    expect(devices.single['handled'], isTrue);
    expect(status['message'], contains('1'));
  });
}
