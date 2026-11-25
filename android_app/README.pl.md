# android_app/ — aplikacja RemoteAppTester (Android, Flutter)

🌐 [English](README.md) · **Polski**

Odbiera aplikacje zbudowane na komputerze/VPS, weryfikuje je, instaluje bez roota i bez ADB
i — jeśli tak wskazano — uruchamia. Łączy się z hostem wyłącznie przez Tailscale, z
certyfikatem przypiętym przy parowaniu i podpisem HMAC każdego żądania. Aplikacja blokuje się
odciskiem palca (albo PIN-em telefonu).

Założenia: [docs/PROJECT_ASSUMPTIONS.md](../docs/PROJECT_ASSUMPTIONS.md) (sekcja 8 —
instalacja wersji debug na Androidzie) · plan: [docs/IMPLEMENTATION_PLAN.md](../docs/IMPLEMENTATION_PLAN.md).

## Parowanie

Na hoście (lokalnie lub przez SSH): `rt p "Mój telefon"` (na VPS: `sudo rt p "Mój telefon"`). W aplikacji: **Skanuj kod QR** albo **Wklej ze
schowka** (link `remoteapptester://pair?...`).

## Uruchomienie

```sh
flutter pub get
flutter run        # telefon z aktywnym Tailscale w tym samym tailnecie co host
```

**Pierwsza instalacja z RemoteAppTester:** Android pokaże jednorazowo zgodę „Instalowanie
nieznanych aplikacji” dla RemoteAppTester — to standardowe zachowanie systemu, nie błąd.

## Stan

- **Automatyczne dostawy:** po połączeniu aplikacja trzyma stały strumień z hostem i sama łączy
  się ponownie (zmiana sieci, uśpienie, restart hosta). Nowa wersja z dowolnego wyzwalacza
  (`rt b`, agent AI, inny telefon) jest pobierana, sprawdzana (SHA-256, nazwa pakietu),
  instalowana (`install: auto`) albo czeka na „Zainstaluj” (`install: ask`), a potem
  uruchamiana (`deliver.launch`). Stan widać na pasku nad listą projektów.
- **Android 12+:** aktualizacje aplikacji zainstalowanych wcześniej przez RemoteAppTester bez okna
  potwierdzenia. Pierwsza instalacja zawsze wymaga potwierdzenia; baner prowadzi do zgody
  „Instalowanie nieznanych aplikacji”.
- **Ręcznie:** dotknięcie projektu = build → pobierz → zainstaluj → uruchom, z podglądem logu,
  anulowaniem i wznowieniem po zerwaniu połączenia.
- **Blokada aplikacji:** odcisk palca albo PIN przy starcie i po powrocie z tła; zmiana ustawień
  blokady wymaga potwierdzenia.

## Struktura

```
android_app/
├── android/app/src/main/
│   ├── AndroidManifest.xml          # INTERNET, REQUEST_INSTALL_PACKAGES, UPDATE_PACKAGES_WITHOUT_USER_ACTION, CAMERA (QR), USE_BIOMETRIC
│   └── kotlin/com/damiannass/remoteapptester/
│       ├── MainActivity.kt          # kanał com.damiannass.remoteapptester/package_installer
│       ├── PackageInstallerPlugin.kt  # PackageInstaller.Session, nazwa pakietu z APK, uruchamianie, dodawanie odcisku palca
│       └── InstallResultReceiver.kt   # wynik instalacji, systemowe potwierdzenie, uruchomienie
└── lib/
    ├── main.dart                    # automatyczne połączenie albo ekran parowania
    ├── generated/                   # kod z proto/remote_tester.proto (nie edytować)
    ├── net/                         # AgentClient (TLS pinning + HMAC), monitor połączenia, komunikaty błędów
    ├── pairing/                     # URI parowania, HMAC (identyczne jak na hoście)
    ├── settings/                    # adres hosta (SharedPreferences), sekrety (Keystore)
    ├── transfer/                    # wznawialne pobieranie + SHA-256
    ├── delivery/                    # DeliveryService: stały strumień dostaw, reconnect, automat instalacji
    ├── install/                     # pobranie → kontrola applicationId → instalacja → uruchomienie
    ├── security/                    # blokada aplikacji, biometria/PIN przed wrażliwymi akcjami
    └── ui/                          # projekty + pasek dostaw, build, parowanie, skan QR, ekran blokady
```

## Testy

```sh
flutter analyze
flutter test
```
