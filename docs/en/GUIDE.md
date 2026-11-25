# Guide: working with RemoteAppTester from scratch

🇵🇱 [Wersja polska](../PORADNIK.md)

Who this is for: you have an idea for an app, you want to build it with the help of artificial
intelligence, and you are not an IT professional. This guide explains how it works, what you need
and how to start. You will do the harder steps together with an AI chat, using our
[ready-made prompts](PROMPTS.md).

> Tools, prices and terms change quickly (this text: November 2026). If something looks different
> from what is described here, ask the AI chat for the current way or check the provider's website.

## 1. The idea: three separate parts

| Part | What it does | Example |
|---|---|---|
| **AI agent** | writes and fixes your app's code as you instruct | Claude Code, Codex, Cursor |
| **RemoteAppTester** | builds the app and delivers it to the phone | this program |
| **Phone** | where you talk to the agent and test the result | Claude app + RemoteAppTester app |

These parts are deliberately separate. The AI agent cannot control RemoteAppTester. It can only
leave a note in the project folder saying "done, please build" (`rt sg --build`). You approve
the build commands. This way a misbehaving or tricked agent cannot take over your computer
through RemoteAppTester.

You can use any agent in any environment where it runs. RemoteAppTester only needs the project
folder on the same computer or server.

## 2. Working from your phone

Example with Claude Code and its Remote Control feature (driving a Claude Code session from the Claude app):

1. A Claude Code session runs on the computer or server, in your project folder.
2. In the **Claude** app on your phone, in the **Code** tab, you open that session and write:
   *"Add a shopping list screen. Each item can be ticked off. When you are done, send the app to
   my phone with rt."*
3. The agent changes the code and finally runs `rt sg -m "Shopping list" --build --wait`.
4. RemoteAppTester builds the app and sends it through Tailscale. The phone asks "Install?"
   (or installs on its own if you choose so) and opens the new version.
5. You test it and go back to the Claude app: *"The button is too small and the list disappears
   when I rotate the phone. Fix it and send it again."*

The computer or server does not need to be near you. It only has to be on and connected to the internet.

**Websites and web apps** work similarly. Instead of installing, press **"Preview"** on the project
screen in RemoteAppTester. The site opens on the phone, and **"Report a problem"** saves your note
(with the browser console) to `.remoteapptester-feedback.md`, which the agent can read.

## 3. What you need

- **An Android phone, version 8 or newer** (12+ recommended). Ideally a separate test phone
  without private data. iPhone is not supported yet (see section 9).
- **A computer that can stay on**, in one of these setups:

  | Setup | Pros | Cons |
  |---|---|---|
  | **A. Your Windows PC** | no extra cost, windowed app | must stay on; an AI agent on your account sees your files (see section 6) |
  | **B. A rented Linux VPS** (e.g. Contabo) | runs 24/7, separated from your private files | monthly cost, terminal only (an AI chat will help): [VPS.md](VPS.md) |
  | **C. A Linux computer** | like B, but at home | needs basic Linux skills |

