import 'dart:io';

import 'package:remotetester_host/generated/remote_tester.pbenum.dart';
import 'package:remotetester_host/project/agent_guide.dart';
import 'package:remotetester_host/project/build_profile.dart';
import 'package:remotetester_host/store/project_store.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late TestHost host;

  setUp(() => host = TestHost());
  tearDown(() => host.dispose());

  Directory newFolder(String name, {String pubspec = 'name: x\nflutter:\n'}) {
    final dir = Directory('${host.home.path}/projects/$name')..createSync(recursive: true);
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    return dir;
  }

  group('przypisywanie folderów', () {
    test('detects Flutter, fills template commands and writes REMOTEAPPTESTER.md', () {
      final record = host.store.add(newFolder('apka'));
      expect(record.kind, ProjectKind.FLUTTER);
      expect(record.profiles.map((p) => p.name), ['Debug', 'Release']);
      expect(record.profile()!.steps.last.run, contains('flutter build apk --debug'));
      final guide = agentGuideFile(record.directory);
      expect(guide.existsSync(), isTrue);
      expect(guide.readAsStringSync(), contains('flutter build apk --debug'));
      expect(host.store.guideState(record).status, GuideStatus.inSync);
    });

    test('the same folder cannot be added twice', () {
      final dir = newFolder('apka');
      host.store.add(dir);
      expect(() => host.store.add(dir), throwsA(isA<ProjectStoreException>()));
    });

    test('byPath maps subfolders to the project (rt b from inside the project)', () {
      final record = host.store.add(newFolder('apka'));
      final lib = Directory('${record.path}/lib/src')..createSync(recursive: true);
      expect(host.store.byPath(lib.path)?.id, record.id);
      expect(host.store.byPath(host.home.path), isNull);
    });

    test('an existing REMOTEAPPTESTER.md is kept and becomes a proposal, never applied silently', () {
      final dir = newFolder('apka');
      File('${dir.path}/REMOTEAPPTESTER.md').writeAsStringSync(renderAgentGuide('apka', [fakeProfile(name: 'Agent')]));
      final record = host.store.add(dir);
      expect(record.profiles.map((p) => p.name), isNot(contains('Agent')));
      final state = host.store.guideState(record);
      expect(state.status, GuideStatus.proposal);
      expect(state.profiles.single.name, 'Agent');
    });
  });

  group('propozycje agenta w REMOTEAPPTESTER.md', () {
    test('import applies the proposal; dismiss stops asking about the same content', () {
      final record = host.store.add(newFolder('apka'));
      final guide = agentGuideFile(record.directory);
      guide.writeAsStringSync(renderAgentGuide('apka', [fakeProfile(name: 'Od agenta')]));

      final state = host.store.guideState(record);
      expect(state.status, GuideStatus.proposal);
      host.store.importGuide(record.id, state);
      final updated = host.store.byId(record.id)!;
      expect(updated.profiles.single.name, 'Od agenta');
      expect(host.store.guideState(updated).status, GuideStatus.inSync);

      guide.writeAsStringSync(renderAgentGuide('apka', [fakeProfile(name: 'Inny')]));
      final second = host.store.guideState(updated);
      host.store.dismissGuide(record.id, second);
      expect(host.store.guideState(host.store.byId(record.id)!).status, GuideStatus.inSync);
      expect(host.store.byId(record.id)!.profiles.single.name, 'Od agenta');
    });

    test('an invalid block is reported, not imported', () {
      final record = host.store.add(newFolder('apka'));
      agentGuideFile(record.directory).writeAsStringSync(
          '<!-- remoteapptester:begin -->\n```yaml\nprofiles:\n  - name: X\n    steps: []\n    artifact: ../x.apk\n```\n<!-- remoteapptester:end -->');
      expect(host.store.guideState(record).status, GuideStatus.invalid);
    });

    test('parseGuideBlock rejects unknown fields', () {
      expect(
        () => parseGuideBlock('profiles:\n  - name: A\n    steps:\n      - {name: a, run: b, shell: x}\n    artifact: a.apk\n'),
        throwsA(isA<ProfileException>()),
      );
      expect(() => parseGuideBlock('command: rm -rf /\nprofiles: []\n'), throwsA(isA<ProfileException>()));
    });
  });

  group('walidacja komend', () {
    test('multi-line commands, escaping artifact paths and empty profiles are rejected', () {
      final record = host.store.add(newFolder('apka'));
      expect(() => host.store.saveProfiles(record.id, [fakeProfile(steps: const [BuildStep('a', 'echo a\necho b')])]),
          throwsA(isA<ProfileException>()));
      expect(
          () => host.store.saveProfiles(
              record.id, [BuildProfile(name: 'X', steps: const [BuildStep('a', 'echo')], artifact: '../../x.apk')]),
          throwsA(isA<ProfileException>()));
      expect(
          () => host.store.saveProfiles(
              record.id, [BuildProfile(name: 'X', steps: const [BuildStep('a', 'echo')], artifact: r'C:\x.apk')]),
          throwsA(isA<ProfileException>()));
      expect(() => host.store.saveProfiles(record.id, []), throwsA(isA<ProfileException>()));
    });

    test('saving commands from the app refreshes REMOTEAPPTESTER.md for agents', () {
      final record = host.store.add(newFolder('apka'));
      host.store.saveProfiles(record.id, [fakeProfile(name: 'Nowy')]);
      expect(agentGuideFile(record.directory).readAsStringSync(), contains('Nowy'));
      expect(host.store.guideState(host.store.byId(record.id)!).status, GuideStatus.inSync);
    });
  });

  group('szyfrowanie bazy', () {
    test('the database file does not contain commands in plain text', () {
      final record = host.store.add(newFolder('apka'));
      host.store.saveProfiles(record.id, [fakeProfile(steps: const [BuildStep('a', 'echo TAJNA_KOMENDA_123')])]);
      host.store.close();
      final raw = File('${host.home.path}/$projectDbPath').readAsBytesSync();
      expect(String.fromCharCodes(raw).contains('TAJNA_KOMENDA_123'), isFalse);
      host.store = ProjectStore.open(home: host.home.path);
    });

    test('opening with a different key fails loudly instead of returning data', () {
      host.store.add(newFolder('apka'));
      host.store.close();
      File('${host.home.path}/$projectDbKeyPath').deleteSync(); // nowy klucz przy otwarciu
      expect(() => ProjectStore.open(home: host.home.path), throwsA(isA<ProjectStoreException>()));
      // sprzątanie: baza z nowym kluczem
      File('${host.home.path}/$projectDbPath').deleteSync();
      for (final suffix in ['-wal', '-shm']) {
        final f = File('${host.home.path}/$projectDbPath$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      host.store = ProjectStore.open(home: host.home.path);
    });
  });

  test('options are saved per project', () {
    final record = host.store.add(newFolder('apka'));
    record
      ..install = InstallPolicy.ask
      ..launch = false
      ..targets = ['tel-1']
      ..phoneTrigger = false;
    host.store.saveOptions(record);
    final loaded = host.store.byId(record.id)!;
    expect(loaded.install, InstallPolicy.ask);
    expect(loaded.launch, isFalse);
    expect(loaded.deliversTo('tel-1'), isTrue);
    expect(loaded.deliversTo('tel-2'), isFalse);
    expect(loaded.phoneTrigger, isFalse);
  });
}
