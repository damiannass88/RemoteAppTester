import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:remotetester_host/project/artifact_finder.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('artifact_finder_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File touch(String relative, {DateTime? modified}) {
    final f = File('${dir.path}/$relative')..createSync(recursive: true);
    f.writeAsStringSync('x');
    if (modified != null) f.setLastModifiedSync(modified);
    return f;
  }

  test('exact path', () {
    final apk = touch('build/app/outputs/flutter-apk/app-debug.apk');
    expect(p.equals(findArtifact(dir, 'build/app/outputs/flutter-apk/app-debug.apk')!.path, apk.path), isTrue);
  });

  test('** matches any depth and the newest file wins', () {
    touch('build/a/old.apk', modified: DateTime(2020));
    final newer = touch('build/b/c/new.apk', modified: DateTime(2025));
    expect(p.equals(findArtifact(dir, 'build/**/*.apk')!.path, newer.path), isTrue);
  });

  test('unsigned release APKs are skipped', () {
    touch('app/build/outputs/apk/release/app-release-unsigned.apk');
    expect(findArtifact(dir, 'app/build/outputs/apk/release/*.apk'), isNull);
  });

  test('patterns escaping the project folder are rejected', () {
    expect(() => findArtifact(dir, '../*.apk'), throwsA(isA<ProfileException>()));
    expect(() => findArtifact(dir, '/etc/*.apk'), throwsA(isA<ProfileException>()));
    expect(() => findArtifact(dir, 'build/**/*.exe'), throwsA(isA<ProfileException>()));
  });

  test('no match returns null', () {
    expect(findArtifact(dir, 'build/**/*.apk'), isNull);
  });
}
