# Gotowe prompty dla czatu AI

🌐 [English](en/PROMPTS.md) · **Polski**

Prompt to gotowy tekst, który wklejasz do czatu AI (Claude, ChatGPT, Gemini…). Każdy niżej
zmienia czat w cierpliwego przewodnika: prowadzi krok po kroku, wyjaśnia każde polecenie,
zanim je wykonasz, i zatrzymuje się przed ryzykownymi krokami.

## Jak używać

1. Znajdź prompt pasujący do zadania. Przeczytaj opis **„Co robi”** i **„Co zmieni”**.
2. Skopiuj cały tekst z szarej ramki i wklej do nowej rozmowy z czatem AI.
3. Uzupełnij miejsca oznaczone `<…>` (np. system, nazwę projektu). Jeśli czegoś nie wiesz,
   zostaw. Czat o to zapyta.
4. Wykonuj polecenia **po jednym**, wklejaj czatowi wynik i czekaj na kolejny krok.

**Dwa sposoby pracy:**

- **Zwykły czat** (w przeglądarce albo w aplikacji): czat podaje polecenia, Ty je wklejasz do
  terminala, a wynik do czatu. Najbezpieczniej, bo widzisz każdy krok.
- **Agent z dostępem do terminala** (np. Claude Code): agent wykonuje polecenia sam. Prompty
  każą mu pytać o zgodę przed każdą zmianą w systemie. Nie wyłączaj tych pytań.

**Zasady, których pilnuj zawsze:**

- Nigdy nie wklejaj do czatu **haseł, tokenów, kluczy prywatnych ani kodu QR parowania**.
  Prompty o to nie proszą, a dobry czat sam Cię przed tym ostrzeże.
- Jeśli czat chce wykonać coś, czego opis nie wspomina (np. otworzyć porty w zaporze, dać
  agentowi `sudo`, wyłączyć zabezpieczenia), zatrzymaj się i zapytaj „po co?”.
- Czat AI się myli. Jeśli coś brzmi dziwnie, poproś o wyjaśnienie albo sprawdź w oficjalnej
  dokumentacji.

