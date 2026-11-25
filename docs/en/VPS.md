# A VPS for RemoteAppTester and an AI agent (example: Contabo)

🇵🇱 [Wersja polska](../VPS.md)

A VPS is a rented Linux computer on the internet that runs all the time. RemoteAppTester and the
AI agent run there, and you control everything from your phone. Your home computer can stay off,
and the agent has no access to your private files.

We use **Contabo** as the example. Other providers (Hetzner, OVH, netcup, DigitalOcean…) work the
same way. Plan names, prices and control panels change, so check them on the provider's website.

> **Easiest way:** go through this together with an AI chat. Paste
> [prompt 1](PROMPTS.md#1-preparing-and-securing-a-vps) first, then
> [prompt 2](PROMPTS.md#2-installing-remoteapptester-on-a-linux-server). The chat explains every
> command and stops before risky steps.

## Before you start: responsibility

- **You are the administrator of this server.** The provider gives you the machine. Securing it and
  what runs on it are your responsibility, under the provider's terms (e.g. no spam, crypto mining
  or scanning other people's networks).
- **A server on the internet is attacked from the first minute** by bots guessing passwords. That is
  why the first step is securing the login (section 3).
- **Personal data:** if your app will store other people's data, choose an EU data centre and keep
  GDPR in mind.
- **Costs** keep running as long as the server exists, even when it is switched off. Cancel it in the
  provider's panel when you stop using it.

## 1. Which server to choose

| Parameter | Minimum | Recommended | Why |
|---|---|---|---|
| CPU | x86_64 (AMD/Intel), 2 cores | 4+ cores | Google's Android build tools exist only for x86_64, so ARM is out |
| RAM | 4 GB | 8 GB or more | Android builds and an AI agent use a lot of memory |
| Disk | 40 GB | 75 GB+ (SSD/NVMe preferred) | Flutter, the Android SDK and build copies take about 15 GB |
| System | Ubuntu 22.04 | **Ubuntu 24.04 LTS** | best tested |
| Location | any | closest to you, in the EU | lower latency, GDPR |

At Contabo choose a regular **Cloud VPS** (not "Storage") with the **Ubuntu 24.04** image. When
ordering, set a strong root password (save it in a password manager). If you know how, add an SSH
key right away. After a few minutes you get an e-mail with the server's **IP address**.

## 2. First login

On your computer open a terminal (Windows: **Terminal** or **PowerShell**; macOS/Linux: Terminal):

```sh
ssh root@IP_ADDRESS
```

| Command | What it does |
|---|---|
| `ssh root@IP_ADDRESS` | connects to the server as administrator (`root`); on the first connection confirm the server's fingerprint with `yes` |

It also works from a phone with an SSH app (e.g. Termius, JuiceSSH), but a computer is more comfortable.

**Lifeline:** if you lock yourself out (e.g. after changing SSH settings), the Contabo panel has a
**VNC** console and a **Rescue** mode. They work without SSH.

## 3. Securing the server (the most important part)

[Prompt 1](PROMPTS.md#1-preparing-and-securing-a-vps) does these steps with you. Here is what is
done and why:

| Step | Commands (example) | Why |
|---|---|---|
| Update the system | `apt update && apt full-upgrade -y` | security patches |
| Automatic patches | `apt install -y unattended-upgrades` | the system installs security fixes by itself |
| Your own admin account | `adduser jan` and `usermod -aG sudo jan` | you do not work as `root` |
| Key-based login | on your computer: `ssh-keygen -t ed25519`, then `ssh-copy-id jan@IP_ADDRESS` | a key cannot be guessed like a password |
| No password or root login | in `/etc/ssh/sshd_config`: `PasswordAuthentication no`, `PermitRootLogin no`, then `systemctl reload ssh` | no more password guessing; **first check in a second window that key login works** |
| Firewall | `ufw allow OpenSSH` and `ufw enable` | blocks everything except SSH; RemoteAppTester only works inside Tailscale anyway |
| (optional) Brute-force protection | `apt install -y fail2ban` | blocks addresses that repeatedly try to log in |
| (optional) Swap, if RAM < 8 GB | `fallocate -l 4G /swapfile` … | spare memory for builds |

> SSH settings can be overridden by files in `/etc/ssh/sshd_config.d/` (Contabo and cloud images
> often have them). The AI chat in prompt 1 checks this on your system.

**Even safer (optional):** after installing Tailscale you can log in through Tailscale
(`ssh jan@server-name`) and close the public SSH port (`ufw delete allow OpenSSH`). The server then
accepts no connections from the internet at all. Do this only once login through Tailscale works,
because if something goes wrong only the VNC console is left.

## 4. Installing RemoteAppTester

1. **Download the package** `RemoteAppTester-linux-<version>.tar.gz` and its `.sha256` file from the
   repository's **Releases** page on GitHub. On the server:

   ```sh
   curl -LO https://github.com/damiannass88/RemoteAppTester/releases/download/v<VERSION>/RemoteAppTester-linux-<VERSION>.tar.gz
   curl -LO https://github.com/damiannass88/RemoteAppTester/releases/download/v<VERSION>/RemoteAppTester-linux-<VERSION>.tar.gz.sha256
   sha256sum -c RemoteAppTester-linux-<VERSION>.tar.gz.sha256
   ```

   Or copy the file from your computer: `scp RemoteAppTester-linux-<VERSION>.tar.gz jan@IP_ADDRESS:~`.

   | Command | What it does |
   |---|---|
   | `curl -LO <address>` | downloads a file into the current folder |
   | `sha256sum -c …` | checks the file is not damaged or tampered with (should say `OK`) |
   | `scp file jan@IP:~` | copies a file from your computer to your home folder on the server |

2. **Install:**

   ```sh
   tar xzf RemoteAppTester-linux-<VERSION>.tar.gz
   cd RemoteAppTester-linux-<VERSION>
   sudo bash install.sh
   ```

   The installer checks file checksums and creates a `remoteapptester` service account without
   administrator rights. It installs the program, Flutter, the Android SDK and Tailscale, starts the
   service, and finally shows a **QR code to scan with your phone**. It takes 10–20 minutes. It opens
   no ports and does not change the firewall. Details and options:
   [host/deploy/linux/README.md](../../host/deploy/linux/README.md) (PL).

   - When a **Tailscale login link** appears, open it and sign in with the same account as on the phone.
   - The installer asks whether you accept the Android SDK licences (Google software). Read them:
     https://developer.android.com/studio/terms. Without consent, Android builds will not work.
     You can consent later: `sudo bash install.sh --accept-android-licenses`.
   - In the Tailscale admin panel (Machines → server → **Disable key expiry**), so the server does not
     sign out after a few months.

3. **Check:** `sudo rt dr` (diagnostics; everything should be `[OK]`).

## 5. An account for the AI agent

The AI agent gets a **separate account without `sudo`** that can only reach the project folders:

```sh
sudo adduser agent
sudo bash install.sh --add-user agent
```

| Command | What it does |
|---|---|
| `sudo adduser agent` | creates a regular `agent` account (asks for a password; save it) |
| `sudo bash install.sh --add-user agent` | adds the account to the group that can write in `/srv/remoteapptester/projects` and use `rt sg`, `rt push`, `rt st` |

[Prompt 4](PROMPTS.md#4-ai-agent-claude-code-on-a-vps) sets up the agent (e.g. Claude Code with Remote Control).

**Never give the agent account `sudo`**, and never store passwords, production signing keys or tokens
for important accounts in its folder.

## 6. Maintenance

| What | How often | How |
|---|---|---|
| System updates | automatic + manually once a month | `sudo apt update && sudo apt full-upgrade`, then `sudo reboot` if needed |
| RemoteAppTester update | when a new version is out | new package → `sudo bash install.sh` (data is kept) |
| Backups | regularly | project code in a git repository; a server snapshot in the Contabo panel |
| Service status | when something does not work | `systemctl status remoteapptester`, `journalctl -u remoteapptester -n 100` |
| Disk space | once a month | `df -h` |

## 7. Cancelling

1. `sudo bash install.sh --uninstall --purge` removes the program, data and projects. Back up your projects first!
2. Remove the server from Tailscale (admin panel → Machines).
3. Cancel the service in the Contabo panel. Just switching the server off does not stop the charges.
