import 'dart:io';

import 'package:remotetester_host/generated/remote_tester.pbenum.dart';
import 'package:remotetester_host/project/project_creator.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late TestHost host;
  late Directory root;
  late List<List<String>> flutterCalls;
  late ProjectCreator creator;

  setUp(() {
    host = TestHost();
    root = Directory('${host.home.path}/projects')..createSync(recursive: true);
    flutterCalls = [];
    creator = ProjectCreator(host.store, root, flutterCreate: (args) async {
      flutterCalls.add(args);
      final dir = Directory(args.last)..createSync(recursive: true);
      File('${dir.path}/pubspec.yaml').writeAsStringSync('name: app\nflutter:\n');
      return ProcessResult(0, 0, '', '');
    });
  });
  tearDown(() => host.dispose());

  test('a new empty folder and a new Flutter app are created inside the projects folder', () async {
    final empty = await creator.create('Notatki', ProjectTemplate.EMPTY_FOLDER);
    expect(empty.path, endsWith('Notatki'));
    expect(Directory('${root.path}/Notatki').existsSync(), isTrue);

    final app = await creator.create('Moja Apka 2', ProjectTemplate.FLUTTER_APP);
    expect(flutterCalls.single, containsAllInOrder(['create', '--project-name', 'moja_apka_2', '--platforms', 'android']));
    expect(app.kind, ProjectKind.FLUTTER);
    expect(app.profiles, isNotEmpty, reason: 'komendy z szablonów hosta');
    expect(host.store.projects().map((p) => p.name), containsAll(['Notatki', 'Moja Apka 2']));
  });

  test('a free folder made by someone else (e.g. an agent) can be assigned by name', () async {
    Directory('${root.path}/od-agenta').createSync();
    host.addProject('juz-projekt');
    Directory('${root.path}/.ukryty').createSync();
    expect(creator.availableFolders().map((f) => f.$1), ['od-agenta']);
    await creator.create('od-agenta', ProjectTemplate.EXISTING_FOLDER);
    expect(creator.availableFolders(), isEmpty);
  });

  test('names cannot leave the projects folder or reuse an existing one', () async {
    for (final bad in ['../poza', r'..\poza', 'a/b', '/etc', 'C:', '.ukryty', 'NUL', 'con.txt', 'kropka.', '']) {
      await expectLater(creator.create(bad, ProjectTemplate.EMPTY_FOLDER), throwsA(isA<ProjectCreationException>()), reason: bad);
    }
    Directory('${root.path}/zajety').createSync();
    await expectLater(creator.create('zajety', ProjectTemplate.EMPTY_FOLDER),
        throwsA(isA<ProjectCreationException>().having((e) => e.alreadyExists, 'alreadyExists', isTrue)));
    await expectLater(creator.create('nie-ma', ProjectTemplate.EXISTING_FOLDER), throwsA(isA<ProjectCreationException>()));
    expect(Directory('${host.home.path}/poza').existsSync(), isFalse);
  });

  test('a linked folder is not offered and cannot be assigned', () async {
    final outside = Directory.systemTemp.createTempSync('rt_outside_');
    addTearDown(() => outside.deleteSync(recursive: true));
    try {
      Link('${root.path}/link').createSync(outside.path);
    } on FileSystemException {
      return; // Windows bez uprawnień do dowiązań
    }
    expect(creator.availableFolders(), isEmpty);
    await expectLater(creator.create('link', ProjectTemplate.EXISTING_FOLDER), throwsA(isA<ProjectCreationException>()));
  });

  test('a failed flutter create leaves no folder behind', () async {
    final failing = ProjectCreator(host.store, root, flutterCreate: (args) async {
      Directory(args.last).createSync(recursive: true);
      return ProcessResult(0, 1, '', 'brak Fluttera');
    });
    await expectLater(failing.create('apka', ProjectTemplate.FLUTTER_APP), throwsA(isA<ProjectCreationException>()));
    expect(Directory('${root.path}/apka').existsSync(), isFalse);
    expect(host.store.projects(), isEmpty);
  });

  test('missing Flutter or an unwritable projects folder give a clear error, not an internal one', () async {
    final noFlutter = ProjectCreator(host.store, root, flutterCreate: (_) async => throw const ProcessException('flutter', []));
    await expectLater(noFlutter.create('Apka', ProjectTemplate.FLUTTER_APP), throwsA(isA<ProjectCreationException>()));

    // Katalog projektów zablokowany plikiem o tej samej nazwie — createSync rzuca FileSystemException.
    final blocked = File('${host.home.path}/zablokowany')..writeAsStringSync('x');
    final badRoot = ProjectCreator(host.store, Directory(blocked.path));
    await expectLater(badRoot.create('Nowy', ProjectTemplate.EMPTY_FOLDER), throwsA(isA<ProjectCreationException>()));
  });
}
