import 'dart:async';

import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import '../delivery/delivery_service.dart';
import '../generated/remote_tester.pbgrpc.dart';
import '../install/apk_installer.dart';
import '../net/agent_client.dart';
import '../security/sensitive_action_gate.dart';
import '../transfer/delta_downloader.dart';
import '../i18n.dart';
import '../settings/sounds.dart';
import 'delivery_text.dart';

/// Opóźnienia między kolejnymi próbami wznowienia po zerwaniu połączenia —
/// krótkie zerwania (LTE↔WiFi) łapiemy szybko, ale nie zalewamy agenta
/// próbami w pętli bez przerwy (docs/IMPLEMENTATION_PLAN.md:
/// "krótkie zerwania nie przerywają builda na Windows").
const _reconnectDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 8),
];

/// Start builda + live log/progress — docs/architektura-remote-build.md,
/// sekcja 5. Po `DONE`: pobranie artefaktu z weryfikacją SHA-256 i
/// instalacja przez `PackageInstaller.Session`, bez roota i bez ADB.
class BuildLogScreen extends StatefulWidget {
  const BuildLogScreen({
    super.key,
    required this.client,
    required this.project,
    this.autoInstall = true,
    this.launchAfterInstall = false,
    this.profile = '',
    this.watchBuildId,
    this.installBuildId,
    this.deliveries,
  });

  /// Wspólna kolejka instalacji (dostawy w tle i ręczne) — dzięki niej ta sama
  /// wersja nie jest pobierana dwa razy. `null` = własne pobieranie (testy).
  final DeliveryService? deliveries;

  final AgentClient client;
  final Project project;

  /// Wariant budowania (nazwa z listy hosta); puste = domyślny.
  final String profile;

  /// Podgląd builda zleconego gdzie indziej (komputer, `rt b`) — bez nowego zlecenia.
  final String? watchBuildId;

  /// Tylko pobierz i zainstaluj gotową wersję (np. „Zainstaluj ostatnią”).
  final String? installBuildId;

  /// `true` — po `DONE` od razu pobierz i zainstaluj; `false` — tylko zbuduj.
  final bool autoInstall;
  final bool launchAfterInstall;

  @override
  State<BuildLogScreen> createState() => _BuildLogScreenState();
}

enum _InstallStage { idle, downloading, verifying, installing, done, failed }

