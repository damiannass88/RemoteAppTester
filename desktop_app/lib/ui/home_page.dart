import 'package:flutter/material.dart';
import 'package:remotetester_host/server/host_runtime.dart';

import '../app_controller.dart';
import 'about_page.dart';
import 'info_page.dart';
import 'phones_page.dart';
import 'projects_page.dart';
import 'settings_page.dart';
import '../i18n.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -0.9,
                    destinations: [
                      NavigationRailDestination(
                        icon: Badge(
                          isLabelVisible: c.pendingProposals > 0,
                          label: Text('${c.pendingProposals}'),
                          child: const Icon(Icons.folder_copy_outlined),
                        ),
                        selectedIcon: const Icon(Icons.folder_copy),
                        label: Text(tr('Projekty')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.smartphone_outlined),
                        selectedIcon: const Icon(Icons.smartphone),
                        label: Text(tr('Telefony ({0})', [c.devices.length])),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text(tr('Ustawienia')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.info_outline),
                        selectedIcon: const Icon(Icons.info),
                        label: Text(tr('Informacje')),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.new_releases_outlined),
                        selectedIcon: const Icon(Icons.new_releases),
                        label: Text(tr('O aplikacji')),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: switch (_tab) {
                      0 => ProjectsPage(controller: c),
                      1 => PhonesPage(controller: c),
                      2 => SettingsPage(controller: c),
                      3 => const InfoPage(),
                      _ => AboutPage(controller: c),
                    },
                  ),
                ],
              ),
            ),
            _StatusBar(controller: c),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final runtime = controller.runtime;
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (runtime.phoneServerState) {
      PhoneServerState.running => (Icons.lan, Colors.green),
      PhoneServerState.waitingForTailscale => (Icons.portable_wifi_off, Colors.orange),
      PhoneServerState.failed => (Icons.error_outline, Colors.red),
      PhoneServerState.starting => (Icons.sync, Colors.grey),
    };
    final engine = controller.engine;
    final online = controller.devices.where((d) => controller.isOnline(d.deviceId)).length;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(runtime.phoneServerMessage ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
            if (controller.paused)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Text('WSTRZYMANE', style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            Text(tr('Buduje: {0}/{1}   W kolejce: {2}   Telefony online: {3}/{4}', [engine.runningCount, engine.maxParallel, engine.queuedCount, online, controller.devices.length]),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
