import 'dart:io';

import 'package:flutter/material.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/project/templates.dart';
import 'package:remotetester_host/store/project_store.dart';

import '../app_controller.dart';
import 'widgets.dart';
import '../i18n.dart';

/// Edytowalna kopia wariantu (kontrolery tekstu).
class _ProfileDraft {
  _ProfileDraft(BuildProfile p)
      : name = TextEditingController(text: p.name),
        artifact = TextEditingController(text: p.artifact),
        steps = [for (final s in p.steps) _StepDraft(s)];

  final TextEditingController name;
  final TextEditingController artifact;
  final List<_StepDraft> steps;

  BuildProfile toProfile() => BuildProfile(
        name: name.text.trim(),
        steps: [for (final s in steps) BuildStep(s.name.text.trim(), s.run.text.trim())],
        artifact: artifact.text.trim(),
      );
}

class _StepDraft {
  _StepDraft(BuildStep s)
      : name = TextEditingController(text: s.name),
        run = TextEditingController(text: s.run);
  final TextEditingController name;
  final TextEditingController run;
}

class CommandsTab extends StatefulWidget {
  const CommandsTab({super.key, required this.controller, required this.project});
  final AppController controller;
  final ProjectRecord project;

  @override
  State<CommandsTab> createState() => _CommandsTabState();
}

