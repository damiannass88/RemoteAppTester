import 'dart:convert';
import 'dart:io';

import '../i18n.dart';

/// Urządzenie z sieci Tailscale (z `tailscale status --json`).
class TailnetDevice {
  const TailnetDevice({required this.name, required this.ip, required this.os, required this.online});

  /// Nazwa jak w panelu Tailscale (pierwsza część nazwy MagicDNS), np. `xiaomi-15-ultra`.
  final String name;
  final String ip;
  final String os;
  final bool online;

  bool get isPhone => const {'android', 'ios'}.contains(os.toLowerCase());
}

/// Ten komputer i pozostałe urządzenia w sieci Tailscale.
class Tailnet {
  const Tailnet(this.self, this.peers);
  final TailnetDevice self;
  final List<TailnetDevice> peers;

  List<TailnetDevice> get phones => peers.where((d) => d.isPhone).toList();
  List<TailnetDevice> get computers => peers.where((d) => !d.isPhone).toList();
}

class TailscaleStatusException implements Exception {
  const TailscaleStatusException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Polecenie `tailscale` (na Windows pełna ścieżka, bo instalator nie zawsze dopisuje PATH).
String tailscaleCli() {
  const windowsCli = r'C:\Program Files\Tailscale\tailscale.exe';
  return Platform.isWindows && File(windowsCli).existsSync() ? windowsCli : 'tailscale';
}

/// Odczytuje urządzenia poleceniem `tailscale status --json` (tylko odczyt).
Future<Tailnet> readTailnet() async {
  final cli = tailscaleCli();
  ProcessResult result;
  try {
    result = await Process.run(cli, ['status', '--json'], stdoutEncoding: utf8);
  } on ProcessException {
    throw TailscaleStatusException(tr('Nie znaleziono programu Tailscale (polecenie „tailscale”).'));
  }
  if (result.exitCode != 0) {
    throw TailscaleStatusException(tr('Tailscale nie podał listy urządzeń: {0}', ['${result.stderr}'.trim()]));
  }
  return parseTailscaleStatus(result.stdout as String);
}

Tailnet parseTailscaleStatus(String json) {
  final doc = jsonDecode(json) as Map<String, Object?>;
  final self = doc['Self'] as Map<String, Object?>?;
  if (self == null) throw TailscaleStatusException(tr('Tailscale nie jest połączony z siecią.'));
  final peers = (doc['Peer'] as Map<String, Object?>? ?? const {}).values.cast<Map<String, Object?>>();
  final devices = [for (final p in peers) _device(p)].whereType<TailnetDevice>().toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  final me = _device(self);
  if (me == null) throw TailscaleStatusException(tr('Tailscale nie jest połączony z siecią.'));
  return Tailnet(me, devices);
}

TailnetDevice? _device(Map<String, Object?> node) {
  final ip = (node['TailscaleIPs'] as List? ?? const []).cast<String>().where((a) => !a.contains(':')).firstOrNull;
  if (ip == null) return null;
  final dns = (node['DNSName'] as String? ?? '').split('.').first;
  final name = dns.isNotEmpty ? dns : (node['HostName'] as String? ?? ip);
  return TailnetDevice(name: name, ip: ip, os: node['OS'] as String? ?? '', online: node['Online'] as bool? ?? false);
}

/// Polityka dostępu Tailscale (panel → Access controls → JSON editor), która pozwala
/// wyłącznie wybranym telefonom łączyć się z RemoteAppTesterem na wybranych komputerach,
/// tylko po TCP na porcie [port] (i portach podglądu aplikacji web [previewPorts],
/// np. `47100-47109`). Nic poza tym nie jest dozwolone.
String buildTailscalePolicy({
  required List<TailnetDevice> phones,
  required List<TailnetDevice> computers,
  required int port,
  String? previewPorts,
}) {
  final hosts = <String, String>{};
  String alias(TailnetDevice d) {
    final base = d.name.toLowerCase().replaceAll(RegExp('[^a-z0-9-]'), '-');
    var name = base.isEmpty ? 'host' : base;
    for (var i = 2; hosts.containsKey(name) && hosts[name] != d.ip; i++) {
      name = '$base-$i';
    }
    hosts[name] = d.ip;
    return name;
  }

  final dst = [for (final d in computers) alias(d)];
  final src = [for (final d in phones) alias(d)];
  final policy = {
    'hosts': hosts,
    'grants': [
      if (src.isNotEmpty && dst.isNotEmpty)
        {
          'src': src,
          'dst': dst,
          'ip': ['tcp:$port', if (previewPorts != null) 'tcp:$previewPorts'],
        },
    ],
  };
  return const JsonEncoder.withIndent('\t').convert(policy);
}
