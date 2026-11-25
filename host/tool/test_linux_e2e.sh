#!/usr/bin/env bash
# Test sieciowy na Linuxie: paczka + atrapa adresu Tailscale + fałszywy telefon
# (tool/e2e_delivery.dart): TLS z pinningiem, HMAC, sygnał agenta, dostawa, delta, wymiana sekretu.
#
#   docker run --rm --cap-add NET_ADMIN -v <paczka>:/pkg:ro -v <host>:/src:ro dart:stable bash /src/tool/test_linux_e2e.sh
set -eu
apt-get -qq update >/dev/null && apt-get -qq install -y iproute2 >/dev/null 2>&1
ip link add tailscale0 type dummy
ip addr add 100.64.1.5/32 dev tailscale0
ip link set tailscale0 up

cp -r /pkg /tmp/pkg && cd /tmp/pkg
bash install.sh --skip-flutter --skip-tailscale --no-service --no-pair >/tmp/install.log 2>&1 || { tail -20 /tmp/install.log; exit 1; }

(rt s >/tmp/serve.log 2>&1 &)
sleep 3
grep -q "100.64.1.5" /tmp/serve.log || { cat /tmp/serve.log; echo "serwer nie nasłuchuje na adresie Tailscale"; exit 1; }
if ss -ltn 2>/dev/null | grep -q '0.0.0.0:47051'; then echo "[FAIL] nasłuch na wszystkich adresach"; exit 1; fi
echo "[OK] nasłuch tylko na adresie Tailscale"

rt n demo >/dev/null
P=/srv/remoteapptester/projects/demo
runuser -u remoteapptester -- sh -c "mkdir -p $P/build && head -c 2000000 /dev/urandom > $P/build/app.apk"
rt o demo --install auto >/dev/null
device=$(rt p e2e | sed -n 's/.*(id: \([^)]*\)).*/\1/p')
[ -n "$device" ] || { echo "brak device id"; exit 1; }
rt dv | grep -q "czeka na zeskanowanie\|waiting for scan\|wartet auf Scan\|čeká na" && echo "[OK] telefon czeka na pierwsze użycie kodu"

# Fałszywy telefon: kompilacja z kopii źródeł, uruchomienie jako użytkownik usługi (czyta rejestr).
mkdir /tmp/src && cd /src && tar --exclude=./.dart_tool --exclude=./build --exclude=./logs -cf - . | tar -xf - -C /tmp/src
cd /tmp/src && dart pub get >/dev/null && dart build cli -t tool/e2e_delivery.dart -o /tmp/e2e >/tmp/e2e.log 2>&1 || { tail -20 /tmp/e2e.log; exit 1; }
chmod -R a+rX /tmp/e2e
cd /var/lib/remoteapptester
runuser -u remoteapptester -- /tmp/e2e/bundle/bin/e2e_delivery --home /var/lib/remoteapptester --device "$device" --timeout 120 >/tmp/phone.log 2>&1 &
phone=$!
sleep 6
# Agent jako inny użytkownik: tylko sygnał.
useradd -m agent; usermod -aG remoteapptester agent
su -s /bin/sh agent -c "cd $P && rt sg -m 'Test e2e' --build" >/dev/null
wait "$phone"; code=$?
cat /tmp/phone.log
exit "$code"
