import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:remotetester_host/generated/remote_tester.pb.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/templates.dart';
import 'package:remotetester_host/store/project_store.dart';

import '../app_controller.dart';
import 'project_detail.dart';
import 'widgets.dart';
import '../i18n.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected;
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(tr('Projekty'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                    _AddMenu(controller: controller),
                  ],
                ),
              ),
              Expanded(
                child: controller.projects.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(tr('Brak projektów.\n\nDodaj folder z aplikacją przyciskiem „+”. RemoteAppTester wykryje technologię, wpisze komendy budowania i utworzy w folderze REMOTEAPPTESTER.md dla agentów AI.')),
                      )
                    : ListView(
                        children: [
                          for (final project in controller.projects) _ProjectTile(controller: controller, project: project),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? Center(child: Text(tr('Wybierz albo dodaj projekt.')))
              : ProjectDetail(key: ValueKey(selected.id), controller: controller, project: selected),
        ),
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.controller, required this.project});
  final AppController controller;
  final ProjectRecord project;

  @override
  Widget build(BuildContext context) {
    final active = controller.engine.activeFor(project.id);
    final last = controller.engine.lastFor(project.id);
    final proposal = controller.guides[project.id]?.status == GuideStatus.proposal;
    final Widget status;
    if (active != null) {
      status = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 3, value: active.started ? (active.progress / 100).clamp(0.02, 1.0) : null),
      );
    } else {
      status = phaseIcon(last?.phase);
    }
    return ListTile(
      selected: controller.selectedId == project.id,
      leading: status,
      title: Text(project.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        active != null
            ? (active.started ? tr('Buduje: {0}', [active.profile.name]) : tr('W kolejce'))
            : '${tr(kindName(project.kind))} · ${project.profile()?.name ?? '—'}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (project.changesPending)
            Tooltip(
              message: 'Agent AI zgłosił zmiany — warto przebudować${project.agentNote == null ? '' : ':\n${project.agentNote}'}',
              child: const Icon(Icons.fiber_new, color: Colors.blue),
            ),
          if (proposal)
            Tooltip(message: tr('Agent zaproponował nowe komendy'), child: Icon(Icons.auto_awesome, color: Colors.amber)),
        ],
      ),
      onTap: () => controller.select(project.id),
    );
  }
}

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tr('Dodaj projekt'),
      icon: Icon(Icons.add_circle, size: 30),
      onSelected: (value) => switch (value) {
        'existing' => _addExisting(context),
        'empty' => _createNew(context, flutter: false),
        _ => _createNew(context, flutter: true),
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'existing', child: ListTile(leading: Icon(Icons.folder_open), title: Text(tr('Dodaj istniejący folder')))),
        PopupMenuItem(value: 'empty', child: ListTile(leading: Icon(Icons.create_new_folder), title: Text(tr('Nowy pusty folder')))),
        PopupMenuItem(value: 'flutter', child: ListTile(leading: Icon(Icons.flutter_dash), title: Text(tr('Nowy projekt Flutter')))),
      ],
    );
  }

  Future<void> _addExisting(BuildContext context) async {
    final path = await getDirectoryPath(confirmButtonText: tr('Przypisz do RemoteAppTester'));
    if (path == null || !context.mounted) return;
    _guarded(context, () => controller.addFolder(Directory(path)));
  }

  Future<void> _createNew(BuildContext context, {required bool flutter}) async {
    final root = controller.runtime.config.projectsRoot.path;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _NewFolderDialog(root: root, flutter: flutter),
    );
    if (result == null || !context.mounted) return;
    final (parent, name) = result;
    final dir = Directory(p.join(parent, name));
    if (dir.existsSync()) {
      showError(context, tr('Folder już istnieje: {0}', [dir.path]));
      return;
    }
    if (!flutter) {
      dir.createSync(recursive: true);
      _guarded(context, () => controller.addFolder(dir));
      return;
    }
    // `flutter create` — nazwa pakietu Dart: małe litery, cyfry, podkreślenia.
    final package = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final ok = await runWithProgress(
      context,
      tr('Tworzenie projektu Flutter…'),
      () => Process.run('flutter', ['create', '--project-name', package, '--platforms', 'android', dir.path],
          runInShell: true),
    );
    if (ok == null || !context.mounted) return;
    if (ok.exitCode != 0) {
      showError(context, tr('flutter create nie powiódł się:\n{0}\n{1}', [ok.stderr, ok.stdout]));
      return;
    }
    _guarded(context, () => controller.addFolder(dir, name: name));
  }

  void _guarded(BuildContext context, ProjectRecord Function() action) {
    try {
      final record = action();
      showInfo(context, tr('Przypisano „{0}” ({1}). Komendy wpisane automatycznie — sprawdź je w zakładce „Komendy”.', [record.name, tr(kindName(record.kind))]));
    } on Object catch (e) {
      showError(context, e.toString());
    }
  }
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({required this.root, required this.flutter});
  final String root;
  final bool flutter;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _name = TextEditingController();
  late String _parent = widget.root;

  @override
  Widget build(BuildContext context) {
    final valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _.-]{0,63}$').hasMatch(_name.text.trim());
    return AlertDialog(
      title: Text(widget.flutter ? tr('Nowy projekt Flutter') : tr('Nowy folder projektu')),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Nazwa folderu')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('W: $_parent', overflow: TextOverflow.ellipsis)),
                TextButton(
                  onPressed: () async {
                    final path = await getDirectoryPath(initialDirectory: _parent);
                    if (path != null) setState(() => _parent = path);
                  },
                  child: Text(tr('Zmień…')),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Anuluj'))),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (_parent, _name.text.trim())) : null,
          child: Text(tr('Utwórz')),
        ),
      ],
    );
  }
}

Widget phaseIcon(BuildPhase? phase) => switch (phase) {
      BuildPhase.DONE => const Icon(Icons.check_circle, color: Colors.green),
      BuildPhase.FAILED => const Icon(Icons.error, color: Colors.red),
      BuildPhase.CANCELLED => const Icon(Icons.cancel, color: Colors.grey),
      _ => const Icon(Icons.folder_outlined),
    };
