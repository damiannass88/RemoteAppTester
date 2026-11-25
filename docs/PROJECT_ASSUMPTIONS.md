# Założenia projektu — RemoteAppTester

> 🌐 **English:** maintainer design notes, written in Polish. User documentation in English: [README](../README.md), [docs/en/](en/GUIDE.md).

> Źródło prawdy dla zakresu i decyzji. Plan realizacji: [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
> Bezpieczeństwo: [SECURITY.md](SECURITY.md). Architektura transportu (TLS pinning, HMAC,
> parowanie, instalacja APK) odziedziczona z projektu RemoteDevelopment:
> [architektura-remote-build.md](architektura-remote-build.md).
> Aktualizować przy każdej zmianie zakresu.

## 1. Cel

**RemoteAppTester buduje aktualny stan aplikacji z wybranego folderu i dostarcza ją na telefon
testowy — jednym kliknięciem albo automatycznie.**

1. Na komputerze Windows działa **aplikacja okienkowa RemoteAppTester** (zasobnik systemowy,
   praca w tle): zarządzanie projektami (folderami), komendy budowania, budowanie wielu
   projektów naraz, log na żywo, historia, telefony.
2. Każdy **przypisany folder** ma własne komendy budowania (warianty: Debug, Release, …) i
   własne opcje (instalacja na telefonie, auto-uruchomienie, docelowe telefony, kto może
   zlecić build). RemoteAppTester sam wykrywa technologię i wpisuje komendy; można je edytować.
3. Komendy i opcje są w **zaszyfrowanej bazie** RemoteAppTestera. W folderze powstaje plik
   **`REMOTEAPPTESTER.md`** — wytyczne dla agentów AI pracujących w folderze z blokiem komend do
   uzupełnienia; zmiany z pliku trafiają do bazy **dopiero po zatwierdzeniu** w aplikacji.
4. **Wyzwalacze**: przycisk w aplikacji, telefon (pilot), terminal / agent AI (`rt b`).
5. Gotowa instalka (APK) trafia na wybrane telefony, instaluje się i — jeśli zaznaczono —
   uruchamia.

Mówimy o wersjach **debug/demo** do testów, nie o publikacji. Telefon jest **pilotem**: widzi
projekty i ich stan, zleca build i instalację, nie zmienia komend ani projektów.

### Poza zakresem (na teraz)

- Sterowanie agentami AI, czat, podgląd sesji agenta.
- Operacje git (klonowanie, branche) — RemoteAppTester buduje folder w obecnym stanie.
- Publikacja do sklepów, podpis produkcyjny, iOS.
- Linux/VPS w tej iteracji — rdzeń działa (`rt s`), paczka instalacyjna wróci później.

## 2. Komponenty

| Komponent | Platforma | Rola |
|---|---|---|
| **Aplikacja okienkowa** (`desktop_app/`, `RemoteAppTester.exe`) | Windows 10/11 | Projekty, komendy, buildy w tle, log, historia, telefony (parowanie QR), ustawienia; zasobnik i autostart |
| **Rdzeń hosta** (`host/`, pakiet `remotetester_host`) | Windows, Linux | Baza projektów, silnik buildów, dostawy, serwer gRPC dla telefonów, lokalny kanał `127.0.0.1` — używany przez aplikację okienkową i `rt` |
| **`rt` / `remoteapptester`** (`host/bin`) | Windows, Linux | Terminal i agenci AI (`rt b`), serwer bez okna (`rt s`, Linux) |
| **Aplikacja Android** (`android_app/`) | Android 8+ (zalecany 12+) | Pilot: projekty i status, zbuduj i zainstaluj, zainstaluj ostatnią, podgląd, automatyczne dostawy |
| **Kontrakt** (`proto/remote_tester.proto`) | — | gRPC między telefonem a hostem |

Aplikacja okienkowa uruchamia rdzeń **w swoim procesie** (jedna kopia — drugie uruchomienie
pokazuje okno działającej). `rt` łączy się z nią przez uwierzytelniony kanał `127.0.0.1`.

## 3. Priorytety (w tej kolejności)

1. **Bezpieczeństwo i prywatność** — nienegocjowalne ([SECURITY.md](SECURITY.md), sekcja 7).
2. **Stabilność** — build nie ginie przy zerwaniu połączenia; połączenie z telefonem samo się
   odnawia (zmiana sieci); przerwany transfer jest wznawiany.
3. **Szybkość i praca w tle** — wiele projektów buduje się równolegle; okno można zamknąć.
4. **Prostota** — dodaj folder → komendy wpisane automatycznie → „Zbuduj i wyślij”.

## 4. Komendy budowania, baza i `REMOTEAPPTESTER.md`

**Baza RemoteAppTestera** (`%LOCALAPPDATA%\RemoteAppTester\data\remotetester.db`, SQLite3MultipleCiphers):
szyfrowana kluczem z Windows DPAPI (`config/db_key`); strony uwierzytelnione — ręczna zmiana
pliku = błąd otwarcia, nie podmiana komend. Zawiera: projekty (folder, nazwa, typ), warianty
komend, opcje per projekt, historię buildów.

**Wariant budowania** = lista kroków (nazwa + **jedna linia** cmd, uruchamiana w folderze
projektu) + wzorzec ścieżki instalki (`*` w katalogu, `**` dowolna głębokość, wyłącznie
`.apk`, wyłącznie wewnątrz folderu). Przykład (Flutter, wpisywany automatycznie):

| Wariant | Kroki | Instalka |
|---|---|---|
| Debug | `flutter pub get`; `flutter build apk --debug --target-platform android-arm64` | `build/app/outputs/flutter-apk/app-debug.apk` |
| Release | `flutter pub get`; `flutter build apk --release --target-platform android-arm64` | `build/app/outputs/flutter-apk/app-release.apk` |

Autowykrywanie: Flutter, natywny Android (Gradle), React Native, Capacitor; inne — szablon
do uzupełnienia.

**`REMOTEAPPTESTER.md`** (tworzony przy przypisaniu folderu, odświeżany po zapisie komend):

- wyjaśnia agentom AI, czym jest RemoteAppTester i jak utrzymywać blok komend
  (`<!-- remoteapptester:begin -->` … blok YAML `profiles:` … `<!-- remoteapptester:end -->`);
- RemoteAppTester co kilka sekund porównuje blok z bazą; różnica = **propozycja** (znaczek w
  aplikacji). „Przejrzyj” pokazuje obecne i proponowane komendy obok siebie → „Zatwierdź i
  zapisz” albo „Odrzuć” (ta sama treść nie wraca). W terminalu: `rt pr import`;
- blok jest walidowany ściśle (tylko `name`/`steps`/`artifact`, kroki jednoliniowe, instalka
  w folderze) — niepoprawny blok jest zgłaszany, nigdy częściowo stosowany;
- istniejący plik przy przypisaniu folderu nie jest nadpisywany — jego komendy stają się
  propozycją.

**Opcje projektu** (zakładka „Opcje”): nazwa; po zbudowaniu — instaluj automatycznie / pytaj
na telefonie / nie wysyłaj; uruchom po instalacji; telefony docelowe (wszystkie albo
wybrane); kto może zlecić build (telefony, agenci AI / `rt b`).

### Polecenia terminala — skróty i historia

`rt` = `remoteapptester`. `rt` bez argumentów pokazuje tabelę poleceń i **ostatnio używane
polecenia**; `rt h [liczba]` — dłuższa lista.

| Skrót | Polecenie | | Skrót | Polecenie |
|---|---|---|---|---|
| `rt b` | build (w folderze projektu) | | `rt ls` | lista projektów i stan REMOTEAPPTESTER.md |
| `rt a` | przypisz folder | | `rt rm` | odepnij projekt |
| `rt pr` / `rt pr import` / `rt pr guide` | komendy / zatwierdź propozycję / odśwież plik | | `rt m` | szablony komend |
| `rt p` / `rt dv` / `rt rv` | paruj / telefony / odwołaj | | `rt dr` | diagnostyka |
| `rt s` / `rt t` | serwer bez okna / paruj + serwer | | `rt i` / `rt v` / `rt h` | init / wersja / historia |

## 5. Budowanie

- Silnik buduje **różne projekty równolegle** (limit w Ustawieniach, domyślnie 2), ten sam
  projekt — pojedynczo (kolejka); kilka szybkich zleceń tego samego wariantu = jeden build.
- Build trwa niezależnie od tego, kto go zlecił (zamknięte okno, rozłączony telefon,
  przerwane `rt b` nie przerywają budowania). Anulowanie zabija całe drzewo procesów.
- Gotowa instalka jest kopiowana do `artifacts/<projekt>/<build>.apk` (2 ostatnie na
  projekt) — kolejny build nie podmieni pliku, który telefon pobiera; „zainstaluj ostatnią
  wersję” działa także po restarcie.
- Log każdego builda: na żywo w aplikacji i na telefonie, zapis w `logs/builds/`.

## 6. Przepływ

```
 Telefon (pilot)            Aplikacja RemoteAppTester (Windows)               Folder projektu
 ───────────────            ────────────────────────────────               ───────────────
                            [Zbuduj i wyślij] ──┐        ◄── rt b ──────── agent AI / terminal
 [Zbuduj i zainstaluj] ──►  StartBuild ─────────┤                          REMOTEAPPTESTER.md
                                                ▼                            │ (propozycja →
                            komendy z zaszyfrowanej bazy ──► cmd ──────────► │  zatwierdzenie)
 ◄── dostawa (WatchDeliveries) ── instalka + SHA-256
 pobranie (wznawialne) → SHA-256 → applicationId → instalacja → uruchomienie
```

## 7. Bezpieczeństwo i prywatność (decyzje)

- **S1. Sieć: Tailscale (WireGuard)** — szyfrowana sieć prywatna, działa między różnymi
  sieciami (NAT traversal, przekaźniki DERP), sama odnawia połączenia po zmianie sieci. Host
  nasłuchuje **wyłącznie** na adresie Tailscale, nigdy na `0.0.0.0`; nie otwieramy portów w
  internecie. Alternatywy (np. Headscale — własny serwer koordynacji Tailscale, albo czysty
  WireGuard) są zgodne z tym modelem i mogą dojść jako opcja dla osób, które nie chcą konta
  Tailscale.
- **S2. Niezależna warstwa aplikacyjna**: TLS z certyfikatem przypiętym przy parowaniu +
  HMAC (nonce, timestamp, okno ~60 s) na każdym żądaniu. Przejęcie konta Tailscale albo błąd
  ACL nie daje dostępu do hosta.
- **S3. Parowanie wyłącznie lokalnie** na komputerze (aplikacja: Telefony → kod QR; albo
  `rt p`), osobny sekret na każdy telefon, pojedyncze odwołanie. Brak RPC do parowania.
- **S4. Telefon nigdy nie wysyła poleceń ani ścieżek** — tylko nieprzezroczyste
  identyfikatory projektu/builda i nazwę wariantu z listy hosta. Jedyny wyjątek (od 0.6.2,
  do wyłączenia `phone_add_projects: false`): nowy projekt z telefonu, wskazany **samą nazwą
  folderu** (bez separatorów ścieżki, bez nazw zastrzeżonych Windows) i rodzajem z zamkniętej
  listy (Flutter, pusty, wolny folder). Host tworzy go wyłącznie bezpośrednio w `projects_root`,
  nie przyjmuje dowiązań wychodzących poza ten katalog, a komendy wpisuje z własnych szablonów
  (S5 bez zmian).
- **S5. Komendy budowania tylko z zaszyfrowanej bazy** — zmieniane wyłącznie lokalną akcją
  użytkownika (edytor w aplikacji, `rt`) albo po jego jawnym zatwierdzeniu propozycji z
  `REMOTEAPPTESTER.md`. Plik w folderze (który może zmienić agent AI albo repozytorium) nigdy
  nie jest wykonywany bezpośrednio. Projekty = wyłącznie foldery świadomie przypisane.
- **S6. Sekrety i baza w spoczynku**: Windows DPAPI (klucz bazy, `pairing_secret`, klucz TLS,
  token lokalnego kanału); Linux — pliki `0600` użytkownika usługi; Android — Keystore. Nigdy
  plaintext, nigdy w logach (redakcja wzorców sekretów w logach builda). Uwaga: procesy
  działające na TYM SAMYM koncie Windows mają formalnie dostęp do DPAPI — szyfrowanie chroni
  przed innymi kontami, kopiowaniem plików i przypadkową/ukrytą edycją, nie przed złośliwym
  programem uruchomionym jako Ty.
- **S7. Prywatność**: na telefon trafiają tylko nazwa folderu, typ projektu, postęp, log builda
  po redakcji i artefakt. Żadnych ścieżek dysku, nazw użytkownika, treści kodu.
- **S8. Integralność instalki**: SHA-256 w obrębie uwierzytelnionego kanału, kontrola
  `applicationId` (zmiana nazwy pakietu = pytanie użytkownika), Android wymusza zgodność
  podpisu przy aktualizacji.
- **S9. Klucz podpisujący**: wyłącznie deweloperski/testowy. Host utrzymuje **stały** klucz
  debug (na VPS — w katalogu użytkownika usługi), żeby aktualizacje na telefonie nie
  wymagały odinstalowania.
- **S10. Minimalne uprawnienia na hoście**: zwykły użytkownik, nigdy SYSTEM/root; instalacja
  na Windows bez administratora (UAC tylko dla opcjonalnej reguły zapory); na VPS dedykowany
  użytkownik `remoteapptester` bez sudo, usługa systemd utwardzona.
- **S11. Lokalny kanał** `127.0.0.1` (`rt b`, „pokaż okno”): token z SecretStore, porównanie w
  stałym czasie, odrzucanie żądań z przeglądarki (nagłówek `Origin`).

## 8. Android — ograniczanie „obrony” systemu przy wersjach debug

Android celowo utrudnia instalację aplikacji spoza sklepu. Co da się zoptymalizować, a co
zostaje decyzją użytkownika:

| Bariera | Rozwiązanie w RemoteAppTester |
|---|---|
| „Instalowanie nieznanych aplikacji” | Jednorazowa zgoda dla RemoteAppTester w ustawieniach. Aplikacja prowadzi do właściwego ekranu (`ACTION_MANAGE_UNKNOWN_APP_SOURCES`). |
| Okno „Zainstalować?” przy każdej aktualizacji | Android 12+ (API 31): `PackageInstaller.SessionParams.setRequireUserAction(USER_ACTION_NOT_REQUIRED)` + uprawnienie `UPDATE_PACKAGES_WITHOUT_USER_ACTION`. Działa przy **aktualizacji** aplikacji, którą wcześniej zainstalował RemoteAppTester (installer of record), gdy testowana aplikacja ma aktualny `targetSdk` (Flutter spełnia domyślnie). **Pierwsza** instalacja zawsze wymaga potwierdzenia. |
| Konflikt podpisu (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`) | Stały klucz debug na hoście (S9). Gdy podpis się zmieni — czytelny komunikat i propozycja „odinstaluj i zainstaluj” (z potwierdzeniem). |
| Google Play Protect („niebezpieczna aplikacja”, skan) | Nie da się i nie wolno tego obchodzić programowo. Pierwszy raz: „Zainstaluj mimo to”; instrukcja w aplikacji. Stały podpis zmniejsza liczbę ostrzeżeń. |
| Producenci (Xiaomi HyperOS/MIUI, Samsung) — dodatkowe skanery i zgody | Instrukcje per producent w aplikacji; wykrywanie i czytelny komunikat zamiast cichej porażki. |
| Uruchamianie aplikacji z tła (Android 10+) | Gdy RemoteAppTester jest na ekranie — uruchomienie od razu po instalacji. W tle — powiadomienie „Gotowe: Uruchom” (bez obchodzenia ograniczeń). |
| Odbiór dostaw w tle | Opcjonalna usługa pierwszoplanowa z powiadomieniem (`FOREGROUND_SERVICE` + `POST_NOTIFICATIONS`), włączana przez użytkownika; domyślnie odbiór, gdy aplikacja jest otwarta. |
| Duże APK debug (wszystkie ABI) | Szablony komend z `--target-platform android-arm64` — kilkukrotnie mniejszy transfer. |

Uprawnienia aplikacji: `INTERNET`, `REQUEST_INSTALL_PACKAGES`,
`UPDATE_PACKAGES_WITHOUT_USER_ACTION`, `CAMERA` (tylko skan QR parowania; jest alternatywa
„Wklej ze schowka”), `USE_BIOMETRIC`; dla odbioru w tle (później) `FOREGROUND_SERVICE` i
`POST_NOTIFICATIONS`.

**Biometria/PIN** — przed buildem zleconym z telefonu i przed każdą instalacją, którą
zatwierdza użytkownik (`install: ask`, zmiana nazwy pakietu). Dostawy z `install: auto`
instalują się bez biometrii — to świadoma decyzja właściciela komputera w opcjach projektu
(inaczej automat nie byłby automatem).

## 9. Środowisko

| Element | Wartość |
|---|---|
| Host Windows | Windows 11 (maszyna deweloperska), Flutter 3.47 stable; do budowania aplikacji okienkowej: Visual Studio C++ i tryb dewelopera Windows (dowiązania wtyczek) |
| Host Linux | Ubuntu 24.04 (instalator `host/deploy/linux/install.sh`: użytkownik usługi, Flutter, Android SDK, JDK 17, Tailscale, systemd) |
| Telefon testowy | Android z aplikacją Tailscale; zweryfikowany wcześniej Xiaomi 15 Ultra |
| Dart SDK | 3.13 (z Fluttera) |
| protoc + protoc-gen-dart | w `PATH` — patrz [proto/README.md](../proto/README.md) |

## 10. Biblioteki (wyłącznie sprawdzone)

- Host: `grpc`, `protobuf`, `fixnum`, `crypto`, `yaml`, `path`, `qr`, `basic_utils` (cert
  TLS), `win32`/`ffi` (DPAPI), `sqlite3` (z SQLite3MultipleCiphers — szyfrowana baza).
- Aplikacja okienkowa: `window_manager`, `tray_manager` (0.5.x), `file_selector` (oficjalny,
  flutter.dev), `qr_flutter`.
- Android: `grpc`, `protobuf`, `fixnum`, `crypto`, `flutter_secure_storage`,
  `shared_preferences`, `path_provider`, `mobile_scanner`, `local_auth`; instalacja przez
  własny, mały kanał do `PackageInstaller` (Kotlin), bez pakietów instalacyjnych trzecich stron.

## 11. Otwarte pytania (z roboczymi odpowiedziami)

1. Czy telefon może zmieniać komendy albo dodawać projekty? **Nie** — tylko komputer.
2. Wiele wersji w kolejce, gdy telefon offline? **Tylko najnowsza** per projekt.
3. Automatyczny build po zapisaniu plików w folderze? **Na razie nie** — przycisk, telefon
   albo `rt b` (agent AI). Do rozważenia po testach.
4. Linux/VPS: paczka wróci, gdy aplikacja Windows zostanie przetestowana (budowanie `rt` na
   Linuxie przez `dart build cli`).