- **A free [Tailscale](https://tailscale.com) account**, the same on the computer and the phone.
  Tailscale creates a private network of only your devices, so nothing has to be opened to the internet.
- **An account with an AI agent provider**, e.g. a Claude subscription that includes Claude Code.
  It is usually a paid service. Check current pricing and limits.
- **Build tools.** On a Linux server the RemoteAppTester installer sets up Flutter and the Android SDK
  itself. On Windows you install them yourself, and the installation prompt walks you through it.

## 4. First setup, step by step

Each step has a ready-made prompt in [PROMPTS.md](PROMPTS.md). Paste it into an AI chat, and the chat
will explain every command before you run it.

1. **Tailscale** on the phone and the computer/server, signed in with the same account.
2. **RemoteAppTester:**
   - Windows: [prompt 3](PROMPTS.md#3-installing-remoteapptester-on-windows) and [instructions](../../host/deploy/windows/README.md) (PL);
   - VPS: first [prompt 1 (securing the server)](PROMPTS.md#1-preparing-and-securing-a-vps),
     then [prompt 2](PROMPTS.md#2-installing-remoteapptester-on-a-linux-server).
3. **Phone app:** install `RemoteAppTester-android-<version>.apk`. Android asks for permission to
   install from an unknown source, because the app does not come from a store. Scan the pairing QR
   code from the computer.
4. **Battery:** Settings → Apps → RemoteAppTester (and Tailscale) → Battery → **"Unrestricted"**.
   Without it some phones (e.g. Xiaomi) drop the connection.
5. **App lock:** on first start the app asks for your fingerprint. If the phone has no fingerprint,
   the app shows how to add one.
6. **Project:** on the phone "New project" (Flutter or an empty folder), or on the computer
   "Projects → +". Build commands are filled in automatically.
7. **AI agent:** [prompt 4 (VPS)](PROMPTS.md#4-ai-agent-claude-code-on-a-vps) or
   [prompt 5 (Windows)](PROMPTS.md#5-ai-agent-claude-code-on-windows).
8. **Your first app:** send [prompt 6](PROMPTS.md#6-first-request-to-the-agent-in-a-project) to the agent in the project folder.

## 5. Settings worth knowing

| Where | Setting | Why |
|---|---|---|
| Project → Options | **Install: ask / automatic / off** | "ask" is the safe choice to start with |
| Project → Options | **Agent signal starts a build** | off: the agent's signal only marks "new changes" |
| Project → Options | **AI agent may send its own APK** (`rt push`) | turn off if only RemoteAppTester should build |
| Project → Commands | **Approve the agent's proposal** | the agent can only propose commands in `REMOTEAPPTESTER.md`; you approve them after reading |
| Phone → Settings | **App lock** | fingerprint on start and after returning from background; turning it off needs your fingerprint |
| Computer → Phones | **Revoke** | cut off a lost phone immediately |

## 6. Safe habits (the most important part)

1. **The AI agent should not have access to your private files.** On a VPS the agent gets a separate
   account without `sudo`. On Windows, ideally a separate Windows account, a virtual machine or WSL.
   An agent running on your account sees everything you can see.
2. **Read what you approve.** When RemoteAppTester shows "The agent proposed new commands", read them,
   or ask an AI chat to explain them, before you click "Approve".
3. **Test on a phone without private data** (or in a work profile). The tested app is code that
   nobody has reviewed carefully.
4. **Treat the pairing QR code like a password.** Do not photograph it or send it by messenger.
5. **Never paste passwords, tokens or QR codes anywhere**, including AI chats and GitHub issues.
6. **Backups:** keep your project code in a git repository (e.g. a private one on GitHub). An AI agent
   can break or delete things.

More: the **Info** tab in the app (also `rt info`) and [SECURITY.md](../SECURITY.md) (PL).

## 7. Common problems

| Symptom | Most common cause | What to do |
|---|---|---|
| Phone: "Connection timed out" | battery restrictions, Tailscale off, or Tailscale access rules (ACL) | battery "Unrestricted" for both apps; Tailscale on; rules: `rt acl` or the "Generate JSON for Tailscale" button |
| Phone does not see the computer after changing networks | a short disconnect | wait a few seconds; the app reconnects by itself |
| Build failed | a bug in the code or missing tools | open the log on the phone and paste the last lines to the agent: "The build fails, fix it" |
| Agent: `rt: command not found` or exit code 3 | the RemoteAppTester service is not running, or the agent's account is not in the group | `sudo systemctl status remoteapptester`; `sudo bash install.sh --add-user <account>` |
| Agent: exit code 4 | nobody received the version | install option "off", or no phone selected in the project options |
| "Installation blocked" on the phone | no permission to install apps | Settings → Apps → RemoteAppTester → "Install unknown apps" |
| Fingerprint locked after several tries | Android sensor lockout | unlock with your phone PIN |

If nothing helps, use [prompt 7 (diagnosis)](PROMPTS.md#7-diagnosing-a-problem). If it is a bug in the
program, report it on GitHub, without secrets: [bug report](../../.github/ISSUE_TEMPLATE/bug_report.md).

## 8. From testing to release

RemoteAppTester sends **test versions** (debug). To make your app available to others you need:

- **Google Play:** a developer account (one-time fee), identity verification, your own signing key
  (do not lose it!), a privacy policy, the data safety form, and for new personal accounts a closed
  test with a group of testers before going public. The rules change.
- **A website or web app:** hosting, a domain, an HTTPS certificate, and a privacy and cookie policy
  if you collect data.
- **Law:** if the app processes personal data (e.g. user accounts), data protection law applies
  (in the EU: GDPR). Selling it brings taxes and terms of service.

[Prompt 8 (Google Play)](PROMPTS.md#8-releasing-an-app-on-google-play) and
[prompt 9 (web)](PROMPTS.md#9-releasing-a-web-app) walk you through it. Do not make legal or tax
decisions based only on an AI chat. If you earn money, check them with a professional.

## 9. What RemoteAppTester does not do (yet)

- It does not build iPhone (iOS) apps and does not run on a Mac. Building for iOS needs a Mac, and the
  author has no Apple hardware to test it properly. Help from Mac users is welcome
  ([CONTRIBUTING.md](../../CONTRIBUTING.md)).
- It does not deliver Windows or Linux programs to the phone. Websites are shown through the preview.
- It does not control the AI agent and has no chat. You talk to the agent in its own app.
- It does not publish to stores. You do that yourself (see section 8).
