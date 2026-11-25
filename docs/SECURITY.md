# Bezpieczeństwo i prywatność — RemoteAppTester

🌐 [English](en/SECURITY.md) · **Polski**

> Decyzje S1–S10: [PROJECT_ASSUMPTIONS.md](PROJECT_ASSUMPTIONS.md), sekcja 7. Szczegółowa
> architektura i uzasadnienia warstwy transportu (odziedziczone z RemoteDevelopment, gdzie
> zostały zweryfikowane end-to-end, także z prawdziwym telefonem):
> [architektura-remote-build.md](architektura-remote-build.md), sekcja 6. Zgłaszanie podatności:
> [.github/SECURITY.md](../.github/SECURITY.md).

## Model zagrożeń

| Zagrożenie | Zabezpieczenie | Stan |
|---|---|---|
| Przejęte konto Tailscale / błąd ACL | TLS z certyfikatem przypiętym przy parowaniu, niezależny od Tailscale | działa |
| Atak powtórzeniowy (replay) | HMAC z nonce + timestamp, okno ~60 s, pamięć nonce per urządzenie | działa |
| Telefon wysyła polecenie powłoki / ścieżkę | kontrakt nie ma takich pól; tylko `project_id`, `build_id` i nazwa wariantu z listy hosta; komendy wyłącznie z bazy | działa |
| **Agent AI / repozytorium zmienia komendy budowania** | komendy WYŁĄCZNIE w zaszyfrowanej bazie (SQLite3MultipleCiphers, klucz w DPAPI); `REMOTEAPPTESTER.md` w folderze to tylko propozycja — do bazy po jawnym zatwierdzeniu w aplikacji (podgląd obok obecnych komend); ścisła walidacja bloku | działa |
| **Agent AI zatwierdza własną propozycję** | zatwierdzenie tylko w oknie aplikacji albo w interaktywnym terminalu (`rt pr import` odmawia bez konsoli, np. `echo t \| rt pr import`); wytyczne w REMOTEAPPTESTER.md mówią agentom, że to decyzja człowieka | działa |
| **Kopia programu bez szyfrowania bazy** | start sprawdza obecność SQLite3MultipleCiphers i odmawia działania bez niej (nie powstanie jawna baza) | działa |
| **Ręczna/ukryta zmiana bazy** | strony bazy szyfrowane i uwierzytelnione — modyfikacja pliku = błąd otwarcia; inne konta Windows nie odczytają klucza (DPAPI) | działa |
| **Fałszywy wyzwalacz lokalny od innego procesu** | kanał tylko `127.0.0.1` + token w SecretStore (porównanie w stałym czasie); żądania z przeglądarki (`Origin`) odrzucane; tylko znane projekty; najgorszy skutek = build skonfigurowanego folderu (kolejka, debounce) | działa |
| **Automatyczna instalacja czegoś nieoczekiwanego** | tylko sparowane, nieodwołane urządzenia z `deliver.devices`; artefakt pobiera wyłącznie zlecający lub adresat; SHA-256 w uwierzytelnionym kanale; zmiana `applicationId` = pytanie użytkownika; Android wymusza zgodność podpisu przy aktualizacji; `install: auto` to świadomy wybór w pliku projektu | działa |
| MITM podmienia APK | cały kanał uwierzytelniony (TLS pinning + HMAC); SHA-256 jako kontrola integralności w jego obrębie | działa |
| Path traversal przez `project_id` / wzorzec instalki | `project_id` losowy, mapowany w bazie na świadomie przypisany folder; wzorzec instalki względny, bez `..`, wynik sprawdzany po rozwiązaniu dowiązań (musi leżeć w folderze) | działa |
| Podejrzany lub wykradziony kod parowania | kod jednorazowy i ważny 1 godzinę; telefon od razu wymienia go na własny sekret, a stary przestaje działać; rotacja sekretu co 30 dni; kopiowanie linku z ostrzeżeniem i czyszczeniem schowka po 2 min | działa |
| Sekret w logu builda | redakcja: przypisania i flagi z hasłami/tokenami, dane w adresach URL, nagłówki Bearer, znane formaty tokenów, klucze prywatne, nazwa użytkownika w ścieżkach; to filtr wzorców, nie gwarancja | działa |
| Kopia zapasowa telefonu | `allowBackup=false` i reguły ekstrakcji: dane aplikacji nie trafiają do chmury ani na nowy telefon | działa |
| Agent AI na tym samym koncie | szyfrowanie DPAPI nie chroni przed programem działającym jako użytkownik; granica „tylko sygnał” jest wtedy umową, nie barierą. Zalecenie: agent i build w sandboksie (zakładka Informacje) | ryzyko świadome |
| Build wykonuje kod z repozytorium | Gradle i inne narzędzia uruchamiają skrypty projektu; build w tym samym środowisku co agent | ryzyko świadome |
| Zgubiony telefon | Keystore, blokada aplikacji (odcisk palca/PIN przy starcie i po powrocie z tła), biometria/PIN przed wrażliwymi akcjami, pojedyncze odwołanie `remoteapptester revoke` | działa |
| Inny użytkownik / malware na hoście czyta sekrety | Windows DPAPI; Linux plik `0600` użytkownika `remoteapptester`; nigdy plaintext | działa |
| Brute-force / DoS | rate limiting per urządzenie, lockout per adres źródłowy, jeden build naraz, kill-switch | działa |
| Wyciek sekretów w logach builda | redakcja wzorców `*_KEY`/`*_TOKEN`/`*_PASSWORD`/`*_SECRET` przed wysłaniem na telefon | działa |
| Telefon A widzi buildy/logi telefonu B | strumień tylko do zlecającego; `GetBuildStatus`/`CancelBuild` sprawdzają `device_id` | działa |
| Zdalne dopisanie nowego urządzenia | parowanie wyłącznie lokalnie w terminalu hosta; brak RPC parowania | działa |
| Ujawnienie klucza produkcyjnego | wyłącznie klucz deweloperski/testowy w tym pipeline | polityka |
| Host dostępny z internetu | bind tylko na adres Tailscale; brak adresu = brak startu (nigdy fallback na `0.0.0.0`); instalator nie otwiera portów | działa |
| Agent AI (lub cokolwiek w folderze) wysyła sygnał | sygnał = plik `.remoteapptester-signal` w folderze projektu, bez tokenu i bez dostępu do bazy; z pliku brane są tylko: „są zmiany”, `build: true/false` i notatka (≤ 300 znaków, jedna linia, bez znaków sterujących i kierunkowych); dowiązania i pliki > 4 KB odrzucane bez czytania; build tylko gdy opcja projektu „Sygnał agenta uruchamia build” jest włączona, nie przy wstrzymaniu, zawsze komendami z bazy; kolejne sygnały nie mnożą buildów (deduplikacja w kolejce) | działa |
| Telefon zmienia opcje projektu | `UpdateProjectOptions` (HMAC jak każde RPC) zmienia tylko: tryb instalacji, uruchamianie, sygnał agenta i dostawy na TEN telefon; komend i „budowania z telefonu” nie zmienia; każda zmiana w logu audytowym | działa |
| Odwołany telefon ponawia połączenia | znany, odwołany `device_id` nie liczy się do blokady adresu (inaczej blokowałby się bez końca, także po ponownym parowaniu); własny limit żądań, jeden wpis w logu na 5 min; aktywny telefon przechodzi przez blokadę adresu, ale jego błędne podpisy blokują jego identyfikator | działa |
| Podstawiona baza delty | telefon podaje tylko sumę SHA-256 swojej wersji; host szuka jej wyłącznie wśród instalek tego samego projektu; telefon sprawdza sumę przesłanego pliku i sumę złożonej instalki z sumą builda — inna instalka niż zbudowana nie przejdzie | działa |
| Wyciek prywatnych danych na telefon | na telefon: nazwa folderu, typ, postęp, log po redakcji, artefakt — bez ścieżek dysku i nazw użytkownika | działa |

