# Plan realizacji — RemoteAppTester

> 🌐 **English:** maintainer design notes, written in Polish. User documentation in English: [README](../README.md), [docs/en/](en/GUIDE.md).

> Zakres i decyzje: [PROJECT_ASSUMPTIONS.md](PROJECT_ASSUMPTIONS.md). Bezpieczeństwo:
> [SECURITY.md](SECURITY.md). Każda faza kończy się zielonym `dart analyze`/`dart test`
> (host) i `flutter analyze`/`flutter test` (aplikacja) oraz testem na prawdziwym telefonie
> tam, gdzie zmienia się ścieżka sieć → instalacja.

## Faza 0 — Start z RemoteDevelopment (zrobione)

Projekt skopiowany z RemoteDevelopment (pełna historia zostaje w tamtym repozytorium),
nowe repozytorium git, nowe założenia.

- [x] Nazwy: `host/` (polecenie `remoteapptester`, pakiet `remotetester_host`), `android_app/`
      („RemoteAppTester”, `com.damiannass.remoteapptester`), `proto/remote_tester.proto`
      (`remotetester.v1.HostAgent`), schemat parowania `remoteapptester://pair`.
- [x] Host jako **czysty Dart CLI** — usunięte GUI Flutter Desktop (`lib/main.dart`,
      `lib/ui/`, `windows/`); te same polecenia na Windows i Linuxie.
- [x] Usunięte: obsługa agentów AI (sygnały/hooki, aktywność folderu, pulpit stanu agenta,
      spike'i Claude/Codex, sprawdzanie CLI dostawców w `doctor`, instalacja Node/Claude/Codex
      w instalatorze VPS), operacje git z telefonu (`AddProject`/clone, `ListBranches`,
      przełączanie branchy), narzędzie `tool/pair_device.dart` (zastąpione `remoteapptester pair`).
- [x] Zostaje i działa: Tailscale-only bind, TLS pinning, HMAC z nonce/timestamp, rate
      limiting/lockout, DPAPI/plik 0600/Keystore, redakcja logów, kolejka, receptury
      Flutter/Gradle, `GetBuildStatus`/`CancelBuild` (reconnect), wznawiany transfer z SHA-256,
      kill-switch, instalacja i uruchomienie przez `PackageInstaller`, monitor połączenia.
- [x] Testy: host 110 zielonych (6 pominiętych — wymagają uprawnień symlinków / innej
      platformy), aplikacja 28 zielonych; analiza czysta po obu stronach.

**Uwaga:** zmiana schematu URI i nazwy pakietu Android oznacza, że telefony sparowane z
RemoteDevelopment trzeba sparować ponownie, a aplikacja instaluje się obok starej.

## Fazy 1–3 — wersja do testów (zrobione 2026-10-13, szybka iteracja)

Cel tej iteracji: działający łańcuch „wyzwalacz → build → dostawa → instalacja → uruchomienie”,
żeby po testach na prawdziwym telefonie zdecydować, co warto dodać i zmienić.

### Faza 1 — Specyfikacja projektu i metody budowania

- [x] `ProjectSpec` (format 1, `host/lib/project/project_spec.dart`) — ścisła walidacja:
      nieznane pola, metody, typy i wartości = błąd; limit 64 KB; build zablokowany przy błędzie,
      komunikat widoczny na telefonie i w `rt ls`.
- [x] Metody z identyfikatorami (`host/lib/build/build_recipes.dart`):
      `flutter-apk-debug-arm64`* , `flutter-apk-debug`, `flutter-apk-profile`,
      `flutter-apk-release`, `gradle-assemble-debug`*, `gradle-assemble-release`.
- [x] `rt m` (methods), `rt pr i` (project init, `--force` z kopią `.bak`), `rt pr c`
      (walidacja + dostępność narzędzi), `rt ls` (projekty, typ, metoda, stan pliku).
