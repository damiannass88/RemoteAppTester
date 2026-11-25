# Security and privacy — RemoteAppTester

🌐 **English** · [Polski](../SECURITY.md)

> Decisions S1–S10: [PROJECT_ASSUMPTIONS.md](../PROJECT_ASSUMPTIONS.md), section 7 (PL). The detailed
> architecture and reasoning behind the transport layer (inherited from RemoteDevelopment, where it was
> verified end to end, including with a real phone): [architektura-remote-build.md](../architektura-remote-build.md),
> section 6 (PL). To report a vulnerability: [.github/SECURITY.md](../../.github/SECURITY.md).

## Threat model

| Threat | Protection | Status |
|---|---|---|
| Compromised Tailscale account / ACL mistake | TLS with a certificate pinned at pairing, independent of Tailscale | works |
| Replay attack | HMAC with nonce + timestamp, ~60 s window, nonce memory per device | works |
| The phone sends a shell command / path | the contract has no such fields; only `project_id`, `build_id` and a variant name from the host's list; commands only from the database | works |
| **An AI agent / the repository changes the build commands** | commands ONLY in the encrypted database (SQLite3MultipleCiphers, key in DPAPI); `REMOTEAPPTESTER.md` in the folder is only a proposal, applied after explicit approval in the app (shown next to the current commands); strict block validation | works |
| **An AI agent approves its own proposal** | approval only in the app window or an interactive terminal (`rt pr import` refuses without a console, e.g. `echo t \| rt pr import`); the guidelines in REMOTEAPPTESTER.md tell agents this is the human's decision | works |
| **A copy of the program without database encryption** | startup checks that SQLite3MultipleCiphers is present and refuses to run without it (no plain database is ever created) | works |
| **Manual/hidden database change** | database pages are encrypted and authenticated: modifying the file = open error; other Windows accounts cannot read the key (DPAPI) | works |
| **Fake local trigger from another process** | channel only on `127.0.0.1` + token in SecretStore (constant-time comparison); browser requests (`Origin`) rejected; only known projects; worst case = a build of a configured folder (queue, debounce) | works |
| **Automatic install of something unexpected** | only paired, non-revoked devices from `deliver.devices`; the artifact can be downloaded only by the requester or a recipient; SHA-256 in the authenticated channel; a changed `applicationId` = the user is asked; Android enforces signature match on update; `install: auto` is a deliberate choice in the project file | works |
| MITM replaces the APK | the whole channel is authenticated (TLS pinning + HMAC); SHA-256 as an integrity check inside it | works |
| Path traversal through `project_id` / the build output pattern | `project_id` is random and mapped in the database to a deliberately assigned folder; the output pattern is relative, without `..`, and the result is checked after resolving links (it must lie inside the folder) | works |
| A pairing code seen or stolen | one-time code valid for 1 hour; the phone immediately exchanges it for its own secret and the old one stops working; secret rotation every 30 days; copying the link shows a warning and clears the clipboard after 2 min | works |
| A secret in the build log | redaction: assignments and flags with passwords/tokens, credentials in URLs, Bearer headers, known token formats, private keys, the user name in paths; it is a pattern filter, not a guarantee | works |
| Phone backup | `allowBackup=false` and extraction rules: app data does not go to the cloud or to a new phone | works |
| AI agent on the same account | DPAPI encryption does not protect against a program running as the same user; the "signal only" boundary is then an agreement, not a barrier. Recommendation: agent and build in a sandbox (Info tab) | accepted risk |
| A build runs code from the repository | Gradle and other tools run project scripts; the build runs in the same environment as the agent | accepted risk |
| Lost phone | Keystore, app lock (fingerprint/PIN at start and after background), biometrics/PIN before sensitive actions, revoking a single device with `remoteapptester revoke` | works |
| Another user / malware on the host reads secrets | Windows DPAPI; on Linux a `0600` file of the `remoteapptester` user; never plaintext | works |
| Brute force / DoS | per-device rate limiting, lockout per source address, one build at a time, kill switch | works |
| Secrets leaking in build logs | redaction of `*_KEY`/`*_TOKEN`/`*_PASSWORD`/`*_SECRET` patterns before sending to the phone | works |
| Phone A sees phone B's builds/logs | the stream goes only to the requester; `GetBuildStatus`/`CancelBuild` check `device_id` | works |
| Adding a new device remotely | pairing only locally in the host's terminal or window; no pairing RPC | works |
| Exposing a production key | only a development/test key in this pipeline | policy |
| Host reachable from the internet | bind only to the Tailscale address; no address = no start (never a fallback to `0.0.0.0`); the installer opens no ports | works |
| An AI agent (or anything in the folder) sends a signal | the signal is a `.remoteapptester-signal` file in the project folder, with no token and no database access; only "there are changes", `build: true/false` and a note (≤ 300 characters, one line, no control or bidirectional characters) are read from it; links and files > 4 KB are rejected unread; a build happens only when the project option "Agent signal starts a build" is on, not while paused, always with the database commands; repeated signals do not multiply builds (queue deduplication) | works |
| The phone changes project options | `UpdateProjectOptions` (HMAC like every RPC) changes only: install mode, launching, agent signal and deliveries to THIS phone; it does not change commands or "building from the phone"; every change goes to the audit log | works |
| A revoked phone keeps reconnecting | a known, revoked `device_id` does not count towards the address lockout (otherwise it would block forever, even after re-pairing); its own request limit, one log entry per 5 min; an active phone passes the address lockout, but its bad signatures block its own identifier | works |
| A forged delta base | the phone sends only the SHA-256 of its installed version; the host looks for it only among builds of the same project; the phone checks the checksum of the transferred file and of the assembled APK against the build's checksum, so a different APK than the one built cannot pass | works |
| Private data leaking to the phone | the phone gets: folder name, type, progress, redacted log, the artifact; no disk paths or user names | works |

