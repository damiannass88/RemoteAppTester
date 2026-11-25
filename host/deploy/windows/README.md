# RemoteAppTester on Windows

🌐 **English** · [Polski](README.pl.md)

## Installation

1. Unzip `RemoteAppTester-windows-x64-<version>.zip` (the whole folder).
2. Run **`install.cmd`** (double-click). It does not need administrator rights. It asks for
   administrator consent (a UAC window) only for the firewall rule, and only if you agree.
3. The RemoteAppTester app opens: **Phones → Pair phone**, then scan the code with the phone app
   (`RemoteAppTester-android-<version>.apk`).
   **Required on the phone:** Settings → Apps → RemoteAppTester → Battery → **"Unrestricted"**
   (the same for the Tailscale app). Xiaomi/HyperOS restricts new apps by default, and then the
   phone cannot reach the computer ("Connection timed out").
4. **Projects → "+"**: add the folder with your app. Build commands are filled in automatically.

Requirements: Windows 10/11 64-bit, [Tailscale](https://tailscale.com/download/windows) signed in
with the same account as on the phone (the installer offers to install it with `winget`), and the
tools to build your projects (e.g. Flutter, Android SDK).

Not technical? [Prompt 3](../../../docs/en/PROMPTS.md#3-installing-remoteapptester-on-windows) walks
you through it with an AI chat.

Options (`install.cmd -Option`): `-NoAutostart`, `-NoFirewall`, `-NoShortcuts`, `-NoPath`,
`-NoLaunch`, `-Port 47051`.

**Tailscale access rules (ACL).** If your Tailscale admin panel (Access controls) has your own rules
instead of the default "everyone to everyone", allow the phones to reach the RemoteAppTester port
(default **47051**; up to version 0.6 it was 50051). The **Phones → Generate JSON for Tailscale**
button (or `rt acl`) builds a ready policy from the devices in your Tailscale network, e.g.:

```json
"grants": [{"src": ["<phone IP>"], "dst": ["<computer IP>"], "ip": ["tcp:47051"]}]
```

Without it the phone gets "Connection timed out", even though Tailscale shows a connection.

**New project from the phone.** The "New project" button in the phone app creates a Flutter project
or an empty folder, or assigns a free folder. It always works inside the computer's projects folder
(`projects_root`), by name only, and the computer fills in the commands. To turn it off, set
`phone_add_projects: false` in `host-config.yaml` and restart the program.

## What the installer does

| Step | Details |
|---|---|
| App | `%LOCALAPPDATA%\Programs\RemoteAppTester\RemoteAppTester.exe`; SHA-256 checksums of all files are checked before installing |
| Terminal / AI agents | `rt` and `remoteapptester` in the user's PATH (`...\RemoteAppTester\cli\bin`) |
| Data | `%LOCALAPPDATA%\RemoteAppTester`: encrypted database of projects and commands, paired phones, logs, builds; keys in Windows DPAPI |
| Shortcuts and autostart | Start menu, desktop; starts hidden in the tray at sign-in (can be turned off in Settings) |
| Firewall | rule "RemoteAppTester (Tailscale only)": only `RemoteAppTester.exe`, this port, addresses `100.64.0.0/10` |

The program accepts phone connections only on the Tailscale address. Updating: newer package →
`install.cmd` (data stays; a version 0.3 setup with Task Scheduler is migrated automatically).
Uninstalling: `uninstall.cmd` (data stays) or `uninstall.cmd -Purge`. Project folders and their
`REMOTEAPPTESTER.md` are left untouched.

## Notes

- **SmartScreen:** the program is not signed with a paid certificate: "More info" → "Run anyway".
  Check the `.sha256` file of the download first. The installer removes the "downloaded from the
  internet" mark from the installed files.
- **Closing the window** hides the app in the tray. Builds and phones keep working.
  "Exit" is in the tray icon's menu.
