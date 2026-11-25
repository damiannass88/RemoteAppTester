# RemoteAppTester na Windows

## Instalacja

1. Rozpakuj `RemoteAppTester-windows-x64-<wersja>.zip` (cały folder).
2. Uruchom **`install.cmd`** (dwuklik). Nie wymaga uprawnień administratora — o zgodę
   administratora (okno UAC) zapyta tylko przy regule zapory, jeśli się zgodzisz.
3. Otworzy się aplikacja RemoteAppTester: **Telefony → Sparuj telefon** i zeskanuj kod w
   aplikacji na telefonie (`RemoteAppTester-android-<wersja>.apk` z tej paczki).
   **Na telefonie obowiązkowo:** Ustawienia → Aplikacje → RemoteAppTester → Oszczędzanie baterii →
   **„Bez ograniczeń”** (to samo dla aplikacji Tailscale). Xiaomi/HyperOS domyślnie ogranicza nowe
   aplikacje i wtedy telefon nie łączy się z komputerem („Connection timed out”).
4. **Projekty → „+”** — dodaj folder z aplikacją; komendy budowania wpiszą się same.

Wymagania: Windows 10/11 64-bit, [Tailscale](https://tailscale.com/download/windows)
zalogowany tym samym kontem co na telefonie (instalator zaproponuje instalację przez
`winget`), narzędzia do budowania projektów (np. Flutter, Android SDK).

Opcje (`install.cmd -Opcja`): `-NoAutostart`, `-NoFirewall`, `-NoShortcuts`, `-NoPath`,
`-NoLaunch`, `-Port 47051`.

**Reguły dostępu Tailscale (ACL).** Jeśli w panelu Tailscale (Access controls) masz własne reguły
zamiast domyślnego „wszyscy do wszystkich”, dodaj dostęp telefonów do portu RemoteAppTestera
(domyślnie **47051**; do wersji 0.6 było 50051). przycisk **Telefony → Generuj JSON dla Tailscale** (albo `rt acl`) tworzy gotową
politykę z urządzeń Twojej sieci Tailscale, np.:

```json
"grants": [{"src": ["<IP telefonu>"], "dst": ["<IP komputera>"], "ip": ["tcp:47051"]}]
```

Bez tego telefon dostaje „Connection timed out”, choć Tailscale pokazuje połączenie.

**Nowy projekt z telefonu.** W aplikacji na telefonie przycisk „Nowy projekt” tworzy projekt
Flutter albo pusty folder, albo przypisuje wolny folder — zawsze w katalogu projektów
komputera (`projects_root`), po samej nazwie; komendy wpisuje komputer. Wyłączysz to w
`host-config.yaml`: `phone_add_projects: false` (potem uruchom program ponownie).

## Co robi instalator

| Krok | Szczegóły |
|---|---|
| Aplikacja | `%LOCALAPPDATA%\Programs\RemoteAppTester\RemoteAppTester.exe`; sumy SHA-256 wszystkich plików sprawdzane przed instalacją |
| Terminal / agenci AI | `rt` i `remoteapptester` w PATH użytkownika (`...\RemoteAppTester\cli\bin`) |
| Dane | `%LOCALAPPDATA%\RemoteAppTester` — zaszyfrowana baza projektów i komend, sparowane telefony, logi, instalki; klucze w Windows DPAPI |
| Skróty i autostart | menu Start, pulpit; start przy logowaniu schowany w zasobniku (wyłączysz w Ustawieniach) |
| Zapora | reguła „RemoteAppTester (Tailscale only)”: tylko `RemoteAppTester.exe`, ten port, adresy `100.64.0.0/10` |

Program przyjmuje połączenia od telefonów wyłącznie na adresie Tailscale. Aktualizacja:
nowsza paczka → `install.cmd` (dane zostają; wersja 0.3 z Harmonogramem zadań jest
przenoszona automatycznie). Odinstalowanie: `uninstall.cmd` (dane zostają) albo
`uninstall.cmd -Purge`. Foldery projektów i ich `REMOTEAPPTESTER.md` zostają nietknięte.

## Uwagi

- **SmartScreen:** program nie jest podpisany certyfikatem — „Więcej informacji” →
  „Uruchom mimo to”. Instalator zdejmuje znacznik „pobrane z internetu” z zainstalowanych plików.
- **Zamknięcie okna** chowa aplikację do zasobnika — buildy i telefony działają dalej.
  „Zakończ” jest w menu ikony w zasobniku.
