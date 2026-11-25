# android_app/ — RemoteAppTester app (Android, Flutter)

🌐 **English** · [Polski](README.pl.md)

Receives apps built on the computer/VPS, verifies them, installs them without root or ADB and, if
configured, launches them. It connects to the host only through Tailscale, with a certificate pinned
at pairing and an HMAC signature on every request. The app locks with your fingerprint (or phone PIN).

Design decisions: [docs/PROJECT_ASSUMPTIONS.md](../docs/PROJECT_ASSUMPTIONS.md) (PL, section 8:
installing debug builds on Android) · plan: [docs/IMPLEMENTATION_PLAN.md](../docs/IMPLEMENTATION_PLAN.md) (PL).

## Pairing

On the host (locally or over SSH): `rt p "My phone"` (on a VPS: `sudo rt p "My phone"`). In the app:
**Scan QR code** or **Paste from clipboard** (a `remoteapptester://pair?...` link).

## Running

```sh
flutter pub get
flutter run        # a phone with Tailscale on, in the same tailnet as the host
```

**First install through RemoteAppTester:** Android shows a one-time "Install unknown apps" consent
for RemoteAppTester. This is normal system behaviour, not an error.

## Status

- **Automatic delivery:** once connected, the app keeps a permanent stream to the host and reconnects
  by itself (network change, sleep, host restart). A new version from any trigger (`rt b`, an AI agent,
  another phone) is downloaded, checked (SHA-256, package name), installed (`install: auto`) or waits
  for "Install" (`install: ask`), and then launched (`deliver.launch`). The state is shown in the bar
  above the project list.
- **Android 12+:** updates of apps previously installed by RemoteAppTester happen without a confirmation
  window. The first install always needs confirmation; a banner leads to the "Install unknown apps" consent.
- **Manually:** tapping a project = build → download → install → launch, with a log preview,
  cancelling, and resuming after a dropped connection.
- **App lock:** fingerprint or PIN at start and after returning from the background; changing the lock
  settings requires confirmation.

## Structure

```
android_app/
├── android/app/src/main/
│   ├── AndroidManifest.xml          # INTERNET, REQUEST_INSTALL_PACKAGES, UPDATE_PACKAGES_WITHOUT_USER_ACTION, CAMERA (QR), USE_BIOMETRIC
│   └── kotlin/com/damiannass/remoteapptester/
│       ├── MainActivity.kt          # channel com.damiannass.remoteapptester/package_installer
│       ├── PackageInstallerPlugin.kt  # PackageInstaller.Session, package name from the APK, launching, fingerprint enrolment
│       └── InstallResultReceiver.kt   # install result, system confirmation, launching
└── lib/
    ├── main.dart                    # automatic connection or the pairing screen
    ├── generated/                   # code from proto/remote_tester.proto (do not edit)
    ├── net/                         # AgentClient (TLS pinning + HMAC), connection monitor, error messages
    ├── pairing/                     # pairing URI, HMAC (identical to the host)
    ├── settings/                    # host address (SharedPreferences), secrets (Keystore)
    ├── transfer/                    # resumable download + SHA-256
    ├── delivery/                    # DeliveryService: permanent delivery stream, reconnect, install automation
    ├── install/                     # download → applicationId check → install → launch
    ├── security/                    # app lock, biometrics/PIN before sensitive actions
    └── ui/                          # projects + delivery bar, build, pairing, QR scan, lock screen
```

## Tests

```sh
flutter analyze
flutter test
```
