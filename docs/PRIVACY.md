# Polityka prywatności / Privacy policy: RemoteAppTester

*Wersja / Version: 2026-11-25. English below.*

## Po polsku

**Krótko: RemoteAppTester nie zbiera, nie wysyła i nie sprzedaje żadnych Twoich danych.**
Autor projektu nie prowadzi serwerów, do których program by się łączył.

**Gdzie są dane.** Wszystko zostaje na Twoich urządzeniach:

| Dane | Gdzie |
|---|---|
| Projekty, komendy budowania, opcje, historia buildów, logi | na Twoim komputerze/serwerze (baza zaszyfrowana na Windows) |
| Dane parowania (identyfikator telefonu, sekret, odcisk certyfikatu) | na komputerze/serwerze i w bezpiecznym magazynie telefonu (Android Keystore) |
| Pobrane wersje aplikacji | w prywatnym folderze aplikacji na telefonie |
| Ustawienia aplikacji (język, motyw, dźwięki, blokada) | na telefonie |

**Połączenia sieciowe.** Telefon łączy się wyłącznie z Twoim komputerem/serwerem przez Twoją
sieć Tailscale. Tailscale przetwarza dane potrzebne do zestawienia tej sieci według swojej
polityki prywatności (https://tailscale.com/privacy-policy). Instalatory pobierają programy
(Flutter, Android SDK, Tailscale) z oficjalnych źródeł ich producentów.

**Uprawnienia aplikacji na telefonie:**

| Uprawnienie | Po co |
|---|---|
| Internet | połączenie z Twoim komputerem przez Tailscale |
| Instalowanie aplikacji | instalacja testowanych wersji, za Twoją zgodą |
| Aparat | tylko skan kodu QR parowania |
| Biometria (odcisk palca) | blokada aplikacji i potwierdzanie ważnych akcji; odcisk sprawdza Android, aplikacja go nie widzi |
| Powiadomienia | informacja o nowej wersji, gdy aplikacja jest w tle |

Brak analityki, reklam, śledzenia i kopii zapasowych w chmurze (kopia zapasowa Androida jest
wyłączona). Odinstalowanie aplikacji usuwa jej dane z telefonu.

**Aplikacje, które testujesz,** mają własne zasady prywatności. Odpowiada za nie ich twórca.

**Kontakt:** zgłoszenia w repozytorium projektu na GitHubie (zakładka Issues; sprawy
bezpieczeństwa: [SECURITY.md](../.github/SECURITY.md)).

## In English

**In short: RemoteAppTester does not collect, transmit or sell any of your data.** The project's
author runs no servers that the software connects to.

**Where data lives:** projects, build commands, options, build history and logs stay on your
computer/server (the database is encrypted on Windows). Pairing data is on the computer/server and in
the phone's secure storage (Android Keystore). Downloaded app versions stay in the app's private folder on
the phone, and app settings stay on the phone.

**Network:** the phone connects only to your own computer/server through your Tailscale network. Tailscale
processes the data needed to run that network under its own policy (https://tailscale.com/privacy-policy).
The installers download Flutter, the Android SDK and Tailscale from their vendors' official sources.

**Phone permissions:** Internet (connection to your computer), install packages (installing test builds
with your consent), camera (only for scanning the pairing QR code), biometrics (app lock and confirming
sensitive actions; Android checks the fingerprint and the app never sees it), notifications (new version
while in background). No analytics, ads, tracking or cloud backup (Android backup is disabled).
Uninstalling the app removes its data.

**Apps you test** have their own privacy rules, which are their developer's responsibility.

**Contact:** GitHub Issues in the project repository; security reports: [SECURITY.md](../.github/SECURITY.md).
