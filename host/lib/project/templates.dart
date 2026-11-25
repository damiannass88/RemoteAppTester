import 'dart:io';

import '../generated/remote_tester.pbenum.dart';
import 'build_profile.dart';

/// Domyślne komendy budowania dla rozpoznanego typu projektu — wpisywane przy
/// przypisaniu folderu (autowykrywanie). Użytkownik może je potem zmienić w
/// aplikacji, a agent AI zaproponować lepsze w `REMOTEAPPTESTER.md`.
///
/// Komendy zależą od systemu hosta (cmd na Windows, bash na Linuxie).
List<BuildProfile> templateProfiles(ProjectKind kind, {bool? windows}) {
  final win = windows ?? Platform.isWindows;
  switch (kind) {
    case ProjectKind.FLUTTER:
      return [
        BuildProfile(
          name: 'Debug',
          steps: const [
            BuildStep('Zależności', 'flutter pub get'),
            BuildStep('Budowanie APK (debug, arm64)', 'flutter build apk --debug --target-platform android-arm64'),
          ],
          artifact: 'build/app/outputs/flutter-apk/app-debug.apk',
        ),
        BuildProfile(
          name: 'Release',
          steps: const [
            BuildStep('Zależności', 'flutter pub get'),
            BuildStep('Budowanie APK (release, arm64)', 'flutter build apk --release --target-platform android-arm64'),
          ],
          artifact: 'build/app/outputs/flutter-apk/app-release.apk',
        ),
      ];
    case ProjectKind.ANDROID_GRADLE:
      final gradlew = win ? 'gradlew.bat' : 'sh gradlew';
      return [
        BuildProfile(
          name: 'Debug',
          steps: [BuildStep('Budowanie APK (debug)', '$gradlew assembleDebug')],
          artifact: 'app/build/outputs/apk/debug/*.apk',
        ),
        BuildProfile(
          name: 'Release',
          steps: [BuildStep('Budowanie APK (release)', '$gradlew assembleRelease')],
          artifact: 'app/build/outputs/apk/release/*.apk',
        ),
      ];
    case ProjectKind.REACT_NATIVE:
      final gradlew = win ? 'gradlew.bat' : 'sh gradlew';
      return [
        BuildProfile(
          name: 'Release (bundle w APK)',
          steps: [
            const BuildStep('Zależności', 'npm install'),
            BuildStep('Budowanie APK', 'cd android && $gradlew assembleRelease'),
          ],
          artifact: 'android/app/build/outputs/apk/release/*.apk',
        ),
      ];
    case ProjectKind.CAPACITOR:
      final gradlew = win ? 'gradlew.bat' : 'sh gradlew';
      return [
        BuildProfile(
          name: 'Debug',
          steps: [
            const BuildStep('Zależności', 'npm install'),
            const BuildStep('Budowanie web', 'npm run build'),
            const BuildStep('Synchronizacja Android', 'npx cap sync android'),
            BuildStep('Budowanie APK', 'cd android && $gradlew assembleDebug'),
          ],
          artifact: 'android/app/build/outputs/apk/debug/*.apk',
        ),
      ];
    default:
      // Nieznany typ: szablon do uzupełnienia (np. przez agenta AI w REMOTEAPPTESTER.md).
      return [
        BuildProfile(
          name: 'Debug',
          steps: const [BuildStep('Budowanie', 'echo Uzupelnij komende budowania w RemoteAppTester')],
          artifact: 'build/**/*.apk',
        ),
      ];
  }
}

const kindNames = {
  ProjectKind.FLUTTER: 'Flutter',
  ProjectKind.ANDROID_GRADLE: 'Android (Gradle)',
  ProjectKind.REACT_NATIVE: 'React Native',
  ProjectKind.CAPACITOR: 'Capacitor',
  ProjectKind.OTHER: 'Inny',
};

String kindName(ProjectKind kind) => kindNames[kind] ?? 'Inny';