class _CommandsTabState extends State<CommandsTab> {
  late List<_ProfileDraft> _drafts;
  String? _default;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load(widget.project.profiles);
  }

  void _load(List<BuildProfile> profiles) {
    _drafts = [for (final p in profiles) _ProfileDraft(p)];
    _default = widget.project.profile()?.name ?? profiles.firstOrNull?.name;
    _dirty = false;
  }

  void _changed() => setState(() => _dirty = true);

  void _save() {
    final profiles = [for (final d in _drafts) d.toProfile()];
    try {
      validateProfiles(profiles);
      final def = profiles.any((p) => p.name == _default) ? _default : profiles.first.name;
      widget.controller.saveProfiles(widget.project, profiles, defaultProfile: def);
      setState(() => _dirty = false);
      showInfo(context, tr('Zapisano komendy w bazie RemoteAppTester i odświeżono REMOTEAPPTESTER.md.'));
    } on Object catch (e) {
      showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.controller.guides[widget.project.id];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GuidePanel(controller: widget.controller, project: widget.project, state: guide, onImported: () {
          setState(() => _load(widget.controller.store.byId(widget.project.id)!.profiles));
        }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(tr('Warianty budowania'), style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () async {
                if (await confirm(context, tr('Wpisać komendy wykryte automatycznie?'),
                    tr('Obecne komendy w edytorze zostaną zastąpione szablonem dla typu „{0}”. Zmiana zapisze się dopiero po „Zapisz”.', [tr(kindName(widget.project.kind))]))) {
                  setState(() {
                    _drafts = [for (final p in templateProfiles(widget.project.kind)) _ProfileDraft(p)];
                    _default = _drafts.first.name.text;
                    _dirty = true;
                  });
                }
              },
              icon: const Icon(Icons.auto_fix_high),
              label: Text(tr('Wykryj ponownie')),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                _drafts.add(_ProfileDraft(BuildProfile(
                    name: tr('Wariant {0}', [_drafts.length + 1]),
                    steps: [BuildStep(tr('Budowanie'), '')],
                    artifact: _drafts.firstOrNull?.artifact.text ?? 'build/**/*.apk')));
                _dirty = true;
              }),
              icon: const Icon(Icons.add),
              label: Text(tr('Dodaj wariant')),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: _dirty ? _save : null, icon: const Icon(Icons.save), label: Text(tr('Zapisz'))),
          ],
        ),
        Text(
          tr('Każdy krok to jedna linia polecenia cmd uruchamiana w folderze projektu. Komendy są zapisywane wyłącznie w zaszyfrowanej bazie RemoteAppTester; telefon może je tylko uruchomić.'),
          style: TextStyle(fontSize: 12),
        ),
        RadioGroup<String>(
          groupValue: _default,
          onChanged: (v) => setState(() {
            _default = v;
            _dirty = true;
          }),
          child: Column(children: [for (final (i, draft) in _drafts.indexed) _profileCard(i, draft)]),
        ),
      ],
    );
  }

  Widget _profileCard(int index, _ProfileDraft draft) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Radio<String>(value: draft.name.text),
                Text(tr('domyślny  ')),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: draft.name,
                    decoration: InputDecoration(labelText: tr('Nazwa wariantu'), isDense: true),
                    onChanged: (_) => _changed(),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: tr('Usuń wariant'),
                  onPressed: _drafts.length <= 1
                      ? null
                      : () => setState(() {
                            _drafts.removeAt(index);
                            _dirty = true;
                          }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            for (final (si, step) in draft.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text('${si + 1}.')),
                    SizedBox(
                      width: 200,
                      child: TextField(
                        controller: step.name,
                        decoration: InputDecoration(labelText: tr('Krok'), isDense: true),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: step.run,
                        style: const TextStyle(fontFamily: 'Consolas'),
                        decoration: InputDecoration(labelText: tr('Komenda (cmd)'), isDense: true),
                        onChanged: (_) => _changed(),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('W górę'),
                      onPressed: si == 0
                          ? null
                          : () => setState(() {
                                draft.steps.insert(si - 1, draft.steps.removeAt(si));
                                _dirty = true;
                              }),
                      icon: const Icon(Icons.arrow_upward, size: 18),
                    ),
                    IconButton(
                      tooltip: tr('Usuń krok'),
                      onPressed: draft.steps.length <= 1
                          ? null
                          : () => setState(() {
                                draft.steps.removeAt(si);
                                _dirty = true;
                              }),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  draft.steps.add(_StepDraft(BuildStep(tr('Krok'), '')));
                  _dirty = true;
                }),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Dodaj krok')),
              ),
            ),
            TextField(
              controller: draft.artifact,
              style: const TextStyle(fontFamily: 'Consolas'),
              decoration: InputDecoration(
                labelText: tr('Gotowa instalka (.apk) — ścieżka względem folderu, * i ** dozwolone'),
                isDense: true,
              ),
              onChanged: (_) => _changed(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.controller, required this.project, required this.state, required this.onImported});
  final AppController controller;
  final ProjectRecord project;
  final GuideState? state;
  final VoidCallback onImported;

  @override
  Widget build(BuildContext context) {
    final status = state?.status ?? GuideStatus.missing;
    final (color, icon, text) = switch (status) {
      GuideStatus.inSync => (Colors.green, Icons.check_circle_outline,
          tr('REMOTEAPPTESTER.md jest aktualny — agenci AI w tym folderze widzą bieżące komendy.')),
      GuideStatus.proposal => (Colors.amber, Icons.auto_awesome,
          tr('Agent AI (albo ktoś inny) zaproponował nowe komendy w REMOTEAPPTESTER.md. Nie działają, dopóki ich nie zatwierdzisz.')),
      GuideStatus.missing => (Colors.grey, Icons.description_outlined,
          tr('Brak REMOTEAPPTESTER.md — agenci AI nie wiedzą, jak budować ten projekt dla RemoteAppTester.')),
      GuideStatus.invalid => (Colors.red, Icons.error_outline, tr('Blok komend w REMOTEAPPTESTER.md jest niepoprawny: {0}', [state?.error])),
    };
    return Card(
      color: color.withValues(alpha: 0.12),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            if (status == GuideStatus.proposal) ...[
              TextButton(onPressed: () => controller.dismissGuide(project), child: Text(tr('Odrzuć'))),
              FilledButton(onPressed: () => _review(context), child: Text(tr('Przejrzyj…'))),
            ],
            if (status != GuideStatus.proposal)
              TextButton(
                onPressed: () {
                  controller.writeGuide(project);
                  showInfo(context, tr('Zapisano REMOTEAPPTESTER.md z aktualnymi komendami.'));
                },
                child: Text(status == GuideStatus.missing ? tr('Utwórz') : tr('Odśwież z bazy')),
              ),
            if (status != GuideStatus.missing)
              TextButton(
                onPressed: () => Process.start('notepad.exe', [agentGuideFile(project.directory).path]),
                child: Text(tr('Otwórz')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context) async {
    final proposed = state!.profiles;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Propozycja komend z REMOTEAPPTESTER.md')),
        content: SizedBox(
          width: 900,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ProfilesPreview(title: tr('Obecnie (baza)'), profiles: project.profiles)),
              const VerticalDivider(),
              Expanded(child: _ProfilesPreview(title: tr('Propozycja'), profiles: proposed)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Anuluj'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Zatwierdź i zapisz'))),
        ],
      ),
    );
    if (ok == true) {
      controller.importGuide(project);
      onImported();
      if (context.mounted) showInfo(context, tr('Zapisano nowe komendy w bazie RemoteAppTester.'));
    }
  }
}

class _ProfilesPreview extends StatelessWidget {
  const _ProfilesPreview({required this.title, required this.profiles});
  final String title;
  final List<BuildProfile> profiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SelectableText(
          [
            for (final p in profiles)
              '[${p.name}]\n${p.steps.map((s) => '  ${s.name}: ${s.run}').join('\n')}\n  instalka: ${p.artifact}',
          ].join('\n\n'),
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
        ),
      ],
    );
  }
}
