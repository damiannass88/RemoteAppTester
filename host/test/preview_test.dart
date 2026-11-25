import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:remotetester_host/build/operation_log.dart';
import 'package:remotetester_host/generated/remote_tester.pb.dart';
import 'package:remotetester_host/preview/preview_manager.dart';
import 'package:remotetester_host/preview/preview_proxy.dart';
import 'package:remotetester_host/preview/preview_recipe.dart';
import 'package:remotetester_host/security/tls_identity.dart';
import 'package:remotetester_host/server/kill_switch.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Mały serwer aplikacji „z projektu”: odpowiada ścieżką i ciasteczkami, echo WebSocket.
const _appServer = r'''
import 'dart:io';
Future<void> main(List<String> args) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, int.parse(args.first));
  print('listening');
  await for (final req in server) {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final ws = await WebSocketTransformer.upgrade(req);
      ws.listen((m) => ws.add('echo:$m'));
      continue;
    }
    if (req.uri.path == '/go') {
      req.response.statusCode = 302;
      req.response.headers.set('location', 'http://127.0.0.1:${args.first}/target');
      await req.response.close();
      continue;
    }
    final body = await req.fold<List<int>>([], (a, b) => a..addAll(b));
    req.response.headers.add('set-cookie', 'app=1; Path=/');
    req.response.write('${req.method} ${req.uri} cookie=${req.headers.value('cookie')} host=${req.headers.value('host')} body=${body.length}');
    await req.response.close();
  }
}
''';

