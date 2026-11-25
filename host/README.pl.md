# host/ — RemoteAppTester host (CLI)

🌐 [English](README.md) · **Polski**

Program `remoteapptester` dla Windows i Linuxa (preferowany Ubuntu). Konfiguruje projekty,
buduje je stałymi recepturami, trzyma kolejkę i serwer gRPC (tylko w sieci Tailscale), z
którego telefon pobiera gotowe instalki. Czysty Dart — bez Fluttera i bez GUI.

Założenia: [docs/PROJECT_ASSUMPTIONS.md](../docs/PROJECT_ASSUMPTIONS.md) · plan:
[docs/IMPLEMENTATION_PLAN.md](../docs/IMPLEMENTATION_PLAN.md) · bezpieczeństwo:
[docs/SECURITY.md](../docs/SECURITY.md) · instalacja na VPS:
[deploy/linux/README.pl.md](deploy/linux/README.pl.md).

## Rola na Windows i Linuxie

- **Windows:** główna jest aplikacja okienkowa (`../desktop_app`), która uruchamia ten rdzeń
  u siebie. `rt` służy terminalowi i agentom AI (`rt b` w folderze projektu) i korzysta z tej
  samej zaszyfrowanej bazy w `%LOCALAPPDATA%\RemoteAppTester`.
- **Linux/VPS:** `rt s` uruchamia rdzeń bez okna, jako usługę systemową instalowaną przez
  [deploy/linux/install.sh](deploy/linux/README.pl.md).

## Polecenia (`rt` = `remoteapptester`)

| Skrót | Polecenie | Działanie |
|---|---|---|
| `rt b` | `build [folder] [--no-wait]` | build przez działający RemoteAppTester; kod wyjścia = wynik |
| `rt n` | `new <nazwa> [--flutter]` | nowy folder projektu i przypisanie |
| `rt o` | `options [folder] [--install …] [--launch …] [--agent-build …] [--phone-build …] [--terminal …]` | opcje projektu |
| `rt lg` | `log [folder]` | historia buildów i log ostatniego |
| `rt in` | `info` | przewodnik: bezpieczeństwo, agenci AI, sandbox, publikacja |
| `rt la` | `language [auto\|pl\|en\|de\|cs]` | język poleceń |
| `rt sg` | `signal [-m "notatka"] [--build] [--wait] [--json]` | sygnał agenta AI: „są zmiany” (plik w folderze, bez dostępu do RemoteAppTestera) |
| `rt pu` | `push [plik.apk] [-m "notatka"] [--wait] [--installed] [--json]` | agent AI wysyła na telefony instalkę zbudowaną samodzielnie |
| `rt st` | `status [folder] [--json]` | wynik ostatniego sygnału lub wysyłki (`.remoteapptester-status.json`) |
| `rt a` / `rt rm` | `add [folder]` / `remove <folder\|nazwa>` | przypisz / odepnij projekt |
| `rt ls` | `projects` | projekty i stan `REMOTEAPPTESTER.md` |
| `rt pr` | `project [folder]`, `pr import`, `pr guide` | komendy; zatwierdź propozycję agenta; odśwież plik |
| `rt m` | `methods` | szablony komend dla technologii |
| `rt p` / `rt dv` / `rt rv` | `pair` / `devices` / `revoke` | telefony |
| `rt s` / `rt t` | `serve` / `tunnel` | serwer bez okna (Linux) / paruj + serwer |
| `rt i` / `rt dr` / `rt h` / `rt v` | `init` / `doctor` / `history` / `version` | |

`rt` bez argumentów pokazuje tabelę i **ostatnio używane polecenia**.

## Agenci AI

W każdym przypisanym folderze jest `REMOTEAPPTESTER.md`: wytyczne i blok komend do
uzupełnienia. Agent poprawia blok → RemoteAppTester pokazuje propozycję → zatwierdzasz w
aplikacji (albo `rt pr import` w interaktywnym terminalu). Po skończonej pracy agent daje
znać: w folderze leży opisany wzór `.remoteapptester-signal` — agent ustawia `build: true` i
`message` i zapisuje (albo `rt sg -m "co zmieniono" [--build]`). RemoteAppTester oznacza projekt
„nowe zmiany” i (domyślnie) buduje i wysyła. Wskazówka trafia też do CLAUDE.md i AGENTS.md.
`rt b` (lokalny token) zostaje dla człowieka w terminalu.

Agent, który sam zbudował APK, wysyła go poleceniem `rt push <plik.apk> -m "…" --wait --json`
(kod wyjścia 0 = wysłane na telefon). Pełny opis dla agentów: [docs/AGENCI_AI.md](../docs/AGENCI_AI.md).

## Struktura

```
host/
├── bin/remoteapptester.dart, rt.dart  # punkt wejścia CLI (dwie nazwy)
├── config/host-config.example.yaml
├── deploy/windows/              # instalator Windows (install.ps1/.cmd): PATH, autostart, zapora
├── deploy/linux/                # uniwersalny instalator Linux + usługa systemd
├── tool/build_release.ps1       # paczka Windows ZIP: aplikacja okienkowa + rt (+ APK)
├── tool/build_release.sh        # paczka Linux x64/arm64 (Docker)
├── tool/e2e_delivery.dart       # test dostaw bez telefonu (udaje aplikację: TLS pinning + HMAC)
├── lib/
│   ├── cli/                     # polecenia i skróty, historia poleceń, doctor, kod QR w terminalu
│   ├── config/                  # host-config.yaml
│   ├── discovery/               # rozpoznawanie technologii folderu
│   ├── build/                   # BuildEngine (równoległe buildy w tle), uruchamianie kroków, artefakty, redakcja logów
│   ├── store/                   # zaszyfrowana baza: projekty, komendy, opcje, historia
│   ├── project/                 # warianty komend, szablony, REMOTEAPPTESTER.md, wyszukiwanie instalki
│   ├── server/                  # HostRuntime, serwer gRPC (Tailscale, TLS), dostawy, lokalny kanał, kill-switch
│   ├── pairing/                 # rejestr urządzeń, URI parowania, HMAC, nonce, rate limiting
│   ├── security/                # SecretStore (DPAPI / plik 0600), tożsamość TLS
│   ├── net/                     # wykrycie adresu Tailscale
│   └── generated/               # kod z proto/remote_tester.proto (nie edytować)
└── test/
```

## Testy

```sh
dart analyze
dart test
```

Część testów jest pomijana poza Windows (DPAPI) albo bez uprawnień do symlinków.

Test dostaw bez telefonu (przy działającym `rt s`): `rt p "e2e"`, potem
`dart run tool/e2e_delivery.dart --home <dane> --device <device_id>` i w drugim terminalu `rt b <folder>`.

## Konfiguracja

[config/host-config.example.yaml](config/host-config.example.yaml) — bez sekretów. Sekrety
(`pairing_secret`, klucz prywatny TLS) żyją wyłącznie w `SecretStore` (Windows DPAPI, Linux
plik `0600` użytkownika usługi).
