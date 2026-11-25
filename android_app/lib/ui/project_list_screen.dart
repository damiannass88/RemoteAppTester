import 'dart:async';

import 'package:flutter/material.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../net/agent_client.dart';
import '../net/connection_monitor.dart';
import '../net/friendly_errors.dart';
import '../delivery/delivery_service.dart';
import '../install/apk_installer.dart';
import 'about_screen.dart';
import 'add_project_screen.dart';
import 'build_log_screen.dart';
import 'delivery_banner.dart';
import 'info_screen.dart';
import 'project_detail_screen.dart';
import 'project_kind_ui.dart';
import 'settings_screen.dart';
import '../i18n.dart';

/// Pilot: projekty przypisane na komputerze, ich status na żywo i akcje
/// (zbuduj i zainstaluj, zainstaluj ostatnią wersję, uruchom, podgląd).
/// Projekty i komendy zmienia się wyłącznie na komputerze — telefon nigdy
/// nie podaje ścieżek ani komend.
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key, required this.client, this.deliveries});

  final AgentClient client;

  /// Automatyczne dostawy — `null` w testach widżetów.
  final DeliveryService? deliveries;

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  late Future<ProjectList> _projectsFuture;
  late final ConnectionMonitor _connectionMonitor;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _projectsFuture = widget.client.listProjects();
    _connectionMonitor = ConnectionMonitor(widget.client, interval: const Duration(seconds: 15));
    // Status buildów (także zleconych z komputera albo przez agenta AI) co kilka sekund.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _connectionMonitor.dispose();
    super.dispose();
  }

  Future<void> _silentRefresh() async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    try {
      final list = await widget.client.listProjects();
      if (mounted) setState(() => _projectsFuture = Future.value(list));
    } catch (_) {
      // Chwilowy brak połączenia pokazuje wskaźnik w pasku — listę zostawiamy.
    }
  }

  void _open(Project project, {String profile = '', String? watch, String? install}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => BuildLogScreen(
            client: widget.client,
            project: project,
            profile: profile,
            watchBuildId: watch,
            installBuildId: install,
            // Podgląd builda z komputera nie instaluje drugi raz — wersja dotrze jako dostawa.
            autoInstall: watch == null,
            launchAfterInstall: project.launchAfterInstall,
            deliveries: widget.deliveries,
          ),
        ))
        .then((_) => _silentRefresh());
  }

  /// „Zainstaluj ostatnią” — przez wspólną kolejkę (postęp na pasku u góry).
  void _installLast(Project project) {
    final service = widget.deliveries;
    if (service == null) {
      _open(project, install: project.lastArtifactBuildId);
      return;
    }
    unawaited(service.installBuild(
      projectId: project.projectId,
      projectName: project.displayName,
      buildId: project.lastArtifactBuildId,
      launch: project.launchAfterInstall,
    ));
  }

  Future<void> _addProject() async {
    final project = await Navigator.of(context).push<Project>(
      MaterialPageRoute(builder: (_) => AddProjectScreen(client: widget.client)),
    );
    if (project == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Dodano projekt „{0}”.', [project.displayName]))));
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _projectsFuture = widget.client.listProjects();
    });
    try {
      await _projectsFuture;
    } catch (_) {
      // Błąd pokazuje FutureBuilder (_ErrorView) — tu tylko czekamy na koniec
      // żądania, żeby RefreshIndicator/przycisk nie zostawiły nieobsłużonego
      // wyjątku (widocznego jako "Unhandled Exception" w logu).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Projekty')),
        actions: [
          _ConnectionStatusIndicator(monitor: _connectionMonitor),
          IconButton(
            tooltip: tr('Informacje'),
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
          IconButton(
            tooltip: tr('O aplikacji'),
            icon: const Icon(Icons.new_releases_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AboutScreen(client: widget.client))),
          ),
          IconButton(
            tooltip: tr('Ustawienia / ponowne parowanie'),
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProject,
        icon: const Icon(Icons.add),
        label: Text(tr('Nowy projekt')),
      ),
      body: Column(
        children: [
          if (widget.deliveries != null) DeliveryBanner(service: widget.deliveries!),
          Expanded(child: _projectList(context)),
        ],
      ),
    );
  }

  Widget _projectList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<ProjectList>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: snapshot.error!, onRetry: _refresh);
          }
          final projects = snapshot.data!.projects;
          if (projects.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        tr('Na komputerze nie ma jeszcze żadnego projektu.\n\nDodaj go przyciskiem „Nowy projekt” albo w aplikacji RemoteAppTester na komputerze.'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final buildable = project.installableOnPhone && project.phoneTriggerAllowed;
              return ListTile(
                leading: project.building
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: project.progressPercent > 0 ? project.progressPercent / 100 : null,
                        ),
                      )
                    : Badge(
                        isLabelVisible: project.changesPending,
                        smallSize: 10,
                        backgroundColor: Colors.blue,
                        child: Icon(projectKindIcon(project)),
                      ),
                title: Text(project.displayName),
                subtitle: Text(
                  projectSubtitle(project),
                  style: project.specError.isNotEmpty ? const TextStyle(color: Colors.red) : null,
                ),
                trailing: _ProjectActions(
                  project: project,
                  buildable: buildable,
                  onBuild: (profile) => _open(project, profile: profile),
                  onInstallLast: () => _installLast(project),
                  onWatch: () => _open(project, watch: project.activeBuildId),
                ),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(client: widget.client, project: project, deliveries: widget.deliveries),
                    ))
                    .then((_) => _silentRefresh()),
              );
            },
          );
        },
      ),
    );
  }
}

