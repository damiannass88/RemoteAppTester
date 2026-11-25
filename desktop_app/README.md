# desktop_app/ — RemoteAppTester for Windows (windowed app)

🌐 **English** · [Polski](README.pl.md)

Flutter for Windows. It runs the host core (`../host`, `HostRuntime`) in its own process: the
encrypted project database, parallel builds, deliveries and the server for phones (Tailscale), plus
the local `127.0.0.1` channel for `rt b`.

```
lib/
├── main.dart            # startup: data folder, single instance, tray, window (--minimized at autostart)
├── app_controller.dart  # app state on top of HostRuntime (projects, live builds, agent proposals)
└── ui/
    ├── home_page.dart       # navigation + status bar (Tailscale, builds, phones online)
    ├── projects_page.dart   # project list, adding (existing / empty / Flutter)
    ├── project_detail.dart  # Build: variant, Build and send, phones, live log, history
    ├── commands_tab.dart    # command editor + proposals from REMOTEAPPTESTER.md
    ├── options_tab.dart     # project options (install, launch, phones, triggers)
    ├── phones_page.dart     # QR pairing, online state, revoking, Tailscale ACL generator
    └── settings_page.dart   # autostart, parallel builds, pause, diagnostics
```

Development run: `flutter run -d windows`. Needs Windows Developer Mode (native plugins:
`window_manager`, `tray_manager`, `file_selector`).
Data: `%LOCALAPPDATA%\RemoteAppTester` (or `REMOTEAPPTESTER_HOME`).
