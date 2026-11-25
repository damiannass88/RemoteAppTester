# Publikacja RemoteAppTester (dla opiekuna projektu)

🌐 [English](en/PUBLISHING.md) · **Polski**

Stan zasad: listopad 2026. Przed wydaniem sprawdź je w oficjalnych źródłach.
Repozytorium publiczne: https://github.com/damiannass88/RemoteAppTester

Wszystko tutaj jest **bezpłatne**: własny klucz podpisu Androida, sumy SHA-256 i GitHub Releases.
Płatne certyfikaty podpisu kodu dla Windows nie są używane.

## 1. Klucz podpisu Androida (bezpłatny, jednorazowo)

Paczki z kolejnych wersji muszą być podpisane **tym samym kluczem**. Inaczej Android odmówi
aktualizacji i użytkownik musi odinstalować aplikację (a z nią parowanie). Klucz debug działa tylko
na jednym komputerze, więc nie nadaje się do publicznych wydań.

1. Utwórz klucz **poza repozytorium** (hasła wpisujesz tylko w terminalu; zapisz je w menedżerze haseł):

   ```powershell
   New-Item -ItemType Directory -Force "$env:USERPROFILE\keys"
   & "C:\Program Files\Android\openjdk\jdk-21.0.8\bin\keytool.exe" -genkeypair -v `
     -keystore "$env:USERPROFILE\keys\remoteapptester-release.jks" `
     -keyalg RSA -keysize 4096 -validity 10000 -alias remoteapptester
   ```

   `keytool` pyta o hasło magazynu i o dane właściciela. Wystarczy samo imię/pseudonim, bo te dane
   są widoczne w certyfikacie aplikacji. Ścieżka do `keytool` zależy od instalacji: `flutter doctor -v`
   pokazuje „Java binary at”, a `keytool.exe` leży obok.

2. **Kopia zapasowa:** plik `.jks` i hasło w dwóch miejscach poza tym komputerem (np. zaszyfrowany
   pendrive i menedżer haseł). **Utrata klucza = koniec aktualizacji dla obecnych użytkowników.**

3. Utwórz `android_app/android/key.properties` (jest w `.gitignore`, nigdy go nie commituj):

   ```properties
   storeFile=C:/Users/<konto>/keys/remoteapptester-release.jks
   storePassword=<hasło>
   keyAlias=remoteapptester
   keyPassword=<hasło>
   ```

4. Od teraz `build_release.ps1 -WithAndroid` podpisuje APK tym kluczem. Sprawdzenie:
   `apksigner verify --print-certs <plik.apk>` (Android SDK, build-tools) pokazuje Twój certyfikat.

> Zmiana z klucza debug na nowy klucz oznacza jednorazowe odinstalowanie aplikacji z telefonów,
> które mają wersję testową, i ponowne parowanie.

## 2. Windows bez płatnego certyfikatu

- Pliki nie są podpisane, więc SmartScreen ostrzega („Więcej informacji” → „Uruchom mimo to”).
  Instrukcje mówią użytkownikom, żeby najpierw sprawdzili sumę SHA-256.
- Do każdej paczki publikujemy plik `.sha256`, a w paczce `SHA256SUMS` (sprawdza je instalator).
- Opcja bezpłatna na przyszłość: programy podpisywania kodu dla projektów open source (np. SignPath
  Foundation) po spełnieniu ich warunków. Wymaga zgłoszenia i automatycznego budowania (CI).

## 3. Wydanie na GitHubie (lista kontrolna)

1. Podnieś wersję we wszystkich miejscach ([CONTRIBUTING.md](../CONTRIBUTING.md)) i dopisz zmiany
   w [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).
2. Testy: `cd host && dart test`, `cd desktop_app && flutter test`, `cd android_app && flutter test`.
3. Paczki: `host\tool\build_release.ps1 -WithAndroid` i `bash host/tool/build_release.sh`
   (Docker; dla arm64 jednorazowo `docker run --privileged --rm tonistiigi/binfmt --install arm64`).
4. Skopiuj APK z `host/build/release/windows/` obok paczek i policz jego sumę.
5. `git tag v<wersja>` i `git push origin v<wersja>` (albo utwórz tag w formularzu wydania).
6. Na stronie repozytorium: **Releases** (prawa kolumna) → **Draft a new release**
   (link bezpośredni: `https://github.com/damiannass88/RemoteAppTester/releases/new`) → tag `v<wersja>`, tytuł `RemoteAppTester <wersja>`,
   opis z IMPLEMENTATION_PLAN.md, załączniki:
   - `RemoteAppTester-windows-x64-<wersja>.zip` + `.sha256`
   - `RemoteAppTester-linux-<wersja>.tar.gz` + `.sha256`
   - `RemoteAppTester-android-<wersja>.apk` + `.sha256`
   Zaznacz **Set as a pre-release**, dopóki program jest w becie.

## 4. Google Play (opcjonalnie, później)

RemoteAppTester jest dystrybuowany przez GitHub Releases. Wydanie w Google Play jest możliwe, ale:

- **Identyfikator** `com.damiannass.remoteapptester` jest nie do zmiany po publikacji.
- **`REQUEST_INSTALL_PACKAGES`**: dopuszczone tylko, gdy instalowanie pakietów jest główną funkcją
  aplikacji, z deklaracją w Play Console. Trzeba uczciwie opisać działanie i liczyć się z oceną Google.
- **`UPDATE_PACKAGES_WITHOUT_USER_ACTION`**: sprawdzić, czy jest potrzebne w wersji sklepowej.
- **Konto osobiste po 13.11.2023**: test zamknięty z min. 12 testerami przez 14 dni przed produkcją.
- **Polityka prywatności**: [PRIVACY.md](PRIVACY.md); formularz bezpieczeństwa danych.
- **Opłata** za konto dewelopera Google Play (jednorazowa) to jedyny koszt tej drogi.
- **Weryfikacja deweloperów Androida**: od 30.09.2026 w czterech krajach, globalnie od 2027. Dotyczy też
  instalacji poza sklepem, czyli może objąć aplikacje instalowane przez RemoteAppTester. Śledzić zasady.
