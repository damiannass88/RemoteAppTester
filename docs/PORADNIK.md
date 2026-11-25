# Poradnik: praca z RemoteAppTester od zera

🇬🇧 [English version](en/GUIDE.md)

Dla kogo: masz pomysł na aplikację, chcesz ją zbudować z pomocą sztucznej inteligencji
i nie jesteś informatykiem. Ten poradnik tłumaczy, jak to działa, czego potrzebujesz i jak
zacząć. Trudniejsze kroki zrobisz z czatem AI, dla którego mamy [gotowe prompty](PROMPTY.md).

> Narzędzia, ceny i regulaminy zmieniają się szybko (stan opisu: listopad 2026). Gdy coś
> wygląda inaczej niż tutaj, zapytaj czat AI o aktualny sposób albo sprawdź stronę dostawcy.

## 1. Zamysł: trzy osobne części

| Część | Co robi | Przykład |
|---|---|---|
| **Agent AI** | pisze i poprawia kod Twojej aplikacji według Twoich poleceń | Claude Code, Codex, Cursor |
| **RemoteAppTester** | buduje aplikację i dostarcza ją na telefon | ten program |
| **Telefon** | tu rozmawiasz z agentem i testujesz wynik | aplikacja Claude + aplikacja RemoteAppTester |

Te części są celowo rozdzielone. Agent AI nie może sterować RemoteAppTesterem: może tylko
zostawić w folderze projektu notatkę „skończyłem, zbuduj” (`rt sg --build`). Komendy budowania
zatwierdzasz Ty. Dzięki temu źle działający albo oszukany agent nie przejmie Twojego komputera
przez RemoteAppTester.

Możesz używać dowolnego agenta i dowolnego środowiska, w którym on pracuje. RemoteAppTester
potrzebuje tylko folderu projektu na tym samym komputerze lub serwerze.

## 2. Jak wygląda praca z telefonu

Przykład z Claude Code i funkcją Remote Control (sterowanie sesją Claude Code z aplikacji Claude):

1. Na komputerze albo serwerze działa sesja Claude Code w folderze Twojego projektu.
2. W aplikacji **Claude** na telefonie, w zakładce **Code**, wybierasz tę sesję i piszesz:
   *„Dodaj ekran z listą zakupów. Każdą pozycję da się odhaczyć. Gdy skończysz, wyślij
   aplikację na telefon przez rt.”*
3. Agent zmienia kod i na końcu wykonuje `rt sg -m "Lista zakupów" --build --wait`.
4. RemoteAppTester buduje aplikację i wysyła ją przez Tailscale. Telefon pyta
   „Zainstalować?” (albo instaluje sam, jeśli tak ustawisz) i uruchamia nową wersję.
5. Testujesz i wracasz do aplikacji Claude: *„Przycisk jest za mały, a po obróceniu
   telefonu lista znika. Popraw i wyślij.”*

Komputer ani serwer nie musi być obok Ciebie. Musi być tylko włączony i połączony z internetem.

**Strony i aplikacje WWW** działają podobnie. Zamiast instalacji na ekranie projektu w
RemoteAppTester naciskasz **„Podgląd”**. Strona otwiera się na telefonie, a przycisk
**„Zgłoś problem”** zapisuje Twoją uwagę (z konsolą przeglądarki) w pliku
`.remoteapptester-feedback.md`, który agent może przeczytać.

## 3. Czego potrzebujesz

- **Telefon z Androidem 8 lub nowszym** (zalecany 12+). Najlepiej osobny telefon testowy bez
  prywatnych danych. iPhone na razie nie jest obsługiwany (patrz rozdział 9).
- **Komputer, który może zostać włączony**, w jednym z wariantów:

  | Wariant | Plusy | Minusy |
  |---|---|---|
  | **A. Twój komputer z Windows** | bez dodatkowych kosztów, okienkowa aplikacja | musi być włączony; agent AI na Twoim koncie widzi Twoje pliki (patrz rozdział 6) |
  | **B. Wynajęty serwer VPS z Linuxem** (np. Contabo) | działa 24/7, oddzielony od Twoich prywatnych plików | miesięczny koszt, obsługa tylko z terminala (pomoże czat AI): [VPS.md](VPS.md) |
  | **C. Komputer z Linuxem** | jak B, ale u Ciebie | wymaga podstaw Linuksa |

