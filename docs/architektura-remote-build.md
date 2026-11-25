# Architektura transportu i bezpieczeństwa (odziedziczona z RemoteDevelopment)

> **Status w RemoteAppTester:** dokument historyczny z projektu RemoteDevelopment (Etap A),
> zachowany jako uzasadnienie warstwy transportu i bezpieczeństwa, które RemoteAppTester przejął
> bez zmian: Tailscale-only bind, TLS pinning, HMAC z nonce/timestamp, parowanie lokalne,
> izolacja per urządzenie, instalacja APK przez `PackageInstaller` (sekcje 2–3, 4a, 5–7).
> Nieaktualne w RemoteAppTester: GUI z tray-em agenta (host jest CLI), wybór brancha i
> operacje git z telefonu, nazwy `desktop_agent`/`mobile_app`/`BuildAgent` (teraz `host`,
> `android_app`, `HostAgent`), struktura repozytorium i plan faz (sekcje 8–9).
> Obowiązujące założenia: [PROJECT_ASSUMPTIONS.md](PROJECT_ASSUMPTIONS.md); plan:
> [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md); bezpieczeństwo: [SECURITY.md](SECURITY.md).

Założenia wejściowe: komputer buildujący = **Windows**, sieć = **Tailscale** (WireGuard),
telefon wybiera **projekt/branch zdalnie**, agent ma **GUI z tray-em**, system obsługuje
**wiele sparowanych telefonów jednocześnie**. Priorytety: stabilność, prywatność,
bezpieczeństwo, minimalne uprawnienia, wyłącznie sprawdzone biblioteki.

---

## 1. Komponenty systemu

| Komponent | Rola | Platforma |
|---|---|---|
| **Remote App** | pilot – wybór projektu/brancha, start builda, podgląd logów, odbiór i instalacja APK | Android (Flutter), wiele instancji na wielu telefonach |
| **Build Agent** | aplikacja z GUI i tray-em – zarządza parowaniem wielu urządzeń, odbiera zlecenia, wykonuje `git`/`flutter`, streamuje status, wysyła plik | Windows (Flutter Desktop) |
| **Tailscale** | warstwa sieciowa – prywatna, szyfrowana sieć nakładkowa (mesh VPN na WireGuard) | wszystkie urządzenia |

Nie ma serwera pośredniczącego w chmurze — Tailscale daje połączenie **peer-to-peer** (lub
przez ich DERP relay, gdy NAT nie pozwala na bezpośrednie połączenie, ale i tak end-to-end
zaszyfrowane). To realizuje wymóg "niezależne od sieci lokalnej, ale prywatne".

---

## 2. Warstwa sieciowa – dlaczego Tailscale

- Oparty o **WireGuard** (audytowany, minimalna powierzchnia ataku, w jądrze Linux/Windows).
- Każde urządzenie dostaje stały adres w prywatnej sieci `100.x.x.x` (tailnet) — telefon
  łączy się z komputerem po tym adresie **niezależnie od tego, w jakiej sieci fizycznie się
  znajduje** (LTE, inne WiFi, hotspot).
- **Tailscale ACL** (access control list) pozwala ograniczyć, że tylko Twoje konto/urządzenia
  mogą się widzieć, oraz że telefon może łączyć się z agentem tylko na jednym konkretnym porcie.
- Nie musisz stawiać własnego serwera VPN, otwierać portów na routerze ani zarządzać
  certyfikatami sieciowymi — to zmniejsza powierzchnię błędu konfiguracyjnego.
- Alternatywa "własny WireGuard" wymagałaby samodzielnego zarządzania kluczami, serwerem
  koordynującym i NAT traversal — więcej ruchomych części przy tym samym poziomie
  bezpieczeństwa. Tailscale jest tu uzasadnionym kompromisem "sprawdzona biblioteka/usługa".

**Ważne:** Tailscale to zaufanie do firmy Tailscale co do *koordynacji* połączenia (wymiana
kluczy publicznych). Sam ruch danych (build, logi, APK) i tak jest E2E szyfrowany WireGuardiem
— Tailscale nie widzi treści. Jeśli to nieakceptowalne, można w przyszłości podmienić na
self-hosted Headscale (open-source, kompatybilny protokołowo) bez zmiany reszty architektury.

---

## 3. Protokół komunikacji między telefonem a agentem

Transport bazowy to Tailscale, ale — po analizie zagrożeń w sekcji 6 — **każde połączenie
aplikacyjne dodatkowo idzie po TLS z przypiętym certyfikatem** generowanym lokalnie przez
agenta. To źródło zaufania niezależne od Tailscale: nawet gdyby ktoś dotarł do adresu agenta
(błąd w ACL, przejęte konto Tailscale), bez znajomości sparowanego certyfikatu i klucza HMAC
i tak nie nawiąże ważnej sesji. Szczegóły w sekcji 6.3.

