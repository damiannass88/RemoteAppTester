# RemoteAppTester on a Linux server (VPS)

🌐 **English** · [Polski](README.pl.md)

The version without a window: the same features as on Windows (projects, commands, options, builds,
delivery to the phone, AI agent signals, languages), operated with `rt` commands and from the phone.

New to servers? Follow the step-by-step [VPS guide](../../../docs/en/VPS.md) together with an AI chat.

## Requirements

- Linux with glibc 2.34+: Ubuntu 22.04+, Debian 12+, RHEL/Alma/Rocky 9+, Fedora, openSUSE, Arch and derivatives.
- x86_64 (Google publishes the Android build tools for x86_64 only).
- At least 4 GB RAM (or swap) and about 15 GB free space for Flutter and the Android SDK.
- A Tailscale account, the same one as on the phone.

Alpine and other musl systems are not supported: the installer refuses with an explanation.

## Installation

```
tar xzf RemoteAppTester-linux-<version>.tar.gz
cd RemoteAppTester-linux-<version>
sudo bash install.sh
```

The installer checks SHA-256 checksums and creates a `remoteapptester` user without administrator
rights. It installs the program, Flutter, the Android SDK and Tailscale, starts the service and shows
a QR code to scan with the phone. Running it again updates the program and keeps your data. Options: `--help`.

**Required on the phone:** Settings → Apps → RemoteAppTester (and Tailscale) → Battery →
**"Unrestricted"**. Xiaomi/HyperOS restricts new apps by default, and then the phone cannot reach the
server ("Connection timed out").

The installer asks you to accept Google's Android SDK licences (https://developer.android.com/studio/terms).
Without a terminal (e.g. cloud-init), `--accept-android-licenses` gives that consent. Without the Android SDK: `--skip-flutter`.

Installing without a terminal (e.g. cloud-init): `TS_AUTHKEY=... sudo -E bash install.sh --no-pair`.

**Tailscale access rules (ACL).** If your Tailscale admin panel (Access controls) has your own rules
instead of the default "everyone to everyone", allow the phones to reach the RemoteAppTester port
(default **47051**; up to version 0.6 it was 50051). `sudo rt acl` (with `--with <computer>` for further
computers running RemoteAppTester) builds a ready policy from the devices in your Tailscale network, e.g.:

```json
"grants": [{"src": ["<phone IP>"], "dst": ["<computer IP>"], "ip": ["tcp:47051"]}]
```

Without it the phone gets "Connection timed out", even though Tailscale shows a connection.

**New project from the phone.** The "New project" button in the phone app creates a Flutter project
or an empty folder, or assigns a free folder. It always works inside the computer's projects folder
(`projects_root`), by name only, and the computer fills in the commands. To turn it off, set
`phone_add_projects: false` in `host-config.yaml` and restart the program.

## Where things are

| What | Where |
|---|---|
| Program | `/opt/remoteapptester` |
| Data (database, keys, logs) | `/var/lib/remoteapptester`, only for the service user |
| Projects | `/srv/remoteapptester/projects`, writable by the `remoteapptester` group |

## Daily use

```
sudo rt                         # list of commands and recently used ones
sudo rt n myapp --flutter       # new project
sudo rt a /path/to/folder       # assign an existing folder
sudo rt pr myapp                # build commands
sudo rt pr import               # approve commands proposed by the agent
sudo rt o myapp --install ask --agent-build on
sudo rt b myapp                 # build and send
sudo rt lg myapp                # history and log
sudo rt p "Second phone"        # pair another phone
sudo rt acl                     # Tailscale access rules (JSON) for the phones
sudo rt la en                   # command language: auto, pl, en, de, cs
sudo rt info                    # guide: security, AI agents, sandbox, publishing
```

## AI agents

Add the agent's account to the projects group: `sudo bash install.sh --add-user <login>` (or
`usermod -aG remoteapptester <login>`). The agent works in `/srv/remoteapptester/projects/<project>`
and, when done, sends a signal, without sudo and without access to the program's data:

```
rt sg -m "what changed" --build --wait            # RemoteAppTester builds with the approved commands
rt push build/app/outputs/flutter-apk/app-debug.apk -m "what changed" --wait --json   # the agent built it itself
rt st --json                                      # result of the last request
```

Exit codes, result format and rules: [docs/en/AI_AGENTS.md](../../../docs/en/AI_AGENTS.md). To stop agents
sending their own APKs: `sudo rt o <project> --agent-push off`.

Never give the agent `sudo`. A build runs scripts from the repository, so on a server with other
services it is better to give the agents a separate machine. More: `sudo rt info`.

## Service

`systemctl status remoteapptester`, `journalctl -u remoteapptester -f`. On OpenRC systems the
installer creates `/etc/init.d/remoteapptester`; without a service manager run `sudo rt s` in tmux or screen.

The server listens only on the Tailscale address. The installer opens no ports and does not change the firewall.

## Uninstalling

```
sudo bash install.sh --uninstall           # data and projects stay
sudo bash install.sh --uninstall --purge   # also removes data, projects and the user
```