- **Darmowe konto [Tailscale](https://tailscale.com)**, to samo na komputerze i telefonie.
  Tailscale tworzy prywatną sieć tylko z Twoich urządzeń, więc nic nie trzeba otwierać w internecie.
- **Konto u dostawcy agenta AI**, np. subskrypcja Claude z dostępem do Claude Code. To zwykle
  usługa płatna. Sprawdź aktualny cennik i limity.
- **Narzędzia do budowania aplikacji**. Na serwerze Linux instalator RemoteAppTester sam
  instaluje Fluttera i Android SDK. Na Windows trzeba je zainstalować samodzielnie, a prompt
  instalacyjny przeprowadzi Cię przez to.

## 4. Pierwsze uruchomienie krok po kroku

Każdy krok ma gotowy prompt w [PROMPTY.md](PROMPTY.md). Wklej go do czatu AI. Czat wyjaśni
każde polecenie, zanim je wykonasz.

1. **Tailscale** na telefonie i komputerze/serwerze, zalogowany tym samym kontem.
2. **RemoteAppTester:**
   - Windows: [prompt 3](PROMPTY.md#3-instalacja-remoteapptester-na-windows) i [instrukcja](../host/deploy/windows/README.md);
   - VPS: najpierw [prompt 1 (zabezpieczenie serwera)](PROMPTY.md#1-przygotowanie-i-zabezpieczenie-serwera-vps),
     potem [prompt 2](PROMPTY.md#2-instalacja-remoteapptester-na-serwerze-linux).
3. **Aplikacja na telefonie:** zainstaluj plik `RemoteAppTester-android-<wersja>.apk`. Android
   zapyta o zgodę na instalację z nieznanego źródła, bo aplikacja nie pochodzi ze sklepu.
   Zeskanuj kod QR parowania z komputera.
4. **Bateria:** Ustawienia → Aplikacje → RemoteAppTester (i Tailscale) → Bateria →
   **„Bez ograniczeń”**. Bez tego część telefonów (np. Xiaomi) zrywa połączenie.
5. **Blokada aplikacji:** przy pierwszym uruchomieniu aplikacja poprosi o odcisk palca. Jeśli
   telefon nie ma odcisku, aplikacja pokaże, jak go dodać.
6. **Projekt:** na telefonie „Nowy projekt” (Flutter albo pusty folder) albo na komputerze
   „Projekty → +”. Komendy budowania wpiszą się same.
7. **Agent AI:** [prompt 4 (VPS)](PROMPTY.md#4-agent-ai-claude-code-na-serwerze-vps) albo
   [prompt 5 (Windows)](PROMPTY.md#5-agent-ai-claude-code-na-windows).
8. **Pierwsza aplikacja:** [prompt 6](PROMPTY.md#6-pierwsza-prośba-do-agenta-w-projekcie)
   napisz do agenta w folderze projektu.

## 5. Ustawienia, które warto znać

| Gdzie | Ustawienie | Po co |
|---|---|---|
| Projekt → Opcje | **Instalacja: pytaj / automatycznie / wyłączona** | „pytaj” to bezpieczny wybór na start |
| Projekt → Opcje | **Sygnał agenta uruchamia build** | wyłączone: sygnał agenta tylko oznacza „nowe zmiany” |
| Projekt → Opcje | **Agent AI może wysłać własną instalkę** (`rt push`) | wyłącz, jeśli wolisz, żeby budował tylko RemoteAppTester |
| Projekt → Komendy | **Zatwierdź propozycję agenta** | agent może tylko zaproponować komendy w `REMOTEAPPTESTER.md`; zatwierdzasz Ty, po przeczytaniu |
| Telefon → Ustawienia | **Blokada aplikacji** | odcisk palca przy starcie i po powrocie z tła; wyłączenie wymaga odcisku |
| Komputer → Telefony | **Odwołaj** | zgubiony telefon odetnij od razu |

## 6. Bezpieczne nawyki (najważniejsze)

1. **Agent AI nie powinien mieć dostępu do Twoich prywatnych plików.** Na serwerze VPS agent
   dostaje osobne konto bez `sudo`. Na Windows najlepiej osobne konto Windows, maszyna
   wirtualna albo WSL. Agent uruchomiony na Twoim koncie widzi wszystko to, co Ty.
2. **Czytaj, co zatwierdzasz.** Gdy RemoteAppTester pokazuje „Agent zaproponował nowe komendy”,
   przeczytaj je albo poproś czat AI o wyjaśnienie, zanim klikniesz „Zatwierdź”.
3. **Testuj na telefonie bez prywatnych danych** (albo w profilu służbowym). Testowana aplikacja
   to kod, którego nikt dokładnie nie sprawdził.
4. **Kod QR parowania traktuj jak hasło.** Nie rób mu zdjęć i nie wysyłaj go komunikatorem.
5. **Nie wklejaj nigdzie haseł, tokenów ani kodów QR**, także do czatu AI i do zgłoszeń na GitHubie.
6. **Kopie zapasowe:** trzymaj kod projektu w repozytorium git (np. prywatnym na GitHubie).
   Agent AI może coś zepsuć albo skasować.

Więcej: zakładka **Informacje** w aplikacji (także `rt info`) i [SECURITY.md](SECURITY.md).

## 7. Najczęstsze problemy

| Objaw | Najczęstsza przyczyna | Co zrobić |
|---|---|---|
| Telefon: „Connection timed out” | bateria ograniczona, Tailscale wyłączony albo reguły dostępu Tailscale (ACL) | bateria „Bez ograniczeń” dla obu aplikacji; Tailscale włączony; reguły: `rt acl` albo przycisk „Generuj JSON dla Tailscale” |
| Telefon nie widzi komputera po zmianie sieci | chwilowe zerwanie | poczekaj kilkanaście sekund, aplikacja łączy się sama |
| Build się nie udał | błąd w kodzie albo brak narzędzi | otwórz log na telefonie i wklej agentowi ostatnie linie: „Build nie przechodzi, popraw” |
| Agent: `rt: command not found` albo kod 3 | usługa RemoteAppTester nie działa albo konto agenta nie jest w grupie | `sudo systemctl status remoteapptester`; `sudo bash install.sh --add-user <konto>` |
| Agent: kod 4 | nikt nie dostał wersji | opcja instalacji „wyłączona” albo żaden telefon nie jest wybrany w opcjach projektu |
| „Instalacja zablokowana” na telefonie | brak zgody na instalowanie aplikacji | Ustawienia → Aplikacje → RemoteAppTester → „Instaluj nieznane aplikacje” |
| Zablokowany odcisk po kilku próbach | blokada czujnika w Androidzie | odblokuj PIN-em telefonu |

Gdy nic nie pomaga, użyj [promptu 7 (diagnoza)](PROMPTY.md#7-diagnoza-problemu). Jeśli to błąd
programu, zgłoś go na GitHubie, ale bez sekretów: [zgłoszenia](../.github/ISSUE_TEMPLATE/bug_report.md).

## 8. Od testów do wydania

RemoteAppTester wysyła **wersje testowe** (debug). Żeby udostępnić aplikację innym, potrzebujesz:

- **Google Play:** konto dewelopera (jednorazowa opłata), weryfikacja tożsamości, własny klucz
  podpisu (nie zgub go!), polityka prywatności, formularz bezpieczeństwa danych, a dla nowych
  kont prywatnych także test zamknięty z grupą testerów przed publikacją. Zasady się zmieniają.
- **Strona / aplikacja WWW:** hosting, domena, certyfikat HTTPS, polityka prywatności i cookies,
  jeśli zbierasz dane.
- **Prawo:** jeśli aplikacja przetwarza dane osobowe (np. konta użytkowników), obowiązuje RODO.
  Przy sprzedaży pojawiają się też podatki i regulamin.

Przeprowadzi Cię przez to [prompt 8 (Google Play)](PROMPTY.md#8-wydanie-aplikacji-w-google-play)
i [prompt 9 (WWW)](PROMPTY.md#9-wydanie-aplikacji-www). Nie podejmuj decyzji prawnych ani
podatkowych tylko na podstawie czatu AI. Przy działalności zarobkowej skonsultuj je ze specjalistą.

## 9. Czego RemoteAppTester (jeszcze) nie robi

- Nie buduje aplikacji na iPhone'a (iOS) i nie działa na Macu. Budowanie dla iOS wymaga
  komputera Mac, a autor nie ma sprzętu Apple, żeby to rzetelnie przetestować. Pomoc osób
  z Makiem jest mile widziana ([CONTRIBUTING.md](../CONTRIBUTING.md)).
- Nie dostarcza na telefon programów na Windows ani Linux. Strony WWW pokazuje przez podgląd.
- Nie steruje agentem AI i nie ma czatu. Z agentem rozmawiasz w jego własnej aplikacji.
- Nie publikuje w sklepach. To robisz Ty (patrz rozdział 8).
