#!/usr/bin/env bash
# Instalator RemoteAppTester na serwer Linux (VPS). Działa na dystrybucjach z glibc 2.34+:
# Ubuntu 22.04+, Debian 12+, RHEL/Alma/Rocky 9+, Fedora, openSUSE Leap 15.6+/Tumbleweed, Arch
# i pochodne. Paczka zawiera program dla architektur, dla których ją zbudowano.
#
#   tar xzf RemoteAppTester-linux-<wersja>.tar.gz && cd RemoteAppTester-linux-<wersja>
#   sudo bash install.sh [opcje]
#
# Opcje:
#   --port <port>          Port w sieci Tailscale (domyślnie 47051).
#   --phone-name <nazwa>   Nazwa pierwszego telefonu.
#   --add-user <login>     Dodaj użytkownika do grupy projektów (praca agentów AI w folderach).
#   --skip-flutter         Bez Fluttera i Android SDK (zainstalujesz sam).
#   --accept-android-licenses  Akceptuj licencje Android SDK bez pytania (instalacja bez terminala).
#   --skip-tailscale       Bez Tailscale (np. masz własną konfigurację).
#   --no-login             Nie loguj do Tailscale; tylko instrukcje.
#   --no-service           Bez usługi (uruchamiasz sam: rt s).
#   --no-pair              Bez parowania telefonu na końcu.
#   --uninstall            Usuń program i usługę (dane i projekty ZOSTAJĄ).
#   --purge                Z --uninstall: usuń też dane, projekty i użytkownika.
#
# Klucz logowania Tailscale do instalacji bez terminala podawaj w zmiennej TS_AUTHKEY.
#
# Zasady (docs/SECURITY.md):
#   - root tylko do pakietów, użytkownika i usługi; program i buildy działają jako
#     nieuprzywilejowany użytkownik "remoteapptester" bez sudo;
#   - każdy plik programu jest sprawdzany sumą SHA-256 przed instalacją;
#   - serwer nasłuchuje wyłącznie na adresie Tailscale; instalator NIE otwiera portów
#     i NIE zmienia zapory ani SSH;
#   - ponowne uruchomienie = aktualizacja, bez utraty danych i sparowanych telefonów.
set -euo pipefail

HOST_VERSION="0.6.6"
APP_USER="remoteapptester"
APP_HOME="/var/lib/remoteapptester"
PROJECTS="/srv/remoteapptester/projects"
INSTALL_DIR="/opt/remoteapptester"
SERVICE="remoteapptester"

case "${LC_ALL:-${LANG:-}}" in pl*) PL=1 ;; *) PL=0 ;; esac
# m "polski" "english"
m() { if [ "$PL" -eq 1 ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'; else B=""; G=""; Y=""; R=""; N=""; fi
step() { printf '\n%s==> %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '%s  ✓ %s%s\n' "$G" "$*" "$N"; }
warn() { printf '%s  ! %s%s\n' "$Y" "$*" "$N"; }
die()  { printf '%s  ✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
have_tty() { [ -r /dev/tty ] && [ -w /dev/tty ] && ( : </dev/tty ) 2>/dev/null; }

opt_port=47051; opt_phone="$(m 'Mój telefon' 'My phone')"; opt_add_user=""
opt_skip_flutter=0; opt_skip_tailscale=0; opt_no_login=0; opt_no_service=0; opt_no_pair=0
opt_uninstall=0; opt_purge=0; opt_accept_licenses=0
while [ $# -gt 0 ]; do
  case "$1" in
    --port) opt_port="$2"; shift 2 ;;
    --phone-name) opt_phone="$2"; shift 2 ;;
    --add-user) opt_add_user="$2"; shift 2 ;;
    --skip-flutter) opt_skip_flutter=1; shift ;;
    --accept-android-licenses) opt_accept_licenses=1; shift ;;
    --skip-tailscale) opt_skip_tailscale=1; shift ;;
    --no-login) opt_no_login=1; shift ;;
    --no-service) opt_no_service=1; shift ;;
    --no-pair) opt_no_pair=1; shift ;;
    --uninstall) opt_uninstall=1; shift ;;
    --purge) opt_purge=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "$(m 'Nieznana opcja' 'Unknown option'): $1 (--help)" ;;
  esac