- [x] Kontrakt: `BuildRequest` niesie tylko `project_id` (usunięty `BuildFlavor`) — metoda
      zawsze z pliku na hoście. `Project`: `has_spec`, `method_id`, `spec_error`,
      `phone_trigger_allowed`, `launch_after_install`.
- [x] Folder bez pliku = zalecana metoda dla typu (szybki start); wariant metody musi być w
      `allowed_build_flags` hosta.

### Faza 2 — Wyzwalacz lokalny (użytkownik i agenci AI)

- [x] `BuildEngine` — buildy w tle, niezależnie od połączenia, które je zleciło (zerwany
      telefon albo przerwane `rt b` nie zatrzymują builda); debounce: projekt czekający w
      kolejce nie dostaje drugiego builda.
- [x] Lokalny kanał `127.0.0.1:<control_port>` (domyślnie `listen_port + 1`), token w
      SecretStore, porównanie w stałym czasie, odrzucanie żądań z nagłówkiem `Origin`, limit
      16 KB, tylko znane projekty, `triggers.local`, kill-switch.
- [x] `rt b [folder] [--no-wait]` — postęp w terminalu (long-poll), kod wyjścia = wynik builda.
- [x] Skróty poleceń (`rt` = `remoteapptester`, `rt b`, `rt p`, `rt s` …) i tabelka ostatnio
      używanych poleceń (`rt` / `rt help` / `rt h`, plik `logs/cli_history.json`).
- [ ] Przykład dla agentów AI: wpis do `CLAUDE.md`/`AGENTS.md` i hook „Stop” → `rt b`
      (opisane w README hosta; do sprawdzenia w praktyce).

### Faza 3 — Automatyczne dostarczanie na telefon

- [x] `WatchDeliveries` (heartbeat co 20 s) + `AckDelivery`; odbiorcy wg `deliver.devices`;
      najnowsza dostawa per (projekt, telefon) czeka na telefon offline; artefakt może pobrać
      tylko zlecający albo adresat dostawy.
- [x] Aplikacja: `DeliveryService` — stały strumień, backoff 1–30 s, zerwanie po 70 s ciszy,
      keepalive gRPC (25 s), deduplikacja obsłużonych buildów, `install: auto|ask`, `launch`.
- [x] Android 12+: `setRequireUserAction(USER_ACTION_NOT_REQUIRED)` +
      `UPDATE_PACKAGES_WITHOUT_USER_ACTION`; baner zgody „Instalowanie nieznanych aplikacji”
      z przejściem do ustawień.
- [x] Polityka biometrii: `install: auto` bez biometrii (zgoda właściciela hosta w pliku
      projektu); `install: ask`, zmiana nazwy pakietu, ręczny build z telefonu — z biometrią.
- [x] Weryfikacja na tej maszynie: `rt b` → build Flutter (APK 129 MB) → dostawa przez
      Tailscale do klienta testowego (`host/tool/e2e_delivery.dart`: TLS pinning, HMAC,
      odrzucenie złego certyfikatu i braku podpisu, SHA-256, ack) — wszystko OK.
- [ ] **Test na prawdziwym telefonie** (instalacja, aktualizacja bez okna, uruchomienie,
      zmiana WiFi → LTE, telefon offline w chwili builda).
- [ ] Obsługa `INSTALL_FAILED_UPDATE_INCOMPATIBLE` (inny podpis) z propozycją odinstalowania.
- [ ] Powiadomienie „Zainstalowano — Uruchom”, gdy aplikacja jest w tle; odbiór w tle
      (usługa pierwszoplanowa).
- [ ] Wskazówki Play Protect / producentów telefonu w aplikacji.

### Do obserwacji w testach

- Rozmiar APK debug (arm64 ~100–130 MB) a czas transferu przez przekaźnik DERP — może warto
  dodać metodę `profile`/`release` z podpisem debug jako domyślną do testów wydajności.