void main() {
  group('recipes', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('rt_recipe_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('ASP.NET project one level down is found and bound to 127.0.0.1', () {
      Directory('${dir.path}/src/Shop').createSync(recursive: true);
      File('${dir.path}/src/Shop/Shop.csproj').writeAsStringSync('<Project Sdk="Microsoft.NET.Sdk.Web"></Project>');
      File('${dir.path}/Shop.sln').writeAsStringSync('');
      final r = detectPreviewRecipe(dir)!;
      expect(r.kind, 'ASP.NET');
      expect(r.command, contains('--project "src/Shop/Shop.csproj"'));
      expect(r.command, contains('--urls http://127.0.0.1:{port}'));
    });

    test('Node, Python, PHP and static sites are recognised', () {
      File('${dir.path}/package.json').writeAsStringSync('{"scripts":{"dev":"vite"},"devDependencies":{"vite":"5"}}');
      expect(detectPreviewRecipe(dir)!.kind, 'Vite');
      expect(detectPreviewRecipe(dir)!.prepare, 'npm install');
      File('${dir.path}/package.json').deleteSync();
      File('${dir.path}/manage.py').writeAsStringSync('');
      expect(detectPreviewRecipe(dir, windows: false)!.command, 'python3 manage.py runserver 127.0.0.1:{port}');
      File('${dir.path}/manage.py').deleteSync();
      File('${dir.path}/index.php').writeAsStringSync('');
      expect(detectPreviewRecipe(dir)!.kind, 'PHP');
      File('${dir.path}/index.php').deleteSync();
      Directory('${dir.path}/dist').createSync();
      File('${dir.path}/dist/index.html').writeAsStringSync('<h1>x</h1>');
      final r = detectPreviewRecipe(dir)!;
      expect(r.isStatic, isTrue);
      expect(r.staticFolder, 'dist');
    });

    test('a plain folder has no recipe', () {
      expect(detectPreviewRecipe(dir), isNull);
    });
  });

  group('proxy', () {
    late Directory dir;
    late Process app;
    late int appPort;
    late PreviewProxy proxy;
    const token = 'abc123';

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('rt_proxy_');
      File('${dir.path}/server.dart').writeAsStringSync(_appServer);
      appPort = await freeLocalPort();
      app = await Process.start(Platform.resolvedExecutable, ['${dir.path}/server.dart', '$appPort']);
      await app.stdout.transform(utf8.decoder).firstWhere((l) => l.contains('listening'));
      proxy = await PreviewProxy.start(
        address: InternetAddress.loopbackIPv4,
        port: 0,
        token: token,
        targetPort: appPort,
        secureCookie: false,
      );
    });
    tearDownAll(() async {
      await proxy.close();
      app.kill();
      await app.exitCode;
      dir.deleteSync(recursive: true);
    });

    Future<HttpClientResponse> get(String path, {String? cookie, String method = 'GET', List<int>? body}) async {
      final client = HttpClient();
      final req = await client.openUrl(method, Uri.parse('http://127.0.0.1:${proxy.port}$path'));
      req.followRedirects = false;
      if (cookie != null) req.headers.set('cookie', cookie);
      if (body != null) {
        req.contentLength = body.length;
        req.add(body);
      }
      final resp = await req.close();
      client.close();
      return resp;
    }

    test('without the token nothing reaches the app', () async {
      expect((await get('/')).statusCode, HttpStatus.forbidden);
      expect((await get('/?$previewTokenParam=wrong')).statusCode, HttpStatus.forbidden);
      expect((await get('/', cookie: '$previewCookieName=wrong')).statusCode, HttpStatus.forbidden);
    });

    test('the token becomes a cookie and is never passed to the app', () async {
      final first = await get('/page?x=1&$previewTokenParam=$token');
      expect(first.statusCode, HttpStatus.found);
      expect(first.headers.value('location'), '/page?x=1');
      expect(first.headers['set-cookie']!.single, startsWith('$previewCookieName=$token; Path=/; HttpOnly'));

      final page = await get('/page?x=1', cookie: '$previewCookieName=$token; theme=dark', method: 'POST', body: [1, 2, 3]);
      final text = await page.transform(utf8.decoder).join();
      expect(page.statusCode, 200);
      expect(text, 'POST /page?x=1 cookie=theme=dark host=127.0.0.1:$appPort body=3');
      expect(page.headers['set-cookie'], ['app=1; Path=/']);
    });

    test('redirects to the app address stay inside the proxy', () async {
      final r = await get('/go', cookie: '$previewCookieName=$token');
      expect(r.statusCode, 302);
      expect(r.headers.value('location'), '/target');
    });

    test('WebSockets are passed through with the session cookie', () async {
      await expectLater(WebSocket.connect('ws://127.0.0.1:${proxy.port}/ws'), throwsA(anything));
      final ws = await WebSocket.connect('ws://127.0.0.1:${proxy.port}/ws', headers: {'cookie': '$previewCookieName=$token'});
      ws.add('hi');
      expect(await ws.first, 'echo:hi');
      await ws.close();
    });
  });

  test('static site: files only from the site folder, SPA fallback to index.html', () async {
    final dir = Directory.systemTemp.createTempSync('rt_static_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/site').createSync();
    File('${dir.path}/site/index.html').writeAsStringSync('<h1>home</h1>');
    File('${dir.path}/site/app.js').writeAsStringSync('1');
    File('${dir.path}/secret.txt').writeAsStringSync('nope');
    final proxy = await PreviewProxy.start(
      address: InternetAddress.loopbackIPv4,
      port: 0,
      token: 't',
      staticRoot: Directory('${dir.path}/site'),
      secureCookie: false,
    );
    addTearDown(proxy.close);
    Future<(int, String, String?)> fetch(String path) async {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:${proxy.port}$path'));
      req.headers.set('cookie', '$previewCookieName=t');
      final r = await req.close();
      final body = await r.transform(utf8.decoder).join();
      client.close();
      return (r.statusCode, body, r.headers.contentType?.mimeType);
    }

    expect(await fetch('/'), (200, '<h1>home</h1>', 'text/html'));
    expect(await fetch('/app.js'), (200, '1', 'text/javascript'));
    expect(await fetch('/orders/7'), (200, '<h1>home</h1>', 'text/html'));
    expect((await fetch('/../secret.txt')).$1, isNot(200));
    expect((await fetch('/%2e%2e/secret.txt')).$1, isNot(200));
    expect((await fetch('/missing.png')).$1, 404);
  });

  group('manager', () {
    late TestHost host;
    late PreviewManager manager;
    late TlsIdentity tls;
    final killSwitch = KillSwitch();

    setUp(() {
      host = TestHost();
      tls = TlsIdentity.loadOrGenerate(
        certFile: File('${host.home.path}/config/tls_cert.pem'),
        keyFile: File('${host.home.path}/config/tls_key.pem'),
      );
      manager = PreviewManager(
        store: host.store,
        killSwitch: killSwitch,
        operationLog: OperationLog(File('${host.home.path}/logs/preview.log')),
        tailscaleAddress: () => InternetAddress.loopbackIPv4,
        settings: const PreviewSettings(firstPort: 47190, portCount: 2, tailscaleServe: false),
        tls: SecurityContext()
          ..useCertificateChainBytes(utf8.encode(tls.certificatePem))
          ..usePrivateKeyBytes(utf8.encode(tls.privateKeyPem)),
        scriptDir: Directory('${host.home.path}/tmp'),
      );
    });
    tearDown(() async {
      await manager.close();
      await host.dispose();
    });

    test('starts the project server, serves it over pinned HTTPS with the token, then stops it', () async {
      final project = host.addProject('web');
      File('${project.path}/server.dart').writeAsStringSync(_appServer);
      final exe = Platform.resolvedExecutable;
      project.previewCommand = '"$exe" server.dart {port}';
      host.store.saveOptions(project);

      final events = <PreviewEvent>[];
      final running = Completer<PreviewEvent>();
      final sub = manager.watch(host.store.byId(project.id)!, requester: 'phone').listen((e) {
        events.add(e);
        if (e.state == PreviewState.PREVIEW_RUNNING && !running.isCompleted) running.complete(e);
      });
      final ready = await running.future.timeout(const Duration(seconds: 60));
      expect(ready.pinnedTls, isTrue);
      expect(ready.url, startsWith('https://127.0.0.1:47190/?$previewTokenParam='));
      expect(events.map((e) => e.logLine), contains(contains('server.dart')));
      expect(manager.isRunning(project.id), isTrue);

      // Certyfikat hosta — klient akceptuje go wyłącznie po odcisku (jak telefon).
      final client = HttpClient()..badCertificateCallback = (cert, _, _) => true;
      final req = await client.getUrl(Uri.parse(ready.url));
      req.followRedirects = false;
      final first = await req.close();
      await first.drain<void>();
      expect(first.statusCode, HttpStatus.found);
      final cookie = first.headers['set-cookie']!.single.split(';').first;
      final page = await (await client.getUrl(Uri.parse('https://127.0.0.1:47190/hello'))
            ..headers.set('cookie', cookie))
          .close();
      expect(await page.transform(utf8.decoder).join(), startsWith('GET /hello'));
      client.close();

      // Zmiany od agenta: restart serwera na nowym porcie, potem „odśwież” dla telefonu.
      final firstPort = int.parse(RegExp(r'server\.dart (\d+)').firstMatch(events.map((e) => e.logLine).join('\n'))!.group(1)!);
      await manager.reload(project.id);
      await pumpEventQueue();
      expect(events.any((e) => e.reload), isTrue);
      expect(manager.isRunning(project.id), isTrue);
      final ports = RegExp(r'server\.dart (\d+)').allMatches(events.map((e) => e.logLine).join('\n')).map((m) => int.parse(m.group(1)!)).toList();
      expect(ports, hasLength(2));
      expect(await previewServerResponds(firstPort), isFalse, reason: 'stary serwer zatrzymany');
      final client2 = HttpClient()..badCertificateCallback = (cert, _, _) => true;
      final after = await (await client2.getUrl(Uri.parse('https://127.0.0.1:47190/again'))..headers.set('cookie', cookie)).close();
      expect(await after.transform(utf8.decoder).join(), startsWith('GET /again'));
      client2.close();

      // Zgłoszenie z działającego podglądu zawiera log serwera.
      manager.reportIssue(host.store.byId(project.id)!, PreviewIssue(note: 'x'), deviceName: 'Pixel');
      expect(File('${project.path}/$previewFeedbackFileName').readAsStringSync(), contains('Log serwera'));

      // Drugi telefon dołącza do tego samego podglądu.
      final again = await manager.watch(host.store.byId(project.id)!, requester: 'phone2').firstWhere((e) => e.url.isNotEmpty);
      expect(again.url, ready.url);

      expect(await manager.stop(project.id), isTrue);
      await sub.asFuture<void>().timeout(const Duration(seconds: 20));
      expect(events.last.state, PreviewState.PREVIEW_STOPPED);
      expect(manager.isRunning(project.id), isFalse);
      // Proces serwera zatrzymany razem z procesami potomnymi.
      expect(await previewServerResponds(int.parse(RegExp(r'server\.dart (\d+)').firstMatch(events.map((e) => e.logLine).join('\n'))!.group(1)!)), isFalse);
    });

    test('a server that exits reports FAILED with its log', () async {
      final project = host.addProject('broken');
      project.previewCommand = '"${Platform.resolvedExecutable}" nonexistent.dart {port}';
      host.store.saveOptions(project);
      final last = await manager.watch(host.store.byId(project.id)!, requester: 'phone').last.timeout(const Duration(seconds: 60));
      expect(last.state, PreviewState.PREVIEW_FAILED);
      expect(manager.isRunning(project.id), isFalse);
    });

    test('a project without a web app cannot be previewed', () {
      final project = host.addProject('plain');
      File('${project.path}/pubspec.yaml').deleteSync();
      expect(() => manager.watch(project, requester: 'phone'), throwsStateError);
    });

    test('issue reports go to the feedback file, newest first, without the token', () {
      final project = host.addProject('fb');
      manager.reportIssue(project, PreviewIssue(note: 'Przycisk nie działa', pageUrl: '/cart?$previewTokenParam=deadbeef', console: ['[error] boom']),
          deviceName: 'Pixel', now: DateTime(2026, 1, 1, 10));
      manager.reportIssue(project, PreviewIssue(note: 'Drugi', pageUrl: '/'), deviceName: 'Pixel', now: DateTime(2026, 1, 1, 11));
      final text = File('${project.path}/$previewFeedbackFileName').readAsStringSync();
      expect(text.indexOf('Drugi'), lessThan(text.indexOf('Przycisk nie działa')));
      expect(text, contains('`/cart`'));
      expect(text, contains('[error] boom'));
      expect(text, isNot(contains('deadbeef')));
    });
  });
}
