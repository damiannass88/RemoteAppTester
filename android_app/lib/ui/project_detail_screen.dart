import 'dart:async';

import 'package:flutter/material.dart';

import '../delivery/delivery_service.dart';
import '../generated/remote_tester.pbgrpc.dart';
import '../install/apk_installer.dart';
import '../net/agent_client.dart';
import 'build_log_screen.dart';
import 'delivery_text.dart';
import 'preview_screen.dart';
import 'project_kind_ui.dart';
import '../i18n.dart';

/// Pilot jednego projektu: podgląd tego, co się dzieje (konsola), i przyciski
/// w kolejności kroków: zbuduj → zainstaluj → uruchom. Instalacje idą przez
/// [DeliveryService], więc ta sama wersja nie jest pobierana ani instalowana dwa razy.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.client, required this.project, this.deliveries});

  final AgentClient client;
  final Project project;

  /// Wspólna kolejka instalacji — `null` w testach widżetów.
  final DeliveryService? deliveries;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Project _project = widget.project;
  late String _profile = _project.defaultProfile;
  Timer? _poll;
  bool _gone = false;
  bool _saving = false;
  String? _installedBuild;
  String? _installedPackage;

  /// Podgląd konsoli: log trwającego builda i kroki instalacji.
  final List<String> _console = [];
  final _consoleScroll = ScrollController();
  StreamSubscription<BuildEvent>? _buildSub;
  String? _watchedBuild;
  String? _lastDeliveryLine;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
    widget.deliveries?.addListener(_onDelivery);
    _loadInstalled();
    _followBuild();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _buildSub?.cancel();
    _consoleScroll.dispose();
    widget.deliveries?.removeListener(_onDelivery);
    super.dispose();
  }

  Future<void> _loadInstalled() async {
    final build = await ApkInstaller.installedBuildFor(_project.projectId);
    final package = await ApkInstaller.installedPackageFor(_project.projectId);
    if (mounted) {
      setState(() {
        _installedBuild = build;
        _installedPackage = package;
      });
    }
  }

  void _onDelivery() {
    final status = widget.deliveries?.statusFor(_project.projectId);
    if (status == null || !mounted) return;
    final line = deliveryStatusText(status);
    if (line.isEmpty || line == _lastDeliveryLine) return;
    setState(() {
      // Postęp pobierania nadpisuje poprzednią linię zamiast zalewać podgląd.
      if (_lastDeliveryLine != null && status.stage == DeliveryStage.downloading && _console.isNotEmpty && _console.last == _lastDeliveryLine) {
        _console.removeLast();
      }
      _console.add(line);
      _lastDeliveryLine = line;
    });
    if (status.stage == DeliveryStage.done) _loadInstalled();
    _scrollConsole();
  }

  /// Log trwającego builda (także zleconego z komputera albo przez agenta AI).
  void _followBuild() {
    final id = _project.activeBuildId;
    if (id.isEmpty || id == _watchedBuild) return;
    _watchedBuild = id;
    _buildSub?.cancel();
    _console.add(tr('— build {0} —', [_project.defaultProfile]));
    _buildSub = widget.client.getBuildStatus(BuildId(buildId: id)).listen((e) {
      if (!mounted || e.logLine.isEmpty) return;
      setState(() {
        _console.add(e.logLine);
        if (_console.length > 200) _console.removeRange(0, _console.length - 200);
      });
      _scrollConsole();
    }, onError: (Object _) {}, cancelOnError: true);
  }

  void _scrollConsole() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_consoleScroll.hasClients) _consoleScroll.jumpTo(_consoleScroll.position.maxScrollExtent);
    });
  }

  Future<void> _refresh() async {
    if (!mounted || _saving || ModalRoute.of(context)?.isCurrent != true) return;
    try {
      final list = await widget.client.listProjects();
      final fresh = list.projects.where((p) => p.projectId == _project.projectId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _gone = fresh == null;
        if (fresh != null) _project = fresh;
        if (!_project.profiles.contains(_profile)) _profile = _project.defaultProfile;
      });
      _followBuild();
    } catch (_) {
      // Chwilowy brak połączenia — zostaje ostatni znany stan.
    }
  }

  void _open({String profile = '', String? watch}) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => BuildLogScreen(
            client: widget.client,
            project: _project,
            profile: profile,
            watchBuildId: watch,
            autoInstall: watch == null,
            launchAfterInstall: _project.launchAfterInstall,
            deliveries: widget.deliveries,
          ),
        ))
        .then((_) {
      _refresh();
      _loadInstalled();
    });
  }

  /// Podgląd konsoli otwiera pełny ekran builda: trwającego albo ostatniego.
  Future<void> _openPreview() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreviewScreen(client: widget.client, project: _project),
    ));
    if (mounted) unawaited(_refresh());
  }

  void _openConsole() {
    final id = _project.activeBuildId.isNotEmpty ? _project.activeBuildId : _project.lastArtifactBuildId;
    if (id.isNotEmpty) _open(watch: id);
  }

  Future<void> _installLatest() async {
    final service = widget.deliveries;
    final build = _project.lastArtifactBuildId;
    if (build.isEmpty) return;
    if (service == null) {
      // Bez wspólnej kolejki (testy) — dawny ekran z pobieraniem.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BuildLogScreen(client: widget.client, project: _project, installBuildId: build, launchAfterInstall: _project.launchAfterInstall),
      ));
      return;
    }
    setState(() => _console.add(tr('Instalacja ostatniej wersji…')));
    await service.installBuild(
      projectId: _project.projectId,
      projectName: _project.displayName,
      buildId: build,
      launch: _project.launchAfterInstall,
    );
  }

  /// Zmiana opcji — od razu na komputerze (okno RemoteAppTester odświeży się samo).
  Future<void> _setOption(ProjectOptionsUpdate update) async {
    setState(() => _saving = true);
    try {
      final fresh = await widget.client.updateProjectOptions(update..projectId = _project.projectId);
      if (mounted) setState(() => _project = fresh);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Nie zapisano opcji: {0}', [e]))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _launch() async {
    final ok = await ApkInstaller.launch(_project.projectId);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Aplikacja nie jest zainstalowana przez RemoteAppTester na tym telefonie.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.deliveries;
    return service == null ? _body(context, null) : ListenableBuilder(listenable: service, builder: (context, _) => _body(context, service));
  }

  Widget _body(BuildContext context, DeliveryService? service) {
    final p = _project;
    final buildable = p.installableOnPhone && p.phoneTriggerAllowed && !_gone;
    final delivery = service?.statusFor(p.projectId);
    final busy = service?.isBusyFor(p.projectId) ?? false;
    final waiting = delivery?.stage == DeliveryStage.waitingForUser;
    final upToDate = p.lastArtifactBuildId.isNotEmpty && p.lastArtifactBuildId == _installedBuild;

    // Kolejność kroków: zbuduj → zainstaluj → uruchom. Każdy przycisk jest aktywny tylko wtedy,
    // gdy ma sens; trwająca instalacja blokuje kolejną tej samej aplikacji.
    final (installLabel, VoidCallback? onInstall) = waiting
        ? (tr('Zainstaluj teraz'), service!.installAwaiting)
        : busy
            ? (tr('Instalowanie…'), null)
            : upToDate
                ? (tr('Najnowsza zainstalowana'), null)
                : (tr('Zainstaluj ostatnią'), p.lastArtifactBuildId.isEmpty ? null : _installLatest);

    return Scaffold(
      appBar: AppBar(title: Text(p.displayName)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_gone)
              _Note(icon: Icons.link_off, color: Colors.red, text: tr('Projekt został odpięty na komputerze.')),
            _StatusCard(
              project: p,
              busy: busy,
              upToDate: upToDate,
              console: _console,
              scroll: _consoleScroll,
              onTap: p.activeBuildId.isNotEmpty || p.lastArtifactBuildId.isNotEmpty ? _openConsole : null,
            ),
            if (p.changesPending || p.agentNote.isNotEmpty) _AgentCard(project: p),
            if (p.specError.isNotEmpty) _Note(icon: Icons.error_outline, color: Colors.red, text: p.specError),
            if (!p.phoneTriggerAllowed)
              _Note(
                icon: Icons.block,
                color: Colors.orange,
                text: tr('Budowanie z telefonu jest wyłączone w opcjach projektu na komputerze.'),
              ),
            if (p.previewAvailable) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _gone ? null : _openPreview,
                icon: const Icon(Icons.public),
                label: Text(p.previewRunning
                    ? tr('Podgląd strony działa — otwórz')
                    : tr('Podgląd strony ({0})', [p.previewKind])),
              ),
            ],
            const SizedBox(height: 16),
            if (p.profiles.length > 1) ...[
              Text(tr('Wariant'), style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [for (final name in p.profiles) ButtonSegment(value: name, label: Text(name))],
                selected: {_profile.isEmpty ? p.profiles.first : _profile},
                onSelectionChanged: (s) => setState(() => _profile = s.first),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: buildable && !p.building && !busy ? () => _open(profile: _profile) : null,
              icon: const Icon(Icons.send_to_mobile),
              label: Text(p.building
                  ? tr('Trwa budowanie…')
                  : p.changesPending
                      ? tr('Zbuduj nowe zmiany i zainstaluj')
                      : tr('Zbuduj i zainstaluj')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: onInstall,
                    icon: Icon(upToDate && !busy && !waiting ? Icons.check : Icons.download),
                    label: Text(installLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: _installedPackage != null && !busy ? _launch : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(tr('Uruchom')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _OptionsSection(project: p, enabled: !_saving && !_gone, onChange: _setOption),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.project,
    required this.busy,
    required this.upToDate,
    required this.console,
    required this.scroll,
    required this.onTap,
  });
  final Project project;
  final bool busy;
  final bool upToDate;
  final List<String> console;
  final ScrollController scroll;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final (icon, color, label) = p.building
        ? (Icons.autorenew, Colors.blue, p.progressPercent > 0 ? tr('Buduje… {0}%', [p.progressPercent]) : tr('W kolejce'))
        : busy
            ? (Icons.install_mobile, Colors.blue, tr('Instalowanie na tym telefonie'))
            : switch (p.lastPhase) {
                BuildPhase.DONE => (Icons.check_circle, Colors.green, tr('Ostatni build: gotowe')),
                BuildPhase.FAILED => (Icons.error, Colors.red, tr('Ostatni build: błąd')),
                BuildPhase.CANCELLED => (Icons.cancel, Colors.grey, tr('Ostatni build: anulowany')),
                _ => (Icons.circle_outlined, Colors.grey, tr('Jeszcze nie budowano')),
              };
    final ago = timeAgo(p.lastBuildUnixMs.toInt());
    final lines = console.isNotEmpty
        ? console
        : [
            tr('{0} · domyślny wariant: {1}', [projectKindLabel(p), p.defaultProfile.isEmpty ? '—' : p.defaultProfile]),
            if (upToDate) tr('Na tym telefonie jest najnowsza wersja.'),
            if (p.lastArtifactBuildId.isEmpty) tr('Brak gotowej wersji — zbuduj projekt.'),
          ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                if (!p.building && ago.isNotEmpty) Text(ago, style: Theme.of(context).textTheme.bodySmall),
                if (onTap != null) const Icon(Icons.open_in_full, size: 18),
              ]),
              if (p.building) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: p.progressPercent > 0 ? p.progressPercent / 100 : null),
              ],
              const SizedBox(height: 8),
              Container(
                height: 110,
                width: double.infinity,
                color: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListView.builder(
                  controller: scroll,
                  itemCount: lines.length,
                  itemBuilder: (_, i) => Text(
                    lines[i],
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final ago = timeAgo(p.agentNoteUnixMs.toInt());
    return Card(
      color: p.changesPending ? Colors.blue.withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: Icon(p.changesPending ? Icons.fiber_new : Icons.smart_toy_outlined,
            color: p.changesPending ? Colors.blue : null),
        title: Text(p.changesPending ? tr('Agent AI zgłosił nowe zmiany') : tr('Ostatnia notatka agenta AI')),
        subtitle: Text([if (p.agentNote.isNotEmpty) '„${p.agentNote}”', if (ago.isNotEmpty) ago].join(' · ')),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ]),
      );
}

/// Opcje projektu — te same co w oknie na komputerze, zapisywane od razu.
class _OptionsSection extends StatelessWidget {
  const _OptionsSection({required this.project, required this.enabled, required this.onChange});
  final Project project;
  final bool enabled;
  final void Function(ProjectOptionsUpdate) onChange;

  @override
  Widget build(BuildContext context) {
    final p = project;
    final mode = p.installMode == InstallMode.INSTALL_MODE_UNSPECIFIED ? InstallMode.AUTO : p.installMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('Opcje projektu'), style: Theme.of(context).textTheme.titleMedium),
        Text(tr('Zapisują się od razu — także w oknie RemoteAppTester na komputerze.'),
            style: Theme.of(context).textTheme.bodySmall),
        SizedBox(height: 12),
        Text(tr('Po zbudowaniu'), style: Theme.of(context).textTheme.labelLarge),
        SizedBox(height: 8),
        SegmentedButton<InstallMode>(
          segments: [
            ButtonSegment(value: InstallMode.AUTO, icon: Icon(Icons.install_mobile), label: Text(tr('Instaluj'))),
            ButtonSegment(value: InstallMode.ASK, icon: Icon(Icons.help_outline), label: Text(tr('Pytaj'))),
            ButtonSegment(value: InstallMode.OFF, icon: Icon(Icons.block), label: Text(tr('Nie wysyłaj'))),
          ],
          selected: {mode},
          onSelectionChanged: enabled ? (s) => onChange(ProjectOptionsUpdate(installMode: s.first)) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Ten telefon dostaje nowe wersje')),
          subtitle: Text(tr('Wyłącz, jeśli ten projekt testujesz na innym telefonie.')),
          value: p.deliversToThisPhone,
          onChanged: enabled ? (v) => onChange(ProjectOptionsUpdate(deliverToThisPhone: v)) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Uruchom po instalacji')),
          value: p.launchAfterInstall,
          onChanged: enabled ? (v) => onChange(ProjectOptionsUpdate(launchAfterInstall: v)) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Sygnał agenta AI buduje i wysyła')),
          subtitle: Text(tr('Agent po pracy zapisuje .remoteapptester-signal (albo rt sg --build) — RemoteAppTester sam zbuduje zatwierdzonymi komendami.')),
          value: p.agentBuildAllowed,
          onChanged: enabled ? (v) => onChange(ProjectOptionsUpdate(agentBuildAllowed: v)) : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tr('Agent AI może wysłać własną instalkę')),
          subtitle: Text(tr('Agent, który sam zbudował APK, wysyła go poleceniem rt push — tylko pliki .apk z folderu projektu.')),
          value: p.agentPushAllowed,
          onChanged: enabled ? (v) => onChange(ProjectOptionsUpdate(agentPushAllowed: v)) : null,
        ),
        _OptionRow(label: tr('Budowanie z telefonu (zmiana tylko na komputerze)'), value: p.phoneTriggerAllowed),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.value});
  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(value ? Icons.check : Icons.close, size: 18, color: value ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Text(label),
        ]),
      );
}