- Czy uruchamianie po instalacji działa, gdy RemoteAppTester jest w tle (ograniczenia Androida).
- Czy wyzwalanie `rt b` przez agentów AI wymaga dodatkowego trybu (np. „buduj po N sekundach
  bez zmian”).
- Na VPS agent AI działający jako inny użytkownik potrzebuje `sudo rt b` albo pracy jako
  użytkownik `remoteapptester` — do decyzji.

## Faza 4 — Instalki Windows i VPS Linux (zrobione 2026-10-29)

- [x] `host/tool/build_release.ps1` — paczka `RemoteAppTester-host-windows-x64-<wersja>.zip`
      (exe, instalator, sumy SHA-256), `-WithAndroid` dodaje APK aplikacji (release z kluczem
      debug, arm64), `-WithLinux` buduje też paczkę Linux.
- [x] `host/tool/build_release.sh` — `RemoteAppTester-host-linux-<wersja>.tar.gz` (x64 + arm64,
      instalator, sumy); instalator sam wybiera binarkę obok skryptu i sprawdza sumę.
- [x] Instalator Windows (`deploy/windows/install.ps1` + `install.cmd`/`uninstall.cmd`), bez
      administratora: `%LOCALAPPDATA%\Programs\RemoteAppTester` (`remoteapptester.exe` + `rt.exe`), dane
      w `%LOCALAPPDATA%\RemoteAppTester`, PATH użytkownika (zapis z zachowaniem `REG_EXPAND_SZ`) i
      `REMOTEAPPTESTER_HOME`, autostart przy logowaniu (Harmonogram zadań jako użytkownik, pętla
      restartu), reguła zapory tylko dla programu/portu/`100.64.0.0/10` (UAC na żądanie),
      Tailscale przez `winget` na życzenie, diagnostyka i parowanie; deinstalacja z `-Purge`.
- [x] CLI czyta katalog danych z `REMOTEAPPTESTER_HOME`; diagnostyka podpowiada polecenia dla
      właściwego systemu.
- [x] Sprawdzone: instalacja i deinstalacja na sucho w katalogach tymczasowych (bez zmian w
      PATH/autostarcie/zaporze), rejestracja zadania bez administratora, binarka Linux z paczki
      w Ubuntu (WSL: sumy, `v`, `m`, `--help`).
- [ ] Pełna instalacja na czystym Ubuntu 24.04 VPS (systemd, Flutter, Android SDK, Tailscale).
- [ ] Pełna instalacja na Windows z autostartem i regułą zapory + połączenie z telefonu.
- [ ] Stały klucz debug na hoście (VPS i Windows) — kolejne buildy z tym samym podpisem.
- [ ] Podpisanie `remoteapptester.exe` (SmartScreen) — do rozważenia.
- [ ] Opcjonalnie: usługa pierwszoplanowa na Androidzie do odbioru dostaw w tle.

## Faza 5 — Aplikacja okienkowa Windows + zaszyfrowana baza (0.4, zrobione 2026-10-29)

Decyzje użytkownika: aplikacja okienkowa jak wersja mobilna, telefon = pilot, praca w tle i
równolegle, komendy edytowalne per folder, bezpieczeństwo najważniejsze → komendy w bazie
dostępnej tylko dla RemoteAppTestera, a w folderze plik z wytycznymi dla agentów AI.

- [x] Zaszyfrowana baza SQLite (SQLite3MultipleCiphers, klucz w DPAPI): projekty (tylko
      foldery świadomie przypisane), warianty komend, opcje per projekt, historia buildów.
      Zastępuje `remoteapptester.yaml` i skanowanie `projects_root`.
- [x] Warianty komend (kroki cmd + wzorzec instalki), autowykrywanie Flutter / Gradle /
      React Native / Capacitor, walidacja (jednoliniowe kroki, instalka `.apk` w folderze).
