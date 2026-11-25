import 'dart:io';

import 'package:remotetester_host/cli/remotetester_cli.dart';
import 'package:remotetester_host/i18n.dart';
import 'package:remotetester_host/cli/doctor.dart';
import 'package:remotetester_host/cli/terminal_qr.dart';
import 'package:remotetester_host/config/host_config.dart';
import 'package:test/test.dart';
import 'package:qr/qr.dart';

/// CLI hosta (`bin/remoteapptester.dart`).
void main() {
  // Teksty w asercjach są po polsku.
  setUpAll(() => setHostLanguage('pl'));

  group('renderQrForTerminal', () {
    const data = 'remoteapptester://pair?host=100.64.0.1&port=50051&device_id=abc&secret=xyz&cert_fp=00&name=T';

    test('draws a square code: every line equally wide, two modules per line', () {
      final modules = QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L).moduleCount;
      final lines = renderQrForTerminal(data).trimRight().split('\n');

      final size = modules + 4; // 2 moduły marginesu z każdej strony
      expect(lines.length, (size + 1) ~/ 2);
      expect(lines.every((l) => l.length == size), isTrue);
    });

    test('the quiet zone is light: drawn as full blocks on a dark terminal', () {
      final first = renderQrForTerminal(data).split('\n').first;
      expect(first, isNot(contains(' ')));
    });

    test('invert swaps light and dark', () {
      final normal = renderQrForTerminal(data);
      final inverted = renderQrForTerminal(data, invert: true);
      expect(inverted, isNot(equals(normal)));
      expect(inverted.split('\n').first.trim(), isEmpty);
    });
  });

  group('remoteapptester init', () {
    late Directory home;
    late Directory originalCwd;

    setUp(() {
      originalCwd = Directory.current;
      home = Directory.systemTemp.createTempSync('remotetester_cli_test_');
    });
    tearDown(() {
      Directory.current = originalCwd;
      if (home.existsSync()) home.deleteSync(recursive: true);
    });

    test('creates a config that HostConfig can load, and the projects root', () async {
      final projects = '${home.path}${Platform.pathSeparator}projects';

      final code = await runCli(['--home', home.path, 'init', '--projects-root', projects, '--port', '50123']);

      expect(code, 0);
      final config = HostConfig.load('config/host-config.yaml');
      expect(config.listenPort, 50123);
      expect(config.projectsRoot.path, projects);
      expect(config.maxParallelBuilds, 2);
    });

    test('never overwrites an existing config', () async {
      final projects = '${home.path}${Platform.pathSeparator}projects';
      await runCli(['--home', home.path, 'init', '--projects-root', projects, '--port', '50123']);

      await runCli(['--home', home.path, 'init', '--projects-root', projects, '--port', '50999']);

      expect(HostConfig.load('config/host-config.yaml').listenPort, 50123);
    });

    test('rejects an invalid port', () async {
      final code = await runCli(['--home', home.path, 'init', '--projects-root', home.path, '--port', '70000']);
      expect(code, 64);
      expect(File('config/host-config.yaml').existsSync(), isFalse);
    });
  });

  group('parseJavaMajorVersion (doctor)', () {
    test('modern OpenJDK', () => expect(parseJavaMajorVersion('openjdk version "17.0.20.1" 2026-08-18'), 17));
    test('Java 21', () => expect(parseJavaMajorVersion('openjdk version "21" 2023-09-19'), 21));
    test('legacy 1.8 scheme means Java 8', () => expect(parseJavaMajorVersion('java version "1.8.0_451"'), 8));
    test('unreadable output', () => expect(parseJavaMajorVersion('command not found'), 0));
  });

  group('hasInboundTcpAllowRuleForPort (doctor, Windows Firewall)', () {
    String rule({
      String enabled = 'Yes',
      String dir = 'In',
      String protocol = 'TCP',
      String? localPort = '50051',
      String action = 'Allow',
      String? program,
    }) {
      final b = StringBuffer()
        ..writeln('Rule Name:                            R')
        ..writeln('----------------------------------------------------------------------')
        ..writeln('Enabled:                              $enabled')
        ..writeln('Direction:                            $dir')
        ..writeln('Protocol:                             $protocol');
      if (localPort != null) b.writeln('LocalPort:                            $localPort');
      if (program != null) b.writeln('Program:                              $program');
      b
        ..writeln('Action:                               $action')
        ..writeln();
      return b.toString();
    }

    test('finds the documented host rule (port-specific, any program)', () {
      expect(hasInboundTcpAllowRuleForPort(rule(), 50051), isTrue);
    });

    test('port lists and ranges', () {
      expect(hasInboundTcpAllowRuleForPort(rule(localPort: '80,50051'), 50051), isTrue);
      expect(hasInboundTcpAllowRuleForPort(rule(localPort: '50000-50100'), 50051), isTrue);
      expect(hasInboundTcpAllowRuleForPort(rule(localPort: '50052-50100'), 50051), isFalse);
    });

    test('ignores disabled, blocking, outbound and UDP rules', () {
      expect(hasInboundTcpAllowRuleForPort(rule(enabled: 'No'), 50051), isFalse);
      expect(hasInboundTcpAllowRuleForPort(rule(action: 'Block'), 50051), isFalse);
      expect(hasInboundTcpAllowRuleForPort(rule(dir: 'Out'), 50051), isFalse);
      expect(hasInboundTcpAllowRuleForPort(rule(protocol: 'UDP'), 50051), isFalse);
    });

    // Sytuacja z pierwszego testu z prawdziwym telefonem (2026-09-28): 25 reguł
    // "TCP, dowolny port" — każda dla innego programu. Żadna nie wpuszcza hosta.
    test("an any-port rule for ANOTHER program does not count", () {
      final output = rule(localPort: 'Any', program: r'C:\Program Files\Microsoft\Teams\ms-teams.exe') +
          rule(localPort: 'Any', program: r'C:\Program Files (x86)\Steam\Steam.exe');
      expect(hasInboundTcpAllowRuleForPort(output, 50051), isFalse);
    });

    test("an any-port rule for the host's own executable counts", () {
      final output = rule(localPort: 'Any', program: r'C:\Program Files\RemoteAppTester\remoteapptester.exe');
      expect(hasInboundTcpAllowRuleForPort(output, 50051), isTrue);
    });
  });
}
