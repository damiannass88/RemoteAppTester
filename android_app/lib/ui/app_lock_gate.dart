import 'dart:async';

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../security/app_lock.dart';

/// Owija całą aplikację (MaterialApp.builder): pilnuje czasu w tle i
/// bezczynności, a gdy [AppLock.locked] — zasłania interfejs ekranem blokady.
/// Interfejs pod spodem żyje dalej (połączenie, log builda, dostawy).
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  late final AppLifecycleListener _lifecycle;
  Timer? _idleTimer;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    _idleTimer = Timer.periodic(const Duration(seconds: 20), (_) => AppLock.checkIdle());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  void _onHide() {
    // Okno odcisku palca bywa osobnym oknem systemu — to nie wyjście do tła.
    if (AppLock.authInProgress) return;
    _backgroundedAt ??= DateTime.now();
  }

  void _onShow() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since != null) AppLock.onResumedAfter(DateTime.now().difference(since));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => AppLock.touch(),
      child: ValueListenableBuilder<bool>(
        valueListenable: AppLock.locked,
        builder: (context, locked, child) => Stack(
          fit: StackFit.expand,
          children: [
            // Pod blokadą: bez animacji, bez dostępności (czytnik ekranu nie
            // przeczyta treści) i bez dotyku.
            TickerMode(
              enabled: !locked,
              child: ExcludeSemantics(excluding: locked, child: AbsorbPointer(absorbing: locked, child: child!)),
            ),
            if (locked) const _LockScreen(),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> with WidgetsBindingObserver {
  LockCapability? _capability;
  String? _message;
  bool _busy = false;

  /// Okno odcisku pokazujemy samo tylko po prawdziwym powrocie z tła — nie po
  /// zamknięciu samego okna odcisku (anulowanie nie może wywołać go od nowa).
  bool _promptOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _promptOnResume = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    _refreshAndPrompt(prompt: !_promptOnResume);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.hidden || state == AppLifecycleState.paused) && !AppLock.authInProgress) {
      _promptOnResume = true;
    } else if (state == AppLifecycleState.resumed && _promptOnResume) {
      // Powrót z tła albo z ustawień Androida (np. po dodaniu odcisku).
      _promptOnResume = false;
      _refreshAndPrompt(prompt: true);
    }
  }

  Future<void> _refreshAndPrompt({required bool prompt}) async {
    final capability = await AppLock.capability();
    if (!mounted) return;
    setState(() => _capability = capability);
    // Okno odcisku od razu, bez szukania przycisku.
    if (prompt && capability != LockCapability.none) await _unlock();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final outcome = await AppLock.unlock();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (outcome) {
        AuthOutcome.ok || AuthOutcome.cancelled => null,
        AuthOutcome.lockedOut => tr('Zbyt wiele nieudanych prób. Odczekaj chwilę albo użyj PIN-u telefonu.'),
        AuthOutcome.notEnrolled => tr('Telefon nie ma już zapisanej blokady — dodaj odcisk palca.'),
        AuthOutcome.failed => tr('Nie udało się sprawdzić odcisku palca. Spróbuj ponownie.'),
      };
    });
    if (outcome == AuthOutcome.notEnrolled) {
      final capability = await AppLock.capability();
      if (mounted) setState(() => _capability = capability);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capability = _capability;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 56, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  tr('RemoteAppTester jest zablokowany'),
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (capability == null)
                  const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                else if (capability == LockCapability.none)
                  ..._setupNeeded(context)
                else
                  ..._unlockControls(context, capability),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _unlockControls(BuildContext context, LockCapability capability) => [
        Text(
          capability == LockCapability.biometric
              ? tr('Przyłóż palec do czytnika, żeby wrócić do aplikacji.')
              : tr('Potwierdź PIN-em telefonu, żeby wrócić do aplikacji.'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _unlock,
          icon: Icon(capability == LockCapability.biometric ? Icons.fingerprint : Icons.pin_outlined),
          label: Text(capability == LockCapability.biometric ? tr('Odblokuj odciskiem palca') : tr('Odblokuj')),
        ),
        if (capability == LockCapability.credentialOnly) ...[
          const SizedBox(height: 16),
          Text(
            tr('Telefon nie ma zapisanego odcisku palca — odblokujesz szybciej, gdy go dodasz.'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            onPressed: AppLock.openEnrollment,
            icon: const Icon(Icons.fingerprint),
            label: Text(tr('Dodaj odcisk palca')),
          ),
        ],
      ];

  List<Widget> _setupNeeded(BuildContext context) => [
        Text(
          tr('Ten telefon nie ma odcisku palca ani blokady ekranu, więc nie ma czym potwierdzić, że to Ty.\n\nDodaj odcisk palca w ustawieniach Androida (Android poprosi też o PIN zapasowy). Potem wróć tutaj — aplikacja od razu poprosi o odcisk.'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: AppLock.openEnrollment,
          icon: const Icon(Icons.fingerprint),
          label: Text(tr('Dodaj odcisk palca')),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: AppLock.continueWithoutProtection,
          child: Text(tr('Kontynuuj bez zabezpieczenia (do zamknięcia aplikacji)')),
        ),
      ];
}