- [x] `REMOTEAPPTESTER.md` w folderze: wytyczne dla agentów AI + blok komend; zmiany wykrywane
      i pokazywane jako propozycja; do bazy tylko po zatwierdzeniu (aplikacja / `rt pr import`).
- [x] Silnik: równoległe buildy różnych projektów (limit 1–4), ten sam projekt w kolejce,
      kroki przez skrypt `.cmd` (bez problemów z cytowaniem), anulowanie całego drzewa
      procesów (`taskkill /T`), kopie instalek w `artifacts/`, logi w `logs/builds/`.
- [x] `HostRuntime` — wspólny rdzeń aplikacji okienkowej i `rt s`; serwer dla telefonów
      sam ponawia start, gdy Tailscale jeszcze nie działa.
- [x] Aplikacja okienkowa (`desktop_app/`, Flutter Windows): projekty (dodaj istniejący /
      nowy pusty / nowy Flutter, odepnij, Eksplorator, VS Code), Budowanie (wariant,
      „Zbuduj i wyślij”, „Tylko zbuduj”, wybór telefonów, log na żywo, historia), Komendy
      (edytor, domyślny wariant, wykryj ponownie, propozycje agenta), Opcje, Telefony
      (parowanie QR w oknie, online, odwołanie), Ustawienia (autostart, równoległość,
      wstrzymanie, diagnostyka); zasobnik, jedna kopia, start schowany przy autostarcie.
- [x] Telefon jako pilot: status projektów na żywo, „Zbuduj i zainstaluj: <wariant>”,
      „Zainstaluj ostatnią wersję”, „Uruchom”, podgląd trwającego builda.
- [x] CLI: `rt a`/`rm`/`ls`/`pr`/`pr import`/`pr guide`/`m`/`b`; katalog danych domyślnie
      `%LOCALAPPDATA%\RemoteAppTester` (wspólny z aplikacją).
- [x] Instalator Windows: aplikacja + `rt` (PATH), skróty Start/pulpit, autostart (HKCU Run),
      zapora tylko dla `RemoteAppTester.exe`, SHA256SUMS wszystkich plików; aktualizacja z 0.3.
- [x] Testy: rdzeń 117 (baza, szyfrowanie, propozycje agenta, wzorce instalek, równoległość,
      anulowanie, pilot, izolacja telefonów, lokalny kanał); aplikacja Android 28; e2e `rt`
      (skompilowany) → build → dostawa do testowego „telefonu” przez Tailscale.
- [x] Aplikacja okienkowa zbudowana i uruchomiona (tryb dewelopera włączony): otwiera bazę
      utworzoną przez `rt`, pokazuje propozycję agenta, buduje z logiem na żywo; paczka
      `RemoteAppTester-windows-x64-0.4.0.zip` (38,8 MB z APK), instalacja/deinstalacja na sucho
      sprawdzona, baza z paczki zaszyfrowana (brak jawnego nagłówka SQLite).
- [x] Poprawki z testu: SQLite3MultipleCiphers także w aplikacji okienkowej (+ odmowa startu
      bez szyfrowania), odświeżanie okna po zmianach z `rt`, zatwierdzanie propozycji w
      terminalu tylko z interaktywnej konsoli (agent nie zatwierdzi sam siebie), instalator
      usuwa stary autostart/skróty tylko wskazujące na własny katalog.
- [ ] Ręczny test w oknie: „Przejrzyj… → Zatwierdź”, edytor komend, opcje, parowanie QR,
      zasobnik, autostart po zalogowaniu.
- [ ] Test z prawdziwym telefonem: pilot, równoległe buildy, propozycja agenta.
- [ ] Paczka Linux/VPS z nowym rdzeniem (`dart build cli` na Linuxie, instalacja `bin/` + `lib/`).

## Faza 5b — 0.5: uwagi z pierwszego testu