class _BuildLogScreenState extends State<BuildLogScreen> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();
  BuildPhase _phase = BuildPhase.QUEUED;
  int _progress = 0;
  String? _buildId;
  String? _error;

  _InstallStage _installStage = _InstallStage.idle;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  bool _awaitingConfirmation = false;
  String? _installError;

  final _authGate = SensitiveActionGate();
  late final _installer = ApkInstaller(authGate: _authGate);

  bool _reconnecting = false;
  StreamSubscription<BuildEvent>? _buildSub;

  @override
  void initState() {
    super.initState();
    final install = widget.installBuildId;
    final watch = widget.watchBuildId;
    if (install != null) {
      _buildId = install;
      _phase = BuildPhase.DONE;
      _progress = 100;
      _lines.add(tr('Gotowa wersja z komputera — pobieranie i instalacja.'));
      // Po pierwszej klatce — setState w initState nie odświeżyłby ekranu.
      WidgetsBinding.instance.addPostFrameCallback((_) => _downloadAndInstall());
    } else if (watch != null) {
      _buildId = watch;
      unawaited(_reconnect(watch));
    } else {
      _authenticateThenStart();
    }
  }

  @override
  void dispose() {
    _buildSub?.cancel();
    super.dispose();
  }

  Future<void> _authenticateThenStart() async {
    try {
      await _authGate.requireAuth(
        tr('Potwierdź uruchomienie builda: {0}', [widget.project.displayName]),
      );
    } on SensitiveActionAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      return;
    }
    if (!mounted) return;
    _listen();
  }

  void _listen() {
    final stream = widget.client.startBuild(
      BuildRequest(projectId: widget.project.projectId, profile: widget.profile),
    );
    _buildSub = stream.listen(_handleEvent, onError: _handleStreamError);
  }

  void _handleEvent(BuildEvent event) {
    final wasDone = _phase == BuildPhase.DONE;
    final wasFailed = _phase == BuildPhase.FAILED;
    setState(() {
      _reconnecting = false;
      _error = null;
      _phase = event.phase;
      _buildId = event.buildId;
      if (event.progressPercent > 0) _progress = event.progressPercent;
      if (event.logLine.isNotEmpty) _lines.add(event.logLine);
      if (event.phase == BuildPhase.QUEUED && event.queuePosition > 0) {
        _lines.add(tr('W kolejce, pozycja: {0}', [event.queuePosition]));
      }
    });
    // Auto-start pobierania i instalacji zaraz po DONE — bez dodatkowego
    // tapnięcia (na prośbę użytkownika). Guard na `wasDone`, żeby nie
    // odpalić drugi raz, gdyby DONE przyszło więcej niż raz.
    if (event.phase == BuildPhase.DONE && !wasDone) unawaited(Sounds.play(SoundEvent.buildDone));
    if (event.phase == BuildPhase.FAILED && !wasFailed) unawaited(Sounds.play(SoundEvent.buildFailed));
    if (event.phase == BuildPhase.DONE && !wasDone && widget.autoInstall) {
      _downloadAndInstall();
    }
    _scrollToBottom();
  }

  /// Zerwanie streamu `StartBuild` (np. WiFi↔LTE) NIE musi oznaczać, że
  /// build na hoście też stanął — host trzyma jego stan niezależnie
  /// (`_ActiveBuild` w `host_agent_service.dart`). Jeśli mamy już
  /// `_buildId` i faza nie jest terminalna, próbujemy wznowić przez
  /// `GetBuildStatus` zamiast od razu pokazywać błąd — na TYM SAMYM,
  /// już uwierzytelnionym (TLS pinning + HMAC) [AgentClient], nigdy przez
  /// jakiś słabszy/inny kanał.
  void _handleStreamError(Object error) {
    final buildId = _buildId;
    if (buildId == null || _terminalPhases.contains(_phase)) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      return;
    }
    unawaited(_reconnect(buildId));
  }

  Future<void> _reconnect(String buildId) async {
    if (!mounted) return;
    setState(() {
      _reconnecting = true;
      _error = null;
    });

    for (final delay in _reconnectDelays) {
      await Future<void>.delayed(delay);
      if (!mounted) return;

      final firstEvent = Completer<void>();
      final stream = widget.client.getBuildStatus(BuildId(buildId: buildId));
      // GetBuildStatus odtwarza PEŁNĄ historię od nowa (bufor po stronie
      // agenta) — czyścimy lokalny log, żeby nie zdublować linii sprzed
      // zerwania połączenia.
      _lines.clear();
      _buildSub = stream.listen(
        (event) {
          if (!firstEvent.isCompleted) firstEvent.complete();
          _handleEvent(event);
        },
        onError: (Object e) {
          if (!firstEvent.isCompleted) {
            firstEvent.completeError(e);
          } else {
            // Zerwane ZNOWU w trakcie odtwarzania — kolejna runda prób.
            _handleStreamError(e);
          }
        },
        cancelOnError: false,
      );

      try {
        await firstEvent.future;
        return; // sukces — dalsze zdarzenia obsłuży już listener powyżej
      } on GrpcError catch (e) {
        // notFound/permissionDenied to NIE przejściowy problem sieciowy —
        // build zniknął (agent zrestartowany / zaczął się nowy) albo to w
        // ogóle nie nasz build. Dalsze próby nic by nie dały.
        if (e.code == StatusCode.notFound || e.code == StatusCode.permissionDenied) {
          if (!mounted) return;
          setState(() {
            _reconnecting = false;
            _error = tr('Nie udało się wznowić: {0}', [e.message]);
          });
          return;
        }
        // Inny błąd (unavailable, deadlineExceeded, ...) — prawdopodobnie
        // wciąż przejściowy, spróbuj po kolejnym opóźnieniu.
      } catch (_) {
        // jw. — traktuj jako przejściowe i spróbuj ponownie.
      }
    }

    if (!mounted) return;
    setState(() {
      _reconnecting = false;
      _error = tr('Nie udało się wznowić połączenia po zerwaniu. Sprawdź sieć i spróbuj ponownie.');
    });
  }

  static const _terminalPhases = {BuildPhase.DONE, BuildPhase.FAILED, BuildPhase.CANCELLED};

  bool get _canCancel => _buildId != null && !_terminalPhases.contains(_phase);

  Future<void> _cancelBuild() async {
    final buildId = _buildId;
    if (buildId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Anulować build?')),
        content: Text(tr('Trwający proces budowania zostanie zatrzymany na komputerze.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Nie'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Anuluj build'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final ack = await widget.client.cancelBuild(BuildId(buildId: buildId));
      if (!ack.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ack.message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Nie udało się anulować: {0}', [e]))),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _downloadAndInstall() async {
    final buildId = _buildId;
    if (buildId == null) return;
    final service = widget.deliveries;
    if (service != null) {
      await service.installBuild(
        projectId: widget.project.projectId,
        projectName: widget.project.displayName,
        buildId: buildId,
        launch: widget.launchAfterInstall,
      );
      return;
    }

    setState(() {
      _installStage = _InstallStage.downloading;
      _downloadedBytes = 0;
      _installError = null;
    });

    try {
      final file = await _installer.download(
        client: widget.client,
        buildId: buildId,
        projectId: widget.project.projectId,
        onProgress: (bytes, total) => setState(() {
          _downloadedBytes = bytes;
          _totalBytes = total;
        }),
      );

      setState(() => _installStage = _InstallStage.installing);
      await _installer.install(
        projectId: widget.project.projectId,
        projectName: widget.project.displayName,
        apk: file,
        confirmPackageChange: _confirmPackageNameChanged,
        launchAfterInstall: widget.launchAfterInstall,
        onNeedsConfirmation: () {
          if (mounted) setState(() => _awaitingConfirmation = true);
        },
      );
      if (!mounted) return;
      setState(() {
        _awaitingConfirmation = false;
        _installStage = _InstallStage.done;
      });
    } on InstallCancelledException {
      if (mounted) setState(() => _installStage = _InstallStage.idle);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _awaitingConfirmation = false;
        _installStage = _InstallStage.failed;
        _installError = e.toString();
      });
    }
  }

  Future<bool> _confirmPackageNameChanged(String previous, String current) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Nazwa pakietu się zmieniła')),
        content: Text(
          tr('Poprzednio dla tego projektu instalowano "{0}", a ten APK to "{1}". Kontynuować instalację?', [previous, current]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Anuluj'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Kontynuuj'))),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Build: {0}', [widget.project.displayName])),
        actions: [
          if (_canCancel)
            IconButton(
              onPressed: _cancelBuild,
              icon: const Icon(Icons.cancel),
              tooltip: tr('Anuluj build'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(_phase.name),
                const SizedBox(width: 12),
                Expanded(child: LinearProgressIndicator(value: _progress / 100)),
                const SizedBox(width: 12),
                Text('$_progress%'),
              ],
            ),
          ),
          if (_reconnecting)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text(tr('Zerwano połączenie — wznawianie...'), style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_phase == BuildPhase.DONE)
            widget.deliveries == null
                ? _buildInstallSection()
                : ListenableBuilder(listenable: widget.deliveries!, builder: (context, _) => _sharedInstallSection(widget.deliveries!)),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _lines.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  child: Text(
                    _lines[index],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stan instalacji tego builda we wspólnej kolejce.
  Widget _sharedInstallSection(DeliveryService service) {
    final status = service.statusFor(widget.project.projectId);
    final mine = status != null && status.delivery.buildId == _buildId ? status : null;
    final Widget child;
    if (mine == null || mine.stage == DeliveryStage.idle) {
      child = FutureBuilder<String?>(
        future: ApkInstaller.installedBuildFor(widget.project.projectId),
        builder: (context, snap) => snap.data == _buildId
            ? Row(children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('Ta wersja jest już zainstalowana.'))),
              ])
            : FilledButton.icon(
                onPressed: _downloadAndInstall,
                icon: const Icon(Icons.download),
                label: Text(tr('Pobierz i zainstaluj APK')),
              ),
      );
    } else {
      final working = mine.stage == DeliveryStage.downloading || mine.stage == DeliveryStage.installing;
      child = Row(children: [
        if (working)
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Icon(switch (mine.stage) {
            DeliveryStage.done => Icons.check_circle,
            DeliveryStage.failed => Icons.error,
            _ => Icons.help_outline,
          }, color: switch (mine.stage) {
            DeliveryStage.done => Colors.green,
            DeliveryStage.failed => Colors.red,
            _ => Colors.amber,
          }),
        const SizedBox(width: 12),
        Expanded(child: Text(deliveryStatusText(mine))),
        if (mine.stage == DeliveryStage.waitingForUser) FilledButton(onPressed: service.installAwaiting, child: Text(tr('Zainstaluj'))),
        if (mine.stage == DeliveryStage.failed) TextButton(onPressed: _downloadAndInstall, child: Text(tr('Ponów'))),
      ]);
    }
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: child);
  }

  Widget _buildInstallSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: switch (_installStage) {
        _InstallStage.idle => FilledButton.icon(
            onPressed: _downloadAndInstall,
            icon: const Icon(Icons.download),
            label: Text(tr('Pobierz i zainstaluj APK')),
          ),
        _InstallStage.downloading => Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(tr('Pobieranie… {0}', [transferLabel(_downloadedBytes, _totalBytes)])),
            ],
          ),
        _InstallStage.verifying => Row(
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text(tr('Weryfikacja SHA-256...')),
            ],
          ),
        _InstallStage.installing => Row(
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_awaitingConfirmation
                    ? tr('Potwierdź instalację w oknie Androida (albo w powiadomieniu).')
                    : tr('Instalowanie…')),
              ),
            ],
          ),
        _InstallStage.done => Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.launchAfterInstall ? tr('Zainstalowano — uruchamiam.') : tr('Zainstalowano.'))),
            ],
          ),
        _InstallStage.failed => Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(_installError ?? tr('Błąd instalacji.'))),
              TextButton(onPressed: _downloadAndInstall, child: Text(tr('Ponów'))),
            ],
          ),
      },
    );
  }
}
