# RemoteAppTester dla agentów AI

Instrukcja dla agenta AI (Claude Code, Codex, Cursor i innych), który pracuje w folderze projektu
przypisanym do RemoteAppTestera, na serwerze Linux/VPS albo na Windows. Każdy taki folder ma
też `REMOTEAPPTESTER.md`, a CLAUDE.md i AGENTS.md mają w nim krótką wskazówkę.

## Zasada działania

Agent nie ma dostępu do RemoteAppTestera: nie widzi bazy, kluczy, tokenu ani połączenia z
telefonem, i nie potrzebuje `sudo`. Porozumiewa się z RemoteAppTesterem wyłącznie przez pliki
w folderze projektu:

| Plik | Kto pisze | Po co |
|---|---|---|
| `.remoteapptester-signal` | agent (`rt sg`, `rt push`) | zlecenie: notatka, prośba o build albo gotowa instalka |
| `.remoteapptester-status.json` | RemoteAppTester | wynik ostatniego zlecenia |
| `.remoteapptester-push.apk` | `rt push` | kopia instalki spoza folderu projektu |

Usługa RemoteAppTester sprawdza foldery co około 3 sekundy. Gdy znajdzie zlecenie, przywraca
wzór pliku sygnału, wykonuje zlecenie (jeśli pozwalają na to opcje projektu) i zapisuje wynik.
Telefon dostaje nową wersję przez Tailscale. Instalacja przebiega tak, jak ustawiono w opcjach
projektu: `ask` (telefon pyta), `auto` albo `off`.

## Dwa sposoby dostarczenia aplikacji

**1. RemoteAppTester buduje** zatwierdzonymi komendami z bazy (agent może je tylko
zaproponować w `REMOTEAPPTESTER.md`, a zatwierdza człowiek):

```sh
rt sg -m "Dodano ekran logowania" --build --wait --json
```

**2. Agent buduje sam** i wysyła gotowy plik APK:

```sh
flutter build apk --debug --target-platform android-arm64
rt push build/app/outputs/flutter-apk/app-debug.apk -m "Dodano ekran logowania" --wait --json
```

- Bez ścieżki `rt push` wysyła najnowszy `build/**/*.apk` z projektu.
- Plik spoza folderu projektu jest kopiowany do `.remoteapptester-push.apk`.
- Przyjmowany jest tylko podpisany plik `.apk` (nagłówek ZIP, bez `unsigned` w nazwie, do 1 GB),
  który leży w folderze projektu, także po rozwiązaniu dowiązań.
- Musi być włączona opcja projektu „Agent AI może wysłać własną instalkę” (domyślnie jest).
  Zmienia się ją poleceniem `sudo rt o <projekt> --agent-push on|off` albo w oknie aplikacji.
- `--installed` czeka też, aż każdy telefon potwierdzi, że obsłużył dostawę.

## Wynik i kody wyjścia

`--wait` czeka na wynik, `--timeout <s>` zmienia limit (domyślnie 600 s dla `push` i 3600 s dla
`sg --build`). `--json` wypisuje jedną linię JSON. Wynik można też odczytać później: `rt st --json`.

| Kod | Znaczenie | Co zrobić |
|---|---|---|
| 0 | wysłane na telefon(y); z `--installed` także potwierdzone | poprosić użytkownika o test |
| 1 | odrzucone albo build nieudany | przeczytać `message` i `log_tail`, poprawić, ponowić |
| 2 | przekroczony czas | sprawdzić później: `rt st` |
| 3 | RemoteAppTester nie odebrał sygnału | usługa nie działa: powiedzieć użytkownikowi |
| 4 | gotowe, ale żaden telefon nie dostał wersji | instalacja `off` albo brak wybranych telefonów: powiedzieć użytkownikowi |
| 64 | złe użycie polecenia | `rt push --help` |

Przykład wyniku (`.remoteapptester-status.json`):

```json
{
  "request": "033c043c30cbfb36",
  "action": "push",
  "state": "done",
  "message": "Gotowe — wysłano na telefony: 1; potwierdziło: 0.",
  "project": "apka",
  "build_id": "hnx2lu1xw8",
  "phase": "DONE",
  "sha256": "ebd707aa…",
  "size_bytes": 18234567,
  "install": "ask",
  "devices": [{"id": "…", "name": "Pixel", "online": true, "handled": false}],
  "updated_at": "2026-11-06T20:21:22Z"
}
```

`action` przyjmuje wartości `push`, `build` albo `note`, a `state` wartości `queued`, `running`,
`done`, `rejected`, `failed` albo `cancelled`. Przy `failed` w polu `log_tail` jest ostatnie
40 linii logu builda.

## Przygotowanie agenta na VPS (robi człowiek)

```sh
sudo bash install.sh --add-user <login-agenta>   # konto agenta w grupie projektów, bez sudo
sudo rt n aplikacja --flutter                    # albo: sudo rt a /srv/remoteapptester/projects/<folder>
sudo rt o aplikacja --install ask --agent-push on
```

Agent pracuje w `/srv/remoteapptester/projects/<projekt>` i używa wyłącznie `rt sg`, `rt push`
i `rt st`, które działają bez `sudo`. Pozostałe polecenia `rt` wymagają `sudo` i są dla człowieka.

## Zasady

- Nie zatwierdzaj komend z `REMOTEAPPTESTER.md` sam (`rt pr import`): to decyzja człowieka.
- Notatka `-m` to krótki tekst do 300 znaków bez sekretów, bo wyświetla się na telefonie.
- Dodaj `.remoteapptester-signal`, `.remoteapptester-status.json` i `.remoteapptester-push.apk`
  do `.gitignore`.
- Wysyłaj wersje debug do testów, a kluczy podpisu release nie trzymaj w folderze agenta.
