# Serwer VPS dla RemoteAppTester i agenta AI (przykład: Contabo)

🇬🇧 [English version](en/VPS.md)

VPS to wynajęty w internecie komputer z Linuxem, który działa cały czas. Na takim serwerze
działają RemoteAppTester i agent AI, a Ty sterujesz wszystkim z telefonu. Twój domowy
komputer może być wyłączony, a agent nie ma dostępu do Twoich prywatnych plików.

Jako przykładu używamy firmy **Contabo**. Tak samo działa u innych dostawców (Hetzner, OVH,
netcup, DigitalOcean…). Nazwy planów, ceny i wygląd panelu się zmieniają, więc sprawdzaj je
na stronie dostawcy.

> **Najprościej:** przejdź ten opis razem z czatem AI. Wklej mu
> [prompt 1](PROMPTY.md#1-przygotowanie-i-zabezpieczenie-serwera-vps), a potem
> [prompt 2](PROMPTY.md#2-instalacja-remoteapptester-na-serwerze-linux). Czat wyjaśni każde
> polecenie i zatrzyma się przed ryzykownymi krokami.

## Zanim zaczniesz: odpowiedzialność

- **Jesteś administratorem tego serwera.** Dostawca daje maszynę, a za jej zabezpieczenie
  i to, co na niej działa, odpowiadasz Ty, zgodnie z regulaminem dostawcy (np. zakaz spamu,
  kopania kryptowalut i skanowania cudzych sieci).
- **Serwer w internecie jest atakowany od pierwszej minuty** przez automaty zgadujące hasła.
  Dlatego pierwszy krok to zabezpieczenie logowania (rozdział 3).
- **Dane osobowe:** jeśli Twoja aplikacja będzie przechowywać dane innych osób, wybierz
  centrum danych w UE i pamiętaj o RODO.
- **Koszty** naliczają się, dopóki serwer istnieje, nawet wyłączony. Zrezygnuj w panelu
  dostawcy, gdy przestaniesz go używać.

## 1. Jaki serwer wybrać

| Parametr | Minimum | Zalecane | Dlaczego |
|---|---|---|---|
| Procesor | x86_64 (AMD/Intel), 2 rdzenie | 4+ rdzenie | narzędzia Google do budowania Androida są tylko dla x86_64; ARM odpada |
| Pamięć RAM | 4 GB | 8 GB lub więcej | budowanie aplikacji Android i agent AI zużywają dużo pamięci |
| Dysk | 40 GB | 75 GB+ (najlepiej SSD/NVMe) | Flutter, Android SDK i kopie builda zajmują ok. 15 GB |
| System | Ubuntu 22.04 | **Ubuntu 24.04 LTS** | najlepiej przetestowany |
| Lokalizacja | dowolna | najbliżej Ciebie, w UE | mniejsze opóźnienia, RODO |

W Contabo wybierz zwykły **Cloud VPS** (nie „Storage”) z obrazem **Ubuntu 24.04**. Przy
zamówieniu ustaw silne hasło roota (zapisz je w menedżerze haseł). Jeśli umiesz, od razu dodaj
klucz SSH. Po kilku minutach dostaniesz e-mail z **adresem IP** serwera.

## 2. Pierwsze logowanie

Na komputerze otwórz terminal (Windows: **Terminal** albo **PowerShell**; macOS/Linux: Terminal):

```sh
ssh root@ADRES_IP
```

| Polecenie | Co robi |
|---|---|
| `ssh root@ADRES_IP` | łączy się z serwerem jako administrator (`root`); przy pierwszym połączeniu potwierdź odcisk serwera słowem `yes` |

Z telefonu też się da, aplikacją SSH (np. Termius, JuiceSSH), ale wygodniej z komputera.

**Koło ratunkowe:** jeśli się zablokujesz (np. po zmianie ustawień SSH), w panelu Contabo jest
konsola **VNC** albo **tryb ratunkowy (Rescue)**. Działają bez SSH.

## 3. Zabezpieczenie serwera (najważniejsze)

Te kroki wykona z Tobą [prompt 1](PROMPTY.md#1-przygotowanie-i-zabezpieczenie-serwera-vps).
Dla przejrzystości poniżej opis, co i po co się robi:

| Krok | Polecenia (przykład) | Po co |
|---|---|---|
| Aktualizacja systemu | `apt update && apt full-upgrade -y` | łatki bezpieczeństwa |
| Automatyczne łatki | `apt install -y unattended-upgrades` | system sam instaluje poprawki bezpieczeństwa |
| Własne konto administratora | `adduser jan` i `usermod -aG sudo jan` | nie pracuje się na koncie `root` |
| Logowanie kluczem | na komputerze: `ssh-keygen -t ed25519`, potem `ssh-copy-id jan@ADRES_IP` | klucza nie da się zgadnąć jak hasła |
| Wyłączenie logowania hasłem i jako root | w `/etc/ssh/sshd_config`: `PasswordAuthentication no`, `PermitRootLogin no`, potem `systemctl reload ssh` | koniec zgadywania haseł; **najpierw sprawdź w drugim oknie, że logowanie kluczem działa** |
| Zapora | `ufw allow OpenSSH` i `ufw enable` | blokuje wszystko poza SSH; RemoteAppTester i tak działa tylko w Tailscale |
| (opcjonalnie) Ochrona przed zgadywaniem | `apt install -y fail2ban` | blokuje adresy, które wielokrotnie próbują się zalogować |
| (opcjonalnie) Swap, gdy RAM < 8 GB | `fallocate -l 4G /swapfile` … | zapas pamięci przy budowaniu |

> Ustawienia SSH mogą być nadpisane przez pliki w `/etc/ssh/sshd_config.d/` (Contabo i
> obrazy chmurowe często je mają). Czat AI z promptu 1 sprawdzi to na Twoim systemie.

**Jeszcze bezpieczniej (dla chętnych):** po zainstalowaniu Tailscale możesz logować się
przez Tailscale (`ssh jan@nazwa-serwera`) i zamknąć publiczny port SSH (`ufw delete allow OpenSSH`).
Wtedy z internetu serwer nie przyjmuje żadnych połączeń. Zrób to dopiero, gdy logowanie przez
Tailscale działa, bo w razie problemu zostaje tylko konsola VNC.

## 4. Instalacja RemoteAppTester

1. **Pobierz paczkę** `RemoteAppTester-linux-<wersja>.tar.gz` i jej sumę `.sha256`
   z zakładki **Releases** repozytorium na GitHubie. Na serwerze:

   ```sh
   curl -LO https://github.com/damiannass88/RemoteAppTester/releases/download/v<WERSJA>/RemoteAppTester-linux-<WERSJA>.tar.gz
   curl -LO https://github.com/damiannass88/RemoteAppTester/releases/download/v<WERSJA>/RemoteAppTester-linux-<WERSJA>.tar.gz.sha256
   sha256sum -c RemoteAppTester-linux-<WERSJA>.tar.gz.sha256
   ```

   Albo prześlij plik z komputera: `scp RemoteAppTester-linux-<WERSJA>.tar.gz jan@ADRES_IP:~`.

   | Polecenie | Co robi |
   |---|---|
   | `curl -LO <adres>` | pobiera plik do bieżącego folderu |
   | `sha256sum -c …` | sprawdza, czy plik nie jest uszkodzony ani podmieniony (powinno być `OK`) |
   | `scp plik jan@IP:~` | kopiuje plik z Twojego komputera do folderu domowego na serwerze |

2. **Zainstaluj:**

   ```sh
   tar xzf RemoteAppTester-linux-<WERSJA>.tar.gz
   cd RemoteAppTester-linux-<WERSJA>
   sudo bash install.sh
   ```

   Instalator sprawdza sumy plików, tworzy konto usługi `remoteapptester` bez uprawnień
   administratora, instaluje program, Fluttera, Android SDK i Tailscale, uruchamia usługę
   i na końcu pokazuje **kod QR do zeskanowania telefonem**. Trwa to kilkanaście minut.
   Nie otwiera portów i nie zmienia zapory. Szczegóły i opcje: [host/deploy/linux/README.md](../host/deploy/linux/README.md).

   - Gdy pojawi się **link logowania Tailscale**, otwórz go i zaloguj się tym samym kontem co na telefonie.
   - Instalator zapyta, czy akceptujesz licencje Android SDK (narzędzia Google). Przeczytaj je:
     https://developer.android.com/studio/terms. Bez zgody budowanie aplikacji Android nie zadziała;
     zgodę możesz dać później: `sudo bash install.sh --accept-android-licenses`.
   - Zaznacz w panelu Tailscale (Machines → serwer → **Disable key expiry**), żeby serwer nie
     wylogował się po kilku miesiącach.

3. **Sprawdź:** `sudo rt dr` (diagnoza, wszystko powinno być `[OK]`).

## 5. Konto dla agenta AI

Agent AI dostaje **osobne konto bez `sudo`**, które ma dostęp tylko do folderów projektów:

```sh
sudo adduser agent
sudo bash install.sh --add-user agent
```

| Polecenie | Co robi |
|---|---|
| `sudo adduser agent` | tworzy zwykłe konto `agent` (zapyta o hasło, zapisz je) |
| `sudo bash install.sh --add-user agent` | dodaje konto do grupy, która może pisać w `/srv/remoteapptester/projects` i używać `rt sg`, `rt push`, `rt st` |

Konfigurację agenta (np. Claude Code z Remote Control) przeprowadzi
[prompt 4](PROMPTY.md#4-agent-ai-claude-code-na-serwerze-vps).

**Nigdy nie dawaj kontu agenta `sudo`** i nie zapisuj w jego folderze haseł, kluczy
podpisu produkcyjnego ani tokenów do ważnych kont.

## 6. Utrzymanie

| Co | Jak często | Jak |
|---|---|---|
| Aktualizacje systemu | automatycznie + raz w miesiącu ręcznie | `sudo apt update && sudo apt full-upgrade` i ewentualnie `sudo reboot` |
| Aktualizacja RemoteAppTester | przy nowej wersji | nowa paczka → `sudo bash install.sh` (dane zostają) |
| Kopia zapasowa | regularnie | kod projektów w repozytorium git; w panelu Contabo snapshot serwera |
| Stan usługi | gdy coś nie działa | `systemctl status remoteapptester`, `journalctl -u remoteapptester -n 100` |
| Miejsce na dysku | raz w miesiącu | `df -h` |

## 7. Rezygnacja

1. `sudo bash install.sh --uninstall --purge` usuwa program, dane i projekty. Najpierw zrób kopię projektów!
2. Usuń serwer z Tailscale (panel → Machines).
3. Anuluj usługę w panelu Contabo. Samo wyłączenie serwera nie zatrzymuje opłat.