done
[[ "$opt_port" =~ ^[0-9]+$ ]] && [ "$opt_port" -ge 1 ] && [ "$opt_port" -le 65534 ] || die "$(m 'Nieprawidłowy port' 'Invalid port'): $opt_port"
[ "$(id -u)" -eq 0 ] || die "$(m 'Uruchom jako administrator: sudo bash install.sh' 'Run as administrator: sudo bash install.sh')"

has_systemd() { command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; }
has_openrc() { command -v rc-service >/dev/null 2>&1 && [ -d /etc/init.d ]; }

# ---------------------------------------------------------------- deinstalacja
if [ "$opt_uninstall" -eq 1 ]; then
  step "$(m 'Usuwanie RemoteAppTester' 'Removing RemoteAppTester')"
  if has_systemd; then
    systemctl disable --now "$SERVICE" 2>/dev/null || true
    rm -f "/etc/systemd/system/$SERVICE.service"
    systemctl daemon-reload 2>/dev/null || true
  elif has_openrc; then
    rc-service "$SERVICE" stop 2>/dev/null || true
    rc-update del "$SERVICE" default 2>/dev/null || true
    rm -f "/etc/init.d/$SERVICE"
  fi
  rm -f /usr/local/bin/rt /usr/local/bin/remoteapptester
  rm -rf "$INSTALL_DIR"
  ok "$(m 'Usunięto program i usługę.' 'Program and service removed.')"
  if [ "$opt_purge" -eq 1 ]; then
    userdel "$APP_USER" 2>/dev/null || true
    groupdel "$APP_USER" 2>/dev/null || true
    rm -rf "$APP_HOME" /srv/remoteapptester
    ok "$(m "Usunięto dane, projekty i sparowania ($APP_HOME, /srv/remoteapptester)." "Removed data, projects and pairings ($APP_HOME, /srv/remoteapptester).")"
  else
    warn "$(m "Dane i projekty zostały w $APP_HOME i $PROJECTS (usuń: --uninstall --purge)." "Data and projects stay in $APP_HOME and $PROJECTS (remove: --uninstall --purge).")"
  fi
  warn "$(m 'Tailscale zostaje; to osobny program.' 'Tailscale stays; it is a separate program.')"
  exit 0
fi

# ---------------------------------------------------------------- system
step "$(m 'Sprawdzanie systemu' 'Checking the system')"
os_name="Linux"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  os_name="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-${ID:-Linux}}")"
fi
ok "$os_name"
case "$(uname -m)" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) die "$(m 'Nieobsługiwana architektura' 'Unsupported architecture'): $(uname -m) (x86_64, aarch64)" ;;
esac
ok "$(m 'Architektura' 'Architecture'): $(uname -m)"
if ldd --version 2>&1 | grep -qi musl || ls /lib/ld-musl-* >/dev/null 2>&1; then
  die "$(m 'Ten system używa biblioteki musl (np. Alpine). RemoteAppTester, Flutter i narzędzia Androida wymagają glibc: wybierz np. Debian lub Ubuntu.' 'This system uses musl (e.g. Alpine). RemoteAppTester, Flutter and the Android tools require glibc: choose e.g. Debian or Ubuntu.')"
fi
glibc=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
if [ -n "$glibc" ] && [ "$(printf '%s\n2.34\n' "$glibc" | sort -V | head -1)" != "2.34" ]; then
  die "$(m "Ten system ma glibc $glibc, a szyfrowana baza wymaga 2.34 lub nowszej (Ubuntu 22.04+, Debian 12+, RHEL/Alma/Rocky 9+)." "This system has glibc $glibc; the encrypted database requires 2.34 or newer (Ubuntu 22.04+, Debian 12+, RHEL/Alma/Rocky 9+).")"