Rekomendacja: **gRPC (streaming) po HTTP/2 z TLS**, biblioteka `grpc` (oficjalna, Google,
dojrzała, ma wsparcie w Dart/Flutter). Powody:
- natywne wsparcie **bidirectional streaming** — idealne do logów builda w czasie rzeczywistym,
- silnie typowane kontrakty (`.proto`) — mniej błędów integracyjnych niż ręczny JSON/WebSocket,
- **wbudowane, natywne wsparcie TLS** — nie trzeba dokładać osobnej biblioteki kryptograficznej,
- transfer dużego pliku (APK) też można zrobić strumieniowo w ramach tego samego API (chunki).

Każde wywołanie RPC niesie dodatkowo metadane uwierzytelniające — `pairing_key_id`,
`timestamp`, `nonce`, `hmac` — opisane w sekcji 6.4. To chroni przed atakiem powtórzeniowym
nawet w obrębie już nawiązanej, zaufanej sesji TLS.

Alternatywa prostsza we wdrożeniu: **WebSocket + JSON** (pakiet `web_socket_channel`) + osobny
endpoint HTTP do transferu pliku, również po TLS. Mniej "ceremonii" niż gRPC, ale trzeba samemu
pilnować protokołu wiadomości, retry itd. Dla pojedynczego dewelopera to sensowny punkt
startowy — gRPC można wprowadzić później, gdy poczujesz potrzebę.

### Szkic kontraktu (proto / logiczny)

```proto
service BuildAgent {
  rpc ListProjects(Empty) returns (ProjectList);
  rpc ListBranches(ProjectRequest) returns (BranchList);
  rpc StartBuild(BuildRequest) returns (stream BuildEvent); // status streaming
  rpc DownloadArtifact(ArtifactRequest) returns (stream Chunk); // transfer APK
  rpc CancelBuild(BuildId) returns (Ack);
}

message BuildRequest {
  string project_id = 1;
  string branch = 2;
  string build_flavor = 3; // debug/release
}

message BuildEvent {
  string build_id = 1;
  BuildPhase phase = 2; // QUEUED, GIT_CHECKOUT, PUB_GET, BUILDING, PACKAGING, DONE, FAILED
  string log_line = 3;
  int32 progress_percent = 4;
}
```

Uwierzytelnienie (`pairing_key_id`, `timestamp`, `nonce`, `hmac`) nie jest polem w każdej
wiadomości biznesowej — jest dołączane jako **gRPC metadata** (nagłówki) przez wspólny
interceptor po obu stronach, więc kontrakty powyżej zostają czyste, a cała logika auth
siedzi w jednym miejscu, łatwym do zaudytowania.

---

## 4. Komponent: Build Agent (Windows)

### Odpowiedzialności
1. Nasłuchuje na porcie TCP **tylko na interfejsie Tailscale** (nie na `0.0.0.0`) — agent
   nie jest w ogóle widoczny poza tailnetem.
2. Uwierzytelnia każde żądanie **per urządzenie** (własny sekret parowania na telefon —
   szczegóły w sekcji 4a).
3. Wykonuje **z góry zdefiniowaną, białą listę operacji** — nigdy dowolnego shella z telefonu:
   - `git fetch` + `git checkout -- <branch>` (jawny separator `--` blokuje interpretację
     nazwy brancha jako flagi, np. `--upload-pack=...`; nazwy zaczynające się od `-` są
     odrzucane jeszcze przed wywołaniem procesu) w obrębie katalogu wskazanego przez
     `project_id`,
   - `flutter pub get`,
   - `flutter build apk --release` (lub inny z ustalonego, zamkniętego zbioru flag —
     żadna flaga nigdy nie jest budowana z danych przysłanych przez telefon),
   - odczyt wynikowego pliku z `build/app/outputs/flutter-apk/`.
4. Streamuje `stdout`/`stderr` procesu **tylko do urządzenia, które zleciło dany build** —
   inne sparowane telefony nie widzą cudzych logów (patrz 4a).
5. Po sukcesie liczy **SHA-256** artefaktu i wysyła razem z plikiem (integralność).
6. Serializuje buildy w **jednej globalnej kolejce** — jedna maszyna, jeden aktywny build
   naraz, niezależnie od tego, które i ile urządzeń zleca żądania (patrz 4a).
7. Utrzymuje log operacji (audyt lokalny, z adnotacją *które* urządzenie co zleciło).

### Stos technologiczny (stabilne, sprawdzone)
- **Dart** jako runtime agenta (spójność języka z resztą projektu; `dart:io` ma solidne
  `Process.start` do uruchamiania komend) **lub** Flutter Desktop (Windows) jeśli chcesz GUI
  z tray-iconem pokazującym status — polecane, bo dajesz sobie wgląd lokalnie i możliwość
  awaryjnego "kill switch" bez telefonu.
