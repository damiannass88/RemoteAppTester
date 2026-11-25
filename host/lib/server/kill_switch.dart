/// Globalny przycisk "Wstrzymaj przyjmowanie nowych zleceń" (/// docs/IMPLEMENTATION_PLAN.md). Blokuje WYŁĄCZNIE nowe `StartBuild`/
/// `AddProject` — celowo NIE dotyka builda już w toku (do tego służy osobne
/// `CancelBuild`) ani odczytu (`ListProjects`/`ListBranches`/
/// `GetBuildStatus`/`DownloadArtifact`), więc telefon może dalej sprawdzać
/// stan i pobrać gotowy artefakt, nawet gdy agent jest "wstrzymany".
///
/// Stan trzymany tylko w pamięci (nie na dysku) — restart agenta zawsze
/// wraca do "przyjmuje zlecenia", co jest bezpieczniejszym domyślnym stanem
/// niż przypadkowe pozostanie zablokowanym po awarii/aktualizacji.
///
/// Czysty Dart (bez `ChangeNotifier` z Fluttera) — ta klasa jest częścią
/// rdzenia używanego też przez headless agenta na Linuxie. GUI
/// Windows nasłuchuje przez [addListener], tak jak wcześniej.
class KillSwitch {
  bool _paused = false;
  final List<void Function()> _listeners = [];

  bool get isPaused => _paused;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void pause() {
    if (_paused) return;
    _paused = true;
    _notify();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _notify();
  }

  void toggle() => _paused ? resume() : pause();

  void _notify() {
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }
}