## Checklist

### Sieć i transport

- [x] Bind wyłącznie na adres interfejsu Tailscale (`host/lib/net/tailscale_interface.dart`).
- [x] TLS z samopodpisanym certyfikatem generowanym przy pierwszym uruchomieniu; odcisk SHA-256
      w kodzie QR; telefon odrzuca inny certyfikat (`CertificatePinningException`); URI
      parowania bez `cert_fp` odrzucane.
- [x] HMAC-SHA256(pairing_secret, method‖payload‖timestamp‖nonce) w metadanych gRPC na każdym
      żądaniu; wszystkie wywołania z telefonu przez `AgentClient`, żeby podpisu nie dało się
      pominąć.
- [ ] **Tailscale ACL** — dla każdego hosta: grant tylko telefon(y) → host na porcie usługi
      (domyślnie `tcp:47051`), reszta zabroniona. `rt acl` / przycisk „Generuj JSON dla Tailscale”
      przygotowuje politykę.
- [ ] **Windows Firewall** — reguła przychodząca na port usługi, zawężona do adresu telefonu
      w tailnecie (osobna warstwa od ACL; bez niej Windows po cichu blokuje telefon).
      `remoteapptester doctor` sprawdza jej obecność. Polecenie (PowerShell jako administrator):
      ```powershell
      New-NetFirewallRule -DisplayName "RemoteAppTester (gRPC 47051 - phone only)" `
        -Direction Inbound -Protocol TCP -LocalPort 47051 `
        -RemoteAddress <adres-telefonu-w-tailnecie> -Action Allow -Profile Private -Enabled True
      ```
