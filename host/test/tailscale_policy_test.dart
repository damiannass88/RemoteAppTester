import 'dart:convert';

import 'package:remotetester_host/net/tailscale_policy.dart';
import 'package:test/test.dart';

const _status = '''
{
  "Self": {"HostName": "DELL", "DNSName": "dell.tail2ff74a.ts.net.", "OS": "windows",
           "TailscaleIPs": ["100.81.17.106", "fd7a:115c:a1e0::cf01:11b9"], "Online": true},
  "Peer": {
    "a": {"HostName": "Xiaomi 15 Ultra", "DNSName": "xiaomi-15-ultra.tail2ff74a.ts.net.", "OS": "android",
          "TailscaleIPs": ["100.111.210.37"], "Online": true},
    "b": {"HostName": "agents-vps", "DNSName": "agents-vps.tail2ff74a.ts.net.", "OS": "linux",
          "TailscaleIPs": ["100.80.58.28"], "Online": true},
    "c": {"HostName": "iPhone", "DNSName": "iphone.tail2ff74a.ts.net.", "OS": "iOS",
          "TailscaleIPs": ["100.90.1.2"], "Online": false}
  }
}
''';

void main() {
  test('phones and computers come from tailscale status', () {
    final t = parseTailscaleStatus(_status);
    expect(t.self.name, 'dell');
    expect(t.phones.map((d) => d.name), ['iphone', 'xiaomi-15-ultra']);
    expect(t.computers.map((d) => d.name), ['agents-vps']);
  });

  test('the policy lets only the phones reach RemoteAppTester on its port', () {
    final t = parseTailscaleStatus(_status);
    final policy = jsonDecode(buildTailscalePolicy(phones: t.phones, computers: [t.self, ...t.computers], port: 47051)) as Map;
    expect(policy['hosts'], {
      'dell': '100.81.17.106',
      'agents-vps': '100.80.58.28',
      'iphone': '100.90.1.2',
      'xiaomi-15-ultra': '100.111.210.37',
    });
    expect(policy['grants'], [
      {
        'src': ['iphone', 'xiaomi-15-ultra'],
        'dst': ['dell', 'agents-vps'],
        'ip': ['tcp:47051'],
      }
    ]);
  });

  test('without phones there is no grant (nothing is opened)', () {
    final t = parseTailscaleStatus(_status);
    final policy = jsonDecode(buildTailscalePolicy(phones: const [], computers: [t.self], port: 47051)) as Map;
    expect(policy['grants'], isEmpty);
  });

  test('names that are not valid aliases are cleaned and kept unique', () {
    const a = TailnetDevice(name: 'My Phone', ip: '100.64.0.1', os: 'android', online: true);
    const b = TailnetDevice(name: 'my-phone', ip: '100.64.0.2', os: 'android', online: true);
    const pc = TailnetDevice(name: 'pc', ip: '100.64.0.3', os: 'windows', online: true);
    final policy = jsonDecode(buildTailscalePolicy(phones: const [a, b], computers: const [pc], port: 1)) as Map;
    expect(policy['hosts'], {'pc': '100.64.0.3', 'my-phone': '100.64.0.1', 'my-phone-2': '100.64.0.2'});
  });
}
