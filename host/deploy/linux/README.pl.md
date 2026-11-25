# RemoteAppTester na serwer Linux (VPS)

🌐 [English](README.md) · **Polski**

Wersja bez okna: te same funkcje co na Windows (projekty, komendy, opcje, buildy, dostawy na
telefon, sygnał agenta AI, języki), obsługiwane poleceniami `rt` i z telefonu.

## Wymagania

- Linux z glibc 2.34+: Ubuntu 22.04+, Debian 12+, RHEL/Alma/Rocky 9+, Fedora, openSUSE, Arch i pochodne.
- x86_64 (narzędzia Google do budowania Androida są publikowane dla x86_64).
- Min. 4 GB RAM (lub swap) i ok. 15 GB wolnego miejsca na Flutter i Android SDK.
- Konto Tailscale, to samo co na telefonie.

Alpine i inne systemy z musl nie są obsługiwane: instalator odmówi z wyjaśnieniem.

## Instalacja

```
tar xzf RemoteAppTester-linux-<wersja>.tar.gz
cd RemoteAppTester-linux-<wersja>
sudo bash install.sh
```

Instalator sprawdza sumy SHA-256, tworzy użytkownika `remoteapptester` bez uprawnień administratora,
instaluje program, Flutter, Android SDK i Tailscale, uruchamia usługę i pokazuje kod QR do
zeskanowania telefonem. Ponowne uruchomienie to aktualizacja, bez utraty danych. Opcje: `--help`.

**Na telefonie obowiązkowo:** Ustawienia → Aplikacje → RemoteAppTester (i Tailscale) → Oszczędzanie
baterii → **„Bez ograniczeń”**. Xiaomi/HyperOS domyślnie ogranicza nowe aplikacje i wtedy telefon
nie łączy się z serwerem („Connection timed out”).

Instalator pyta o zgodę na licencje Android SDK firmy Google (https://developer.android.com/studio/terms).
Bez terminala (np. cloud-init) zgodę daje opcja `--accept-android-licenses`. Bez Android SDK: `--skip-flutter`.

Instalacja bez terminala (np. cloud-init): `TS_AUTHKEY=... sudo -E bash install.sh --no-pair`.

**Reguły dostępu Tailscale (ACL).** Jeśli w panelu Tailscale (Access controls) masz własne reguły
zamiast domyślnego „wszyscy do wszystkich”, dodaj dostęp telefonów do portu RemoteAppTestera
(domyślnie **47051**; do wersji 0.6 było 50051). `sudo rt acl` (z `--with <komputer>` dla kolejnych komputerów z RemoteAppTesterem) tworzy
gotową politykę z urządzeń Twojej sieci Tailscale, np.:

```json
"grants": [{"src": ["<IP telefonu>"], "dst": ["<IP komputera>"], "ip": ["tcp:47051"]}]
```

Bez tego telefon dostaje „Connection timed out”, choć Tailscale pokazuje połączenie.

**Nowy projekt z telefonu.** W aplikacji na telefonie przycisk „Nowy projekt” tworzy projekt
Flutter albo pusty folder, albo przypisuje wolny folder — zawsze w katalogu projektów
komputera (`projects_root`), po samej nazwie; komendy wpisuje komputer. Wyłączysz to w
`host-config.yaml`: `phone_add_projects: false` (potem uruchom program ponownie).

## Gdzie co jest

| Co | Gdzie |
|---|---|
| Program | `/opt/remoteapptester` |
| Dane (baza, klucze, logi) | `/var/lib/remoteapptester`, tylko dla użytkownika usługi |
| Projekty | `/srv/remoteapptester/projects`, zapis dla grupy `remoteapptester` |

## Praca

```
sudo rt                         # lista poleceń i ostatnio używane
sudo rt n aplikacja --flutter   # nowy projekt
sudo rt a /sciezka/do/folderu   # przypisz istniejący folder
sudo rt pr aplikacja            # komendy budowania
sudo rt pr import               # zatwierdź komendy zaproponowane przez agenta
sudo rt o aplikacja --install ask --agent-build on
sudo rt b aplikacja             # zbuduj i wyślij
sudo rt lg aplikacja            # historia i log
sudo rt p "Drugi telefon"       # sparuj kolejny telefon
sudo rt acl                     # reguły dostępu Tailscale (JSON) dla telefonów
sudo rt la en                   # język poleceń: auto, pl, en, de, cs
sudo rt info                    # przewodnik: bezpieczeństwo, agenci AI, sandbox, publikacja
```

## Agenci AI

Dodaj konto agenta do grupy projektów: `sudo bash install.sh --add-user <login>` (albo
`usermod -aG remoteapptester <login>`). Agent pracuje w `/srv/remoteapptester/projects/<projekt>`
i po skończonej pracy wysyła sygnał, bez sudo i bez dostępu do danych programu:

```
rt sg -m "co zmieniono" --build --wait            # RemoteAppTester buduje zatwierdzonymi komendami
rt push build/app/outputs/flutter-apk/app-debug.apk -m "co zmieniono" --wait --json   # agent zbudował sam
rt st --json                                      # wynik ostatniego zlecenia
```

Kody wyjścia, format wyniku i zasady: [docs/AGENCI_AI.md](../../../docs/AGENCI_AI.md). Wysyłanie
własnych instalek wyłączysz opcją `sudo rt o <projekt> --agent-push off`.

Nie dawaj agentowi `sudo`. Build wykonuje skrypty z repozytorium, więc na serwerze z innymi
usługami lepiej przeznaczyć dla agentów osobną maszynę. Więcej: `sudo rt info`.

## Usługa

`systemctl status remoteapptester`, `journalctl -u remoteapptester -f`. Na systemach z OpenRC
powstaje `/etc/init.d/remoteapptester`, a bez menedżera usług uruchom `sudo rt s` w tmux lub screen.

Serwer nasłuchuje wyłącznie na adresie Tailscale. Instalator nie otwiera portów i nie zmienia zapory.

## Odinstalowanie

```
sudo bash install.sh --uninstall           # dane i projekty zostają
sudo bash install.sh --uninstall --purge   # usuwa też dane, projekty i użytkownika
```
