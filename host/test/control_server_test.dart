import 'dart:convert';
import 'dart:io';

import 'package:remotetester_host/build/build_engine.dart';
import 'package:remotetester_host/generated/remote_tester.pb.dart';
import 'package:remotetester_host/server/control_server.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:remotetester_host/store/project_store.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Lokalny kanał `rt b` i okna aplikacji — bezpieczeństwo (docs/SECURITY.md).
void main() {
  late TestHost host;
  late ProjectRecord project;
  late ControlServer server;
  late KillSwitch killSwitch;
  var shown = 0;
  const token = 'tajny-token-testowy';

  setUp(() async {
    host = TestHost();
    project = host.addProject('app');
    shown = 0;
    server = await ControlServer.start(
      port: 0,
      token: token,
      store: host.store,
      engine: host.engine,
      killSwitch: killSwitch = KillSwitch(),
      onShow: () => shown++,
    );
  });

  tearDown(() async {
    await server.close();
    await host.dispose();
  });

  Future<(int, Map<String, dynamic>)> post(String path, Map<String, Object?> body,
      {String? auth, String? origin}) async {
    final client = HttpClient();
    try {
      final request = await client.post('127.0.0.1', server.port, path);
      if (auth != null) request.headers.set(HttpHeaders.authorizationHeader, auth);
      if (origin != null) request.headers.set('origin', origin);
      request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  test('rejects requests without the token or with a wrong one', () async {
    expect((await post('/v1/build', {'path': project.path})).$1, HttpStatus.unauthorized);
    expect((await post('/v1/build', {'path': project.path}, auth: 'Bearer zly')).$1, HttpStatus.unauthorized);
    expect((await post('/v1/show', {}, auth: 'Bearer zly')).$1, HttpStatus.unauthorized);
    expect(shown, 0);
  });

  test('rejects browser requests (Origin header) even with the token', () async {
    final r = await post('/v1/build', {'path': project.path}, auth: 'Bearer $token', origin: 'https://evil.example');
    expect(r.$1, HttpStatus.forbidden);
  });

  test('rejects a folder that is not assigned to RemoteAppTester', () async {
    final r = await post('/v1/build', {'path': host.home.path}, auth: 'Bearer $token');
    expect(r.$1, HttpStatus.notFound);
  });

  test('respects the per-project "rt b" option and the kill-switch', () async {
    project.localTrigger = false;
    host.store.saveOptions(project);
    expect((await post('/v1/build', {'path': project.path}, auth: 'Bearer $token')).$1, HttpStatus.forbidden);
    project.localTrigger = true;
    host.store.saveOptions(project);
    killSwitch.pause();
    expect((await post('/v1/build', {'path': project.path}, auth: 'Bearer $token')).$1, HttpStatus.serviceUnavailable);
  });

  test('builds a subfolder of a project with the stored commands, ignoring anything in the request', () async {
    final lib = Directory('${project.path}${Platform.pathSeparator}lib')..createSync();
    final r = await post('/v1/build', {'path': lib.path, 'run': 'evil', 'profile': 'evil'}, auth: 'Bearer $token');
    expect(r.$1, HttpStatus.ok);
    expect(r.$2['method'], 'Debug');
    final record = host.engine.byId(r.$2['build_id'] as String)!;
    expect(record.requester, localRequester);
    await record.watch().drain<void>();
    expect(record.phase, BuildPhase.DONE);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('show asks the running app to show its window', () async {
    expect((await post('/v1/show', {}, auth: 'Bearer $token')).$1, HttpStatus.ok);
    expect(shown, 1);
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals('abc', 'abc'), isTrue);
    expect(constantTimeEquals('abc', 'abd'), isFalse);
    expect(constantTimeEquals('abc', 'abcd'), isFalse);
  });
}
