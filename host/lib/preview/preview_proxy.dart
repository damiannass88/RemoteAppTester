import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

/// Parametr adresu z jednorazowym tokenem (telefon dostaje go w StartPreview).
const previewTokenParam = 'rt_preview_token';

/// Ciasteczko sesji podglądu — ustawiane po poprawnym tokenie, niewidoczne dla aplikacji.
const previewCookieName = '__rt_preview';

/// Nagłówki „hop-by-hop” — dotyczą jednego połączenia, nie przechodzą przez proxy.
const _hopByHop = {
  'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization', //
  'te', 'trailer', 'transfer-encoding', 'upgrade', 'host', 'content-length',
};

/// Losowy token (256 bitów, hex).
String randomPreviewToken() {
  final r = Random.secure();
  return List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Proxy podglądu: jedyna droga do serwera deweloperskiego (który słucha tylko na
/// 127.0.0.1). Wpuszcza wyłącznie z tokenem z RemoteAppTestera — w adresie przy
/// pierwszym wejściu, potem w ciasteczku HttpOnly. Przekazuje HTTP i WebSockety
/// (hot reload Vite, Blazor/SignalR). Bez [targetPort] serwuje pliki z [staticRoot].
class PreviewProxy {
  PreviewProxy._(this._server, this.token, this.targetPort, this.staticRoot, this.onActivity, this.secureCookie);

  final HttpServer _server;
  final String token;
  /// Port serwera aplikacji — zmienia się przy restarcie serwera (np. po zmianach agenta).
  int? targetPort;
  final Directory? staticRoot;
  final void Function() onActivity;
  final bool secureCookie;
  final _client = HttpClient()
    ..autoUncompress = false
    ..idleTimeout = const Duration(seconds: 15);

  int get port => _server.port;

  static Future<PreviewProxy> start({
    required InternetAddress address,
    required int port,
    required String token,
    int? targetPort,
    Directory? staticRoot,
    SecurityContext? tls,
    bool secureCookie = true,
    void Function()? onActivity,
  }) async {
    assert((targetPort == null) != (staticRoot == null));
    final server = tls == null ? await HttpServer.bind(address, port) : await HttpServer.bindSecure(address, port, tls);
    // Domyślne nagłówki Dart (X-Frame-Options itp.) zmieniałyby zachowanie aplikacji.
    server.defaultResponseHeaders.clear();
    server.autoCompress = false;
    final proxy = PreviewProxy._(server, token, targetPort, staticRoot, onActivity ?? () {}, secureCookie);
    server.listen((req) => unawaited(proxy._handle(req)), onError: (_) {});
    return proxy;
  }

  Future<void> close() async {
    _client.close(force: true);
    await _server.close(force: true);
  }

  Future<void> _handle(HttpRequest req) async {
    onActivity();
    try {
      final offered = req.uri.queryParameters[previewTokenParam];
      if (offered != null) {
        if (!_same(offered, token)) return await _deny(req);
        final query = Map.of(req.uri.queryParametersAll)..remove(previewTokenParam);
        final clean = Uri(path: req.uri.path.isEmpty ? '/' : req.uri.path, queryParameters: query.isEmpty ? null : query);
        req.response
          ..statusCode = HttpStatus.found
          ..headers.add('set-cookie', '$previewCookieName=$token; Path=/; HttpOnly; SameSite=Lax${secureCookie ? '; Secure' : ''}')
          ..headers.set('location', clean.toString())
          ..headers.set('cache-control', 'no-store');
        await req.response.close();
        return;
      }
      if (!_hasSessionCookie(req)) return await _deny(req);
      if (staticRoot != null) return await _serveStatic(req, staticRoot!);
      if (WebSocketTransformer.isUpgradeRequest(req)) return await _proxyWebSocket(req);
      await _proxyHttp(req);
    } on Object {
      try {
        req.response.statusCode = HttpStatus.badGateway;
        req.response.headers.contentType = ContentType.text;
        req.response.write('RemoteAppTester: serwer podglądu nie odpowiada (może się jeszcze uruchamia).');
        await req.response.close();
      } on Object {
        // Nagłówki już wysłane albo połączenie zerwane — nic więcej nie zrobimy.
      }
    }
  }

  static bool _same(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  bool _hasSessionCookie(HttpRequest req) {
    for (final header in req.headers['cookie'] ?? const <String>[]) {
      for (final part in header.split(';')) {
        final i = part.indexOf('=');
        if (i > 0 && part.substring(0, i).trim() == previewCookieName && _same(part.substring(i + 1).trim(), token)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Ciasteczka aplikacji bez ciasteczka podglądu (serwer aplikacji go nie widzi).
  static String? _appCookies(HttpRequest req) {
    final parts = [
      for (final header in req.headers['cookie'] ?? const <String>[])
        for (final part in header.split(';'))
          if (part.trim().isNotEmpty && !part.trim().startsWith('$previewCookieName=')) part.trim(),
    ];
    return parts.isEmpty ? null : parts.join('; ');
  }

  Future<void> _deny(HttpRequest req) async {
    req.response
      ..statusCode = HttpStatus.forbidden
      ..headers.contentType = ContentType.html
      ..write('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
          '<p style="font-family:sans-serif">Podgląd RemoteAppTester — otwórz go z aplikacji RemoteAppTester na telefonie.</p>');
    await req.response.close();
  }

  String get _origin => 'http://127.0.0.1:$targetPort';

  Future<void> _proxyHttp(HttpRequest req) async {
    final target = Uri.parse('$_origin${req.uri}');
    final out = await _client.openUrl(req.method, target);
    out.followRedirects = false;
    out.persistentConnection = true;
    req.headers.forEach((name, values) {
      if (_hopByHop.contains(name) || name == 'cookie') return;
      for (final v in values) {
        out.headers.add(name, name == 'origin' || name == 'referer' ? _toUpstream(name, v) : v);
      }
    });
    final cookies = _appCookies(req);
    if (cookies != null) out.headers.set('cookie', cookies);
    out.headers.set('host', '127.0.0.1:$targetPort');
    out.headers.set('x-forwarded-proto', secureCookie ? 'https' : 'http');
    final forwardedHost = req.headers.value('host');
    if (forwardedHost != null) out.headers.set('x-forwarded-host', forwardedHost);
    if (req.contentLength >= 0) {
      out.contentLength = req.contentLength;
    } else if (req.headers.chunkedTransferEncoding) {
      out.headers.chunkedTransferEncoding = true;
    } else {
      out.contentLength = 0;
    }
    await out.addStream(req);
    final resp = await out.close();

    final res = req.response;
    res.statusCode = resp.statusCode;
    res.reasonPhrase = resp.reasonPhrase;
    res.headers.clear();
    resp.headers.forEach((name, values) {
      if (_hopByHop.contains(name)) return;
      for (final v in values) {
        res.headers.add(name, name == 'location' ? _fromUpstream(v) : v, preserveHeaderCase: true);
      }
    });
    final noBody = req.method == 'HEAD' || resp.statusCode == HttpStatus.notModified || resp.statusCode == HttpStatus.noContent;
    if (noBody) {
      await resp.drain<void>();
      res.contentLength = 0;
      await res.close();
      return;
    }
    if (resp.contentLength >= 0) {
      res.contentLength = resp.contentLength;
    } else {
      res.headers.chunkedTransferEncoding = true;
    }
    // Strumień po kawałku (SSE, długie odpowiedzi) — bez buforowania całości.
    res.bufferOutput = false;
    await res.addStream(resp);
    await res.close();
  }

  /// `http://127.0.0.1:<port>/x` w przekierowaniu aplikacji → `/x` (zostaje w proxy).
  String _fromUpstream(String location) {
    for (final origin in [_origin, 'http://localhost:$targetPort']) {
      if (location.startsWith(origin)) {
        final rest = location.substring(origin.length);
        return rest.isEmpty ? '/' : rest;
      }
    }
    return location;
  }

  /// Origin/Referer telefonu → adres serwera aplikacji (sprawdzanie CORS, Vite, antiforgery).
  String _toUpstream(String name, String value) {
    if (name == 'origin') return _origin;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme) return value;
    return uri.replace(scheme: 'http', host: '127.0.0.1', port: targetPort).toString();
  }

  Future<void> _proxyWebSocket(HttpRequest req) async {
    final protocols = [
      for (final h in req.headers['sec-websocket-protocol'] ?? const <String>[])
        for (final s in h.split(','))
          if (s.trim().isNotEmpty) s.trim(),
    ];
    final cookies = _appCookies(req);
    final upstream = await WebSocket.connect(
      'ws://127.0.0.1:$targetPort${req.uri}',
      protocols: protocols.isEmpty ? null : protocols,
      headers: {
        'origin': _origin,
        'cookie': ?cookies,
      },
    );
    final socket = await WebSocketTransformer.upgrade(
      req,
      protocolSelector: protocols.isEmpty ? null : (_) => upstream.protocol ?? protocols.first,
    );
    upstream.listen((m) {
      onActivity();
      socket.add(m);
    }, onDone: () => _closeLike(socket, upstream), onError: (_) => socket.close());
    socket.listen((m) {
      onActivity();
      upstream.add(m);
    }, onDone: () => _closeLike(upstream, socket), onError: (_) => upstream.close());
  }

  /// Zamyka [target] tym samym kodem co [source] — kodów zarezerwowanych (1005 „brak kodu”,
  /// 1006 „zerwane połączenie”, 1015 TLS) nie wolno wysłać, wtedy zamykamy bez kodu.
  static Future<void> _closeLike(WebSocket target, WebSocket source) {
    final code = source.closeCode;
    if (code == null || code == 1005 || code == 1006 || code == 1015) return target.close();
    return target.close(code, source.closeReason);
  }

  static const _types = {
    '.html': 'text/html; charset=utf-8', '.htm': 'text/html; charset=utf-8', //
    '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8', '.json': 'application/json', '.map': 'application/json',
    '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
    '.gif': 'image/gif', '.webp': 'image/webp', '.ico': 'image/x-icon', '.avif': 'image/avif',
    '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.otf': 'font/otf',
    '.wasm': 'application/wasm', '.txt': 'text/plain; charset=utf-8', '.xml': 'application/xml',
    '.webmanifest': 'application/manifest+json', '.mp4': 'video/mp4', '.webm': 'video/webm', '.mp3': 'audio/mpeg',
  };

  /// Pliki wyłącznie z [root] (bez wychodzenia ścieżką i bez dowiązań na zewnątrz).
  /// Brak pliku bez rozszerzenia → `index.html` (aplikacje SPA z routingiem).
  Future<void> _serveStatic(HttpRequest req, Directory root) async {
    final res = req.response;
    if (req.method != 'GET' && req.method != 'HEAD') {
      res.statusCode = HttpStatus.methodNotAllowed;
      await res.close();
      return;
    }
    final base = root.resolveSymbolicLinksSync();
    final segments = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.any((s) => s == '..' || s.contains(r'\') || s.contains(':'))) {
      res.statusCode = HttpStatus.badRequest;
      await res.close();
      return;
    }
    File? file;
    var candidate = p.joinAll([base, ...segments]);
    if (Directory(candidate).existsSync()) candidate = p.join(candidate, 'index.html');
    if (File(candidate).existsSync()) {
      final real = File(candidate).resolveSymbolicLinksSync();
      if (p.isWithin(base, real)) file = File(real);
    } else if (p.extension(candidate).isEmpty) {
      final index = File(p.join(base, 'index.html'));
      if (index.existsSync()) file = index;
    }
    if (file == null) {
      res.statusCode = HttpStatus.notFound;
      res.headers.contentType = ContentType.text;
      res.write('404');
      await res.close();
      return;
    }
    res.headers.set('content-type', _types[p.extension(file.path).toLowerCase()] ?? 'application/octet-stream');
    res.headers.set('cache-control', 'no-cache');
    res.contentLength = file.lengthSync();
    if (req.method == 'HEAD') {
      await res.close();
      return;
    }
    await res.addStream(file.openRead());
    await res.close();
  }
}

/// Zwięzły zapis błędu na potrzeby logu podglądu.
String describePreviewError(Object e) => e is SocketException ? (e.osError?.message ?? e.message) : '$e';

/// Czy serwer na 127.0.0.1:[port] odpowiada na HTTP (dowolny status = gotowy).
Future<bool> previewServerResponds(int port) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/'));
    req.followRedirects = false;
    final resp = await req.close().timeout(const Duration(seconds: 10));
    await resp.drain<void>();
    return true;
  } on Object {
    return false;
  } finally {
    client.close(force: true);
  }
}

/// Wolny port TCP na 127.0.0.1.
Future<int> freeLocalPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Linie tekstu z bajtów procesu (UTF-8, bez wyjątków na błędnych znakach).
StreamTransformer<List<int>, String> get previewLines => StreamTransformer.fromBind(
    (s) => s.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()));
