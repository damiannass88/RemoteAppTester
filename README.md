# RemoteAppTester

**Build your app on a computer or a server, test it on your phone, and drive the whole thing from your phone.**

RemoteAppTester is for people who have an idea for an app and want to work on it with an AI
coding agent (for example Claude Code), without being an IT professional. You tell the AI agent
what to build or fix. RemoteAppTester builds the result and puts it on your phone, through your
own private network. You test it, tell the agent what to change, and repeat. All of this
can be done from the phone, wherever you are.

🇵🇱 [Polska wersja](README.pl.md) · 📘 [Beginner guide](docs/en/GUIDE.md) ·
🤖 [Ready-made AI prompts](docs/en/PROMPTS.md) · 🖥️ [VPS setup](docs/en/VPS.md)

> **Status: beta (0.6.x).** It works daily for its author, but expect rough edges.
> Use a test phone and test projects. See [Disclaimer](#disclaimer).

## How it works

```
 You (phone)                Your computer or VPS                     Your phone
 ───────────                ─────────────────────                    ──────────
 "Add a login screen"  ──►  AI agent (e.g. Claude Code)
 via the Claude app         edits the project folder
                            and sends a signal: rt sg --build
                                      │
                                      ▼
                            RemoteAppTester builds the app  ──Tailscale──►  installs
                            with commands YOU approved                      and opens it
```

1. **The AI agent works on its own.** You set it up separately (Claude Code, Codex, Cursor…).
   Claude Code can be driven from the Claude mobile app ("Remote Control"), so you talk to
   the agent from your phone.
2. **When the agent is done, it signals RemoteAppTester** (`rt sg --build` or `rt push`).
   The agent never gets access to RemoteAppTester itself: it can only leave a note and ask for a build.
3. **RemoteAppTester builds the app** with build commands that only you can approve, and sends it to
   your paired phone over [Tailscale](https://tailscale.com) (a free private network between your
   devices). Nothing goes through our servers. We do not have any.
4. **The phone installs and opens the new version.** You test it and write your next request to the agent.

## What you can test

| Mode | What happens |
|---|---|
| **Android apps** (Flutter, Gradle; more planned) | Built into an APK, sent to the phone, installed and launched. Only the changed parts are transferred. |
| **Web apps** (ASP.NET, Next.js, Vite, Angular, Django, Flask, Laravel, PHP, static sites…) | "Preview" starts the dev server on the computer and opens it on the phone through Tailscale, in a phone-sized or desktop-sized view. "Report a problem" writes your note and the browser console to a file for the agent. |

Where RemoteAppTester runs:

| Host | For whom |
|---|---|
| **Windows 10/11** (windowed app + `rt` command) | You have a PC that stays on. Easiest to start. |
| **Linux / VPS** (`rt` command + background service) | You want a small server rented online (e.g. Contabo, Hetzner, OVH) that works 24/7, also for the AI agent. |
| **Android phone** (the remote) | Lists projects, builds, installs, previews and locks with your fingerprint. |

**Not supported yet: iPhone/iOS and macOS.** Building for iOS needs a Mac, and the author has no Apple
hardware to test it properly. Help from Mac users is welcome.

## Quick start

1. **Tailscale:** create a free account and install Tailscale on the computer/server and the phone.
2. **Install RemoteAppTester:**
   - Windows: unzip `RemoteAppTester-windows-x64-<version>.zip` and run `install.cmd`
     ([details](host/deploy/windows/README.md)).
   - Linux/VPS: `sudo bash install.sh` from `RemoteAppTester-linux-<version>.tar.gz`
     ([details, PL](host/deploy/linux/README.md), [VPS step by step](docs/en/VPS.md)).
3. **Phone:** install `RemoteAppTester-android-<version>.apk` and scan the pairing QR code.
   Set battery saving to **"Unrestricted"** for RemoteAppTester and Tailscale.
4. **Add a project** (a folder with your app). Build commands are filled in automatically.
5. **Set up your AI agent** in that folder. There is a [prompt for that](docs/en/PROMPTS.md).

Not technical? Paste the matching prompt from [docs/en/PROMPTS.md](docs/en/PROMPTS.md) into an AI chat
(Claude, ChatGPT…) and let it guide you step by step. Every prompt explains what it does.

## Security in one paragraph

The phone talks to the computer only inside your Tailscale network, over TLS with a certificate
pinned at pairing, and every request is signed. The phone cannot send commands or file paths.
Build commands live in an encrypted database and change only when you approve them. AI agents
communicate only through files in the project folder. The phone app locks with your fingerprint.
Details: [docs/SECURITY.md](docs/SECURITY.md) (PL). The main risks are explained honestly in the
app's **Info** tab. In short: run AI agents in a separate account or machine, and test on a phone without private data.

## Publishing your app

RemoteAppTester is for **testing** (debug builds). Releasing to Google Play or a website is a separate
step with its own rules: developer account, signing key, privacy policy, store testing requirements.
[docs/en/PROMPTS.md](docs/en/PROMPTS.md) has a prompt that walks you through it with an AI chat.

## Building from source

See [host/README.md](host/README.md), [desktop_app/README.md](desktop_app/README.md),
[android_app/README.md](android_app/README.md). Release packages:
`host/tool/build_release.ps1 -WithAndroid` (Windows + APK) and `host/tool/build_release.sh` (Linux, Docker).
Architecture and decisions: [docs/PROJECT_ASSUMPTIONS.md](docs/PROJECT_ASSUMPTIONS.md),
[docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) (PL).

## Support the project

RemoteAppTester is free and open source. If it saves you time, you can
[buy the author a coffee](https://buymeacoffee.com/damiannass88). Donations are voluntary and buy no
support, warranty or features.

Contributions are welcome: [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: [.github/SECURITY.md](.github/SECURITY.md).

## Disclaimer

Provided **"as is", without warranty of any kind** (see [LICENSE](LICENSE)). You are responsible for
your computers, servers, phones, the code your AI agents write and run, the apps you install, and
your use of third-party services (Tailscale, Google, your VPS provider, AI providers) under their
terms. More in [docs/LEGAL.md](docs/LEGAL.md). RemoteAppTester is an independent project. It is not
affiliated with or endorsed by Anthropic, Google, Tailscale or any other company named here.
All trademarks belong to their owners.