## Checklist

### Network and transport

- [x] Bind only to the Tailscale interface address (`host/lib/net/tailscale_interface.dart`).
- [x] TLS with a self-signed certificate generated on first start; its SHA-256 fingerprint is in the
      QR code; the phone rejects any other certificate (`CertificatePinningException`); pairing URIs
      without `cert_fp` are rejected.
- [x] HMAC-SHA256(pairing_secret, method‖payload‖timestamp‖nonce) in gRPC metadata on every request;
      all phone calls go through `AgentClient`, so the signature cannot be skipped.
- [ ] **Tailscale ACL**: for each host, grant only the phone(s) → host on the service port
      (default `tcp:47051`), everything else denied. `rt acl` / the "Generate JSON for Tailscale" button
      prepares the policy.
- [ ] **Windows Firewall**: an inbound rule for the service port, narrowed to the phone's tailnet
      address (a separate layer from the ACL; without it Windows silently blocks the phone).
      `remoteapptester doctor` checks that it exists. Command (PowerShell as administrator):
      ```powershell
      New-NetFirewallRule -DisplayName "RemoteAppTester (gRPC 47051 - phone only)" `
        -Direction Inbound -Protocol TCP -LocalPort 47051 `
        -RemoteAddress <phone-tailnet-address> -Action Allow -Profile Private -Enabled True
      ```
- [x] Reconnecting in the app (keepalive 25 s, host heartbeat 20 s, drop after 70 s of silence,
      backoff 1–30 s), always over the same TLS pinning + HMAC channel, with no fallback.
      Verified with the test client `host/tool/e2e_delivery.dart` (wrong certificate and missing
      HMAC rejected).

### Host

- [x] Process as a regular user (Windows) / a dedicated `remoteapptester` user without sudo (Linux);
      hardened systemd service (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `PrivateTmp`).
- [x] Secrets in `SecretStore` (DPAPI / `0600`), migration of old plaintext files.
- [x] Build commands only from the encrypted database (editor in the app / approved proposal from
      `REMOTEAPPTESTER.md`); each step in a separate script in the data folder; cancelling kills the
      whole process tree.
- [x] Only explicitly assigned projects (database); the output pattern cannot leave the folder (tests).
- [x] Log redaction (`host/lib/build/log_redactor.dart`).
- [x] Operation log with `device_id` (audit, local).
- [x] Database encryption + test: no commands in the file as plain text, a different key = error (`test/project_store_test.dart`).
- [x] Proposals from `REMOTEAPPTESTER.md` are never applied without approval; strict block validation (tests).
- [x] Local trigger channel with a token + tests: missing/wrong token, `Origin`, unknown folder,
      `triggers.local`, kill switch, the method always from the host (`test/control_server_test.dart`).
- [x] Artifact access only for the requester, the delivery recipients and the phones in the project options (tests).
- [ ] A permanent debug key on the host, outside the project folders (Phase 4).

### Android app

- [x] `device_id`, `pairing_secret`, certificate fingerprint in the Keystore (`flutter_secure_storage`).
- [x] App lock: fingerprint/PIN at start and after the background timeout; turning it off or making it
      weaker requires confirmation (`app_lock.dart`).
- [x] Biometrics/PIN before starting a build and before installing (`sensitive_action_gate.dart`).
- [x] SHA-256 and `applicationId` before installing; installing through `PackageInstaller`, without
      root or ADB.
- [x] The downloaded APK in the private `cacheDir`, no storage permissions.
- [x] Biometrics policy for deliveries (`install: auto` without, `ask`/package change/manual build with).
- [x] `UPDATE_PACKAGES_WITHOUT_USER_ACTION` + `USER_ACTION_NOT_REQUIRED`: works only for updates of
      packages installed by RemoteAppTester; no attempts to bypass Play Protect or background launch limits.
- [ ] Test on a real phone (update without a window, launch after install).

## Verification with a real phone (after every change to the network → install path)

1. Host: `remoteapptester doctor`: everything `[OK]` (including Tailscale and the firewall on Windows).
2. Phone: Tailscale connected; in RemoteAppTester scan the code from `remoteapptester pair "name"`.
3. Build from the phone → download → install → launch.
4. Change networks during a build and during a transfer (Wi-Fi → LTE): the build continues and the
   transfer resumes where it stopped.
5. `remoteapptester revoke <device_id>` → the next request from the phone is rejected.
