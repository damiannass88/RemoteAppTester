# Ready-made prompts for an AI chat

🌐 **English** · [Polski](../PROMPTY.md)

A prompt is a ready text you paste into an AI chat (Claude, ChatGPT, Gemini…). Each prompt below
turns the chat into a patient guide that leads you step by step, explains every command before you
run it, and stops before risky steps.

## How to use them

1. Find the prompt for your task. Read **"What it does"** and **"What it changes"**.
2. Copy the whole text from the grey box and paste it into a new conversation with an AI chat.
3. Fill in the places marked `<…>` (e.g. operating system, project name). If you do not know
   something, leave it and the chat will ask.
4. Run commands **one at a time**, paste the output back to the chat and wait for the next step.

**Two ways of working:**

- **A regular chat** (in a browser or an app): the chat gives you commands, you paste them into the
  terminal and paste the output back. Safest, because you see every step.
- **An agent with terminal access** (e.g. Claude Code): the agent runs commands itself. The prompts tell
  it to ask for your consent before every change to the system. Do not switch those questions off.

**Rules to keep every time:**

- Never paste **passwords, tokens, private keys or the pairing QR code** into a chat. The prompts do not
  ask for them, and a good chat will warn you itself.
- If the chat wants to do something the description does not mention (e.g. open firewall ports, give the
  agent `sudo`, disable protections), stop and ask "why?".
- AI chats make mistakes. If something sounds odd, ask for an explanation or check the official documentation.