- [x] Odnawianie połączenia w aplikacji (keepalive 25 s, heartbeat hosta 20 s, zerwanie po
      70 s ciszy, backoff 1–30 s) — zawsze tym samym kanałem TLS pinning + HMAC, bez fallbacku.
      Zweryfikowane klientem testowym `host/tool/e2e_delivery.dart` (zły certyfikat i brak
      HMAC odrzucone).

### Host

- [x] Proces jako zwykły użytkownik (Windows) / dedykowany `remoteapptester` bez sudo (Linux),
      usługa systemd utwardzona (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`,
      `PrivateTmp`).
- [x] Sekrety w `SecretStore` (DPAPI / `0600`), migracja starych plików plaintext.
- [x] Komendy budowania wyłącznie z zaszyfrowanej bazy (edytor w aplikacji / zatwierdzona
      propozycja z `REMOTEAPPTESTER.md`); każdy krok w osobnym skrypcie `.cmd` w katalogu danych;
      anulowanie zabija całe drzewo procesów.
- [x] Projekty tylko jawnie przypisane (baza); wzorzec instalki nie wychodzi poza folder (testy).
- [x] Redakcja logów (`host/lib/build/log_redactor.dart`).
- [x] Log operacji z `device_id` (audyt, lokalnie).
- [x] Szyfrowanie bazy + test: brak komend w pliku jawnym tekstem, inny klucz = błąd (`test/project_store_test.dart`).
- [x] Propozycje z `REMOTEAPPTESTER.md` nigdy nie stosowane bez zatwierdzenia; ścisła walidacja bloku (testy).
- [x] Lokalny kanał wyzwalacza z tokenem + testy: brak/zły token, `Origin`, nieznany folder,
      `triggers.local`, kill-switch, metoda zawsze z hosta (`test/control_server_test.dart`).
- [x] Dostęp do artefaktu tylko dla zlecającego, adresatów dostawy i telefonów z opcji projektu (testy).
- [ ] Stały klucz debug na hoście, poza folderami projektów (Faza 4).

### Aplikacja Android

- [x] `device_id`, `pairing_secret`, odcisk certyfikatu w Keystore (`flutter_secure_storage`).
- [x] Blokada aplikacji: odcisk palca/PIN przy starcie i po czasie w tle; wyłączenie albo
      osłabienie wymaga potwierdzenia (`app_lock.dart`).
- [x] Biometria/PIN przed startem builda i instalacją (`sensitive_action_gate.dart`).
- [x] SHA-256 i `applicationId` przed instalacją; instalacja przez `PackageInstaller`, bez
      roota i ADB.
- [x] Pobrany APK w prywatnym `cacheDir`, bez uprawnień do pamięci masowej.
- [x] Polityka biometrii dla dostaw (`install: auto` bez, `ask`/zmiana pakietu/ręczny build z).
- [x] `UPDATE_PACKAGES_WITHOUT_USER_ACTION` + `USER_ACTION_NOT_REQUIRED` — działa tylko dla
      aktualizacji pakietów zainstalowanych przez RemoteAppTester; żadnych prób obchodzenia
      Play Protect ani ograniczeń uruchamiania z tła.
- [ ] Test na prawdziwym telefonie (aktualizacja bez okna, uruchomienie po instalacji).

## Weryfikacja z prawdziwym telefonem (po każdej zmianie ścieżki sieć → instalacja)

1. Host: `remoteapptester doctor` — wszystko `[OK]` (w tym Tailscale, zapora na Windows).
2. Telefon: Tailscale połączony; w RemoteAppTester zeskanuj kod z `remoteapptester pair "nazwa"`.
3. Build z telefonu → pobranie → instalacja → uruchomienie.
4. Zmiana sieci w trakcie builda i w trakcie transferu (WiFi → LTE) — build trwa dalej,
   transfer wznawia się od miejsca przerwania.
5. `remoteapptester revoke <device_id>` → kolejne żądanie z telefonu odrzucone.
