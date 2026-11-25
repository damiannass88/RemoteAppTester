import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:remotetester_host/net/tailscale_policy.dart';

import '../app_controller.dart';
import 'widgets.dart';
import '../i18n.dart';

class PhonesPage extends StatelessWidget {
  const PhonesPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final devices = controller.devices;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(child: Text(tr('Telefony'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _TailscalePolicyDialog(
                  port: controller.runtime.config.listenPort,
                  previewPorts: controller.runtime.config.preview.portRange,
                ),
              ),
              icon: const Icon(Icons.data_object),
              label: Text(tr('Generuj JSON dla Tailscale')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _pair(context),
              icon: const Icon(Icons.qr_code),
              label: Text(tr('Sparuj telefon')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(tr('Telefony z aplikacją RemoteAppTester łączą się z tym komputerem przez Tailscale (szyfrowanie, certyfikat przypięty przy parowaniu, podpis każdego żądania). Każdy ma własny klucz — odwołanie jednego nie wpływa na pozostałe.')),
        const SizedBox(height: 16),
        if (devices.isEmpty) Text(tr('Brak sparowanych telefonów.')),
        for (final d in devices)
          Card(
            child: ListTile(
              leading: Icon(Icons.smartphone, color: controller.isOnline(d.deviceId) ? Colors.green : null),
              title: Text(d.displayName),
              subtitle: Text('${controller.isOnline(d.deviceId) ? tr('online · ') : ''}'
                  '${d.awaitingFirstUse ? tr('czeka na zeskanowanie, kod ważny do {0}', [d.pairingExpiresAt!.toLocal().toString().substring(11, 16)]) : tr('ostatnio: {0}', [d.lastSeenAt.toLocal().toString().substring(0, 16)])}'
                  '\nid: ${d.deviceId}'),
              isThreeLine: true,
              trailing: TextButton.icon(
                onPressed: () async {
                  if (await confirm(context, tr('Odwołać „{0}”?', [d.displayName]),
                      tr('Telefon natychmiast straci dostęp. Ponowne połączenie wymaga nowego parowania.'),
                      action: tr('Odwołaj'))) {
                    controller.revoke(d.deviceId);
                  }
                },
                icon: const Icon(Icons.block, color: Colors.red),
                label: Text(tr('Odwołaj')),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pair(BuildContext context) async {
    final nameController = TextEditingController(text: tr('Mój telefon'));
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Nazwa telefonu')),
        content: TextField(controller: nameController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Anuluj'))),
          FilledButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: Text(tr('Dalej'))),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    final String uri;
    try {
      uri = controller.pair(name).$2;
    } on Object catch (e) {
      showError(context, e.toString());
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(tr('Zeskanuj kod w aplikacji RemoteAppTester na telefonie „{0}”', [name])),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: uri, size: 320),
              ),
              const SizedBox(height: 12),
              Text(tr('Kod daje dostęp do tego komputera — nie pokazuj go nikomu i zamknij to okno po zeskanowaniu.'),
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              Text(tr('Kod jest jednorazowy i ważny przez 1 godzinę. Telefon od razu wymienia go na własny sekret.')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (!await confirm(
                context,
                tr('Skopiować link parowania?'),
                tr('Link zawiera jednorazowy sekret. Historia schowka Windows (Win+V) i jego synchronizacja mogą go zachować. Bezpieczniej zeskanować kod QR.'),
                action: tr('Kopiuj link'),
              )) {
                return;
              }
              await Clipboard.setData(ClipboardData(text: uri));
              if (context.mounted) showInfo(context, tr('Skopiowano link — w aplikacji wybierz „Wklej ze schowka”. Schowek wyczyści się za 2 minuty.'));
              // Czyścimy tylko, jeśli w schowku nadal jest ten link.
              Future<void>.delayed(const Duration(minutes: 2), () async {
                final current = await Clipboard.getData(Clipboard.kTextPlain);
                if (current?.text == uri) await Clipboard.setData(const ClipboardData(text: ''));
              });
            },
            child: Text(tr('Kopiuj link')),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Gotowe'))),
        ],
      ),
    );
  }
}

/// Reguły dostępu Tailscale: wybrane telefony → wybrane komputery, tylko port RemoteAppTestera.
class _TailscalePolicyDialog extends StatefulWidget {
  const _TailscalePolicyDialog({required this.port, this.previewPorts});
  final int port;
  final String? previewPorts;

  @override
  State<_TailscalePolicyDialog> createState() => _TailscalePolicyDialogState();
}

class _TailscalePolicyDialogState extends State<_TailscalePolicyDialog> {
  Tailnet? _tailnet;
  String? _error;
  final _phones = <String>{};
  final _computers = <String>{};

  @override
  void initState() {
    super.initState();
    readTailnet().then((t) {
      if (!mounted) return;
      setState(() {
        _tailnet = t;
        _phones.addAll(t.phones.map((d) => d.ip));
      });
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e.toString());
    });
  }

  String _policy(Tailnet t) => buildTailscalePolicy(
        phones: t.phones.where((d) => _phones.contains(d.ip)).toList(),
        computers: [t.self, ...t.computers.where((d) => _computers.contains(d.ip))],
        port: widget.port,
        previewPorts: widget.previewPorts,
      );

  @override
  Widget build(BuildContext context) {
    final t = _tailnet;
    return AlertDialog(
      title: Text(tr('Reguły dostępu Tailscale')),
      content: SizedBox(
        width: 640,
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.red))
            : t == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(child: _content(context, t)),
      ),
      actions: [
        if (t != null)
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _policy(t)));
              if (context.mounted) showInfo(context, tr('Skopiowano JSON.'));
            },
            icon: const Icon(Icons.copy),
            label: Text(tr('Kopiuj JSON')),
          ),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('Zamknij'))),
      ],
    );
  }

  Widget _content(BuildContext context, Tailnet t) {
    final mono = TextStyle(fontFamily: 'Consolas', fontSize: 13, color: Theme.of(context).colorScheme.onSurface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Pozwala wybranym telefonom łączyć się z RemoteAppTesterem tylko na porcie {0} (TCP). Wklej w panelu Tailscale: Access controls → JSON editor. To zastępuje całą politykę — inne reguły dopisz ręcznie.', [widget.port])),
        SectionTitle(tr('Telefony')),
        if (t.phones.isEmpty) Text(tr('Brak telefonów w Tailscale — zaloguj Tailscale na telefonie tym samym kontem.')),
        for (final d in t.phones)
          CheckboxListTile(
            dense: true,
            value: _phones.contains(d.ip),
            onChanged: (v) => setState(() => v! ? _phones.add(d.ip) : _phones.remove(d.ip)),
            title: Text(d.name),
            subtitle: Text('${d.ip}${d.online ? tr('  ● online') : ''}'),
          ),
        SectionTitle(tr('Komputery z RemoteAppTesterem')),
        CheckboxListTile(
          dense: true,
          value: true,
          onChanged: null,
          title: Text(tr('{0} (ten komputer)', [t.self.name])),
          subtitle: Text(t.self.ip),
        ),
        for (final d in t.computers)
          CheckboxListTile(
            dense: true,
            value: _computers.contains(d.ip),
            onChanged: (v) => setState(() => v! ? _computers.add(d.ip) : _computers.remove(d.ip)),
            title: Text(d.name),
            subtitle: Text('${d.ip} · ${d.os}${d.online ? tr('  ● online') : ''}'),
          ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: SelectableText(_policy(t), style: mono),
        ),
      ],
    );
  }
}
