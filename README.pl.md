# RemoteAppTester

**Budujesz aplikację na komputerze albo serwerze, testujesz ją na telefonie i wszystkim sterujesz z telefonu.**

RemoteAppTester jest dla osób, które mają pomysł na aplikację i chcą go rozwijać z agentem AI
(np. Claude Code), choć nie są informatykami. Piszesz agentowi, co ma zrobić albo poprawić.
RemoteAppTester buduje wynik i wysyła go na Twój telefon przez Twoją prywatną sieć. Testujesz,
piszesz agentowi kolejne uwagi i tak w kółko. Wszystko to da się robić z telefonu, z dowolnego miejsca.

🇬🇧 [English](README.md) · 📘 [Poradnik dla początkujących](docs/PORADNIK.md) ·
🤖 [Gotowe prompty dla czatu AI](docs/PROMPTY.md) · 🖥️ [Serwer VPS krok po kroku](docs/VPS.md)

> **Stan: beta (0.6.x).** Autor używa programu na co dzień, ale licz się z niedoróbkami.
> Używaj telefonu testowego i projektów testowych. Zobacz [Zastrzeżenia](#zastrzeżenia).

## Jak to działa

```
 Ty (telefon)               Komputer albo VPS                        Twój telefon
 ────────────               ─────────────────                        ────────────
 „Dodaj ekran         ──►   agent AI (np. Claude Code)
  logowania”                zmienia folder projektu
 w aplikacji Claude         i wysyła sygnał: rt sg --build
                                      │
                                      ▼
                            RemoteAppTester buduje aplikację ──Tailscale──► instaluje
                            komendami, które TY zatwierdziłeś              i uruchamia
```

1. **Agent AI pracuje osobno.** Konfigurujesz go niezależnie (Claude Code, Codex, Cursor…).
   Claude Code da się prowadzić z aplikacji Claude na telefonie (funkcja „Remote Control”),
   więc z agentem rozmawiasz z telefonu.
2. **Gdy agent skończy, daje znać RemoteAppTesterowi** (`rt sg --build` albo `rt push`).
   Agent nie ma dostępu do samego RemoteAppTestera: może tylko zostawić notatkę i poprosić o build.
3. **RemoteAppTester buduje aplikację** komendami, które zatwierdzasz tylko Ty, i wysyła ją na
   sparowany telefon przez [Tailscale](https://tailscale.com) (darmową prywatną sieć między Twoimi
   urządzeniami). Nic nie przechodzi przez nasze serwery, bo żadnych nie mamy.
4. **Telefon instaluje i uruchamia nową wersję.** Testujesz i piszesz agentowi kolejną prośbę.

## Co można testować

| Tryb | Co się dzieje |
|---|---|
| **Aplikacje Android** (Flutter, Gradle; kolejne w planach) | Build do APK, wysyłka na telefon, instalacja i uruchomienie. Przesyłana jest tylko zmieniona część. |
| **Aplikacje i strony WWW** (ASP.NET, Next.js, Vite, Angular, Django, Flask, Laravel, PHP, strony statyczne…) | „Podgląd” uruchamia serwer deweloperski na komputerze i otwiera stronę na telefonie przez Tailscale, w widoku telefonu albo komputera. „Zgłoś problem” zapisuje Twoją uwagę i konsolę przeglądarki do pliku dla agenta. |

Gdzie działa RemoteAppTester:

| Komputer | Dla kogo |
|---|---|
| **Windows 10/11** (aplikacja okienkowa + polecenie `rt`) | Masz komputer, który może być włączony. Najłatwiejszy start. |
| **Linux / VPS** (polecenie `rt` + usługa w tle) | Chcesz mały serwer wynajęty w internecie (np. Contabo, Hetzner, OVH), który działa 24/7, także dla agenta AI. |
| **Telefon z Androidem** (pilot) | Lista projektów, build, instalacja, podgląd stron, blokada odciskiem palca. |

**Na razie bez iPhone'a/iOS i macOS.** Budowanie dla iOS wymaga Maca, a autor nie ma sprzętu Apple,
żeby to rzetelnie przetestować. Pomoc osób z Makiem jest mile widziana.

## Szybki start

1. **Tailscale:** załóż darmowe konto i zainstaluj Tailscale na komputerze/serwerze i telefonie.
2. **Zainstaluj RemoteAppTester:**
   - Windows: rozpakuj `RemoteAppTester-windows-x64-<wersja>.zip` i uruchom `install.cmd`
     ([szczegóły](host/deploy/windows/README.md)).
   - Linux/VPS: `sudo bash install.sh` z `RemoteAppTester-linux-<wersja>.tar.gz`
     ([szczegóły](host/deploy/linux/README.md), [VPS krok po kroku](docs/VPS.md)).
3. **Telefon:** zainstaluj `RemoteAppTester-android-<wersja>.apk` i zeskanuj kod QR parowania.
   Ustaw oszczędzanie baterii **„Bez ograniczeń”** dla RemoteAppTester i Tailscale.
4. **Dodaj projekt** (folder z aplikacją). Komendy budowania wpiszą się same.
5. **Skonfiguruj agenta AI** w tym folderze. Jest do tego [gotowy prompt](docs/PROMPTY.md).

Nie znasz się na technice? Wklej odpowiedni prompt z [docs/PROMPTY.md](docs/PROMPTY.md) do czatu AI
(Claude, ChatGPT…) i pozwól mu prowadzić Cię krok po kroku. Przy każdym prompcie jest opis, co robi.

## Bezpieczeństwo w skrócie

Telefon łączy się z komputerem tylko wewnątrz Twojej sieci Tailscale, przez TLS z certyfikatem
przypiętym przy parowaniu, a każde żądanie jest podpisane. Telefon nie może wysłać komend ani ścieżek
plików. Komendy budowania są w zaszyfrowanej bazie i zmieniają się tylko po Twoim zatwierdzeniu.
Agenci AI porozumiewają się tylko przez pliki w folderze projektu. Aplikację na telefonie blokuje
odcisk palca. Szczegóły: [docs/SECURITY.md](docs/SECURITY.md). Główne ryzyka są uczciwie opisane w
zakładce **Informacje** w aplikacji. W skrócie: uruchamiaj agentów AI na osobnym koncie albo maszynie
i testuj na telefonie bez prywatnych danych.

## Wydanie aplikacji na rynek

RemoteAppTester służy do **testów** (wersje debug). Wydanie w Google Play albo w internecie to osobny
krok z własnymi zasadami: konto dewelopera, klucz podpisu, polityka prywatności, wymagania testów w sklepie.
W [docs/PROMPTY.md](docs/PROMPTY.md) jest prompt, z którym czat AI przeprowadzi Cię przez ten proces.

## Budowanie ze źródeł

Zobacz [host/README.md](host/README.md), [desktop_app/README.md](desktop_app/README.md),
[android_app/README.md](android_app/README.md). Paczki: `host/tool/build_release.ps1 -WithAndroid`
(Windows + APK) i `host/tool/build_release.sh` (Linux, Docker). Architektura i decyzje:
[docs/PROJECT_ASSUMPTIONS.md](docs/PROJECT_ASSUMPTIONS.md), [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).

## Wsparcie projektu

RemoteAppTester jest darmowy i otwarty. Jeśli oszczędza Ci czas, możesz
[postawić autorowi kawę](https://buymeacoffee.com/damiannass88). Wsparcie jest dobrowolne i nie kupuje pomocy
technicznej, gwarancji ani funkcji.

Poprawki i zgłoszenia mile widziane: [CONTRIBUTING.md](CONTRIBUTING.md). Problemy bezpieczeństwa:
[.github/SECURITY.md](.github/SECURITY.md).

## Zastrzeżenia

Program jest udostępniany **„tak jak jest”, bez żadnej gwarancji** (zobacz [LICENSE](LICENSE)). Odpowiadasz
za swoje komputery, serwery, telefony, kod pisany i uruchamiany przez Twoich agentów AI, instalowane
aplikacje oraz korzystanie z usług firm trzecich (Tailscale, Google, dostawca VPS, dostawcy AI) zgodnie
z ich regulaminami. Więcej: [docs/LEGAL.md](docs/LEGAL.md). RemoteAppTester to niezależny projekt,
niepowiązany z Anthropic, Google, Tailscale ani innymi wymienionymi firmami i przez nie niepopierany.
Znaki towarowe należą do ich właścicieli.