- `package:grpc` – serwer gRPC (z TLS włączonym natywnie).
- `package:crypto` – HMAC-SHA256 (uwierzytelnianie żądań i artefaktów) oraz sumy kontrolne.
- Sekret parowania i klucz prywatny certyfikatu TLS trzymane przez **Windows DPAPI**
  (`CryptProtectData`) / Credential Manager — nigdy jako plaintext w pliku configu, więc
  nawet odczyt dysku przez inny lokalny proces/użytkownika ich nie ujawnia.
- Proces budowania uruchamiany przez `Process.start` z **jawną, zamkniętą listą argumentów**
  (nigdy interpolacja stringów od usera do shella — to klasyczna droga do command injection).
- Uruchamiany jako zwykły proces użytkownika (nie usługa systemowa/SYSTEM) — brak potrzeby
  podniesionych uprawnień, mniejszy promień rażenia w razie kompromitacji.

### Walidacja wejścia (krytyczne dla bezpieczeństwa)
- `project_id` to **nieprzezroczysty identyfikator** wygenerowany przez agenta podczas skanu
  katalogu nadrzędnego (patrz niżej) — telefon nigdy nie zna ani nie podaje żadnej ścieżki
  systemowej.
- `branch` przepuszczany przez `git check-ref-format` / regex ograniczający do znaków
  dozwolonych w nazwach branchy — zero interpolacji do shella.
- Limit równoległych buildów: 1 (kolejka), by nie przeciążyć maszyny i uniknąć race conditions
  na tym samym katalogu roboczym.

### Discovery projektów — jeden katalog nadrzędny zamiast jawnej listy ścieżek

Zamiast wpisywać w konfiguracji pełną listę `{id, ścieżka, repo}` dla każdego projektu
(co wymagałoby ręcznego utrzymywania i tak czy inaczej trzyma ścieżki w pliku), agent zna
tylko **jeden korzeń**:

```yaml
# agent-config.yaml
projects_root: "D:\Dev\FlutterProjects"
scan_depth: 1          # tylko bezpośrednie podkatalogi, nie rekurencja w głąb
require_marker: pubspec.yaml   # folder liczy się jako "projekt" tylko jeśli go zawiera
```

Przy starcie (i na żądanie `ListProjects`) agent:

1. Skanuje **wyłącznie bezpośrednie podkatalogi** `projects_root` (domyślnie `scan_depth: 1`
   — nie przegląda całego drzewa dysku, więc nawet lokalnie nie buduje sobie mapy Twojego
   systemu plików poza tym jednym miejscu).
2. Odrzuca każdy podkatalog, który nie zawiera `pubspec.yaml` z sekcją `flutter:` —
   filtr "to na pewno projekt Flutter", nie cokolwiek innego, co akurat leży obok.
3. Dla każdego pasującego katalogu generuje **stabilny, nieprzezroczysty `project_id`**
   (np. `sha256(nazwa_folderu)[:12]`) i trzyma mapowanie `project_id → pełna ścieżka`
   **wyłącznie w pamięci procesu agenta** — nigdy nie serializowane, nigdy nie wysyłane.
4. Do telefonu wysyła **tylko**: `project_id` + `display_name` (sama nazwa folderu, bez
   ścieżki nadrzędnej) + opcjonalnie znacznik czasu ostatniego commita. Żadnych informacji
   o dysku, użytkowniku Windows, innych katalogach obok, ani o samej strukturze
   `projects_root`.
5. Każde kolejne żądanie (`ListBranches`, `StartBuild`) referencuje projekt wyłącznie przez
   ten `project_id` — agent po swojej stronie odtwarza pełną ścieżkę z mapy w pamięci.
6. **Zabezpieczenie przed path traversal**: po rozwiązaniu `project_id → ścieżka`, agent
   zawsze kanonizuje wynikową ścieżkę (`realpath`/`File.resolveSymbolicLinksSync`) i
   sprawdza, że nadal zaczyna się od `projects_root` — nawet gdyby ktoś podrzucił symlink
   wychodzący poza katalog, żądanie zostanie odrzucone.

Efekt: jedyna informacja, jaką operator musi ręcznie skonfigurować, to **jeden katalog
nadrzędny**. Dodanie nowego projektu do systemu = po prostu sklonowanie repo do tego
katalogu — nic nie trzeba dopisywać w configu, a telefon i tak nigdy nie zobaczy niczego
poza nazwami folderów, które sam tam umieściłeś.

### 4a. Wiele urządzeń — parowanie i izolacja

Agent trzyma **rejestr sparowanych urządzeń**, nie jeden globalny sekret:

