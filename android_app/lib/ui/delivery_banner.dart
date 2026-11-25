import 'package:flutter/material.dart';

import '../delivery/delivery_service.dart';
import '../transfer/delta_downloader.dart';
import 'app_theme.dart';
import '../native/package_installer.dart';
import '../i18n.dart';
import 'delivery_text.dart';

/// Pasek nad listą projektów: stan automatycznych dostaw i jednorazowa zgoda
/// Androida na instalowanie aplikacji (docs/PROJECT_ASSUMPTIONS.md, sekcja 8).
class DeliveryBanner extends StatefulWidget {
  const DeliveryBanner({super.key, required this.service});

  final DeliveryService service;

  @override
  State<DeliveryBanner> createState() => _DeliveryBannerState();
}

class _DeliveryBannerState extends State<DeliveryBanner> with WidgetsBindingObserver {
  bool? _canInstall;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInstallPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Po powrocie z ustawień Androida sprawdzamy zgodę ponownie.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkInstallPermission();
  }

  Future<void> _checkInstallPermission() async {
    final ok = await DeliveryService.canInstallPackages();
    if (mounted) setState(() => _canInstall = ok);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final children = <Widget>[
          if (_canInstall == false)
            _Bar(
              color: Colors.orange,
              icon: Icons.security,
              text: tr('Android wymaga jednorazowej zgody na instalowanie aplikacji przez RemoteAppTester.'),
              action: TextButton(
                onPressed: PackageInstallerChannel.openInstallPermissionSettings,
                child: Text(tr('Zezwól')),
              ),
            ),
          ?_statusBar(widget.service),
        ];
        return Column(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }

  Widget? _statusBar(DeliveryService service) {
    final status = service.status;
    if (status == null) {
      return service.connected
          ? null
          : _Bar(
              color: Colors.blueGrey,
              icon: Icons.sync_problem,
              text: tr('Łączenie z komputerem — nowe wersje dotrą automatycznie po połączeniu.'),
            );
    }
    final name = status.delivery.projectName;
    return switch (status.stage) {
      DeliveryStage.downloading => _Bar(
          color: Colors.blue,
          icon: Icons.download,
          text: [
            tr('Nowa wersja: {0} — pobieranie {1}', [name, transferLabel(status.bytes, status.totalBytes, fullSize: status.delivery.sizeBytes.toInt())]),
            if (status.bytesPerSecond > 0) speedLabel(status.bytesPerSecond),
          ].join(' · '),
          progress: true,
        ),
      DeliveryStage.installing => _Bar(
          color: Colors.blue,
          icon: Icons.install_mobile,
          text: status.message == null ? tr('Instalowanie: {0}', [name]) : '$name: ${status.message}',
          progress: true,
        ),
      DeliveryStage.waitingForUser => _Bar(
          color: Colors.amber,
          icon: Icons.help_outline,
          text: '$name: ${status.message}',
          action: Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(onPressed: service.dismissAwaiting, child: Text(tr('Pomiń'))),
            FilledButton(onPressed: service.installAwaiting, child: Text(tr('Zainstaluj'))),
          ]),
        ),
      DeliveryStage.done => _Bar(
          color: Colors.green,
          icon: Icons.check_circle,
          text: tr('Zainstalowano: {0}', [name]),
          action: TextButton(onPressed: service.launch, child: Text(tr('Uruchom'))),
        ),
      DeliveryStage.failed => _Bar(
          color: Colors.red,
          icon: Icons.error,
          text: '$name: ${status.message ?? tr('nie udało się')}',
          action: TextButton(onPressed: service.retry, child: Text(tr('Ponów'))),
        ),
      DeliveryStage.idle => null,
    } ?? const SizedBox.shrink();
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.icon, required this.text, this.action, this.progress = false});

  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.tint(context, color),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            progress
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            ?action,
          ],
        ),
      ),
    );
  }
}
