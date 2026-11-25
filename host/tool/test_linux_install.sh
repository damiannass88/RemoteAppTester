#!/usr/bin/env bash
# Test instalatora Linux wewnątrz czystego systemu (uruchamiany w kontenerze, patrz niżej).
# Sprawdza: instalację, polecenia, build, sygnał agenta jako inny użytkownik, szyfrowanie
# bazy, prawa do plików, aktualizację i deinstalację.
#
#   docker run --rm -v <paczka>:/pkg:ro -v <ten plik>:/t.sh:ro ubuntu:24.04 bash /t.sh
set -u
fail=0
check() { if eval "$2" >/dev/null 2>&1; then echo "  [OK]   $1"; else echo "  [FAIL] $1"; fail=1; fi; }

cp -r /pkg /tmp/pkg && cd /tmp/pkg || exit 2
bash install.sh --skip-flutter --skip-tailscale --no-pair >/tmp/install.log 2>&1
code=$?
if [ "$code" -ne 0 ]; then tail -15 /tmp/install.log; echo "  [FAIL] instalacja (kod $code)"; exit 1; fi
echo "  [OK]   instalacja"

check 'rt version' 'rt version'
check 'dane tylko dla usługi (700)' '[ "$(stat -c %a /var/lib/remoteapptester)" = 700 ]'
check 'projekty dla grupy (2775)' '[ "$(stat -c %a /srv/remoteapptester/projects)" = 2775 ]'
check 'użytkownik bez sudo' '! id -nG remoteapptester | grep -qw sudo'

(rt s >/tmp/serve.log 2>&1 &)
for _ in $(seq 1 20); do grep -q 'RemoteAppTester' /tmp/serve.log 2>/dev/null && break; sleep 1; done
check 'usługa wystartowała bez Tailscale' 'grep -q "Tailscale" /tmp/serve.log'

check 'rt n (nowy projekt)' 'rt n demo'
P=/srv/remoteapptester/projects/demo
check 'pliki dla agenta' '[ -f "$P/REMOTEAPPTESTER.md" ] && [ -f "$P/.remoteapptester-signal" ] && [ -f "$P/CLAUDE.md" ] && [ -f "$P/AGENTS.md" ]'
check 'domyślnie pytaj na telefonie' 'rt o demo | grep -q "ask"'
check 'rt o (zmiana opcji)' 'rt o demo --install auto | grep -q "auto"'
runuser -u remoteapptester -- sh -c "mkdir -p $P/build && echo apk > $P/build/app.apk" 2>/dev/null || su -s /bin/sh remoteapptester -c "mkdir -p $P/build && echo apk > $P/build/app.apk"
check 'rt b (build przez kanał lokalny)' 'timeout 120 rt b demo'

useradd -m agent 2>/dev/null; usermod -aG remoteapptester agent
su -s /bin/sh agent -c "cd $P && rt sg -m 'Test sygnalu' --build" >/tmp/sg.log 2>&1
check 'rt sg bez sudo, jako inny użytkownik' 'grep -q . /tmp/sg.log && ! grep -qi "denied\|error" /tmp/sg.log'
for _ in $(seq 1 40); do [ "$(rt lg demo | grep -c DONE)" -ge 2 ] && break; sleep 1; done
check 'sygnał uruchomił build' '[ "$(rt lg demo | grep -c DONE)" -ge 2 ]'
check 'wzór sygnału przywrócony' 'grep -q "build: false" "$P/.remoteapptester-signal"'
check 'agent nie czyta danych usługi' '! su -s /bin/sh agent -c "ls /var/lib/remoteapptester"'

check 'baza zaszyfrowana' '[ "$(head -c 15 /var/lib/remoteapptester/data/remotetester.db)" != "SQLite format 3" ]'
check 'klucz bazy tylko dla usługi (600)' '[ "$(stat -c %a /var/lib/remoteapptester/config/db_key)" = 600 ]'
check 'rt dr' 'rt dr; true'
check 'rt info' 'rt info | grep -q "Tailscale"'
check 'rt la de' 'rt la de | grep -q de && rt | grep -q "Verwendung"'
rt la pl >/dev/null

pkill -f "/opt/remoteapptester/bin/rt" 2>/dev/null; sleep 1
bash install.sh --skip-flutter --skip-tailscale --no-pair >/tmp/update.log 2>&1
check 'aktualizacja zachowuje projekt' 'rt ls | grep -q demo'
bash install.sh --uninstall >/tmp/un.log 2>&1
check 'deinstalacja zostawia dane' '[ ! -e /usr/local/bin/rt ] && [ -d /var/lib/remoteapptester/config ]'
exit $fail