- [x] Telefon: ekran projektu z przyciskami (wariant, „Zbuduj i zainstaluj”, podgląd,
      „Zainstaluj ostatnią”, „Uruchom”), status na żywo, opcje projektu do wglądu.
- [x] Delty instalek (`DownloadDelta`, format RTD1 + gzip): host liczy różnicę względem wersji,
      którą ma telefon (izolat, pamięć podręczna na dysku, 3 instalki na projekt), telefon
      składa strumieniowo i sprawdza SHA-256; pierwsze pobranie = cała instalka skompresowana;
      starszy host → zwykłe pobranie. 150 MB z 8 MB zmian: ~2 s liczenia, ~8 MB transferu.
- [x] Sygnał agenta AI (`rt sg`, plik `.remoteapptester-signal`): znacznik „nowe zmiany” i notatka
      na komputerze i telefonie, opcja projektu „Sygnał agenta uruchamia build”, znacznik
      znika po udanym buildzie; wytyczne w istniejących `REMOTEAPPTESTER.md` odświeżane przy starcie
      (blok komend i propozycje zostają).
- [x] Opcje projektu na telefonie (instalacja, uruchamianie, sygnał agenta, dostawy na ten
      telefon) — `UpdateProjectOptions`, synchronizacja z oknem; „budowanie z telefonu” tylko na komputerze.
- [x] Sygnał agenta: stały, opisany wzór `.remoteapptester-signal` w folderze (agent edytuje
      `build`/`message`), wskazówka w CLAUDE.md i AGENTS.md; „sygnał uruchamia build” domyślnie włączone.
- [x] Blokada adresu nie przedłuża się przez odwołany telefon; ponownie sparowany działa od razu.
- [x] Typ projektu rozpoznawany ponownie, gdy pusty folder stanie się projektem (np. Flutter).
- [x] Usunięta nieaktywna ikona nad nawigacją w oknie.
- [x] Testy: rdzeń 129, Android 33, e2e przez Tailscale: sygnał → build → dostawa → delta.

## Faza 5c — 0.6: nazwa, audyt, VPS

- [x] Nazwa RemoteAppTester (aplikacje, identyfikator Androida, pliki w projektach, katalog danych)
      z migracją danych, autostartu i plików w projektach.
- [x] Z audytu: kod parowania jednorazowy i ważny 1 godzinę, rotacja sekretu co 30 dni, kopiowanie
      linku z ostrzeżeniem, domyślnie „Pytaj na telefonie”, szersza redakcja logów, brak kopii
      zapasowej danych telefonu, podpis wydania przez `key.properties`.
- [x] Zakładka Informacje w oknie, na telefonie i `rt info` (jedno źródło: `tool/i18n/guide.py`).
- [x] Serwer Linux: paczka budowana w Dockerze, uniwersalny `install.sh`, usługa systemd/OpenRC,
      polecenia `rt n`, `rt o`, `rt lg`, `rt info`, `rt la`, języki w `rt`.
- [x] Testy w kontenerach: Ubuntu 22.04/24.04, Debian 12/13, Alma 9, Fedora, openSUSE, Arch (22/22);
      Ubuntu 20.04, Alma 8 (za stara glibc) i Alpine (musl) dostają czytelną odmowę; test sieciowy
      TLS + HMAC + dostawa + delta + wymiana sekretu; usługa na prawdziwym systemd.
- [x] Paczka arm64: `host/tool/build_release.sh` z emulacją QEMU w Dockerze (`tonistiigi/binfmt --install arm64`).
- [ ] Test na prawdziwym VPS z telefonem i prawdziwym buildem Fluttera (w kontenerach bez Fluttera).
- [ ] Własny klucz wydania i decyzje publikacyjne (`docs/PUBLISHING.md`).

## 0.6.1 — agent wysyła własną instalkę, „O aplikacji”

- [x] `rt push` (agent sam zbudował APK), `rt st`, plik wyniku `.remoteapptester-status.json` i kody
      wyjścia; opcja projektu „Agent AI może wysłać własną instalkę” w oknie i na telefonie.