| # | Prompt | Dla kogo |
|---|---|---|
| 1 | [Przygotowanie i zabezpieczenie serwera VPS](#1-przygotowanie-i-zabezpieczenie-serwera-vps) | nowy VPS |
| 2 | [Instalacja RemoteAppTester na serwerze Linux](#2-instalacja-remoteapptester-na-serwerze-linux) | VPS / Linux |
| 3 | [Instalacja RemoteAppTester na Windows](#3-instalacja-remoteapptester-na-windows) | Windows |
| 4 | [Agent AI (Claude Code) na serwerze VPS](#4-agent-ai-claude-code-na-serwerze-vps) | VPS / Linux |
| 5 | [Agent AI (Claude Code) na Windows](#5-agent-ai-claude-code-na-windows) | Windows |
| 6 | [Pierwsza prośba do agenta w projekcie](#6-pierwsza-prośba-do-agenta-w-projekcie) | każdy |
| 7 | [Diagnoza problemu](#7-diagnoza-problemu) | gdy coś nie działa |
| 8 | [Wydanie aplikacji w Google Play](#8-wydanie-aplikacji-w-google-play) | gotowa aplikacja Android |
| 9 | [Wydanie aplikacji WWW](#9-wydanie-aplikacji-www) | gotowa strona / aplikacja WWW |

---

## 1. Przygotowanie i zabezpieczenie serwera VPS

**Co robi:** prowadzi przez pierwsze logowanie na nowy serwer i jego podstawowe zabezpieczenie.
**Co zmieni:** aktualizuje system, tworzy Twoje konto administratora, włącza logowanie kluczem
zamiast hasła, wyłącza logowanie jako `root`, włącza zaporę (tylko SSH) i automatyczne łatki.
**Ryzyko:** źle ustawione SSH może Cię zablokować. Prompt każe najpierw sprawdzić nowe logowanie
w drugim oknie, a w razie czego zostaje konsola VNC w panelu dostawcy.
**Opis bez czatu:** [VPS.md](VPS.md).

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Cel: przygotować i zabezpieczyć nowy serwer VPS, na którym potem zainstaluję RemoteAppTester
(program, który buduje aplikacje i wysyła je na mój telefon przez Tailscale) i agenta AI.
Serwer: <dostawca, np. Contabo>, system <np. Ubuntu 24.04>, adres IP mam z e-maila.
Mój komputer: <Windows / macOS / Linux>.

Zasady pracy:
- Prowadź mnie krok po kroku, jedno polecenie naraz. Przed każdym poleceniem napisz prostymi
  słowami, co robi i co zmieni. Czekaj na wynik, który wkleję, zanim przejdziesz dalej.
- Jeśli masz dostęp do terminala, przed każdą zmianą w systemie pytaj mnie o zgodę.
- Nigdy nie proś mnie o wklejenie hasła, klucza prywatnego ani tokenu. Hasła wpisuję tylko w terminalu.
- Przed każdą operacją, której nie da się łatwo cofnąć, ostrzeż mnie i zapytaj.
- Jeśli coś zależy od wersji systemu albo panelu dostawcy, najpierw każ mi to sprawdzić.

Kroki:
1. Pierwsze logowanie: ssh root@<IP> z mojego komputera (wyjaśnij potwierdzenie odcisku serwera).
2. Aktualizacja systemu i automatyczne łatki bezpieczeństwa (unattended-upgrades).
3. Moje konto administratora z sudo (zaproponuj nazwę, hasło wpiszę sam).
4. Klucz SSH na moim komputerze (ed25519) i skopiowanie go na serwer dla mojego konta.
5. Sprawdzenie w DRUGIM oknie, że loguję się kluczem na nowe konto i działa sudo.
   Dopiero wtedy: wyłączenie logowania hasłem i jako root (sprawdź też pliki w
   /etc/ssh/sshd_config.d/, które mogą nadpisywać ustawienia), przeładowanie SSH
   i ponowny test w nowym oknie, zanim zamknę stare.
6. Zapora ufw: zezwól tylko na OpenSSH, włącz, pokaż status.
7. Opcjonalnie: fail2ban; swap 4 GB, jeśli serwer ma mniej niż 8 GB RAM.
8. Podsumowanie: co zrobiliśmy, jak się teraz loguję, gdzie w panelu dostawcy jest konsola
   ratunkowa (VNC/Rescue), gdybym się zablokował.

Nie instaluj jeszcze RemoteAppTester, Tailscale ani agenta AI. To będzie osobny etap.
Nie otwieraj żadnych innych portów.
```

---

## 2. Instalacja RemoteAppTester na serwerze Linux

**Co robi:** pobiera paczkę RemoteAppTester, sprawdza jej sumę kontrolną, instaluje program
(z Flutterem, Android SDK i Tailscale) i paruje telefon.
**Co zmieni:** tworzy konto usługi `remoteapptester` (bez uprawnień administratora), foldery
`/opt/remoteapptester`, `/var/lib/remoteapptester` i `/srv/remoteapptester/projects`, usługę
systemową. Nie otwiera portów i nie zmienia zapory.
**Uwaga:** instalator zapyta o zgodę na licencje Android SDK firmy Google. Przeczytaj je wcześniej:
https://developer.android.com/studio/terms

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Cel: zainstalować RemoteAppTester na moim serwerze Linux i sparować z nim telefon z Androidem.
Opis programu: https://github.com/damiannass88/RemoteAppTester (README, docs/VPS.md,
host/deploy/linux/README.pl.md). Jeśli możesz, przeczytaj te pliki, zanim zaczniemy.
Serwer jest już zabezpieczony (logowanie kluczem, zapora tylko SSH). Wersja programu: <np. 0.6.5>.

Zasady pracy:
- Jedno polecenie naraz. Przed każdym wyjaśnij prostymi słowami, co robi. Czekaj na wynik.
- Jeśli masz dostęp do terminala, pytaj o zgodę przed każdą zmianą.
- Nigdy nie proś o wklejenie kodu QR parowania, linku parowania, tokenów ani haseł.
  Kod QR skanuję telefonem sam. Nie zapisuj go i nie przepisuj.
- Nie otwieraj portów w zaporze. RemoteAppTester działa tylko w sieci Tailscale.

Kroki:
1. Sprawdź system: uname -m (musi być x86_64), wersję systemu, RAM i miejsce na dysku.
2. Pobierz paczkę i plik .sha256 z zakładki Releases (albo powiedz, jak przesłać ją scp
   z mojego komputera) i sprawdź sumę: sha256sum -c. Bez wyniku OK nie idziemy dalej.
3. Rozpakuj i uruchom: sudo bash install.sh. Wyjaśnij, co instalator robi, zanim go uruchomię.
   Gdy instalator zapyta o licencje Android SDK, przypomnij mi, że decyzja należy do mnie,
   i podaj link do ich treści. Gdy pojawi się link logowania Tailscale, powiedz mi, żebym otworzył go i zalogował się
   tym samym kontem, którego używam na telefonie.
4. Telefon: zainstaluj aplikację Tailscale (Sklep Play) i zaloguj tym samym kontem; zainstaluj
   RemoteAppTester-android-<wersja>.apk (Android zapyta o zgodę na instalację z tego źródła);
   zeskanuj kod QR z terminala. Ustaw dla RemoteAppTester i Tailscale baterię „Bez ograniczeń”.
5. Panel Tailscale: wyłącz wygasanie klucza serwera (Disable key expiry). Jeśli mam własne
   reguły dostępu (ACL), uruchom sudo rt acl i pomóż mi wkleić wynik do panelu.
6. Diagnoza: sudo rt dr. Wszystko powinno być [OK]. Wyjaśnij każdą uwagę.
7. Projekt testowy: sudo rt n demo --flutter, potem sudo rt b demo. Pierwszy build trwa długo.
   Telefon powinien dostać aplikację i zapytać o instalację.
8. Podsumowanie: najważniejsze polecenia (sudo rt, sudo rt info, systemctl status remoteapptester).
```

---

## 3. Instalacja RemoteAppTester na Windows

**Co robi:** instaluje Tailscale, RemoteAppTester i narzędzia do budowania aplikacji Android
(Flutter, Android SDK) oraz paruje telefon.
**Co zmieni:** instaluje programy na Twoim koncie Windows (RemoteAppTester bez uprawnień
administratora), dodaje autostart i, za Twoją zgodą (okno UAC), regułę zapory tylko dla sieci Tailscale.

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Cel: zainstalować RemoteAppTester na moim komputerze z Windows <10/11>, żeby budował aplikacje
Android i wysyłał je na mój telefon. Opis programu: https://github.com/damiannass88/RemoteAppTester
(README, docs/PORADNIK.md, host/deploy/windows/README.pl.md).

Zasady pracy:
- Jeden krok naraz. Przed każdym poleceniem PowerShell wyjaśnij, co robi. Czekaj na wynik.
- Jeśli masz dostęp do terminala, pytaj o zgodę przed każdą instalacją i zmianą ustawień.
- Nie proś o hasła, tokeny ani kod QR parowania. Kod skanuję telefonem.
- Instaluj programy tylko z oficjalnych źródeł (winget albo strona producenta).
- Nie wyłączaj Windows Defendera, zapory ani SmartScreen dla całego systemu.

Kroki:
1. Tailscale: zainstaluj (winget albo tailscale.com) i zaloguj się tym samym kontem co na telefonie.
2. Narzędzia do budowania: Flutter (z Android SDK przez Android Studio albo command-line tools).
   Sprawdź na końcu: flutter doctor. Wyjaśnij, które ostrzeżenia mogę zignorować
   (np. Xcode, Chrome, Visual Studio nie są potrzebne do aplikacji Android).
   Licencje Android SDK (flutter doctor --android-licenses) akceptuję sam, po przeczytaniu.
3. RemoteAppTester: pobierz paczkę RemoteAppTester-windows-x64-<wersja>.zip i plik .sha256
   z zakładki Releases, sprawdź sumę (Get-FileHash), rozpakuj cały folder, uruchom install.cmd.
   Program nie jest podpisany, więc SmartScreen może ostrzec: „Więcej informacji” → „Uruchom mimo to”
   jest w porządku tylko dla pliku, którego suma się zgadza.
4. Telefon: Tailscale ze Sklepu Play; plik RemoteAppTester-android-<wersja>.apk z paczki;
   w aplikacji RemoteAppTester: Telefony → Sparuj telefon i skan kodu QR; bateria „Bez ograniczeń”
   dla RemoteAppTester i Tailscale.
5. Projekt: w oknie RemoteAppTester Projekty → „+” i folder z aplikacją (albo na telefonie
   „Nowy projekt”). Pierwszy build i instalacja na telefonie.
6. Jeśli telefon pokazuje „Connection timed out”: sprawdźmy baterię, Tailscale na obu
   urządzeniach i reguły dostępu (Telefony → Generuj JSON dla Tailscale).
```

---

## 4. Agent AI (Claude Code) na serwerze VPS

**Co robi:** tworzy osobne konto dla agenta AI, instaluje Claude Code i włącza **Remote
Control**, czyli rozmowę z agentem z aplikacji Claude na telefonie.
**Co zmieni:** nowe konto `agent` bez `sudo`, dodane do grupy projektów RemoteAppTester; Claude
Code w folderze domowym tego konta; sesja w `tmux`, żeby działała po rozłączeniu.
**Dlaczego osobne konto:** agent widzi tylko foldery projektów, a nie dane RemoteAppTester ani
Twoje konto administratora. Jeśli ktoś oszuka agenta (np. przez złośliwą stronę WWW), szkody
są ograniczone.
**Wymaga:** konta Claude z dostępem do Claude Code (zwykle płatna subskrypcja). Dokumentacja:
https://code.claude.com/docs/en/remote-control

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Cel: na moim serwerze Linux z zainstalowanym RemoteAppTester skonfigurować agenta AI Claude Code
tak, żebym mógł z nim rozmawiać z aplikacji Claude na telefonie (Remote Control), a agent po
pracy wysyłał aplikację na telefon przez RemoteAppTester (rt sg / rt push).
Dokumentacja: https://code.claude.com/docs (Remote Control: /en/remote-control) oraz
docs/AGENCI_AI.md w repozytorium RemoteAppTester. Sprawdź aktualny sposób instalacji, zanim
podasz polecenia, bo mogły się zmienić.

Zasady pracy:
- Jedno polecenie naraz, z wyjaśnieniem. Czekaj na wynik.
- Konto agenta NIGDY nie dostaje sudo ani dostępu do /var/lib/remoteapptester.
- Nie proś o tokeny, klucze API ani hasła. Logowanie do Claude robię sam przez link.
- Ostrzeż mnie przed każdym ustawieniem, które pozwala agentowi działać bez pytania
  (np. pomijanie zgód). Wyjaśnij ryzyko i niech decyzja będzie moja.

Kroki:
1. Konto agenta: sudo adduser agent; sudo bash install.sh --add-user agent (z folderu paczki
   RemoteAppTester). Sprawdź: id agent (grupa remoteapptester), brak sudo.
2. Projekt: sudo rt n <nazwa> --flutter (albo inny typ, zapytaj mnie) i sprawdź, że konto agent
   może pisać w /srv/remoteapptester/projects/<nazwa>.
3. Zaloguj się jako agent (sudo -iu agent), zainstaluj Claude Code oficjalnym instalatorem
   i tmux (tmux instaluje administrator przez apt). Zaloguj się do Claude (link otworzę w przeglądarce).
4. W folderze projektu: tmux new -s claude, potem uruchom Claude Code z Remote Control
   (np. claude --remote-control albo /remote-control w sesji; sprawdź w dokumentacji).
   Pokaż, jak połączyć się z telefonu: aplikacja Claude → zakładka Code → ta sesja (albo kod QR).
   Wyjaśnij, jak odłączyć się od tmux (Ctrl+B, potem D) i wrócić (tmux attach -t claude).
5. Agent ma już wskazówki w REMOTEAPPTESTER.md i CLAUDE.md w folderze projektu. Sprawdź, że tam są.
6. Test: poproś agenta z telefonu o drobną zmianę i wysłanie przez
   rt sg -m "test" --build --wait --json. Oczekiwany kod 0 i aplikacja na telefonie.
7. Wyjaśnij, co zrobić po restarcie serwera (sesja tmux znika i trzeba ją uruchomić ponownie)
   i jak sprawdzić, czy sesja działa.
```

---

## 5. Agent AI (Claude Code) na Windows

**Co robi:** instaluje Claude Code na Windows i łączy go z RemoteAppTester oraz z aplikacją Claude na telefonie.
**Co zmieni:** instaluje Claude Code (i ewentualnie Git) na wybranym koncie Windows.
**Ważne:** agent uruchomiony na **Twoim głównym koncie** Windows ma dostęp do wszystkich Twoich
plików, haseł w przeglądarce itd. Prompt proponuje bezpieczniejsze warianty: osobne konto
Windows, WSL albo maszynę wirtualną. Ten wybór należy do Ciebie.

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Cel: na Windows z zainstalowanym RemoteAppTester skonfigurować agenta AI Claude Code, żebym
rozmawiał z nim z aplikacji Claude na telefonie (Remote Control), a agent po pracy wysyłał
aplikację na telefon przez polecenie rt (rt sg --build albo rt push).
Dokumentacja: https://code.claude.com/docs i docs/AGENCI_AI.md w repozytorium RemoteAppTester.
Sprawdź aktualny sposób instalacji, zanim podasz polecenia.

Zasady pracy:
- Jeden krok naraz, z wyjaśnieniem. Czekaj na wynik.
- Nie proś o hasła ani tokeny. Logowanie do Claude robię sam.
- Ostrzeż mnie przed każdym ustawieniem, które pozwala agentowi działać bez pytania.

Kroki:
1. Najpierw wyjaśnij mi prosto ryzyko: agent na moim koncie widzi moje pliki. Przedstaw opcje
   (to samo konto / osobne konto Windows / WSL / maszyna wirtualna) z plusami i minusami
   dla kogoś nietechnicznego i poczekaj na mój wybór.
2. Zainstaluj Claude Code oficjalnym sposobem dla Windows (i Git, jeśli jest potrzebny).
3. Folder projektu: ten, który dodałem w RemoteAppTester. Sprawdź, że jest tam REMOTEAPPTESTER.md
   i że polecenie rt działa w tym folderze: rt st.
   (Jeśli agent działa na innym koncie Windows albo w WSL, sprawdź, czy ma dostęp do folderu
   i do polecenia rt. Jeśli nie, zaproponuj rozwiązanie i wyjaśnij jego wady.)
4. Uruchom Claude Code w folderze projektu z Remote Control i pokaż, jak połączyć się z telefonu
   (aplikacja Claude → Code → ta sesja). Komputer musi zostać włączony, a sesja otwarta.
   Pokaż, jak wyłączyć usypianie komputera przy zasilaniu sieciowym.
5. Test: z telefonu poproś agenta o drobną zmianę i rt sg -m "test" --build --wait --json.
```

---

## 6. Pierwsza prośba do agenta w projekcie

**Co robi:** to prompt **dla agenta AI** (np. Claude Code), nie dla zwykłego czatu. Wklejasz
go na początku pracy w folderze projektu. Agent poznaje zasady RemoteAppTester i Twój pomysł.
**Co zmieni:** agent zacznie pisać kod w folderze projektu i wyśle pierwszą wersję na telefon.

```text
Pracujemy nad moją aplikacją w tym folderze. Nie jestem programistą: mów prosto i krótko,
a decyzje techniczne podejmuj sam, ale ważne wybory (np. płatne usługi, zbieranie danych
użytkowników, logowanie przez Google) najpierw mi przedstaw.

Najpierw przeczytaj REMOTEAPPTESTER.md w tym folderze. Opisuje, jak wysyłać aplikację na mój telefon.
Zasady:
- Po każdej skończonej zmianie wyślij aplikację na telefon:
  rt sg -m "<krótko, co zmieniłeś>" --build --wait --json
  Jeśli build się nie uda (kod 1), przeczytaj log_tail, popraw i spróbuj ponownie.
  Kod 3 albo 4: powiedz mi, bo to sprawa ustawień, nie kodu.
- Nigdy sam nie zatwierdzaj komend budowania (rt pr import). To moja decyzja.
- Nie zapisuj w projekcie haseł, kluczy ani tokenów. Nie wysyłaj nigdzie danych z tego serwera.
- Używaj tylko znanych, popularnych bibliotek. Sprawdzaj dokładne nazwy pakietów.
- Pracuj na gicie: małe commity z opisem, żebyśmy mogli cofnąć zmiany.
- Jeśli w folderze jest .remoteapptester-feedback.md, to moje uwagi z podglądu na telefonie: przeczytaj je.

Mój pomysł: <opisz własnymi słowami, np. „aplikacja do zapisywania wydatków domowych
z podziałem na kategorie i wykresem miesięcznym; prosta, duże przyciski, po polsku”>.

Zacznij od najprostszej działającej wersji. Wyślij ją na telefon i napisz mi, co mam sprawdzić.
```

---

## 7. Diagnoza problemu

**Co robi:** pomaga znaleźć przyczynę problemu na podstawie diagnozy programu, bez ujawniania sekretów.
**Co zmieni:** nic. Na początku tylko odczytuje stan. Każdą poprawkę czat zaproponuje osobno.

```text
Jesteś moim cierpliwym przewodnikiem. Nie jestem informatykiem. Odpowiadaj w języku, w którym piszę.

Mam problem z RemoteAppTester (program buduje aplikacje i wysyła je na telefon przez Tailscale;
https://github.com/damiannass88/RemoteAppTester, przeczytaj docs/PORADNIK.md rozdział 7).
System: <Windows / Linux VPS>. Wersja: <z „O aplikacji” albo rt version>.
Co się dzieje: <opisz objaw i dokładny komunikat błędu>.
Od kiedy: <np. po aktualizacji, po zmianie sieci, od początku>.

Zasady:
- Najpierw tylko polecenia, które odczytują stan (np. rt dr, tailscale status,
  systemctl status remoteapptester, journalctl -u remoteapptester -n 100). Nic nie zmieniaj,
  dopóki nie wyjaśnisz przyczyny i nie zgodzę się na poprawkę.
- Zanim wkleję wynik, przypomnij mi, żebym usunął z niego adresy IP, nazwy urządzeń
  i wszystko, co wygląda na token, hasło albo kod parowania.
- Nie każ mi otwierać portów, wyłączać zapory ani dawać komukolwiek sudo.
- Jeśli to wygląda na błąd programu, pomóż mi przygotować zgłoszenie na GitHubie bez sekretów.
```

---

## 8. Wydanie aplikacji w Google Play

**Co robi:** prowadzi od testowej wersji do publikacji w Google Play: konto dewelopera, podpis,
polityka prywatności, testy wymagane przez Google, opis w sklepie.
**Co zmieni:** w projekcie konfigurację podpisu wydania (klucz poza folderem projektu) i
ustawienia buildu release. Rejestrację i płatności robisz sam w Play Console.
**Ważne:** utrata klucza podpisu albo konta może uniemożliwić aktualizacje. Kwestie prawne
i podatkowe przy sprzedaży skonsultuj ze specjalistą.

```text
Jesteś moim przewodnikiem przy wydaniu aplikacji Android w Google Play. Nie jestem informatykiem.
Odpowiadaj w języku, w którym piszę. Zasady Google Play się zmieniają: zanim coś mi podasz,
sprawdź aktualne wymagania w oficjalnych źródłach (support.google.com/googleplay/android-developer,
developer.android.com) i podaj linki.

Moja aplikacja: <nazwa, co robi, dla kogo>. Technologia: <np. Flutter>.
Czy zbiera dane użytkowników (konta, lokalizacja, zdjęcia, analityka, reklamy)? <tak/nie/nie wiem>.
Płatna / reklamy / zakupy w aplikacji: <…>. Kraj, w którym mieszkam: <…>.
Konto Google Play: <nie mam / prywatne / firmowe>.

Prowadź mnie po kolei i przy każdym etapie napisz, ile to mniej więcej trwa i co kosztuje:
1. Konto dewelopera: rodzaj (prywatne czy firmowe), weryfikacja tożsamości, opłata.
2. Identyfikator aplikacji (applicationId): sprawdź, czy nie jest przykładowy (np. com.example),
   bo po publikacji nie da się go zmienić.
3. Klucz podpisu: utworzenie klucza przesyłania POZA folderem projektu i poza zasięgiem agenta AI,
   kopia zapasowa w dwóch miejscach, Play App Signing. Hasła wpisuję sam.
4. Build release (np. flutter build appbundle) i sprawdzenie wersji (versionCode).
5. Polityka prywatności: pomóż napisać ją zgodnie z prawdą o tym, co aplikacja zbiera, i opublikować
   (np. GitHub Pages). Formularz bezpieczeństwa danych w Play Console.
6. Treść w sklepie: opis, zrzuty ekranu, ikona, kategoria, ocena treści, grupa docelowa.
7. Testy wymagane dla mojego typu konta (np. test zamknięty z określoną liczbą testerów przez
   określony czas: sprawdź aktualne liczby), potem produkcja.
8. Uprawnienia wrażliwe: sprawdź AndroidManifest i wyjaśnij, które wymagają deklaracji.
9. Lista „czego nie robić”: kopiowanie cudzych nazw, logo i treści, wprowadzające w błąd opisy,
   zbieranie danych bez zgody.
Na koniec przypomnij o RODO (jeśli dotyczy), regulaminie dla użytkowników i podatkach.
To przypomnienie, nie porada prawna.
```

---

## 9. Wydanie aplikacji WWW

**Co robi:** pomaga wybrać hosting i opublikować stronę albo aplikację WWW, którą testowałeś
przez podgląd w RemoteAppTester.
**Co zmieni:** w projekcie konfigurację produkcyjną. Zakup domeny i hostingu robisz sam.

```text
Jesteś moim przewodnikiem przy publikacji aplikacji WWW. Nie jestem informatykiem.
Odpowiadaj w języku, w którym piszę. Sprawdzaj aktualne ceny i warunki u dostawców.

Moja aplikacja: <co robi>. Technologia: <np. Next.js, ASP.NET, Django, strona statyczna>.
Czy ma konta użytkowników / bazę danych / płatności? <…>. Spodziewany ruch: <mały / średni>.

Prowadź mnie po kolei:
1. Wybór hostingu dopasowany do technologii (od darmowych dla stron statycznych po VPS)
   z plusami, minusami i kosztem. Odradź mi rozwiązania zbyt skomplikowane na start.
2. Domena i HTTPS.
3. Konfiguracja produkcyjna: zmienne środowiskowe zamiast haseł w kodzie, tryb produkcyjny,
   kopie zapasowe bazy danych.
4. Publikacja i sprawdzenie, czy działa (także na telefonie).
5. Bezpieczeństwo: aktualizacje zależności, silne hasła administratora, ograniczenie paneli administracyjnych.
6. Prawo: polityka prywatności, informacja o cookies, RODO, jeśli zbieram dane osobowe
   (przypomnienie, nie porada prawna).
Nie publikuj nic beze mnie i nie zakładaj płatnych usług bez mojej zgody.
```
