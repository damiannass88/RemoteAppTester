# desktop_app/ — RemoteAppTester na Windows (aplikacja okienkowa)

Flutter Windows. Uruchamia rdzeń hosta (`../host`, `HostRuntime`) we własnym procesie:
zaszyfrowana baza projektów, równoległe buildy, dostawy i serwer dla telefonów (Tailscale),
lokalny kanał `127.0.0.1` dla `rt b`.

```
lib/
├── main.dart            # start: katalog danych, jedna kopia, zasobnik, okno (--minimized przy autostarcie)
├── app_controller.dart  # stan aplikacji nad HostRuntime (projekty, buildy na żywo, propozycje agentów)
└── ui/
    ├── home_page.dart       # nawigacja + pasek stanu (Tailscale, buildy, telefony online)
    ├── projects_page.dart   # lista projektów, dodawanie (istniejący / pusty / Flutter)
    ├── project_detail.dart  # Budowanie: wariant, Zbuduj i wyślij, telefony, log na żywo, historia
    ├── commands_tab.dart    # edytor komend + propozycje z REMOTEAPPTESTER.md
    ├── options_tab.dart     # opcje projektu (instalacja, uruchomienie, telefony, wyzwalacze)
    ├── phones_page.dart     # parowanie QR, online, odwołanie
    └── settings_page.dart   # autostart, równoległość, wstrzymanie, diagnostyka
```

Uruchomienie deweloperskie: `flutter run -d windows`. Wymaga trybu dewelopera Windows
(wtyczki natywne: `window_manager`, `tray_manager`, `file_selector`).
Dane: `%LOCALAPPDATA%\RemoteAppTester` (albo `REMOTEAPPTESTER_HOME`).