```
paired_devices:
  - device_id: "a1c9…"        # losowy identyfikator, nie nazwa hosta ani IP
    display_name: "Telefon testowy — Pixel"   # nadawany ręcznie przy parowaniu
    pairing_secret: <zaszyfrowane DPAPI>
    created_at, last_seen_at
```

Konsekwencje tego modelu:
- **Każde urządzenie ma własny `pairing_secret`.** Odwołanie (rewokacja) jednego telefonu
  (zgubiony, sprzedany) nie wpływa na pozostałe — nie trzeba ponownie parować całej floty.
- **Izolacja widoczności.** Telefon A widzi tylko własne buildy, logi i historię — nigdy
  buildów zleconych przez telefon B. Agent filtruje strumienie eventów po `device_id`
  żądającego. To istotne, jeśli z pilotów korzysta więcej niż jedna osoba (np. dwóch
  testerów w zespole).
- **Wspólna, jedna kolejka builda.** Mimo wielu urządzeń, fizycznie jest jeden Windows z
  jednym `flutter build` na raz (współdzielony cache Gradle/Pub czyni równoległe buildy
  ryzykownymi). Żądania z różnych telefonów trafiają do jednej kolejki FIFO; zlecające
  urządzenie widzi swoją pozycję w kolejce, pozostałe urządzenia widzą wyłącznie ogólny
  status "agent zajęty" bez szczegółów cudzego builda.
- **Osobny branch/projekt na urządzenie w danej chwili.** Każdy telefon niezależnie wybiera
  swój `project_id`/`branch` z tego samego wspólnego `projects_root` — nic nie stoi na
  przeszkodzie, by dwa telefony pracowały nad różnymi gałęziami tego samego repo (build i
  tak wykona się sekwencyjnie, więc nie ma konfliktu na katalogu roboczym w danym momencie).
- **Nowe parowanie zawsze wymaga fizycznego dostępu do komputera** — QR generowany jest
  wyłącznie z poziomu GUI agenta (sekcja 4b), nigdy zdalnie przez sieć. To zapobiega
  "samodoparowaniu się" przez kogoś, kto już ma dostęp do jednego telefonu.

### 4b. GUI i tray agenta (Flutter Desktop)

Panel widoczny **wyłącznie lokalnie na ekranie komputera** (nigdy przez sieć — to nie jest
kolejny endpoint API, tylko zwykłe UI procesu):

- **Lista aktywnych połączeń** — które sparowane urządzenia są aktualnie połączone, z jakim
  projektem/branchem aktualnie pracują, status ostatniego builda.
- **Lista wszystkich sparowanych urządzeń** (także offline) z `display_name`, datą
  sparowania, datą ostatniej aktywności, oraz przyciskiem **"Odwołaj"** dla każdego z
  osobna.
- **Generowanie nowego QR do parowania** — jednorazowy kod ważny np. 5 minut, po czym wygasa
  automatycznie, jeśli nikt go nie zeskanuje.
- **Podstawowe informacje o sieci** — status Tailscale (połączony/rozłączony), własny
  adres w tailnecie, oraz dla każdego aktywnego połączenia czy idzie **bezpośrednio (P2P)**
  czy przez **DERP relay** (to standardowa informacja z `tailscale status`, przydatna do
  diagnozowania problemów z łącznością). To nie pogarsza bezpieczeństwa — dane te są
  widoczne tylko lokalnie, na ekranie właściciela komputera, nigdy nie są wysyłane do
  telefonów ani na zewnątrz.
- **Globalny wskaźnik kolejki i przycisk "Wstrzymaj przyjmowanie nowych zleceń"** — ręczny
  kill-switch, przydatny np. gdy pracujesz lokalnie i nie chcesz, by zdalne buildy zajmowały
  maszynę.
- Tray icon pokazuje w skrócie: liczbę połączonych urządzeń i czy trwa build — bez
  otwierania pełnego okna.

**Uwaga dot. prywatności:** panel pokazuje właścicielowi komputera *wszystko* (bo ma
fizyczny dostęp do maszyny i tak), ale to nie zmienia zasady izolacji między telefonami —
telefon A nadal przez sieć nie ma żadnego sposobu, by zapytać agenta o dane telefonu B.

---

## 5. Komponent: Remote App (Android, Flutter)

### Odpowiedzialności
- Discovery / konfiguracja adresu agenta (Tailscale IP lub MagicDNS hostname, np.
  `desktop.tailXXXX.ts.net`) — wpisywane raz, zapisane lokalnie.
- Lista projektów/branchy pobierana z agenta (nie hardkodowana w apce).
- Start builda, live log/progress.
- Odbiór APK strumieniowo, weryfikacja SHA-256 przed instalacją.
- Instalacja bez roota przez **Android PackageInstaller Session API**.

