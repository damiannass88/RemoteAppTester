# Publishing RemoteAppTester (for the maintainer)

🌐 **English** · [Polski](../PUBLISHING.md)

Rules as of November 2026. Check them in official sources before each release.
Public repository: https://github.com/damiannass88/RemoteAppTester

Everything here is **free**: your own Android signing key, SHA-256 checksums and GitHub Releases.
Paid Windows code-signing certificates are not used.

## 1. Android signing key (free, once)

Packages of every version must be signed with **the same key**. Otherwise Android refuses the
update and the user has to uninstall the app (losing the pairing). The debug key exists only on one
computer, so it is not suitable for public releases.

1. Create the key **outside the repository** (passwords are typed only in the terminal; save them in a password manager):

   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\keys"
   & "C:\Program Files\Android\openjdk\jdk-21.0.8\bin\keytool.exe" -genkeypair -v `
     -keystore "$env:USERPROFILE\keys\remoteapptester-release.jks" `
     -keyalg RSA -keysize 4096 -validity 10000 -alias remoteapptester
   ```

   `keytool` asks for the keystore password and the owner details. A name or nickname is enough,
   because these details are visible in the app's certificate. The path to `keytool` depends on your
   installation: `flutter doctor -v` shows "Java binary at", and `keytool.exe` is next to it.

2. **Backup:** the `.jks` file and the password in two places outside this computer (e.g. an encrypted
   USB drive and a password manager). **Losing the key = no more updates for existing users.**

3. Create `android_app/android/key.properties` (it is in `.gitignore`; never commit it):

   ```properties
   storeFile=C:/Users/<account>/keys/remoteapptester-release.jks
   storePassword=<password>
   keyAlias=remoteapptester
   keyPassword=<password>
   ```

4. From now on `build_release.ps1 -WithAndroid` signs the APK with this key. To check:
   `apksigner verify --print-certs <file.apk>` (Android SDK, build-tools) shows your certificate.

> Switching from the debug key to a new key means uninstalling the app once from phones that have a
> test build, and pairing again.

## 2. Windows without a paid certificate

- The files are not signed, so SmartScreen warns ("More info" → "Run anyway").
  The instructions tell users to check the SHA-256 checksum first.
- Every package is published with a `.sha256` file, and the package contains `SHA256SUMS` (checked by the installer).
- A free option for the future: code-signing programmes for open-source projects (e.g. SignPath
  Foundation), if you meet their conditions. It needs an application and automated builds (CI).

## 3. GitHub release (checklist)

1. Raise the version everywhere ([CONTRIBUTING.md](../../CONTRIBUTING.md)) and add the changes to
   [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md).
2. Tests: `cd host && dart test`, `cd desktop_app && flutter test`, `cd android_app && flutter test`.
3. Packages: `host\tool\build_release.ps1 -WithAndroid` and `bash host/tool/build_release.sh`
   (Docker; for arm64 once: `docker run --privileged --rm tonistiigi/binfmt --install arm64`).
4. Copy the APK from `host/build/release/windows/` next to the packages and compute its checksum.
5. `git tag v<version>` and `git push origin v<version>` (or create the tag in the release form).
6. On the repository page: **Releases** (right-hand column) → **Draft a new release**
   (direct link: `https://github.com/damiannass88/RemoteAppTester/releases/new`) → tag `v<version>`,
   title `RemoteAppTester <version>`, description from IMPLEMENTATION_PLAN.md, attachments:
   - `RemoteAppTester-windows-x64-<version>.zip` + `.sha256`
   - `RemoteAppTester-linux-<version>.tar.gz` + `.sha256`
   - `RemoteAppTester-android-<version>.apk` + `.sha256`
   Tick **Set as a pre-release** while the program is in beta.

## 4. Google Play (optional, later)

RemoteAppTester is distributed through GitHub Releases. A Google Play release is possible, but:

- **The identifier** `com.damiannass.remoteapptester` cannot be changed after publishing.
- **`REQUEST_INSTALL_PACKAGES`**: allowed only when installing packages is the app's core function,
  with a declaration in Play Console. Describe the behaviour honestly and expect a review by Google.
- **`UPDATE_PACKAGES_WITHOUT_USER_ACTION`**: check whether the store version needs it.
- **Personal accounts created after 13 Nov 2023**: a closed test with at least 12 testers for 14 days before production.
- **Privacy policy**: [PRIVACY.md](../PRIVACY.md); the data safety form.
- **Fee**: the Google Play developer account (one-time) is the only cost of this route.
- **Android developer verification**: from 30 Sep 2026 in four countries, globally from 2027. It also
  applies to installs outside the store, so it may affect apps installed by RemoteAppTester. Follow the rules.
