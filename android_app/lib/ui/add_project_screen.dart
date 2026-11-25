import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;

import '../generated/remote_tester.pbgrpc.dart';
import '../net/agent_client.dart';
import '../net/friendly_errors.dart';
import '../i18n.dart';
import 'project_kind_ui.dart';

/// Nowy projekt na połączonym komputerze (Windows albo Linux): nowy projekt Flutter,
/// pusty folder albo wolny folder z katalogu projektów. Telefon podaje wyłącznie
/// nazwę folderu — komputer tworzy go w swoim katalogu projektów i sam wpisuje komendy.
class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key, required this.client});
  final AgentClient client;

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  static final _validName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,63}$');

  late final Future<FolderList> _folders = widget.client.listAvailableFolders();
  ProjectTemplate _template = ProjectTemplate.FLUTTER_APP;
  final _name = TextEditingController();
  String? _existing;
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _folderName => _template == ProjectTemplate.EXISTING_FOLDER ? (_existing ?? '') : _name.text.trim();

  bool get _ready => _template == ProjectTemplate.EXISTING_FOLDER
      ? _existing != null
      : _validName.hasMatch(_folderName) && !_folderName.endsWith('.');

  Future<void> _create() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final project = await widget.client.createProject(CreateProjectRequest(folderName: _folderName, template: _template));
      if (mounted) Navigator.of(context).pop(project);
    } on GrpcError catch (e) {
      final own = const {StatusCode.invalidArgument, StatusCode.alreadyExists, StatusCode.permissionDenied}.contains(e.code);
      setState(() => _error = own ? (e.message ?? '') : friendlyErrorMessage(e));
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Nowy projekt'))),
      body: FutureBuilder<FolderList>(
        future: _folders,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(padding: const EdgeInsets.all(24), child: Text(friendlyErrorMessage(snapshot.error!)));
          }
          final list = snapshot.data!;
          if (!list.addingAllowed) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(tr('Komputer nie pozwala dodawać projektów z telefonu. Włączysz to w pliku host-config.yaml: phone_add_projects: true.')),
            );
          }
          return _form(context, list.folders);
        },
      ),
    );
  }

  Widget _form(BuildContext context, List<AvailableFolder> folders) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<ProjectTemplate>(
          segments: [
            ButtonSegment(value: ProjectTemplate.FLUTTER_APP, icon: const Icon(Icons.flutter_dash), label: Text(tr('Flutter'))),
            ButtonSegment(value: ProjectTemplate.EMPTY_FOLDER, icon: const Icon(Icons.create_new_folder), label: Text(tr('Pusty'))),
            ButtonSegment(value: ProjectTemplate.EXISTING_FOLDER, icon: const Icon(Icons.folder_open), label: Text(tr('Istniejący'))),
          ],
          selected: {_template},
          onSelectionChanged: _working ? null : (s) => setState(() => _template = s.first),
        ),
        const SizedBox(height: 16),
        if (_template == ProjectTemplate.EXISTING_FOLDER) ..._existingFolders(folders) else ..._newFolder(),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        FilledButton.icon(
          onPressed: _ready && !_working ? _create : null,
          icon: _working
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add),
          label: Text(_template == ProjectTemplate.EXISTING_FOLDER ? tr('Przypisz folder') : tr('Utwórz projekt')),
        ),
        const SizedBox(height: 12),
        Text(
          tr('Komputer tworzy folder w swoim katalogu projektów i sam wpisuje komendy budowania. Telefon podaje tylko nazwę.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  List<Widget> _newFolder() => [
        TextField(
          controller: _name,
          enabled: !_working,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('Nazwa folderu'),
            helperText: tr('Litery, cyfry, spacje, _ . - (do 64 znaków)'),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_template == ProjectTemplate.FLUTTER_APP)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(tr('Nowa aplikacja Flutter (flutter create, Android). Pierwszy build trwa dłużej.')),
          ),
      ];

  List<Widget> _existingFolders(List<AvailableFolder> folders) {
    if (folders.isEmpty) {
      return [Text(tr('W katalogu projektów komputera nie ma wolnych folderów.'))];
    }
    return [
      Text(tr('Wolne foldery w katalogu projektów komputera:')),
      RadioGroup<String>(
        groupValue: _existing,
        onChanged: (v) => _working ? null : setState(() => _existing = v),
        child: Column(
          children: [
            for (final f in folders)
              RadioListTile<String>(
                value: f.name,
                title: Text(f.name),
                subtitle: Text(projectKindLabel(Project(kind: f.kind))),
                secondary: Icon(projectKindIcon(Project(kind: f.kind))),
              ),
          ],
        ),
      ),
    ];
  }
}
