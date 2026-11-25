import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:remotetester_host/version.dart';

import '../app_controller.dart';
import 'widgets.dart';
import '../i18n.dart';

/// O aplikacji: wersja, krótki opis i najważniejsze dane tej instalacji.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runtime = controller.runtime;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(tr('O aplikacji'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(Icons.phonelink_setup, size: 48, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('RemoteAppTester', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                  Text(tr('Wersja {0} (testowa)', [hostVersion]), style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('Buduje aplikacje Android na tym komputerze i dostarcza je przez Tailscale na sparowane telefony testowe. Agenci AI zgłaszają zmiany przez pliki w folderze projektu, bez dostępu do programu.')),
        SectionTitle(tr('Składniki')),
        _Row(tr('Aplikacja okienkowa'), hostVersion),
        _Row(tr('Narzędzie terminala rt'), hostVersion),
        _Row(tr('Aplikacja na telefon'), hostVersion),
        SectionTitle(tr('Ten komputer')),
        _Row(tr('Adres Tailscale'), runtime.tailscaleAddress?.address ?? tr('brak')),
        _Row(tr('Port dla telefonów'), '${runtime.config.listenPort}'),
        _Row(tr('Sparowane telefony'), '${controller.devices.length}'),
        _Row(tr('Folder projektów'), runtime.config.projectsRoot.path, copy: true),
        _Row(tr('Folder danych'), Directory.current.path, copy: true),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.copy = false});
  final String label;
  final String value;
  final bool copy;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 220, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value)),
          if (copy)
            IconButton(
              tooltip: tr('Kopiuj'),
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        ]),
      );
}