- [x] „O aplikacji” w oknie i na telefonie: wersja, opis, dane instalacji; komputer podaje telefonowi
      swoją wersję (`Pong.host_version`).
- [x] Poprawka: aplikacje miały wersję 1.0.0 z szablonu Fluttera; skrypt wydania sprawdza teraz zgodność
      wersji wszystkich części.
- [x] Poprawka: telefon, który nie połączył się zapisanym parowaniem, pokazuje przyczynę na ekranie
      połączenia (oraz Informacje i O aplikacji), zamiast samego formularza.

## 0.6.2 — Tailscale ACL, nowy projekt z telefonu

- [x] Generator reguł dostępu Tailscale (JSON): Telefony → „Generuj JSON dla Tailscale” w oknie,
      `rt acl [--with <komputer>]` na Linux; port z konfiguracji programu.
- [x] Nowy projekt z telefonu (Flutter, pusty folder, wolny folder z `projects_root`): RPC
      `ListAvailableFolders` / `CreateProject`, sama nazwa folderu, `phone_add_projects` w
      `host-config.yaml` (domyślnie włączone).
- [x] Zrozumiały błąd połączenia na telefonie (także o ACL Tailscale); instrukcje: bateria
      „Bez ograniczeń”, ACL.
- [x] Poprawka: ta sama wersja nie jest już pobierana ani instalowana dwa razy — dostawy w tle,
      „Zainstaluj ostatnią” i „Zbuduj i zainstaluj” idą przez jedną kolejkę (`DeliveryService`);
      telefon pamięta zainstalowany build projektu.
- [x] Ekran projektu na telefonie: przyciski według kroków (zbuduj → zainstaluj → uruchom),
      „Najnowsza zainstalowana”, „Uruchom” tylko dla zainstalowanej aplikacji; podgląd konsoli
      na żywo (log builda, pobieranie, instalacja), dotknięcie otwiera pełny log.

## 0.6.3 (telefon) — dźwięki, poprawka pobierania

- [x] Poprawka: „Cannot rename … .apk.new” — dwie instalacje tego samego projektu naraz (druga usługa
      dostaw po ponownym połączeniu, ponownie wysłana zaległa dostawa); teraz jedna usługa na aplikację,
      pobieranie per projekt po kolei, osobny plik tymczasowy na build.
- [x] „Odtwarzaj dźwięki” (telefon, okno Windows, `rt so` na Linux): krótkie tony — koniec builda,
      błąd builda, instalacja, nowa wersja / zgłoszenie agenta.
- [x] Prędkość pobierania na pasku i w podglądzie projektu (diagnoza wolnej końcówki transferu).
- [x] Instalator Windows: proponuje usunięcie zbędnej reguły zapory wersji 0.3 (jedna zgoda UAC).
- [x] Okno Windows i Linux z dźwiękami trafiły do paczek w 0.6.4.

## 0.6.4 — podgląd aplikacji web przez Tailscale

- [x] Podgląd strony z telefonu (dowolny typ): host rozpoznaje ASP.NET (`dotnet watch`, także projekt
      piętro niżej), Flutter Web, Next.js, Angular, Vite, Node (`npm run dev` / `npm start`, `PORT`),
      Django, Flask, Laravel, PHP i strony statyczne (wbudowany serwer plików, SPA). Własna komenda
      z `{port}` w oknie (Opcje) albo `rt o --preview-cmd`; `rt o --preview on|off`.
- [x] Serwer deweloperski słucha tylko na `127.0.0.1`; do Tailscale wystawia go proxy hosta z
      jednorazowym tokenem (w adresie, potem ciasteczko HttpOnly), także WebSockety (hot reload,
      SignalR). Najpierw `tailscale serve` (HTTPS *.ts.net), bez niego proxy na adresie Tailscale
      z certyfikatem z parowania — telefon akceptuje go wyłącznie po odcisku SHA-256.
