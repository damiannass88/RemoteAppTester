# host/ — RemoteAppTester host (CLI)

🌐 **English** · [Polski](README.pl.md)

The `remoteapptester` program for Windows and Linux (Ubuntu preferred). It configures projects,
builds them with fixed recipes, runs the build queue and a gRPC server (only inside the Tailscale
network) from which the phone downloads finished builds. Pure Dart: no Flutter, no GUI.

Design decisions: [docs/PROJECT_ASSUMPTIONS.md](../docs/PROJECT_ASSUMPTIONS.md) (PL) · plan:
[docs/IMPLEMENTATION_PLAN.md](../docs/IMPLEMENTATION_PLAN.md) (PL) · security:
[docs/en/SECURITY.md](../docs/en/SECURITY.md) · VPS installation:
[deploy/linux/README.md](deploy/linux/README.md).

## Role on Windows and Linux

- **Windows:** the main program is the windowed app (`../desktop_app`), which runs this core
  inside itself. `rt` is for the terminal and AI agents (`rt b` in a project folder) and uses the
  same encrypted database in `%LOCALAPPDATA%\RemoteAppTester`.
- **Linux/VPS:** `rt s` runs the core without a window, as a system service installed by
  [deploy/linux/install.sh](deploy/linux/README.md).

## Commands (`rt` = `remoteapptester`)

| Short | Command | What it does |
|---|---|---|
| `rt b` | `build [folder] [--no-wait]` | build through the running RemoteAppTester; the exit code is the result |
| `rt n` | `new <name> [--flutter]` | new project folder, assigned right away |
| `rt o` | `options [folder] [--install …] [--launch …] [--agent-build …] [--phone-build …] [--terminal …]` | project options |
| `rt lg` | `log [folder]` | build history and the last log |
| `rt in` | `info` | guide: security, AI agents, sandbox, publishing |
| `rt la` | `language [auto\|pl\|en\|de\|cs]` | command language |
| `rt sg` | `signal [-m "note"] [--build] [--wait] [--json]` | AI agent signal "there are changes" (a file in the folder, no access to RemoteAppTester) |
| `rt pu` | `push [file.apk] [-m "note"] [--wait] [--installed] [--json]` | the AI agent sends an APK it built itself to the phones |
| `rt st` | `status [folder] [--json]` | result of the last signal or push (`.remoteapptester-status.json`) |
| `rt a` / `rt rm` | `add [folder]` / `remove <folder\|name>` | assign / unassign a project |
| `rt ls` | `projects` | projects and the state of their `REMOTEAPPTESTER.md` |
| `rt pr` | `project [folder]`, `pr import`, `pr guide` | commands; approve the agent's proposal; refresh the file |
| `rt m` | `methods` | command templates for technologies |
| `rt p` / `rt dv` / `rt rv` | `pair` / `devices` / `revoke` | phones |
| `rt s` / `rt t` | `serve` / `tunnel` | server without a window (Linux) / pair + server |
| `rt i` / `rt dr` / `rt h` / `rt v` | `init` / `doctor` / `history` / `version` | |

`rt` without arguments shows the table and the **recently used commands**.

## AI agents

Every assigned folder has a `REMOTEAPPTESTER.md`: guidelines plus a commands block to fill in.
The agent edits the block → RemoteAppTester shows the proposal → you approve it in the app (or with
`rt pr import` in an interactive terminal). When the agent finishes, it says so: the folder holds a
described `.remoteapptester-signal` template; the agent sets `build: true` and `message` and saves it
(or runs `rt sg -m "what changed" [--build]`). RemoteAppTester marks the project "new changes" and
(by default) builds and sends it. A hint is also added to CLAUDE.md and AGENTS.md.
`rt b` (local token) stays for the human in the terminal.

An agent that built the APK itself sends it with `rt push <file.apk> -m "…" --wait --json`
(exit code 0 = sent to the phone). Full description for agents: [docs/en/AI_AGENTS.md](../docs/en/AI_AGENTS.md).

## Structure

```
host/
├── bin/remoteapptester.dart, rt.dart  # CLI entry point (two names)
├── config/host-config.example.yaml
├── deploy/windows/              # Windows installer (install.ps1/.cmd): PATH, autostart, firewall
├── deploy/linux/                # universal Linux installer + systemd service
├── tool/build_release.ps1       # Windows ZIP package: windowed app + rt (+ APK)
├── tool/build_release.sh        # Linux x64/arm64 package (Docker)
├── tool/e2e_delivery.dart       # delivery test without a phone (acts as the app: TLS pinning + HMAC)
├── lib/
│   ├── cli/                     # commands and shortcuts, command history, doctor, terminal QR code
│   ├── config/                  # host-config.yaml
│   ├── discovery/               # detecting the folder's technology
│   ├── build/                   # BuildEngine (parallel background builds), running steps, artifacts, log redaction
│   ├── store/                   # encrypted database: projects, commands, options, history
│   ├── project/                 # command variants, templates, REMOTEAPPTESTER.md, finding the build output
│   ├── server/                  # HostRuntime, gRPC server (Tailscale, TLS), deliveries, local channel, kill switch
│   ├── pairing/                 # device registry, pairing URI, HMAC, nonce, rate limiting
│   ├── security/                # SecretStore (DPAPI / 0600 file), TLS identity
│   ├── net/                     # detecting the Tailscale address
│   └── generated/               # code from proto/remote_tester.proto (do not edit)
└── test/
```

## Tests

```sh
dart analyze
dart test
```

Some tests are skipped outside Windows (DPAPI) or without permission to create symlinks.

Delivery test without a phone (with `rt s` running): `rt p "e2e"`, then
`dart run tool/e2e_delivery.dart --home <data> --device <device_id>` and in a second terminal `rt b <folder>`.

## Configuration

[config/host-config.example.yaml](config/host-config.example.yaml) contains no secrets. Secrets
(`pairing_secret`, the TLS private key) live only in `SecretStore` (Windows DPAPI, on Linux a `0600`
file owned by the service user).
