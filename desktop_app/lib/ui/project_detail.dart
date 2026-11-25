import 'dart:io';

import 'package:flutter/material.dart';
import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/generated/remote_tester.pb.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/templates.dart';
import 'package:remotetester_host/store/project_store.dart';

import '../app_controller.dart';
import 'commands_tab.dart';
import 'options_tab.dart';
import 'projects_page.dart';
import 'widgets.dart';
import '../i18n.dart';

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({super.key, required this.controller, required this.project});
  final AppController controller;
  final ProjectRecord project;

  @override
  Widget build(BuildContext context) {
    final proposal = controller.guides[project.id]?.status == GuideStatus.proposal;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(project.name, style: Theme.of(context).textTheme.headlineSmall),
                      SelectableText('${tr(kindName(project.kind))} · ${project.path}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('Otwórz folder w Eksploratorze'),
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => Process.start('explorer.exe', [project.path]),
                ),
                IconButton(
                  tooltip: tr('Otwórz w VS Code'),
                  icon: const Icon(Icons.code),
                  onPressed: () async {
                    try {
                      await Process.start('code', [project.path], runInShell: true);
                    } on Object {
                      if (context.mounted) showError(context, tr('Nie znaleziono VS Code (polecenie "code").'));
                    }
                  },
                ),
                IconButton(
                  tooltip: tr('Odepnij projekt od RemoteAppTester (pliki zostają)'),
                  icon: const Icon(Icons.link_off),
                  onPressed: () async {
                    if (await confirm(context, tr('Odpiąć „{0}”?', [project.name]),
                        tr('Projekt zniknie z RemoteAppTester i z telefonów. Pliki na dysku (także REMOTEAPPTESTER.md) zostają.'),
                        action: tr('Odepnij'))) {
                      controller.removeProject(project);
                    }
                  },
                ),
              ],
            ),
          ),
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.play_circle_outline), text: tr('Budowanie')),
              Tab(
                icon: Badge(isLabelVisible: proposal, child: const Icon(Icons.terminal)),
                text: tr('Komendy'),
              ),
              Tab(icon: Icon(Icons.tune), text: tr('Opcje')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BuildTab(controller: controller, project: project),
                CommandsTab(controller: controller, project: project),
                OptionsTab(controller: controller, project: project),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildTab extends StatefulWidget {
  const _BuildTab({required this.controller, required this.project});
  final AppController controller;
  final ProjectRecord project;

  @override
  State<_BuildTab> createState() => _BuildTabState();
}

class _BuildTabState extends State<_BuildTab> {
  String? _profile;
  Set<String>? _targets; // null = z opcji projektu
  String? _viewedBuildId;
  final _scroll = ScrollController();

  AppController get c => widget.controller;
  ProjectRecord get project => widget.project;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _start({required bool deliver}) {
    try {
      final record = c.build(
        project,
        profile: project.profile(_profile),
        targets: deliver ? _targets : <String>{},
      );
      setState(() => _viewedBuildId = record.buildId);
    } on Object catch (e) {
      showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = c.engine.activeFor(project.id);
    final viewed = _viewedBuildId != null ? c.engine.byId(_viewedBuildId!) : null;
    final shown = viewed ?? active ?? c.engine.lastFor(project.id);
    final profileName = project.profile(_profile)?.name;
    final devices = c.devices;
    final targetsLabel = _targets == null
        ? (project.targets.isEmpty ? tr('wszystkie telefony') : tr('telefony z opcji projektu'))
        : (_targets!.isEmpty ? tr('żaden telefon') : tr('{0} wybrane', [_targets!.length]));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: profileName,
                hint: Text(tr('Wariant')),
                items: [
                  for (final p in project.profiles) DropdownMenuItem(value: p.name, child: Text(tr('Wariant: {0}', [p.name]))),
                ],
                onChanged: (v) => setState(() => _profile = v),
              ),
              FilledButton.icon(
                onPressed: c.paused ? null : () => _start(deliver: true),
                icon: const Icon(Icons.send_to_mobile),
                label: Text(tr('Zbuduj i wyślij na telefon')),
              ),
              OutlinedButton.icon(
                onPressed: c.paused ? null : () => _start(deliver: false),
                icon: const Icon(Icons.build),
                label: Text(tr('Tylko zbuduj')),
              ),
              if (active != null)
                TextButton.icon(
                  onPressed: () => c.cancel(active),
                  icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                  label: Text(tr('Anuluj')),
                ),
              PopupMenuButton<String>(
                tooltip: tr('Na które telefony wysłać'),
                onSelected: (id) => setState(() {
                  if (id == '*project') {
                    _targets = null;
                  } else {
                    final set = {...?_targets};
                    set.contains(id) ? set.remove(id) : set.add(id);
                    _targets = set;
                  }
                }),
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(value: '*project', checked: _targets == null, child: Text(tr('Jak w opcjach projektu'))),
                  const PopupMenuDivider(),
                  for (final d in devices)
                    CheckedPopupMenuItem(
                      value: d.deviceId,
                      checked: _targets?.contains(d.deviceId) ?? project.deliversTo(d.deviceId),
                      child: Text('${d.displayName}${c.isOnline(d.deviceId) ? tr('  ● online') : ''}'),
                    ),
                ],
                child: Chip(avatar: const Icon(Icons.smartphone, size: 18), label: Text(tr('Wyślij na: {0}', [targetsLabel]))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (project.changesPending || project.agentNote != null) _AgentNote(project: project),
          if (shown != null) _BuildHeader(record: shown),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _LogView(lines: shown == null ? const [] : c.buildLog(shown.buildId), scroll: _scroll)),
                const SizedBox(width: 12),
                SizedBox(width: 280, child: _History(controller: c, project: project, onOpen: (id) => setState(() => _viewedBuildId = id), selectedId: shown?.buildId)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ostatni sygnał agenta AI (tekst niezaufany — tylko wyświetlany).
class _AgentNote extends StatelessWidget {
  const _AgentNote({required this.project});
  final ProjectRecord project;

  @override
  Widget build(BuildContext context) {
    final pending = project.changesPending;
    final at = project.agentNoteAt ?? project.changesAt;
    return Card(
      color: pending ? Colors.blue.withValues(alpha: 0.08) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(pending ? Icons.fiber_new : Icons.smart_toy_outlined, color: pending ? Colors.blue : null),
        title: Text(pending ? tr('Agent AI zgłosił zmiany, których nie ma jeszcze w instalce') : tr('Ostatnia notatka agenta AI')),
        subtitle: Text([
          if (project.agentNote != null) '„${project.agentNote}”',
          if (at != null) _time(at),
        ].join('  ·  ')),
      ),
    );
  }
}

class _BuildHeader extends StatelessWidget {
  const _BuildHeader({required this.record});
  final BuildRecord record;

  @override
  Widget build(BuildContext context) {
    final phase = record.phase;
    final label = switch (phase) {
      BuildPhase.QUEUED => tr('W kolejce'),
      BuildPhase.PREPARE => tr('Przygotowanie'),
      BuildPhase.BUILDING => tr('Budowanie'),
      BuildPhase.PACKAGING => tr('Pakowanie instalki'),
      BuildPhase.DONE => record.deliveredTo.isEmpty ? tr('Gotowe') : tr('Gotowe — wysłano na {0} tel.', [record.deliveredTo.length]),
      BuildPhase.FAILED => tr('Błąd'),
      BuildPhase.CANCELLED => tr('Anulowano'),
      _ => phase.name,
    };
    return Row(
      children: [
        phaseIcon(phase),
        const SizedBox(width: 8),
        Text('$label · ${record.profile.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 16),
        if (!record.isFinished) Expanded(child: LinearProgressIndicator(value: record.started ? record.progress / 100 : null)),
        if (record.isFinished) const Spacer(),
        Text(_time(record.startedAt), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _LogView extends StatefulWidget {
  const _LogView({required this.lines, required this.scroll});
  final List<String> lines;
  final ScrollController scroll;

  @override
  State<_LogView> createState() => _LogViewState();
}

class _LogViewState extends State<_LogView> {
  @override
  void didUpdateWidget(covariant _LogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Przewijamy na dół tylko, gdy użytkownik już był na dole (nie przeszkadzamy w czytaniu).
    final s = widget.scroll;
    final atBottom = !s.hasClients || s.position.pixels >= s.position.maxScrollExtent - 40;
    if (atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (s.hasClients) s.jumpTo(s.position.maxScrollExtent);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111418), borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(8),
      child: widget.lines.isEmpty
          ? Center(child: Text(tr('Brak logu — zbuduj projekt.'), style: TextStyle(color: Colors.white54)))
          : SelectionArea(
              child: ListView.builder(
                controller: widget.scroll,
                itemCount: widget.lines.length,
                itemBuilder: (_, i) {
                  final line = widget.lines[i];
                  return Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: line.startsWith('==>') ? Colors.lightBlueAccent : const Color(0xFFB8F5B8),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller, required this.project, required this.onOpen, this.selectedId});
  final AppController controller;
  final ProjectRecord project;
  final void Function(String buildId) onOpen;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final entries = controller.history(project.id);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: EdgeInsets.all(12), child: Text(tr('Historia'), style: TextStyle(fontWeight: FontWeight.w600))),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(tr('Jeszcze nic nie zbudowano.')))
                : ListView(
                    children: [
                      for (final e in entries)
                        ListTile(
                          dense: true,
                          selected: e.buildId == selectedId,
                          leading: phaseIcon(BuildPhase.values.where((p) => p.name == e.phase).firstOrNull),
                          title: Text('${e.profile} · ${_time(e.startedAt)}'),
                          subtitle: Text(_requester(controller, e.requester) +
                              (e.sizeBytes != null ? tr(' · {0} MB', [(e.sizeBytes! / 1048576).toStringAsFixed(1)]) : '')),
                          onTap: () => onOpen(e.buildId),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _requester(AppController c, String requester) => switch (requester) {
      desktopRequester => tr('z komputera'),
      localRequester => tr('rt b (terminal)'),
      agentRequester => tr('sygnał agenta AI'),
      _ => 'z telefonu ${c.devices.where((d) => d.deviceId == requester).firstOrNull?.displayName ?? ''}'.trim(),
    };

String _time(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final l = t.toLocal();
  return '${two(l.day)}.${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
}
