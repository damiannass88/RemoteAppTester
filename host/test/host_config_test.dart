import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:remotetester_host/config/host_config.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('rt_config_');
    path = p.join(dir.path, 'host-config.yaml');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('nowa konfiguracja używa portu spoza zakresu dynamicznego Windows', () {
    File(path).writeAsStringSync(HostConfig.render(projectsRoot: dir.path, port: defaultListenPort));
    final config = HostConfig.load(path);
    expect(config.listenPort, lessThan(49152));
    expect(config.controlPort, lessThan(49152));
  });

  test('stary domyślny port 50051 przechodzi na nowy (Windows)', () {
    File(path).writeAsStringSync(HostConfig.render(projectsRoot: dir.path, port: legacyDefaultListenPort));
    expect(HostConfig.migrateLegacyDefaultPort(path, windows: true), isTrue);
    final config = HostConfig.load(path);
    expect(config.listenPort, defaultListenPort);
    expect(config.controlPort, defaultListenPort + 1);
    expect(File(path).readAsStringSync(), contains('# control_port: ${defaultListenPort + 1}'));
    expect(HostConfig.migrateLegacyDefaultPort(path, windows: true), isFalse);
  });

  test('jawnie ustawiony control_port 50052 też przechodzi', () {
    File(path).writeAsStringSync('projects_root: "${dir.path.replaceAll(r'\', r'\\')}"\n'
        'listen_port: 50051\ncontrol_port: 50052\n');
    HostConfig.migrateLegacyDefaultPort(path, windows: true);
    final config = HostConfig.load(path);
    expect((config.listenPort, config.controlPort), (defaultListenPort, defaultListenPort + 1));
  });

  test('własny port i Linux zostają bez zmian', () {
    File(path).writeAsStringSync(HostConfig.render(projectsRoot: dir.path, port: 60000));
    expect(HostConfig.migrateLegacyDefaultPort(path, windows: true), isFalse);
    File(path).writeAsStringSync(HostConfig.render(projectsRoot: dir.path, port: legacyDefaultListenPort));
    expect(HostConfig.migrateLegacyDefaultPort(path, windows: false), isFalse);
    expect(HostConfig.load(path).listenPort, legacyDefaultListenPort);
  });
}