- [x] RPC `StartPreview` (strumień: stan, log, „odśwież”), `StopPreview`, `ReportPreviewIssue`;
      `Project.preview_available/preview_kind/preview_running`; opcja projektu `preview`
      (domyślnie włączona) i `preview_command` w bazie (migracja 5).
- [x] Telefon: ekran podglądu z WebView, log serwera, „Otwórz w przeglądarce” (HTTPS Tailscale),
      zatrzymanie; „Zgłoś problem” zapisuje opis, adres i konsolę JS do `.remoteapptester-feedback.md`
      w projekcie dla agenta AI, razem z ostatnimi liniami logu serwera (błędy Blazor Server są po stronie
      serwera). Widok telefonu 390 px (domyślny) albo komputera 1280 px.
- [x] Sygnał agenta (`rt sg`, `rt push`) restartuje serwer aplikacji (hot reload, np. Blazor Server,
      działa tylko częściowo — jest dodatkiem) i odświeża otwartą stronę, gdy nowy serwer odpowiada.
- [x] Zatrzymanie po bezczynności (`preview_idle_minutes`, 30), przy kill-switchu i zamknięciu hosta;
      porty `preview_port`/`preview_port_count` (47100–47109) w ACL Tailscale i zaporze Windows.
- [x] Poprawka: dodanie projektu z telefonu na starszym hoście (bez `CreateProject`) pokazywało
      „nieoczekiwany błąd” — teraz komunikat o aktualizacji; brak Fluttera i błędy zapisu folderu
      mają czytelny komunikat.

## 0.6.5 / 0.6.6 — blokada odciskiem palca, wydanie open source (MIT)

- [x] Telefon: blokada całej aplikacji odciskiem palca (PIN telefonu jako zapas) przy starcie,
      po powrocie z tła (od razu / 1 / 5 / 15 min, domyślnie 1 min) i po 15 min bez dotyku;
      domyślnie włączona. Wyłączenie i dłuższy czas wymagają odcisku. Telefon bez blokady ekranu
      prowadzi do ustawień Androida, żeby dodać odcisk (`security/app_lock.dart`).
- [x] Dokumentacja dla użytkowników nietechnicznych: README (EN/PL), `docs/PORADNIK.md`,
      `docs/VPS.md`, `docs/PROMPTY.md`, `docs/LEGAL.md`, `docs/PRIVACY.md`; licencja,
      `CONTRIBUTING.md`, `.github/` (bezpieczeństwo, zgłoszenia, wsparcie).
- [x] 0.6.6: instalator Linux pyta o zgodę na licencje Android SDK (`--accept-android-licenses`
      dla instalacji bez terminala); licencja MIT w metadanych aplikacji Windows; poradnik, VPS i prompty
      także po angielsku (`docs/en/`); publiczne repozytorium `damiannass88/RemoteAppTester`.

## Faza 6 — Kolejne technologie

- [ ] React Native (bundle w APK debug, bez Metro), Capacitor (`npx cap sync` + Gradle).
- [ ] Metody z wieloma artefaktami (split per ABI — wybór pliku dla architektury telefonu).
- [ ] Rozważenie: Headscale/WireGuard jako alternatywa dla konta Tailscale; iOS.

## Zasady pracy

- Każda nowa metoda budowania i każda zmiana kontraktu = przegląd bezpieczeństwa
  (SECURITY.md, sekcja „Checklist”).
- Kontrakt zmieniany tylko w `proto/remote_tester.proto`, potem regeneracja po obu stronach
  ([proto/README.md](../proto/README.md)).
- Testy uruchamiające prawdziwe procesy dla wszystkiego, co dotyka `Process.start` (lekcja z
  RemoteDevelopment: zawieszanie się na Windows przy procesach bez wyjścia).
