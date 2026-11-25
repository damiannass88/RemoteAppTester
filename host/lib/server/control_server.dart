import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../build/build_engine.dart';
import '../store/project_store.dart';
import '../security/secret_store.dart';
import 'kill_switch.dart';

/// Maksymalny rozmiar ciała żądania lokalnego kanału.
const int _maxBodyBytes = 16 * 1024;

/// Jak długo `GET .../events` czeka na nowe zdarzenia (long-poll).
const Duration _longPollTimeout = Duration(seconds: 20);

/// Token lokalnego kanału — losowy, w [SecretStore] (DPAPI / plik 0600), więc
/// czyta go tylko użytkownik, jako który działa host. Ten sam przez restarty.
String loadOrCreateControlToken(File file, {SecretStore? store}) {
  final secrets = store ?? SecretStore.forPlatform();
  if (file.existsSync()) return utf8.decode(secrets.read(file));
  final random = Random.secure();
  final token = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  file.parent.createSync(recursive: true);
  secrets.write(file, Uint8List.fromList(utf8.encode(token)));
  return token;
}

/// Porównanie w stałym czasie — nie zdradza tokenu przez czas odpowiedzi.
bool constantTimeEquals(String a, String b) {
  final x = utf8.encode(a);
  final y = utf8.encode(b);
  var diff = x.length ^ y.length;
  for (var i = 0; i < x.length && i < y.length; i++) {
    diff |= x[i] ^ y[i];
  }
  return diff == 0;
}

/// Lokalny kanał wyzwalacza (`rt build`) — docs/PROJECT_ASSUMPTIONS.md, sekcja 6.
///
/// Bezpieczeństwo (docs/SECURITY.md):
/// - nasłuch WYŁĄCZNIE na `127.0.0.1` (nigdy Tailscale ani `0.0.0.0`);
/// - każde żądanie wymaga `Authorization: Bearer <token>`;
/// - żądania z nagłówkiem `Origin` (przeglądarka) są odrzucane — strona WWW
///   nie może wyzwolić builda, nawet gdyby jakoś poznała port;
/// - wejście to wyłącznie ścieżka folderu, mapowana na projekt przypisany do
///   RemoteAppTestera; komendy zawsze z zaszyfrowanej bazy — nigdy z żądania.
class ControlServer {
  ControlServer._(this._server, this._token, this._store, this._engine, this._killSwitch, this._onShow) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final String _token;
  final ProjectStore _store;
  final BuildEngine _engine;
  final KillSwitch _killSwitch;

  /// Drugie uruchomienie aplikacji okienkowej prosi działającą o pokazanie okna.
  final void Function()? _onShow;

  int get port => _server.port;

  static Future<ControlServer> start({
    required int port,
    required String token,
    required ProjectStore store,
    required BuildEngine engine,
    required KillSwitch killSwitch,
    void Function()? onShow,
  }) async {
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException catch (e) {
      // Port zarezerwowany przez system (Windows 10013, Linux EACCES) — bierzemy
      // dowolny wolny; klienci czytają go z `config/control_port`. Port zajęty (np. przez
      // drugą kopię RemoteAppTestera) nadal jest błędem: dwa hosty na jednej bazie.
      final code = e.osError?.errorCode;
      if (code != 10013 && code != 13) rethrow;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    }
    return ControlServer._(server, token, store, engine, killSwitch, onShow);
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.headers.value('origin') != null) {
        return await _send(response, HttpStatus.forbidden, {'error': 'Żądania z przeglądarki są odrzucane.'});
      }
      final auth = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
      if (!auth.startsWith('Bearer ') || !constantTimeEquals(auth.substring(7), _token)) {
        return await _send(response, HttpStatus.unauthorized, {'error': 'Brak lub zły token.'});
      }

      final segments = request.uri.pathSegments;
      if (request.method == 'POST' && request.uri.path == '/v1/show') {
        _onShow?.call();
        return await _send(response, _onShow == null ? HttpStatus.notFound : HttpStatus.ok, {'shown': _onShow != null});
      }
      if (request.method == 'POST' && request.uri.path == '/v1/build') {
        return await _startBuild(request);
      }
      if (request.method == 'GET' && segments.length == 4 && segments[0] == 'v1' && segments[1] == 'builds' &&
          segments[3] == 'events') {
        return await _events(request, segments[2]);
      }
      return await _send(response, HttpStatus.notFound, {'error': 'Nieznany adres.'});
    } on Object catch (e) {
      return await _send(response, HttpStatus.internalServerError, {'error': e.toString()});
    }
  }

  Future<void> _startBuild(HttpRequest request) async {
    final body = await _readBody(request);
    if (body == null) {
      return _send(request.response, HttpStatus.requestEntityTooLarge, {'error': 'Za duże żądanie.'});
    }
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return _send(request.response, HttpStatus.badRequest, {'error': 'Niepoprawny JSON.'});
    }
    final path = json is Map ? json['path'] : null;
    if (path is! String || path.isEmpty) {
      return _send(request.response, HttpStatus.badRequest, {'error': 'Brak pola "path".'});
    }
    if (_killSwitch.isPaused) {
      return _send(request.response, HttpStatus.serviceUnavailable, {'error': 'Host wstrzymany (kill-switch).'});
    }

    final project = _store.byPath(path);
    if (project == null) {
      return _send(request.response, HttpStatus.notFound, {
        'error': 'Ten folder nie jest przypisany do RemoteAppTester. Dodaj go w aplikacji albo: rt a <folder>',
      });
    }
    if (!project.localTrigger) {
      return _send(request.response, HttpStatus.forbidden,
          {'error': 'Budowanie przez "rt b" jest wyłączone w opcjach projektu.'});
    }
    try {
      final record = _engine.start(project: project, requester: localRequester);
      return await _send(request.response, HttpStatus.ok, {
        'build_id': record.buildId,
        'project': project.name,
        'method': record.profile.name,
        'has_spec': true,
      });
    } on BuildRejectedException catch (e) {
      return _send(request.response, HttpStatus.conflict, {'error': e.message});
    }
  }

  Future<void> _events(HttpRequest request, String buildId) async {
    final record = _engine.byId(buildId);
    // Tylko buildy lokalne — `rt build` nie podgląda buildów zleconych z telefonów.
    if (record == null || record.requester != localRequester) {
      return _send(request.response, HttpStatus.notFound, {'error': 'Nieznany build.'});
    }
    final from = int.tryParse(request.uri.queryParameters['from'] ?? '0') ?? 0;
    if (from < 0) return _send(request.response, HttpStatus.badRequest, {'error': 'Zły parametr from.'});
    await record.waitForChange(from, _longPollTimeout);
    final events = record.events.skip(from).toList();
    return _send(request.response, HttpStatus.ok, {
      'events': [
        for (final e in events)
          {'phase': e.phase.name, 'log': e.logLine, 'progress': e.progressPercent, 'queue': e.queuePosition},
      ],
      'next': from + events.length,
      'finished': record.isFinished && from + events.length >= record.events.length,
      'phase': record.phase.name,
    });
  }

  static Future<String?> _readBody(HttpRequest request) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in request) {
      builder.add(chunk);
      if (builder.length > _maxBodyBytes) return null;
    }
    return utf8.decode(builder.takeBytes(), allowMalformed: true);
  }

  static Future<void> _send(HttpResponse response, int status, Map<String, Object?> body) async {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await response.close();
  }
}
