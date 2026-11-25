import 'package:flutter/material.dart';
import 'package:remotetester_host/preview/preview_recipe.dart';
import 'package:remotetester_host/store/project_store.dart';

import '../app_controller.dart';
import 'widgets.dart';
import '../i18n.dart';

class OptionsTab extends StatefulWidget {
  const OptionsTab({super.key, required this.controller, required this.project});
  final AppController controller;
  final ProjectRecord project;

  @override
  State<OptionsTab> createState() => _OptionsTabState();
}

class _OptionsTabState extends State<OptionsTab> {
  late final _name = TextEditingController(text: widget.project.name);
  late InstallPolicy _install = widget.project.install;
  late bool _launch = widget.project.launch;
  late bool _allPhones = widget.project.targets.isEmpty;
  late final Set<String> _targets = {...widget.project.targets}..remove(noPhonesTarget);
  late bool _phoneTrigger = widget.project.phoneTrigger;
  late bool _localTrigger = widget.project.localTrigger;
  late bool _agentBuild = widget.project.agentBuild;
  late bool _agentPush = widget.project.agentPush;
  late bool _preview = widget.project.preview;
  late final _previewCmd = TextEditingController(text: widget.project.previewCommand ?? '');
  late final PreviewRecipe? _detected = detectPreviewRecipe(widget.project.directory);
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    _previewCmd.dispose();
    super.dispose();
  }

  /// Opcje mogą zmienić się z telefonu — bez niezapisanych zmian pokazujemy aktualne.
  @override
  void didUpdateWidget(OptionsTab old) {
    super.didUpdateWidget(old);
    if (_dirty) return;
    final p = widget.project;
    if (_name.text != p.name) _name.text = p.name;
    _install = p.install;
    _launch = p.launch;
    _allPhones = p.targets.isEmpty;
    _targets
      ..clear()
      ..addAll(p.targets)
      ..remove(noPhonesTarget);
    _phoneTrigger = p.phoneTrigger;
    _localTrigger = p.localTrigger;
    _agentBuild = p.agentBuild;
    _agentPush = p.agentPush;
    _preview = p.preview;
    if (_previewCmd.text != (p.previewCommand ?? '')) _previewCmd.text = p.previewCommand ?? '';
  }

  void _set(VoidCallback change) => setState(() {
        change();
        _dirty = true;
      });

  void _save() {
    final p = widget.project
      ..name = _name.text.trim()
      ..install = _install
      ..launch = _launch
      ..targets = _allPhones ? [] : (_targets.isEmpty ? [noPhonesTarget] : _targets.toList())
      ..phoneTrigger = _phoneTrigger
      ..localTrigger = _localTrigger
      ..agentBuild = _agentBuild
      ..agentPush = _agentPush
      ..preview = _preview
      ..previewCommand = _previewCmd.text.trim().isEmpty ? null : _previewCmd.text.trim();
    try {
      widget.controller.saveOptions(p);
      setState(() => _dirty = false);
      showInfo(context, tr('Zapisano opcje projektu.'));
    } on Object catch (e) {
      showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = widget.controller.devices;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _name,
                decoration: InputDecoration(labelText: tr('Nazwa projektu (widoczna na telefonach)')),
                onChanged: (_) => _set(() {}),
              ),
            ),
            SizedBox(width: 16),
            FilledButton.icon(onPressed: _dirty ? _save : null, icon: Icon(Icons.save), label: Text(tr('Zapisz'))),
          ],
        ),
        SectionTitle(tr('Po zbudowaniu')),
        SegmentedButton<InstallPolicy>(
          segments: [
            ButtonSegment(value: InstallPolicy.auto, icon: Icon(Icons.install_mobile), label: Text(tr('Instaluj automatycznie'))),
            ButtonSegment(value: InstallPolicy.ask, icon: Icon(Icons.help_outline), label: Text(tr('Pytaj na telefonie'))),
            ButtonSegment(value: InstallPolicy.off, icon: Icon(Icons.block), label: Text(tr('Nie wysyłaj'))),
          ],
          selected: {_install},
          onSelectionChanged: (s) => _set(() => _install = s.first),
        ),
        SwitchListTile(
          title: Text(tr('Uruchom aplikację po instalacji')),
          subtitle: Text(tr('Telefon otworzy nową wersję od razu po zainstalowaniu.')),
          value: _launch,
          onChanged: (v) => _set(() => _launch = v),
        ),
        SectionTitle(tr('Telefony docelowe')),
        RadioGroup<bool>(
          groupValue: _allPhones,
          onChanged: (v) => _set(() => _allPhones = v ?? true),
          child: Column(children: [
            RadioListTile<bool>(title: Text(tr('Wszystkie sparowane telefony')), value: true),
            RadioListTile<bool>(title: Text(tr('Tylko wybrane')), value: false),
          ]),
        ),
        if (!_allPhones)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: devices.isEmpty
                ? Text(tr('Brak sparowanych telefonów (zakładka Telefony).'))
                : Wrap(
                    spacing: 8,
                    children: [
                      for (final d in devices)
                        FilterChip(
                          label: Text(d.displayName),
                          selected: _targets.contains(d.deviceId),
                          onSelected: (v) => _set(() => v ? _targets.add(d.deviceId) : _targets.remove(d.deviceId)),
                        ),
                    ],
                  ),
          ),
        SectionTitle(tr('Kto może zlecić build')),
        SwitchListTile(
          title: Text(tr('Telefony (pilot)')),
          subtitle: Text(tr('Przycisk „Zbuduj i zainstaluj” w aplikacji na telefonie. Tę opcję zmienia się tylko tutaj; pozostałe opcje można zmieniać także z telefonu.')),
          value: _phoneTrigger,
          onChanged: (v) => _set(() => _phoneTrigger = v),
        ),
        SwitchListTile(
          title: Text(tr('Sygnał agenta AI uruchamia build i wysyłkę')),
          subtitle: Text(tr('Agent kończy pracę poleceniem „rt sg --build” (albo plikiem .remoteapptester-signal). To tylko sygnał: agent nie ma dostępu do RemoteAppTestera, a build idzie zatwierdzonymi komendami. Wyłączone = sygnał tylko oznacza projekt jako „nowe zmiany”.')),
          value: _agentBuild,
          onChanged: (v) => _set(() => _agentBuild = v),
        ),
        SwitchListTile(
          title: Text(tr('Agent AI może wysłać własną instalkę')),
          subtitle: Text(tr('Agent, który sam zbudował APK, wysyła go poleceniem „rt push plik.apk”. Przyjmowane są tylko pliki .apk z folderu projektu; instalacja na telefonie według opcji powyżej.')),
          value: _agentPush,
          onChanged: (v) => _set(() => _agentPush = v),
        ),
        SwitchListTile(
          title: Text(tr('Terminal na tym komputerze (rt b)')),
          subtitle: Text(tr('Polecenie „rt b” w folderze projektu — korzysta z lokalnego tokenu RemoteAppTestera, więc daje więcej niż sam sygnał. Dla agentów AI wystarczy „rt sg”.')),
          value: _localTrigger,
          onChanged: (v) => _set(() => _localTrigger = v),
        ),
        SectionTitle(tr('Podgląd aplikacji web na telefonie')),
        SwitchListTile(
          title: Text(tr('Telefon może uruchomić podgląd strony')),
          subtitle: Text(tr('RemoteAppTester uruchamia serwer deweloperski na tym komputerze (tylko 127.0.0.1) i udostępnia go sparowanym telefonom przez Tailscale, z jednorazowym tokenem. Zmiany od agenta AI odświeżają stronę na telefonie.')),
          value: _preview,
          onChanged: (v) => _set(() => _preview = v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _previewCmd,
            enabled: _preview,
            decoration: InputDecoration(
              labelText: tr('Komenda podglądu ({port} = port, puste = automatycznie)'),
              helperText: _detected == null
                  ? tr('Nie rozpoznano aplikacji web — wpisz komendę, np. npm run dev -- --port {port}')
                  : tr('Automatycznie ({0}): {1}', [_detected.kind, _detected.command]),
              helperMaxLines: 3,
            ),
            onChanged: (_) => _set(() {}),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }
}