### Instalacja APK bez roota, bez ADB — kluczowy mechanizm
Zamiast polegać na ADB przez sieć (wymaga wcześniejszego parowania Wireless Debugging i jest
mniej stabilne jako "produkcyjny" mechanizm), Remote App **sama instaluje siebie-siostrzaną
apkę** przy pomocy natywnego mechanizmu Androida:

- Android `PackageInstaller.Session` (API dostępne z poziomu natywnego kodu, w Flutterze przez
  cienki **MethodChannel** do małego fragmentu Kotlina — kilkadziesiąt linii, nie osobna
  biblioteka stron trzecich).
- Wymaga jednego uprawnienia w manifeście: `REQUEST_INSTALL_PACKAGES`.
- Przy pierwszej instalacji system pokaże **jednorazowy** systemowy prompt "zezwól tej
  aplikacji na instalowanie nieznanych aplikacji" — to standardowe zachowanie Androida,
  nie da się (i nie powinno się) tego ominąć.
- Zaleta względem ADB: działa niezależnie od stanu debugowania USB/sieciowego, nie wymaga
  wcześniejszego "adb pair", więc jest bardziej stabilne jako codzienne narzędzie.
- Pakiet pomocniczy istnieje na pub.dev (`open_filex`/`install_plugin`), ale przy Twoim
  priorytecie "tylko sprawdzone, minimalne" polecam **własny, mały MethodChannel** — mniej
  zależności trzecich w krytycznej ścieżce instalacyjnej, pełna kontrola nad tym co robi kod.

### Uprawnienia Android (i tylko te)
- `INTERNET` — komunikacja z agentem (przez Tailscale, więc technicznie to zwykły ruch IP).
- `REQUEST_INSTALL_PACKAGES` — instalacja pobranego APK.
- Brak dostępu do kontaktów, lokalizacji, pamięci masowej (plik trzymany w prywatnym
  `cacheDir` aplikacji, nie wymaga `WRITE_EXTERNAL_STORAGE`), brak brokerów Bluetooth itd.

### Stos technologiczny
- Flutter (stable channel) jako baza.
- `package:grpc` (Dart) do komunikacji z agentem, z TLS i przypiętym certyfikatem.
- `package:flutter_secure_storage` — dojrzała, szeroko używana biblioteka opakowująca
  Android Keystore (i iOS Keychain, gdyby kiedyś potrzebne). Przechowuje sekret parowania
  oraz odcisk (fingerprint) przypiętego certyfikatu TLS — nigdy w zwykłym
  `SharedPreferences`/plaintext.
- `package:local_auth` — wymaga biometrii/PIN-u urządzenia przed każdą wrażliwą akcją
  (start builda, instalacja APK). Jeśli telefon wpadnie w niepowołane ręce z odblokowanym
  ekranem, sama apka i tak zapyta o dodatkowe potwierdzenie.
- Minimalny natywny plugin Kotlin (PackageInstaller) — pisany samodzielnie, ~100-150 linii,
  łatwy do zaudytowania w całości.
- Tailscale na telefonie: **oficjalna aplikacja Tailscale dla Androida** (osobna, z Google
  Play) uruchomiona równolegle — Twoja apka nie musi integrować VPN-a samodzielnie, po
  prostu łączy się po adresie tailnetowym, tak jak każda inna. To upraszcza Twój kod i
  odsuwa odpowiedzialność za implementację VPN do sprawdzonej, dedykowanej aplikacji.

---

## 6. Bezpieczeństwo i prywatność — ocena zagrożeń i wzmocnienia

Poniżej ocena pierwotnej wersji projektu pod kątem "co jeśli ktoś naprawdę spróbuje to
zaatakować", oraz konkretne poprawki. Kilka punktów z poprzedniej wersji dokumentu było
zaznaczonych jako "opcjonalne, defense in depth" — po analizie **przestają być opcjonalne**.

### 6.1 Model zagrożeń