fi
mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
disk_gb=$(df -Pk / | awk 'NR==2 {print int($4/1024/1024)}')
[ "$mem_mb" -ge 3500 ] && ok "RAM: ${mem_mb} MB" || warn "RAM: ${mem_mb} MB — $(m 'budowanie aplikacji Android zaleca min. 4 GB (lub swap).' 'building Android apps recommends at least 4 GB (or swap).')"
[ "$disk_gb" -ge 15 ] && ok "$(m 'Wolne miejsce' 'Free space'): ${disk_gb} GB" || warn "$(m 'Wolne miejsce' 'Free space'): ${disk_gb} GB — $(m 'Flutter i Android SDK potrzebują ok. 15 GB.' 'Flutter and the Android SDK need about 15 GB.')"
if [ "$ARCH" = "arm64" ] && [ "$opt_skip_flutter" -eq 0 ]; then
  warn "$(m 'Narzędzia Google do budowania Androida są publikowane dla x86_64: na arm64 budowanie APK może wymagać dodatkowej konfiguracji.' 'Google publishes Android build tools for x86_64: on arm64 building APKs may need extra setup.')"
fi

# ---------------------------------------------------------------- pakiety
PM=""
for c in apt-get dnf yum zypper pacman; do command -v "$c" >/dev/null 2>&1 && { PM="$c"; break; }; done
pm_install() {
  case "$PM" in
    apt-get) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@" >/dev/null ;;
    dnf|yum) "$PM" install -y -q "$@" >/dev/null ;;
    zypper) zypper --non-interactive --quiet install --no-recommends "$@" >/dev/null ;;
    pacman) pacman -S --noconfirm --needed --quiet "$@" >/dev/null ;;
    *) return 1 ;;
  esac
}
step "$(m 'Pakiety systemowe' 'System packages')"
ok "$(m 'Menedżer pakietów' 'Package manager'): ${PM:-$(m 'nie rozpoznano' 'not recognised')}"
case "$PM" in
  apt-get) apt-get update -qq >/dev/null; base=(ca-certificates curl git unzip xz-utils zip tar); jdks=(openjdk-17-jdk-headless openjdk-21-jdk-headless default-jdk-headless) ;;
  dnf|yum) base=(ca-certificates curl git unzip xz zip tar shadow-utils util-linux); jdks=(java-17-openjdk-devel java-21-openjdk-devel) ;;
  zypper) zypper --non-interactive --quiet refresh >/dev/null || true; base=(ca-certificates curl git unzip xz zip tar shadow util-linux); jdks=(java-17-openjdk-devel java-21-openjdk-devel) ;;
  pacman) pacman -Sy --noconfirm --quiet >/dev/null; base=(ca-certificates curl git unzip xz zip tar); jdks=(jdk17-openjdk jdk21-openjdk) ;;
  *) base=(); jdks=() ;;