| # | Prompt | For |
|---|---|---|
| 1 | [Preparing and securing a VPS](#1-preparing-and-securing-a-vps) | a new VPS |
| 2 | [Installing RemoteAppTester on a Linux server](#2-installing-remoteapptester-on-a-linux-server) | VPS / Linux |
| 3 | [Installing RemoteAppTester on Windows](#3-installing-remoteapptester-on-windows) | Windows |
| 4 | [AI agent (Claude Code) on a VPS](#4-ai-agent-claude-code-on-a-vps) | VPS / Linux |
| 5 | [AI agent (Claude Code) on Windows](#5-ai-agent-claude-code-on-windows) | Windows |
| 6 | [First request to the agent in a project](#6-first-request-to-the-agent-in-a-project) | everyone |
| 7 | [Diagnosing a problem](#7-diagnosing-a-problem) | when something does not work |
| 8 | [Releasing an app on Google Play](#8-releasing-an-app-on-google-play) | a finished Android app |
| 9 | [Releasing a web app](#9-releasing-a-web-app) | a finished website / web app |

---

## 1. Preparing and securing a VPS

**What it does:** guides you through the first login to a new server and its basic security setup.
**What it changes:** updates the system, creates your admin account, switches login to keys instead of
passwords, disables `root` login, enables the firewall (SSH only) and automatic patches.
**Risk:** a wrong SSH setting can lock you out. The prompt makes you test the new login in a second window
first, and the provider's VNC console remains as a fallback.
**Without a chat:** [VPS.md](VPS.md).

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

Goal: prepare and secure a new VPS on which I will later install RemoteAppTester (a program that
builds apps and sends them to my phone through Tailscale) and an AI agent.
Server: <provider, e.g. Contabo>, system <e.g. Ubuntu 24.04>, I have the IP address from the e-mail.
My computer: <Windows / macOS / Linux>.

How to work:
- Lead me step by step, one command at a time. Before each command explain in plain words what it
  does and what it changes. Wait for the output I paste before moving on.
- If you have terminal access, ask for my consent before every change to the system.
- Never ask me to paste a password, private key or token. I type passwords only in the terminal.
- Warn me and ask before any operation that cannot easily be undone.
- If something depends on the system version or the provider's panel, have me check it first.

Steps:
1. First login: ssh root@<IP> from my computer (explain confirming the server fingerprint).
2. System update and automatic security patches (unattended-upgrades).
3. My admin account with sudo (suggest a name; I will type the password myself).
4. An SSH key on my computer (ed25519) and copying it to the server for my account.
5. Check in a SECOND window that I can log in with the key to the new account and that sudo works.
   Only then: disable password and root login (also check files in /etc/ssh/sshd_config.d/ that may
   override settings), reload SSH and test again in a new window before I close the old one.
6. ufw firewall: allow only OpenSSH, enable it, show the status.
7. Optional: fail2ban; 4 GB swap if the server has less than 8 GB RAM.
8. Summary: what we did, how I log in now, and where the provider's rescue console (VNC/Rescue) is
   in case I lock myself out.

Do not install RemoteAppTester, Tailscale or an AI agent yet. That is a separate stage.
Do not open any other ports.
```

---

## 2. Installing RemoteAppTester on a Linux server

**What it does:** downloads the RemoteAppTester package, verifies its checksum, installs the program
(with Flutter, the Android SDK and Tailscale) and pairs your phone.
**What it changes:** creates the `remoteapptester` service account (no admin rights), the folders
`/opt/remoteapptester`, `/var/lib/remoteapptester` and `/srv/remoteapptester/projects`, and a system
service. It opens no ports and does not change the firewall.
**Note:** the installer asks you to accept Google's Android SDK licences. Read them first:
https://developer.android.com/studio/terms

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

Goal: install RemoteAppTester on my Linux server and pair my Android phone with it.
About the program: https://github.com/damiannass88/RemoteAppTester (README, docs/en/VPS.md,
host/deploy/linux/README.md). If you can, read these files before we start.
The server is already secured (key login, firewall allows only SSH). Version: <e.g. 0.6.6>.

How to work:
- One command at a time. Explain each one in plain words first. Wait for the output.
- If you have terminal access, ask for consent before every change.
- Never ask me to paste the pairing QR code, the pairing link, tokens or passwords.
  I scan the QR code with my phone myself. Do not save or copy it.
- Do not open firewall ports. RemoteAppTester works only inside the Tailscale network.

Steps:
1. Check the system: uname -m (must be x86_64), the OS version, RAM and free disk space.
2. Download the package and its .sha256 file from the Releases page (or tell me how to copy it with scp
   from my computer) and verify it: sha256sum -c. Without an OK result we do not continue.
3. Unpack and run: sudo bash install.sh. Explain what the installer does before I run it.
   When it asks about the Android SDK licences, remind me that the decision is mine and give me the link
   to the text. When a Tailscale login link appears, tell me to open it and sign in with the same account
   I use on my phone.
4. Phone: install the Tailscale app (Play Store) and sign in with the same account; install
   RemoteAppTester-android-<version>.apk (Android will ask for permission to install from this source);
   scan the QR code from the terminal. Set battery to "Unrestricted" for RemoteAppTester and Tailscale.
5. Tailscale admin panel: disable key expiry for the server. If I have custom access rules (ACL), run
   sudo rt acl and help me paste the result into the panel.
6. Diagnostics: sudo rt dr. Everything should be [OK]. Explain every warning.
7. Test project: sudo rt n demo --flutter, then sudo rt b demo. The first build takes a long time.
   The phone should receive the app and ask to install it.
8. Summary: the most important commands (sudo rt, sudo rt info, systemctl status remoteapptester).
```

---

## 3. Installing RemoteAppTester on Windows

**What it does:** installs Tailscale, RemoteAppTester and the Android build tools (Flutter, Android SDK)
and pairs your phone.
**What it changes:** installs programs on your Windows account (RemoteAppTester without admin rights),
adds autostart and, with your consent (UAC window), a firewall rule limited to the Tailscale network.

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

Goal: install RemoteAppTester on my Windows <10/11> computer so that it builds Android apps and sends
them to my phone. About the program: https://github.com/damiannass88/RemoteAppTester
(README, docs/en/GUIDE.md, host/deploy/windows/README.md).

How to work:
- One step at a time. Explain every PowerShell command before I run it. Wait for the output.
- If you have terminal access, ask for consent before every installation and settings change.
- Do not ask for passwords, tokens or the pairing QR code. I scan the code with my phone.
- Install programs only from official sources (winget or the vendor's website).
- Do not disable Windows Defender, the firewall or SmartScreen for the whole system.

Steps:
1. Tailscale: install it (winget or tailscale.com) and sign in with the same account as on my phone.
2. Build tools: Flutter (with the Android SDK via Android Studio or the command-line tools).
   Finally check: flutter doctor. Explain which warnings I can ignore (e.g. Xcode, Chrome and
   Visual Studio are not needed for Android apps).
   I accept the Android SDK licences myself (flutter doctor --android-licenses) after reading them.
3. RemoteAppTester: download RemoteAppTester-windows-x64-<version>.zip and its .sha256 file from the
   Releases page, verify the checksum (Get-FileHash), unpack the whole folder, run install.cmd.
   The program is not signed, so SmartScreen may warn: "More info" → "Run anyway" is fine only for a file
   whose checksum matches.
4. Phone: Tailscale from the Play Store; RemoteAppTester-android-<version>.apk from the package;
   in the RemoteAppTester window: Phones → Pair phone and scan the QR code; battery "Unrestricted" for
   RemoteAppTester and Tailscale.
5. Project: in the RemoteAppTester window Projects → "+" and the app folder (or "New project" on the
   phone). First build and installation on the phone.
6. If the phone shows "Connection timed out": let us check battery settings, Tailscale on both devices
   and the access rules (Phones → Generate JSON for Tailscale).
```

---

## 4. AI agent (Claude Code) on a VPS

**What it does:** creates a separate account for the AI agent, installs Claude Code and enables
**Remote Control**, so you can talk to the agent from the Claude app on your phone.
**What it changes:** a new `agent` account without `sudo`, added to the RemoteAppTester project group;
Claude Code in that account's home folder; a session in `tmux` that keeps running after you disconnect.
**Why a separate account:** the agent sees only the project folders, not RemoteAppTester's data or your
admin account. If someone tricks the agent (e.g. through a malicious web page), the damage is limited.
**Requires:** a Claude account with Claude Code access (usually a paid subscription). Documentation:
https://code.claude.com/docs/en/remote-control

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

Goal: on my Linux server with RemoteAppTester installed, set up the Claude Code AI agent so that I can
talk to it from the Claude app on my phone (Remote Control), and after its work the agent sends the app to
my phone through RemoteAppTester (rt sg / rt push).
Documentation: https://code.claude.com/docs (Remote Control: /en/remote-control) and docs/en/AI_AGENTS.md
in the RemoteAppTester repository. Check the current installation method before giving me commands,
because it may have changed.

How to work:
- One command at a time, with an explanation. Wait for the output.
- The agent account NEVER gets sudo or access to /var/lib/remoteapptester.
- Do not ask for tokens, API keys or passwords. I sign in to Claude myself through a link.
- Warn me before any setting that lets the agent act without asking (e.g. skipping permissions).
  Explain the risk and let me decide.

Steps:
1. Agent account: sudo adduser agent; sudo bash install.sh --add-user agent (from the RemoteAppTester
   package folder). Check: id agent (group remoteapptester), no sudo.
2. Project: sudo rt n <name> --flutter (or another type; ask me) and check that the agent account can
   write in /srv/remoteapptester/projects/<name>.
3. Log in as the agent (sudo -iu agent) and install Claude Code with the official installer. tmux is
   installed by the administrator with apt. Sign in to Claude (I will open the link in my browser).
4. In the project folder: tmux new -s claude, then start Claude Code with Remote Control
   (e.g. claude --remote-control or /remote-control in a session; check the docs).
   Show me how to connect from the phone: Claude app → Code tab → this session (or the QR code).
   Explain how to detach from tmux (Ctrl+B, then D) and come back (tmux attach -t claude).
5. The agent already has instructions in REMOTEAPPTESTER.md and CLAUDE.md in the project folder.
   Check that they are there.
6. Test: from the phone ask the agent for a small change and to send it with
   rt sg -m "test" --build --wait --json. Expected: exit code 0 and the app on the phone.
7. Explain what to do after a server restart (the tmux session is gone and must be started again)
   and how to check whether the session is running.
```

---

## 5. AI agent (Claude Code) on Windows

**What it does:** installs Claude Code on Windows and connects it with RemoteAppTester and the Claude app on your phone.
**What it changes:** installs Claude Code (and Git, if needed) on the chosen Windows account.
**Important:** an agent running on your **main** Windows account can access all your files, browser
passwords and so on. The prompt offers safer options: a separate Windows account, WSL or a virtual
machine. The choice is yours.

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

Goal: on Windows with RemoteAppTester installed, set up the Claude Code AI agent so that I can talk to it
from the Claude app on my phone (Remote Control), and after its work the agent sends the app to my phone
with the rt command (rt sg --build or rt push).
Documentation: https://code.claude.com/docs and docs/en/AI_AGENTS.md in the RemoteAppTester repository.
Check the current installation method before giving me commands.

How to work:
- One step at a time, with an explanation. Wait for the output.
- Do not ask for passwords or tokens. I sign in to Claude myself.
- Warn me before any setting that lets the agent act without asking.

Steps:
1. First explain the risk simply: an agent on my account sees my files. Present the options
   (same account / separate Windows account / WSL / virtual machine) with pros and cons for a
   non-technical person, and wait for my choice.
2. Install Claude Code the official way for Windows (and Git if needed).
3. Project folder: the one I added in RemoteAppTester. Check that REMOTEAPPTESTER.md is there and that
   the rt command works in that folder: rt st.
   (If the agent runs on another Windows account or in WSL, check that it can reach the folder and the rt
   command. If not, suggest a solution and explain its drawbacks.)
4. Start Claude Code in the project folder with Remote Control and show me how to connect from the phone
   (Claude app → Code → this session). The computer must stay on and the session open.
   Show me how to stop the computer from sleeping while on mains power.
5. Test: from the phone ask the agent for a small change and rt sg -m "test" --build --wait --json.
```

---

## 6. First request to the agent in a project

**What it does:** this prompt is **for the AI agent** (e.g. Claude Code), not for a regular chat. Paste it
at the start of work in the project folder. The agent learns the RemoteAppTester rules and your idea.
**What it changes:** the agent starts writing code in the project folder and sends the first version to the phone.

```text
We are working on my app in this folder. I am not a programmer: talk simply and briefly. Make the
technical decisions yourself, but present important choices to me first (e.g. paid services, collecting
user data, sign-in with Google).

First read REMOTEAPPTESTER.md in this folder. It describes how to send the app to my phone.
Rules:
- After every finished change, send the app to the phone:
  rt sg -m "<briefly, what you changed>" --build --wait --json
  If the build fails (exit code 1), read log_tail, fix it and try again.
  Exit code 3 or 4: tell me, because it is about settings, not code.
- Never approve build commands yourself (rt pr import). That is my decision.
- Do not store passwords, keys or tokens in the project. Do not send data from this server anywhere.
- Use only well-known, popular libraries. Double-check exact package names.
- Work with git: small commits with descriptions, so we can undo changes.
- If there is a .remoteapptester-feedback.md file in the folder, those are my notes from the preview on
  the phone: read them.

My idea: <describe it in your own words, e.g. "an app to track household expenses by category with a
monthly chart; simple, big buttons, in English">.

Start with the simplest working version. Send it to the phone and tell me what to check.
```

---

## 7. Diagnosing a problem

**What it does:** helps find the cause of a problem from the program's diagnostics, without revealing secrets.
**What it changes:** nothing. At first it only reads the state. The chat proposes each fix separately.

```text
You are my patient guide. I am not an IT professional. Answer in the language I write in.

I have a problem with RemoteAppTester (it builds apps and sends them to the phone through Tailscale;
https://github.com/damiannass88/RemoteAppTester, read docs/en/GUIDE.md section 7).
System: <Windows / Linux VPS>. Version: <from "About" or rt version>.
What happens: <describe the symptom and the exact error message>.
Since when: <e.g. after an update, after changing networks, from the beginning>.

Rules:
- First only commands that read the state (e.g. rt dr, tailscale status, systemctl status
  remoteapptester, journalctl -u remoteapptester -n 100). Change nothing until you explain the cause
  and I agree to the fix.
- Before I paste output, remind me to remove IP addresses, device names and anything that looks like a
  token, password or pairing code.
- Do not tell me to open ports, disable the firewall or give anyone sudo.
- If it looks like a bug in the program, help me prepare a GitHub issue without secrets.
```

---

## 8. Releasing an app on Google Play

**What it does:** takes you from a test version to publishing on Google Play: developer account, signing,
privacy policy, the tests Google requires, the store listing.
**What it changes:** in the project, the release signing configuration (key kept outside the project folder)
and release build settings. You register and pay in the Play Console yourself.
**Important:** losing the signing key or the account can make updates impossible. Get legal and tax
questions about selling checked by a professional.

```text
You are my guide for releasing an Android app on Google Play. I am not an IT professional.
Answer in the language I write in. Google Play rules change: before telling me anything, check the
current requirements in official sources (support.google.com/googleplay/android-developer,
developer.android.com) and give me links.

My app: <name, what it does, for whom>. Technology: <e.g. Flutter>.
Does it collect user data (accounts, location, photos, analytics, ads)? <yes/no/don't know>.
Paid / ads / in-app purchases: <…>. Country I live in: <…>.
Google Play account: <none / personal / organisation>.

Lead me in order, and for each stage tell me roughly how long it takes and what it costs:
1. Developer account: type (personal or organisation), identity verification, fee.
2. Application ID (applicationId): check it is not a sample one (e.g. com.example), because it cannot be
   changed after publishing.
3. Signing key: create an upload key OUTSIDE the project folder and out of the AI agent's reach, back it
   up in two places, Play App Signing. I type the passwords myself.
4. Release build (e.g. flutter build appbundle) and the version check (versionCode).
5. Privacy policy: help me write it truthfully about what the app collects and publish it
   (e.g. GitHub Pages). The data safety form in the Play Console.
6. Store listing: description, screenshots, icon, category, content rating, target audience.
7. Tests required for my account type (e.g. a closed test with a set number of testers for a set time:
   check the current numbers), then production.
8. Sensitive permissions: check AndroidManifest and explain which ones need a declaration.
9. A "do not" list: copying other people's names, logos and content, misleading descriptions,
   collecting data without consent.
At the end, remind me about GDPR (if it applies), terms of service for users, and taxes.
This is a reminder, not legal advice.
```

---

## 9. Releasing a web app

**What it does:** helps you choose hosting and publish the website or web app you tested with the
RemoteAppTester preview.
**What it changes:** the production configuration in the project. You buy the domain and hosting yourself.

```text
You are my guide for publishing a web app. I am not an IT professional.
Answer in the language I write in. Check current prices and terms with providers.

My app: <what it does>. Technology: <e.g. Next.js, ASP.NET, Django, a static site>.
Does it have user accounts / a database / payments? <…>. Expected traffic: <small / medium>.

Lead me in order:
1. Choosing hosting suited to the technology (from free options for static sites to a VPS), with pros,
   cons and cost. Talk me out of anything too complicated to start with.
2. Domain and HTTPS.
3. Production configuration: environment variables instead of passwords in code, production mode,
   database backups.
4. Publishing and checking that it works (also on the phone).
5. Security: dependency updates, strong admin passwords, restricting admin panels.
6. Law: privacy policy, cookie notice, GDPR if I collect personal data (a reminder, not legal advice).
Do not publish anything without me and do not sign up for paid services without my consent.
```