| Zagrożenie | Ryzyko w wersji pierwotnej | Status po wzmocnieniu |
|---|---|---|
| Ktoś inny w tailnecie / przejęte konto Tailscale / błąd w ACL | Sam Tailscale = jedyna bariera; brak niezależnej warstwy zaufania | zamknięte — TLS z przypiętym certyfikatem (6.3), niezależny od Tailscale |
| Atak powtórzeniowy (nagranie i odtworzenie żądania) | HMAC bez nonce/znacznika czasu można było powtórzyć | zamknięte — nonce + timestamp + okno ważności (6.4) |
| Wstrzyknięcie argumentów do `git`/`flutter` przez nazwę brancha | regex bez separatora `--` to za mało | zamknięte — separator `--` i blokada wiodącego `-` (sekcja 4) |
| Aktywny MITM podmienia APK i przelicza SHA-256 na nowo | czysty SHA-256 bez uwierzytelnienia kanału nic nie gwarantuje | zamknięte — cały kanał autentykowany (TLS pinning + HMAC), SHA-256 pozostaje jako kontrola integralności *w obrębie* już zaufanego kanału |
| Zgubiony/skradziony telefon z odblokowanym ekranem | trwały, cichy dostęp do buildowania i wglądu w kod | ograniczone — Keystore + biometria przed akcją (6.7) + zdalna rewokacja parowania (6.7) |
| Malware/inny użytkownik na tym samym Windows czyta plik configu | token/klucz w plaintext = trwały dostęp | zamknięte — DPAPI/Credential Manager (sekcja 4) |
| Zgadywanie/brute-force tokenu parowania | brak limitu prób | ograniczone — rate limiting + lockout (6.6) |
| Wyciek sekretów (klucze API, hasła) w logach builda streamowanych na telefon | logi w całości trafiają na telefon i tam zostają | częściowo ograniczone — redakcja wzorców (6.9), nie 100% niezawodna |
| Kompromitacja tego narzędzia ujawnia klucz podpisujący produkcyjne APK ze Sklepu Play | jeśli pipeline używałby klucza produkcyjnego | zamknięte przez politykę — osobny klucz deweloperski (6.8) |
| Jeden skompromitowany telefon (z wielu sparowanych) daje dostęp do wszystkich | wspólny sekret dla wszystkich urządzeń = jeden wyciek = pełna kompromitacja | zamknięte — osobny `pairing_secret` na urządzenie, rewokacja pojedyncza (4a, 6.5) |
| Telefon A podsłuchuje/odczytuje logi lub status builda zleconego przez telefon B | brak izolacji strumieni między urządzeniami | zamknięte — filtrowanie eventów po `device_id`, telefon widzi tylko własne buildy (4a) |
| Ktoś zdalnie generuje sobie nowy QR i dopisuje się do systemu | zdalny endpoint do parowania byłby furtką | zamknięte przez projekt — nowe parowanie tylko lokalnie z GUI agenta, wymaga fizycznego dostępu do komputera (4b) |

### 6.2 Warstwy zabezpieczeń (zaktualizowane)

1. **Tailscale/WireGuard** — szyfrowanie transportu, uwierzytelnienie urządzeń w tailnecie.
2. **Tailscale ACL** — jawne "deny all" + wyjątek tylko dla pary telefon↔desktop.
3. **TLS z przypiętym certyfikatem** *(nowość — obowiązkowa, nie opcjonalna)* — niezależne od
   Tailscale źródło zaufania, patrz 6.3.
4. **Parowanie aplikacyjne + HMAC z nonce/timestamp na każdym żądaniu** *(rozszerzone)* —
   patrz 6.4.
5. **Whitelisting komend z ochroną przed argument injection** (sekcja 4).
6. **Integralność artefaktu w obrębie autentykowanego kanału** (sekcja 4/6.4).
7. **Brak nasłuchu na publicznym interfejsie** — bind wyłącznie na adres Tailscale.
8. **Rate limiting i lockout** *(nowość)* — patrz 6.6.
9. **Sekrety w bezpiecznym magazynie po obu stronach** *(nowość)* — DPAPI (Windows) i
   Keystore (Android), patrz 6.9.

### 6.3 TLS z przypiętym certyfikatem — dlaczego to nie jest tylko "wzmocnienie"

WireGuard chroni *treść* ruchu, ale zaufanie do tego, *kto z kim może się połączyć*, opiera
się na koordynacji przez konto Tailscale. Jeśli ktoś przejmie to konto (phishing, wyciek
hasła) i doda urządzenie do tailnetu zanim to zauważysz, albo popełnisz błąd w regule ACL —
sam Tailscale już nie wystarcza jako jedyna bariera.

Rozwiązanie: przy pierwszym uruchomieniu agent generuje **własny, samopodpisany certyfikat
TLS**. Jego odcisk (SHA-256 fingerprint) jest pokazywany w tym samym QR kodzie co token
parowania — telefon zapamiętuje ten odcisk raz, fizycznie, przy biurku. Każde kolejne
połączenie telefon weryfikuje, że certyfikat agenta wciąż ma dokładnie ten sam odcisk
(**certificate pinning**) i odrzuca sesję przy jakiejkolwiek rozbieżności. To źródło zaufania
całkowicie niezależne od Tailscale — nawet gdyby ktoś oszukał warstwę sieciową, nie przejdzie
przez tę.

### 6.4 Ochrona przed atakiem powtórzeniowym (replay)

