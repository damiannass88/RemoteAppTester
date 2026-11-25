# RemoteAppTester for AI agents

🌐 **English** · [Polski](../AGENCI_AI.md)

Instructions for an AI agent (Claude Code, Codex, Cursor and others) working in a project folder
assigned to RemoteAppTester, on a Linux server/VPS or on Windows. Every such folder also has a
`REMOTEAPPTESTER.md`, and CLAUDE.md and AGENTS.md contain a short pointer to it.

## How it works

The agent has no access to RemoteAppTester: it cannot see the database, keys, token or the connection
to the phone, and it does not need `sudo`. It talks to RemoteAppTester only through files in the
project folder:

| File | Written by | Purpose |
|---|---|---|
| `.remoteapptester-signal` | the agent (`rt sg`, `rt push`) | a request: a note, a build request or a ready APK |
| `.remoteapptester-status.json` | RemoteAppTester | result of the last request |
| `.remoteapptester-push.apk` | `rt push` | copy of an APK from outside the project folder |

The RemoteAppTester service checks the folders about every 3 seconds. When it finds a request, it
restores the signal file template, carries out the request (if the project options allow it) and
writes the result. The phone receives the new version through Tailscale. Installation follows the
project options: `ask` (the phone asks), `auto` or `off`.

## Two ways to deliver the app

**1. RemoteAppTester builds** with the approved commands from its database (the agent can only
propose them in `REMOTEAPPTESTER.md`; a human approves them):

```sh
rt sg -m "Added a login screen" --build --wait --json
```

**2. The agent builds** and sends the finished APK:

```sh
flutter build apk --debug --target-platform android-arm64
rt push build/app/outputs/flutter-apk/app-debug.apk -m "Added a login screen" --wait --json
```

- Without a path, `rt push` sends the newest `build/**/*.apk` from the project.
- A file from outside the project folder is copied to `.remoteapptester-push.apk`.
- Only a signed `.apk` file is accepted (ZIP header, no `unsigned` in the name, up to 1 GB) that lies
  inside the project folder, also after resolving links.
- The project option "AI agent may send its own APK" must be on (it is by default).
  Change it with `sudo rt o <project> --agent-push on|off` or in the app window.
- `--installed` also waits until every phone confirms it handled the delivery.

## Result and exit codes

`--wait` waits for the result; `--timeout <s>` changes the limit (default 600 s for `push` and 3600 s
for `sg --build`). `--json` prints one line of JSON. The result can also be read later: `rt st --json`.

| Code | Meaning | What to do |
|---|---|---|
| 0 | sent to the phone(s); with `--installed` also confirmed | ask the user to test |
| 1 | rejected, or the build failed | read `message` and `log_tail`, fix, try again |
| 2 | timed out | check later: `rt st` |
| 3 | RemoteAppTester did not pick up the signal | the service is not running: tell the user |
| 4 | done, but no phone received the version | install `off` or no phones selected: tell the user |
| 64 | wrong command usage | `rt push --help` |

Example result (`.remoteapptester-status.json`):

```json
{
  "request": "033c043c30cbfb36",
  "action": "push",
  "state": "done",
  "message": "Done — sent to phones: 1; confirmed: 0.",
  "project": "myapp",
  "build_id": "hnx2lu1xw8",
  "phase": "DONE",
  "sha256": "ebd707aa…",
  "size_bytes": 18234567,
  "install": "ask",
  "devices": [{"id": "…", "name": "Pixel", "online": true, "handled": false}],
  "updated_at": "2026-11-06T20:21:22Z"
}
```

`action` is `push`, `build` or `note`; `state` is `queued`, `running`, `done`, `rejected`, `failed`
or `cancelled`. With `failed`, the `log_tail` field holds the last 40 lines of the build log.

## Preparing the agent on a VPS (done by a human)

```sh
sudo bash install.sh --add-user <agent-login>   # agent account in the projects group, no sudo
sudo rt n myapp --flutter                       # or: sudo rt a /srv/remoteapptester/projects/<folder>
sudo rt o myapp --install ask --agent-push on
```

The agent works in `/srv/remoteapptester/projects/<project>` and uses only `rt sg`, `rt push` and
`rt st`, which work without `sudo`. All other `rt` commands need `sudo` and are for the human.

## Rules

- Do not approve the commands in `REMOTEAPPTESTER.md` yourself (`rt pr import`): that is the human's decision.
- The `-m` note is a short text of up to 300 characters with no secrets, because it is shown on the phone.
- Add `.remoteapptester-signal`, `.remoteapptester-status.json` and `.remoteapptester-push.apk`
  to `.gitignore`.
- Send debug builds for testing, and never keep release signing keys in the agent's folder.
