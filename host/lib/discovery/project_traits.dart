import 'dart:io';

import 'package:path/path.dart' as p;

import '../generated/remote_tester.pbenum.dart';

/// Niewrażliwe cechy folderu projektu — jedyne,
/// co poza nazwą folderu trafia o projekcie na telefon. Wykrywane wyłącznie
/// po obecności plików w folderze, nigdy z danych od telefonu.
class ProjectTraits {
  const ProjectTraits({required this.kind});

  final ProjectKind kind;

  static ProjectTraits detect(Directory dir) =>
      ProjectTraits(kind: detectKind(dir));

  static ProjectKind detectKind(Directory dir) {
    File f(String relative) => File(p.join(dir.path, relative));
    bool exists(String relative) => f(relative).existsSync();

    // Flutter pierwszy — projekt Flutter ma w środku też android/gradlew,
    // ale w podkatalogu, nie w korzeniu, więc nie pomyli się z natywnym.
    if (_fileMatches(f('pubspec.yaml'), RegExp(r'^flutter\s*:', multiLine: true))) {
      return ProjectKind.FLUTTER;
    }
    final hasGradleWrapper = exists('gradlew') || exists('gradlew.bat');
    final hasSettings = exists('settings.gradle') || exists('settings.gradle.kts');
    final hasAppModule = exists(p.join('app', 'build.gradle')) || exists(p.join('app', 'build.gradle.kts'));
    if (hasGradleWrapper && hasSettings && hasAppModule) {
      return ProjectKind.ANDROID_GRADLE;
    }
    if (_fileMatches(f('package.json'), RegExp(r'"react-native"\s*:')) &&
        Directory(p.join(dir.path, 'android')).existsSync()) {
      return ProjectKind.REACT_NATIVE;
    }
    if (exists('capacitor.config.json') || exists('capacitor.config.ts') || exists('capacitor.config.js')) {
      return ProjectKind.CAPACITOR;
    }
    return ProjectKind.OTHER;
  }

  static bool _fileMatches(File file, RegExp pattern) {
    try {
      return file.existsSync() && pattern.hasMatch(file.readAsStringSync());
    } on Object {
      return false;
    }
  }
}