Każde żądanie niesie w metadanych gRPC: `pairing_key_id`, `timestamp`, losowy `nonce` (16B) i
`hmac = HMAC-SHA256(pairing_secret, method || payload || timestamp || nonce)`. Agent:
- odrzuca żądania starsze niż ok. 60 sekund (wymaga zsynchronizowanego zegara — NTP włączony
  domyślnie w Windows/Android to wystarczy),
- trzyma krótkotrwałą (kilka minut) pamięć widzianych `nonce` i odrzuca duplikaty.

Dzięki temu nawet ktoś, kto podsłuchałby (teoretycznie) pojedyncze zaszyfrowane żądanie, nie
mógłby go odtworzyć później, by np. ponownie zainstalować stary/podmieniony build.

### 6.5 Utrata telefonu i rewokacja dostępu

- W GUI agenta (sekcja 4b) każde sparowane urządzenie ma osobny przycisk **"Odwołaj"** —
  unieważnia *tylko* `pairing_secret` tego jednego telefonu, natychmiast i bez wpływu na
  pozostałe sparowane urządzenia. Zgubiony telefon traci dostęp od razu, nawet gdyby ktoś
  wcześniej ominął blokadę ekranu.
- Certyfikat TLS agenta (współdzielony, patrz 6.3) rewokowany jest tylko w skrajnym
  przypadku (np. podejrzenie kompromitacji samego komputera) — wymusza wtedy ponowne
  sparowanie *wszystkich* urządzeń, więc to osobna, "cięższa" operacja niż zwykłe odwołanie
  jednego telefonu.
- `local_auth` (biometria/PIN) jako dodatkowa bramka przed *każdą* wrażliwą akcją w apce —
  patrz sekcja 5.
- Warto też włączyć w Tailscale wymóg zatwierdzania nowych urządzeń w tailnecie oraz
  przeglądać listę urządzeń/kluczy okresowo.

### 6.6 Ochrona przed nadużyciem i odmową usługi (DoS)

- Rate limiting **per `device_id`** (nie globalnie) — jeden nadgorliwy/skompromitowany
  telefon nie blokuje pozostałych, rozsądny limit żądań/minutę na urządzenie.
- Lockout: po kilku nieudanych weryfikacjach HMAC w krótkim czasie agent tymczasowo
  ignoruje dalsze próby i zapisuje zdarzenie w logu audytowym.
- Kolejka buildów = 1 (opisana w sekcji 7) dodatkowo ogranicza wpływ nawet zalogowanego,
  ale nadgorliwego klienta na zasoby maszyny.

### 6.7 Weryfikacja pakietu przy instalacji

Android sam pilnuje, że **aktualizacja** istniejącej aplikacji musi być podpisana tym samym
certyfikatem co poprzednia wersja — to wbudowana ochrona systemu, którą dostajemy "za darmo"
przy każdej kolejnej instalacji testowanej apki. Dodatkowo Remote App może przed wywołaniem
instalatora zweryfikować nazwę pakietu (`applicationId`) z APK względem oczekiwanej dla
danego projektu, żeby nie dało się przez pomyłkę/podmianę zainstalować czegoś spod innej
nazwy pakietu.

### 6.8 Klucz podpisujący APK — nie używaj klucza produkcyjnego w tym pipeline

Ten kanał służy do szybkiego testowania, nie do dystrybucji w Sklepie Play. Buildy powinny
być podpisywane **osobnym, dedykowanym kluczem deweloperskim/testowym**, nigdy tym samym,
którym podpisujesz wydania trafiające do Google Play. Dzięki temu nawet pełna kompromitacja
tego narzędzia (np. przejęty Windows) nie naraża klucza produkcyjnego. Jeśli kiedyś
faktycznie potrzebny będzie build podpisany kluczem produkcyjnym do testów wewnętrznych —
trzymaj go tylko w Credential Managerze, nigdy w pliku ani w argumentach procesu widocznych
w logu.

### 6.9 Sekrety w spoczynku i w logach

- **Windows**: `pairing_secret` i klucz prywatny TLS w DPAPI/Credential Manager (sekcja 4) —
  nie w pliku YAML.
- **Android**: `pairing_secret` i odcisk przypiętego certyfikatu w `flutter_secure_storage`
  (Keystore) — nie w `SharedPreferences` (sekcja 5).
- **Logi builda**: przed wysłaniem do telefonu agent przepuszcza każdą linię przez prosty
  filtr redakcji (wzorce typu `*_KEY`, `*_TOKEN`, `*_PASSWORD`, `*_SECRET` w zmiennych
  środowiskowych i argumentach) — to nie jest niezawodne w 100%, ale eliminuje najbardziej
  oczywiste, przypadkowe wycieki sekretów budowy do historii logów na telefonie.

---

## 7. Stabilność