esac
# Najpierw razem; przy konflikcie (np. curl i curl-minimal) pojedynczo: liczy się efekt niżej.
if [ ${#base[@]} -gt 0 ] && ! pm_install "${base[@]}" 2>/dev/null; then
  for p in "${base[@]}"; do pm_install "$p" 2>/dev/null || true; done
fi
missing=()
for c in curl git unzip tar useradd; do command -v "$c" >/dev/null 2>&1 || missing+=("$c"); done
[ ${#missing[@]} -eq 0 ] || die "$(m 'Brakuje poleceń (zainstaluj je ręcznie)' 'Missing commands (install them manually)'): ${missing[*]}"
ok "$(m 'Podstawowe polecenia są dostępne.' 'Basic commands are available.')"
if [ "$opt_skip_flutter" -eq 0 ] && ! command -v javac >/dev/null 2>&1; then
  jdk_ok=0
  for j in "${jdks[@]}"; do if pm_install "$j" 2>/dev/null; then jdk_ok=1; ok "JDK: $j"; break; fi; done
  [ "$jdk_ok" -eq 1 ] || warn "$(m 'Nie udało się zainstalować JDK 17+; zainstaluj go ręcznie.' 'Could not install JDK 17+; install it manually.')"
fi

# ---------------------------------------------------------------- użytkownik i katalogi
step "$(m 'Użytkownik usługi' 'Service user')"
if id "$APP_USER" >/dev/null 2>&1; then
  ok "$(m "Użytkownik $APP_USER już istnieje." "User $APP_USER already exists.")"
else
  useradd --system --create-home --home-dir "$APP_HOME" --shell /bin/bash "$APP_USER"
  ok "$(m "Utworzono użytkownika $APP_USER (bez hasła, bez sudo)." "Created user $APP_USER (no password, no sudo).")"
fi
install -d -o "$APP_USER" -g "$APP_USER" -m 700 "$APP_HOME"
# Projekty osobno od danych: grupa ma prawo zapisu (agenci AI), dane programu nie są dostępne.
install -d -o "$APP_USER" -g "$APP_USER" -m 2775 /srv/remoteapptester "$PROJECTS"
cat >"$APP_HOME/.remoteapptester-env" <<EOF
export ANDROID_HOME="$APP_HOME/android-sdk"
export PATH="$APP_HOME/flutter/bin:$APP_HOME/.local/bin:$APP_HOME/android-sdk/cmdline-tools/latest/bin:$APP_HOME/android-sdk/platform-tools:\$PATH"
export HOME="$APP_HOME"
export REMOTEAPPTESTER_HOME="$APP_HOME"
umask 0002
EOF
touch "$APP_HOME/.profile"
grep -q remoteapptester-env "$APP_HOME/.profile" || echo '. "$HOME/.remoteapptester-env"' >>"$APP_HOME/.profile"
chown "$APP_USER:$APP_USER" "$APP_HOME/.remoteapptester-env" "$APP_HOME/.profile"
for u in "${SUDO_USER:-}" "$opt_add_user"; do
  if [ -n "$u" ] && [ "$u" != "root" ] && id "$u" >/dev/null 2>&1; then
    usermod -aG "$APP_USER" "$u" && ok "$(m "$u ma dostęp do projektów w $PROJECTS (po ponownym zalogowaniu)." "$u can work in $PROJECTS (after signing in again).")"
  fi
done
# Polecenia jako użytkownik usługi, w jego katalogu i środowisku.
as_app() {
  (cd "$APP_HOME" && if command -v runuser >/dev/null 2>&1; then runuser -u "$APP_USER" -- bash -lc "$1"; else su -s /bin/bash -l "$APP_USER" -c "$1"; fi)
}

# ---------------------------------------------------------------- program
step "RemoteAppTester $HOST_VERSION"
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
src="$script_dir/$ARCH"
[ -x "$src/bin/rt" ] || die "$(m "Brak programu dla $ARCH w $script_dir (rozpakuj całe archiwum)." "No program for $ARCH in $script_dir (extract the whole archive).")"
[ -f "$script_dir/SHA256SUMS" ] || die "$(m 'Brak pliku SHA256SUMS.' 'SHA256SUMS file is missing.')"
(cd "$script_dir" && grep " \./$ARCH/\| \./install.sh" SHA256SUMS | sha256sum -c --quiet -) \
  || die "$(m 'Suma SHA-256 się nie zgadza; przerywam (plik mógł zostać podmieniony).' 'SHA-256 mismatch; stopping (a file may have been altered).')"
ok "$(m 'Sumy kontrolne zgodne.' 'Checksums match.')"
"$src/bin/rt" version >/dev/null 2>&1 || die "$(m 'Program nie uruchamia się na tym systemie (za stara biblioteka glibc?).' 'The program does not run on this system (glibc too old?).')"

if has_systemd && systemctl list-unit-files 2>/dev/null | grep -q '^remotetester\.service'; then
  systemctl disable --now remotetester 2>/dev/null || true
  warn "$(m 'Wyłączono usługę poprzedniej wersji (remotetester). Jej dane zostały w /var/lib/remotetester; projekty przypisz na nowo.' 'Disabled the previous version service (remotetester). Its data stays in /var/lib/remotetester; add projects again.')"
fi
was_active=0
if has_systemd && systemctl is-active --quiet "$SERVICE"; then was_active=1; systemctl stop "$SERVICE"; fi
if ! has_systemd && has_openrc && rc-service "$SERVICE" status >/dev/null 2>&1; then was_active=1; rc-service "$SERVICE" stop >/dev/null 2>&1 || true; fi
rm -rf "$INSTALL_DIR"
install -d -m 755 "$INSTALL_DIR/bin" "$INSTALL_DIR/lib"
install -m 755 "$src/bin/rt" "$INSTALL_DIR/bin/rt"
install -m 644 "$src"/lib/* "$INSTALL_DIR/lib/"
command -v restorecon >/dev/null 2>&1 && restorecon -R "$INSTALL_DIR" 2>/dev/null || true

# "rt" zawsze działa na danych usługi; `rt sg`, `rt push`, `rt st` (agent) działają jako wywołujący,
# bo czytają i zapisują tylko pliki w folderze projektu i niczego więcej nie potrzebują.
cat >/usr/local/bin/rt <<EOF
#!/bin/sh
orig="\$PWD"
bin="$INSTALL_DIR/bin/rt"
case "\${1:-}" in
  sg|signal|pu|push|st|status|v|version|--version) exec "\$bin" --cwd "\$orig" "\$@" ;;
esac
cd "$APP_HOME" 2>/dev/null || cd /
run='. "$APP_HOME/.remoteapptester-env"; exec "\$0" "\$@"'
if [ "\$(id -un)" = "$APP_USER" ]; then
  umask 0002
  exec "\$bin" --home "$APP_HOME" --cwd "\$orig" "\$@"
elif [ "\$(id -u)" -eq 0 ] && command -v runuser >/dev/null 2>&1; then
  exec runuser -u "$APP_USER" -- sh -c "\$run" "\$bin" --home "$APP_HOME" --cwd "\$orig" "\$@"
elif command -v sudo >/dev/null 2>&1; then
  exec sudo -u "$APP_USER" -H sh -c "\$run" "\$bin" --home "$APP_HOME" --cwd "\$orig" "\$@"
else
  echo "RemoteAppTester: sudo rt ..." >&2
  exit 1
fi
EOF
chmod 755 /usr/local/bin/rt
ln -sf /usr/local/bin/rt /usr/local/bin/remoteapptester
ok "$(m 'Polecenie: sudo rt …  (sygnał agenta bez sudo: rt sg)' 'Command: sudo rt …  (agent signal without sudo: rt sg)')"

# ---------------------------------------------------------------- Flutter + Android SDK
if [ "$opt_skip_flutter" -eq 0 ]; then
  step "Flutter"
  if [ -x "$APP_HOME/flutter/bin/flutter" ]; then
    ok "$(m 'Już zainstalowany (aktualizacja: flutter upgrade).' 'Already installed (update: flutter upgrade).')"
  else
    as_app "git clone --quiet --depth 1 --branch stable https://github.com/flutter/flutter.git \"$APP_HOME/flutter\"" || warn "$(m 'Nie udało się pobrać Fluttera.' 'Could not download Flutter.')"
  fi
  as_app "flutter --disable-analytics >/dev/null 2>&1; flutter precache --android >/dev/null" \
    && ok "$(m 'Flutter gotowy.' 'Flutter ready.')" || warn "$(m 'Flutter: przygotowanie nie powiodło się; sprawdź: sudo rt dr' 'Flutter: setup failed; check: sudo rt dr')"

  step "Android SDK"
  sdk="$APP_HOME/android-sdk"
  if [ -x "$sdk/cmdline-tools/latest/bin/sdkmanager" ]; then
    ok "$(m 'Już zainstalowany.' 'Already installed.')"
  else
    tmp=$(mktemp -d)
    # Najnowsza paczka i jej suma SHA-1 z oficjalnego repozytorium Google.
    chunks=$(curl -fsSL https://dl.google.com/android/repository/repository2-3.xml | tr -d '\n' | sed 's/<archive>/\n<archive>/g' | grep 'commandlinetools-linux-[0-9]*_latest\.zip' || true)
    zip_name=$(printf '%s\n' "$chunks" | grep -o 'commandlinetools-linux-[0-9]*_latest\.zip' | sort -t- -k3 -n | tail -1)
    zip_sha1=$(printf '%s\n' "$chunks" | grep -F "<url>$zip_name</url>" | grep -o '<checksum type="sha1">[0-9a-f]\{40\}' | grep -o '[0-9a-f]\{40\}' | head -1)
    if [ -n "$zip_name" ] && [ -n "$zip_sha1" ] && curl -fsSL "https://dl.google.com/android/repository/$zip_name" -o "$tmp/ct.zip" \
       && echo "$zip_sha1  $tmp/ct.zip" | sha1sum -c --quiet -; then
      install -d -o "$APP_USER" -g "$APP_USER" "$sdk/cmdline-tools"
      unzip -q "$tmp/ct.zip" -d "$tmp/ct"
      mv "$tmp/ct/cmdline-tools" "$sdk/cmdline-tools/latest"
      chown -R "$APP_USER:$APP_USER" "$sdk"
      ok "$(m "Pobrano $zip_name (suma zgodna)." "Downloaded $zip_name (checksum matches).")"
    else
      warn "$(m 'Nie udało się pobrać Android command-line tools.' 'Could not download Android command-line tools.')"
    fi
    rm -rf "$tmp"
  fi
  # Licencje Google akceptuje użytkownik, nie instalator: pytamy albo wymagamy
  # --accept-android-licenses. Raz zaakceptowane zostają w $sdk/licenses.
  licenses_ok=0
  if [ -f "$sdk/licenses/android-sdk-license" ] || [ "$opt_accept_licenses" -eq 1 ]; then
    licenses_ok=1
  elif have_tty; then
    printf '\n  %s\n  https://developer.android.com/studio/terms\n  %s ' \
      "$(m 'Android SDK to narzędzia Google na ich licencji. Przeczytaj ją:' 'The Android SDK is Google software under its own licence. Read it:')" \
      "$(m 'Akceptujesz licencje Android SDK? [t/N]' 'Do you accept the Android SDK licences? [y/N]')" >/dev/tty
    read -r answer </dev/tty || answer=""
    case "$answer" in t|T|tak|Tak|y|Y|yes|Yes) licenses_ok=1 ;; esac
  fi
  if [ "$licenses_ok" -eq 1 ]; then
    as_app "yes | sdkmanager --licenses >/dev/null 2>&1; sdkmanager --install platform-tools >/dev/null 2>&1" \
      && ok "$(m 'Licencje zaakceptowane, platform-tools zainstalowane.' 'Licences accepted, platform-tools installed.')" \
      || warn "$(m 'Android SDK: sprawdź: sudo rt dr' 'Android SDK: check: sudo rt dr')"
  else
    warn "$(m 'Licencje Android SDK nie zostały zaakceptowane: budowanie aplikacji Android nie zadziała. Później: sudo bash install.sh --accept-android-licenses' 'Android SDK licences were not accepted: Android builds will not work. Later: sudo bash install.sh --accept-android-licenses')"
  fi
fi

# ---------------------------------------------------------------- Tailscale
ts_up() { command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; }
if [ "$opt_skip_tailscale" -eq 0 ]; then
  step "$(m 'Tailscale (prywatna sieć między telefonem a serwerem)' 'Tailscale (private network between phone and server)')"
  if command -v tailscale >/dev/null 2>&1; then
    ok "$(m 'Już zainstalowany.' 'Already installed.')"
  else
    curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 \
      && ok "$(m 'Zainstalowano (oficjalny instalator Tailscale).' 'Installed (official Tailscale installer).')" \
      || warn "$(m 'Nie udało się zainstalować; instrukcja: https://tailscale.com/download/linux' 'Could not install; instructions: https://tailscale.com/download/linux')"
  fi
  if ts_up; then
    ok "$(m 'Połączony' 'Connected'): $(tailscale ip -4 2>/dev/null | head -1)"
  elif command -v tailscale >/dev/null 2>&1; then
    if [ -n "${TS_AUTHKEY:-}" ]; then
      tailscale up --authkey "$TS_AUTHKEY" || warn "$(m 'Logowanie kluczem nie powiodło się.' 'Sign-in with the key failed.')"
    elif [ "$opt_no_login" -eq 0 ] && have_tty; then
      echo "  $(m 'Otwórz link, który się pojawi, i zaloguj się TYM SAMYM kontem co w Tailscale na telefonie.' 'Open the link that appears and sign in with the SAME account as Tailscale on your phone.')"
      tailscale up </dev/tty || warn "$(m 'Logowanie nie powiodło się.' 'Sign-in failed.')"
    fi
    ts_up || warn "$(m 'Niepołączony. Uruchom: sudo tailscale up' 'Not connected. Run: sudo tailscale up')"
  fi
fi

# ---------------------------------------------------------------- konfiguracja i usługa
step "$(m 'Usługa' 'Service')"
as_app "\"$INSTALL_DIR/bin/rt\" --home \"$APP_HOME\" init --projects-root \"$PROJECTS\" --port $opt_port" | sed 's/^/  /'
service_running=0
if [ "$opt_no_service" -eq 1 ]; then
  warn "$(m 'Bez usługi. Uruchom ręcznie: sudo rt s' 'No service. Start it manually: sudo rt s')"
elif has_systemd; then
  cat >"/etc/systemd/system/$SERVICE.service" <<EOF
[Unit]
Description=RemoteAppTester: builds apps and delivers them to a test phone
After=network-online.target tailscaled.service
Wants=network-online.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_HOME
UMask=0002
Environment=HOME=$APP_HOME
Environment=REMOTEAPPTESTER_HOME=$APP_HOME
Environment=ANDROID_HOME=$APP_HOME/android-sdk
Environment=PATH=$APP_HOME/flutter/bin:$APP_HOME/.local/bin:$APP_HOME/android-sdk/platform-tools:/usr/local/bin:/usr/bin:/bin
ExecStart=$INSTALL_DIR/bin/rt --home $APP_HOME serve
# Bez Tailscale program czeka i ponawia (nigdy nie nasłuchuje na innym adresie).
Restart=always
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
CapabilityBoundingSet=
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "$SERVICE" >/dev/null 2>&1
  systemctl restart "$SERVICE"
  sleep 3
  if systemctl is-active --quiet "$SERVICE"; then
    service_running=1; ok "$(m 'Usługa działa (systemd).' 'Service running (systemd).')"
  else
    warn "$(m "Usługa nie wystartowała: journalctl -u $SERVICE -n 50" "Service did not start: journalctl -u $SERVICE -n 50")"
  fi
elif has_openrc; then
  cat >"/etc/init.d/$SERVICE" <<EOF
#!/sbin/openrc-run
description="RemoteAppTester"
command="$INSTALL_DIR/bin/rt"
command_args="--home $APP_HOME serve"
command_user="$APP_USER:$APP_USER"
command_background=true
pidfile="/run/$SERVICE.pid"
directory="$APP_HOME"
output_log="$APP_HOME/service.log"
error_log="$APP_HOME/service.log"
depend() { need net; after tailscale; }
EOF
  chmod 755 "/etc/init.d/$SERVICE"
  rc-update add "$SERVICE" default >/dev/null 2>&1 || true
  rc-service "$SERVICE" restart >/dev/null 2>&1 && { service_running=1; ok "$(m 'Usługa działa (OpenRC).' 'Service running (OpenRC).')"; } \
    || warn "$(m 'Usługa nie wystartowała.' 'Service did not start.')"
else
  warn "$(m 'Nie rozpoznano menedżera usług. Uruchom ręcznie w tmux/screen: sudo rt s' 'No service manager recognised. Start manually in tmux/screen: sudo rt s')"
fi
[ "$was_active" -eq 0 ] || ok "$(m 'Aktualizacja: dane i sparowane telefony zostały.' 'Update: data and paired phones kept.')"

# ---------------------------------------------------------------- podsumowanie
step "$(m 'Diagnostyka' 'Diagnostics')"
/usr/local/bin/rt doctor | sed 's/^/  /' || true

if [ "$opt_no_pair" -eq 0 ] && ts_up; then
  step "$(m 'Połącz telefon' 'Connect a phone')"
  /usr/local/bin/rt pair "$opt_phone" || true
elif [ "$opt_no_pair" -eq 0 ]; then
  warn "$(m "Po połączeniu Tailscale sparuj telefon: sudo rt p \"$opt_phone\"" "After connecting Tailscale pair a phone: sudo rt p \"$opt_phone\"")"
fi
echo
ok "$(m 'Gotowe. Projekty:' 'Done. Projects:') $PROJECTS"
echo "  sudo rt            $(m 'lista poleceń i ostatnio używane' 'command list and recently used')"
echo "  sudo rt n $(m 'nazwa' 'name') --flutter   $(m 'nowy projekt' 'new project')"
echo "  sudo rt a $(m 'folder' 'folder')           $(m 'przypisz istniejący folder' 'add an existing folder')"
echo "  sudo rt o          $(m 'opcje projektu' 'project options')"
echo "  $(m 'Podgląd stron www z telefonu: zwykły HTTPS *.ts.net po' 'Web preview from the phone: regular HTTPS *.ts.net after'): sudo tailscale set --operator=$APP_USER"
echo "  sudo rt info       $(m 'przewodnik: bezpieczeństwo, agenci AI, sandbox' 'guide: security, AI agents, sandbox')"
