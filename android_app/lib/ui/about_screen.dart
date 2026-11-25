import 'package:flutter/material.dart';

import '../app_version.dart';
import '../net/agent_client.dart';
import '../net/friendly_errors.dart';
import '../settings/agent_settings.dart';
import '../i18n.dart';

/// O aplikacji: wersja, krótki opis i stan połączenia z komputerem (z jego wersją).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.client});

  /// Połączenie z komputerem — `null`, gdy telefon nie jest jeszcze połączony.
  final AgentClient? client;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  AgentAddress? _address;
  String? _hostVersion;
  String? _connection;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final address = await AgentAddress.load();
    if (mounted) setState(() => _address = address);
    final client = widget.client;
    if (client == null) {
      if (mounted) setState(() => _connection = tr('nie połączono'));
      return;
    }
    try {
      final pong = await client.ping();
      if (!mounted) return;
      setState(() {
        _connection = tr('połączono');
        _hostVersion = pong.hostVersion.isEmpty ? tr('starsza niż 0.6.1') : pong.hostVersion;
      });
    } catch (e) {
      if (mounted) setState(() => _connection = friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = _address;
    return Scaffold(
      appBar: AppBar(title: Text(tr('O aplikacji'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.phonelink_setup, size: 40, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('RemoteAppTester', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                    Text(tr('Wersja {0} (testowa)', [appVersion]), style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
                  ]),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(tr('Pilot do testów: komputer z RemoteAppTester buduje aplikacje Android i wysyła je przez Tailscale na ten telefon, a tu je instalujesz i uruchamiasz.')),
          ),
          _title(context, tr('Komputer')),
          _row(context, tr('Połączenie'), _connection ?? '…'),
          _row(context, tr('Adres'), address == null ? tr('brak — sparuj telefon') : '${address.host}:${address.port}'),
          if (_hostVersion != null) _row(context, tr('Wersja RemoteAppTester'), _hostVersion!),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _row(BuildContext context, String label, String value) => ListTile(
        dense: true,
        title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        subtitle: SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      );
}