/// Wskaźnik "połączono"/"rozłączono" w AppBar, oparty na
/// [ConnectionMonitor]. Sam brak połączenia NIE blokuje UI (lista
/// projektów może dalej pokazywać ostatnio pobrane dane) — to tylko
/// informacja dla użytkownika, nie bramka.
class _ConnectionStatusIndicator extends StatelessWidget {
  const _ConnectionStatusIndicator({required this.monitor});

  final ConnectionMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final (icon, color, tooltip) = switch (monitor.status) {
          ConnectionStatus.checking => (Icons.sync, Colors.grey, tr('Sprawdzanie połączenia...')),
          ConnectionStatus.connected => (Icons.check_circle, Colors.green, tr('Połączono z komputerem')),
          ConnectionStatus.disconnected => (Icons.error, Colors.red, tr('Brak połączenia z komputerem')),
        };
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, color: color),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(friendlyErrorMessage(error)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(tr('Spróbuj ponownie'))),
            const SizedBox(height: 8),
            // Szczegóły techniczne domyślnie ukryte.
            ExpansionTile(
              title: Text(tr('Szczegóły techniczne'), style: TextStyle(fontSize: 13)),
              children: [SelectableText(error.toString(), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))],
            ),
          ],
        ),
      ),
    );
  }
}

/// Akcje pilota dla jednego projektu.
class _ProjectActions extends StatelessWidget {
  const _ProjectActions({
    required this.project,
    required this.buildable,
    required this.onBuild,
    required this.onInstallLast,
    required this.onWatch,
  });

  final Project project;
  final bool buildable;
  final void Function(String profile) onBuild;
  final VoidCallback onInstallLast;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) async {
        if (value.startsWith('build:')) {
          onBuild(value.substring(6));
        } else if (value == 'last') {
          onInstallLast();
        } else if (value == 'watch') {
          onWatch();
        } else if (value == 'launch') {
          final ok = await ApkInstaller.launch(project.projectId);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('Aplikacja nie jest zainstalowana przez RemoteAppTester na tym telefonie.'))),
            );
          }
        }
      },
      itemBuilder: (_) => [
        for (final profile in project.profiles)
          PopupMenuItem(
            value: 'build:$profile',
            enabled: buildable && !project.building,
            child: ListTile(leading: const Icon(Icons.send_to_mobile), title: Text(tr('Zbuduj i zainstaluj: {0}', [profile]))),
          ),
        PopupMenuItem(
          value: 'last',
          enabled: project.lastArtifactBuildId.isNotEmpty,
          child: ListTile(leading: Icon(Icons.download), title: Text(tr('Zainstaluj ostatnią wersję'))),
        ),
        PopupMenuItem(value: 'launch', child: ListTile(leading: Icon(Icons.play_arrow), title: Text(tr('Uruchom aplikację')))),
        if (project.activeBuildId.isNotEmpty)
          PopupMenuItem(value: 'watch', child: ListTile(leading: Icon(Icons.article), title: Text(tr('Podgląd trwającego builda')))),
      ],
    );
  }
}