- **Kolejkowanie buildów** — jedna globalna kolejka FIFO obsługująca żądania ze wszystkich
  sparowanych telefonów naraz (jedna maszyna = jeden aktywny build). Urządzenie zlecające
  widzi swoją pozycję w kolejce; nadmiarowe/powtórzone żądania odrzucane z czytelnym
  komunikatem (nie kolejkowane w nieskończoność, by uniknąć "zombie" żądań po utracie
  połączenia).
- **Reconnect/resume** — gRPC streaming z automatycznym ponawianiem połączenia po zerwaniu
  (Tailscale samo w sobie jest bardzo stabilne, ale telefon zmienia sieci — LTE↔WiFi — więc
  klient musi obsłużyć krótkie zerwania bez gubienia stanu buildu po stronie agenta).
  Build **trwa dalej na Windows** nawet gdy telefon się rozłączy — po ponownym połączeniu
  klient odpytuje o status ostatniego/aktywnego builda zamiast zakładać, że trzeba zacząć od nowa.
- **Transfer pliku w chunkach z checksumą** — pozwala wznowić transfer od ostatniego udanego
  chunku zamiast pobierać cały APK od zera przy zerwaniu.
- **Timeouty i health-check** — telefon co kilka sekund pinguje agenta (lekki RPC), pokazując
  w UI realny status "połączono / rozłączono", zamiast cichego zawieszenia.
- **Logi po stronie agenta trwałe na dysku** — nawet jeśli telefon nigdy nie odbierze pełnego
  streamu logów, historia buildów jest do wglądu lokalnie na Windows.

---

## 8. Struktura repozytorium (propozycja)

```
remote-build-system/
├── proto/                  # wspólne kontrakty .proto (źródło prawdy)
├── mobile_app/              # Flutter (Android) – Remote App
│   └── android/app/...Kotlin plugin instalacyjny
├── desktop_agent/            # Dart/Flutter Windows – Build Agent
│   └── config/agent-config.yaml  # projects_root, scan_depth, dozwolone flagi builda
└── docs/
```

---

## 9. Plan wdrożenia (fazy)

1. **Faza 0 — sieć**: zainstalować Tailscale na obu urządzeniach, zweryfikować połączenie
   (`tailscale ping`), skonfigurować ACL ograniczające dostęp do pary Twoich urządzeń.
2. **Faza 1 — agent CLI**: konsolowy Dart-owy agent z pojedynczym RPC `StartBuild` (bez GUI,
   bez pairing tokenu) — walidacja, że `flutter build apk` uruchomiony programowo działa
   stabilnie i logi da się streamować.
3. **Faza 2 — Remote App MVP**: lista projektów/branchy (statyczna na start), przycisk
   "build", podgląd logów tekstowych.
4. **Faza 3 — transfer i instalacja**: strumieniowanie APK + natywny installer przez
   PackageInstaller, weryfikacja SHA-256.
5. **Faza 4 — bezpieczeństwo**: pairing token + TLS z przypiętym certyfikatem, HMAC z
   nonce/timestamp na każdym żądaniu, whitelisting z ochroną przed argument injection,
   bezpieczne przechowywanie sekretów (DPAPI / Android Keystore), rate limiting i lockout,
   redakcja logów, audyt.
6. **Faza 5 — stabilność**: reconnect, wznawianie transferu, health-check, obsługa wielu
   projektów/branchy z prawdziwej konfiguracji.

---

## 10. Potwierdzone założenia i nowe otwarte decyzje

Rozstrzygnięte:
- Build Agent ma **GUI + tray** (Flutter Desktop) — szczegóły w sekcji 4b.
- System obsługuje **wiele telefonów jednocześnie**, każdy z osobnym parowaniem i
  niezależnym wyborem projektu/brancha — szczegóły w sekcji 4a.
- Wystarczy sam **APK** — praca produkcyjna nadal lokalnie na komputerze.
- Buildy podpisywane osobnym kluczem deweloperskim, nie produkcyjnym (sekcja 6.8).

Nowe pytania, które warto rozstrzygnąć przed implementacją (konsekwencja wielu urządzeń):
- Czy każde sparowane urządzenie ma dostęp do **całego** `projects_root`, czy chcesz móc
  ograniczyć konkretnemu telefonowi widoczność tylko do wybranych podkatalogów (np. gdy
  pilot trafi w ręce innej osoby niż Ty)?
- Czy w GUI agenta chcesz też podgląd logów aktywnego builda innego urządzenia (Ty jako
  właściciel widzisz wszystko lokalnie), czy wystarczy sam status "kto buduje co", bez
  treści logów?
- Ile urządzeń realistycznie chcesz mieć sparowanych naraz (2-3 własne telefony, czy
  faktycznie osobny zespół testerów)? To wpływa na to, czy limit rate-limitingu per
  urządzenie ma być jednakowy dla wszystkich, czy konfigurowalny per telefon w GUI.
