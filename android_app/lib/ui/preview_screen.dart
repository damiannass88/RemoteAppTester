import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:grpc/grpc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../i18n.dart';
import '../net/agent_client.dart';
import '../net/friendly_errors.dart';
import '../settings/agent_settings.dart';

/// Podgląd aplikacji web uruchomionej na komputerze/serwerze — strona w WebView,
/// log serwera, zgłaszanie problemów do agenta AI.
///
/// Bezpieczeństwo: adres z tokenem przychodzi wyłącznie z uwierzytelnionego RPC.
/// Bez `tailscale serve` host podaje stronę z własnym certyfikatem z parowania —
/// akceptujemy go WYŁĄCZNIE po zgodnym odcisku SHA-256 (jak kanał gRPC).
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.client, required this.project});

  final AgentClient client;
  final Project project;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _log = <String>[];
  final _console = <String>[];
  final _logScroll = ScrollController();
  StreamSubscription<PreviewEvent>? _sub;
  PreviewState _state = PreviewState.PREVIEW_STARTING;
  String _message = '';
  String? _url;
  bool _pinnedTls = false;
  String? _pinnedFingerprint;
  bool _disconnected = false;
  bool _showLog = false;
  int _progress = 0;
  WebViewController? _web;

  /// Widok strony: telefon (390 px — szerokość testów w projektach) albo komputer (1280 px).
  bool _desktop = false;
  static const _phoneWidth = 390;
  static const _desktopWidth = 1280;
  static const _desktopAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  int get _viewportWidth => _desktop ? _desktopWidth : _phoneWidth;

  /// Szerokość układu strony: nadpisuje `<meta name="viewport">` (WebView dopasowuje skalę).
  String get _viewportScript => '''
(function(w){ var m=document.querySelector('meta[name=viewport]');
 if(!m){ m=document.createElement('meta'); m.name='viewport'; (document.head||document.documentElement).appendChild(m); }
 var c='width='+w; if (m.getAttribute('content')!==c) m.setAttribute('content', c); })($_viewportWidth);''';

  Future<void> _setDesktop(bool desktop) async {
    final web = _web;
    setState(() => _desktop = desktop);
    if (web == null) return;
    await web.setUserAgent(desktop ? _desktopAgent : null);
    await web.reload();
  }

  @override
  void initState() {
    super.initState();
    PinnedCertificate.load().then((c) => _pinnedFingerprint = c?.fingerprintSha256Hex);
    _connect();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _logScroll.dispose();
    super.dispose();
  }

  void _connect() {
    _sub?.cancel();
    setState(() {
      _disconnected = false;
      if (_state != PreviewState.PREVIEW_RUNNING) _state = PreviewState.PREVIEW_STARTING;
    });
    _sub = widget.client.startPreview(PreviewRequest(projectId: widget.project.projectId)).listen(
      _onEvent,
      onError: (Object e) {
        if (!mounted) return;
        final own = e is GrpcError &&
            const {StatusCode.failedPrecondition, StatusCode.permissionDenied, StatusCode.notFound}.contains(e.code);
        setState(() {
          if (own || _state != PreviewState.PREVIEW_RUNNING) {
            _state = PreviewState.PREVIEW_FAILED;
            _message = own ? (e.message ?? '') : friendlyErrorMessage(e);
          } else {
            _disconnected = true;
          }
        });
      },
      onDone: () {
        if (mounted && !_terminal) setState(() => _disconnected = true);
      },
    );
  }

  bool get _terminal => _state == PreviewState.PREVIEW_STOPPED || _state == PreviewState.PREVIEW_FAILED;

  void _onEvent(PreviewEvent e) {
    if (!mounted) return;
    setState(() {
      if (e.logLine.isNotEmpty) {
        _log.add(e.logLine);
        if (_log.length > 500) _log.removeRange(0, _log.length - 500);
      }
      if (e.state != PreviewState.PREVIEW_STATE_UNSPECIFIED) _state = e.state;
      if (e.message.isNotEmpty) _message = e.message;
      if (e.state == PreviewState.PREVIEW_RUNNING && e.url.isNotEmpty && e.url != _url) {
        _url = e.url;
        _pinnedTls = e.pinnedTls;
        _openPage(e.url);
      }
    });
    if (e.reload) _web?.reload();
    if (e.logLine.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScroll.hasClients) _logScroll.jumpTo(_logScroll.position.maxScrollExtent);
      });
    }
  }

  void _openPage(String url) {
    final controller = _web ?? WebViewController();
    if (_web == null) {
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setOnConsoleMessage((m) => _addConsole('[${m.level.name}] ${m.message}'))
        ..setNavigationDelegate(NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageStarted: (_) => controller.runJavaScript(_viewportScript).catchError((_) {}),
          onPageFinished: (_) => controller.runJavaScript('$_viewportScript\n$_errorHook').catchError((_) {}),
          onHttpError: (e) => _addConsole('[http] ${e.response?.statusCode ?? '?'} ${_withoutToken(e.request?.uri.toString() ?? '')}'),
          onWebResourceError: (e) => _addConsole('[sieć] ${e.description} ${_withoutToken(e.url ?? '')}'),
          onSslAuthError: _onSslError,
        ));
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        // Bez tego Android ignoruje szerokość z <meta viewport> (widok 390 px / 1280 px).
        platform.setUseWideViewPort(true);
      }
      _web = controller;
    }
    controller.loadRequest(Uri.parse(url));
  }

  /// Błędy wczytywania zasobów (obrazki, skrypty) i nieobsłużone obietnice → konsola.
  static const _errorHook = '''
(function(){ if (window.__rtHook) return; window.__rtHook = true;
 window.addEventListener('error', function(e){ var t=e.target; if (t && t !== window && (t.src||t.href)) console.error('Nie wczytano: '+(t.src||t.href)); }, true);
 window.addEventListener('unhandledrejection', function(e){ console.error('Unhandled rejection: '+(e.reason && (e.reason.stack||e.reason.message) || e.reason)); });
})();''';

  Future<void> _onSslError(SslAuthError error) async {
    final der = error.certificate?.data;
    final expected = _pinnedFingerprint ?? (await PinnedCertificate.load())?.fingerprintSha256Hex;
    if (_pinnedTls && der != null && expected != null && sha256.convert(der).toString() == expected) {
      await error.proceed();
    } else {
      await error.cancel();
      _addConsole('[tls] ${tr('Certyfikat strony nie zgadza się z certyfikatem komputera z parowania — połączenie przerwane.')}');
    }
  }

  void _addConsole(String line) {
    _console.add(line);
    if (_console.length > 200) _console.removeRange(0, _console.length - 200);
  }

  static String _withoutToken(String url) => url.replaceAll(RegExp(r'[?&]rt_preview_token=[0-9a-f]*'), '');

  Future<void> _stop() async {
    try {
      await widget.client.stopPreview(PreviewRequest(projectId: widget.project.projectId));
    } on Object catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openExternal() async {
    final url = _url;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _report() async {
    final note = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Zgłoś problem')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Opis trafi do pliku .remoteapptester-feedback.md w projekcie — razem z adresem strony i ostatnimi komunikatami konsoli ({0}). Agent AI może go przeczytać.', ['${_console.length}'])),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: tr('Co jest nie tak? Co powinno się stać?')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Anuluj'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('Wyślij'))),
        ],
      ),
    );
    if (send != true || !mounted) return;
    final web = _web;
    var height = MediaQuery.sizeOf(context).height.round();
    var page = '';
    var agent = '';
    if (web != null) {
      page = _withoutToken(await web.currentUrl() ?? '');
      try {
        agent = '${await web.runJavaScriptReturningResult('navigator.userAgent')}'.replaceAll('"', '');
        height = int.tryParse('${await web.runJavaScriptReturningResult('window.innerHeight')}') ?? height;
      } on Object {
        // strona mogła zablokować skrypt
      }
    }
    try {
      final ack = await widget.client.reportPreviewIssue(PreviewIssue(
        projectId: widget.project.projectId,
        note: note.text,
        pageUrl: page,
        console: _console.length > 100 ? _console.sublist(_console.length - 100) : _console,
        userAgent: '${_desktop ? tr('widok komputera') : tr('widok telefonu')}; $agent',
        viewportWidth: _viewportWidth,
        viewportHeight: height,
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ack.success ? tr('Zgłoszenie zapisane w projekcie.') : ack.message)));
    } on Object catch (e) {
      final text = e is GrpcError && e.code == StatusCode.failedPrecondition ? (e.message ?? '') : friendlyErrorMessage(e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final running = _state == PreviewState.PREVIEW_RUNNING && _web != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final web = _web;
        if (running && !_showLog && web != null && await web.canGoBack()) {
          await web.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.project.displayName, overflow: TextOverflow.ellipsis),
          actions: [
            if (running)
              IconButton(tooltip: tr('Odśwież'), icon: const Icon(Icons.refresh), onPressed: () => _web?.reload()),
            if (running)
              IconButton(tooltip: tr('Zgłoś problem'), icon: const Icon(Icons.bug_report_outlined), onPressed: _report),
            IconButton(
              tooltip: _showLog ? tr('Pokaż stronę') : tr('Log serwera'),
              icon: Icon(_showLog ? Icons.web : Icons.terminal),
              onPressed: running ? () => setState(() => _showLog = !_showLog) : null,
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'browser' => _openExternal(),
                'view' => _setDesktop(!_desktop),
                'stop' => _stop(),
                _ => null,
              },
              itemBuilder: (_) => [
                if (running)
                  PopupMenuItem(
                    value: 'view',
                    child: Text(_desktop ? tr('Widok telefonu ({0} px)', ['$_phoneWidth']) : tr('Widok komputera ({0} px)', ['$_desktopWidth'])),
                  ),
                if (running && !_pinnedTls) PopupMenuItem(value: 'browser', child: Text(tr('Otwórz w przeglądarce'))),
                if (!_terminal) PopupMenuItem(value: 'stop', child: Text(tr('Zatrzymaj podgląd'))),
              ],
            ),
          ],
          bottom: running && _progress < 100 && !_showLog
              ? PreferredSize(preferredSize: const Size.fromHeight(3), child: LinearProgressIndicator(value: _progress / 100))
              : null,
        ),
        body: Column(
          children: [
            if (_disconnected)
              MaterialBanner(
                content: Text(tr('Utracono połączenie z komputerem — strona może być nieaktualna.')),
                actions: [TextButton(onPressed: _connect, child: Text(tr('Połącz ponownie')))],
              ),
            Expanded(
              child: running && !_showLog
                  ? WebViewWidget(controller: _web!)
                  : _StatusView(state: _state, message: _message, kind: widget.project.previewKind, log: _log, scroll: _logScroll, onRetry: _terminal ? _connect : null),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({required this.state, required this.message, required this.kind, required this.log, required this.scroll, this.onRetry});

  final PreviewState state;
  final String message;
  final String kind;
  final List<String> log;
  final ScrollController scroll;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = state == PreviewState.PREVIEW_FAILED;
    final starting = state == PreviewState.PREVIEW_STARTING;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (starting) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
              if (failed) Icon(Icons.error_outline, color: scheme.error),
              if (state == PreviewState.PREVIEW_STOPPED) const Icon(Icons.stop_circle_outlined),
              if (state == PreviewState.PREVIEW_RUNNING) const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.isNotEmpty
                      ? message
                      : starting
                          ? tr('Uruchamiam podgląd ({0})…', [kind])
                          : '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (starting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(tr('Pierwsze uruchomienie może potrwać kilka minut (pobieranie zależności, kompilacja).'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(8),
              child: log.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: scroll,
                      itemCount: log.length,
                      itemBuilder: (_, i) => Text(
                        log[i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                      ),
                    ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.play_arrow), label: Text(tr('Uruchom ponownie'))),
          ],
        ],
      ),
    );
  }
}
