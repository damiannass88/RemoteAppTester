import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:path/path.dart' as p;

import '../project/project_creator.dart';
import '../build/artifact_registry.dart';
import '../build/build_engine.dart';
import '../build/command_runner.dart';
import '../build/operation_log.dart';
import '../config/host_config.dart';
import '../i18n.dart';
import '../net/tailscale_interface.dart';
import '../pairing/device_registry.dart';
import '../pairing/nonce_store.dart';
import '../pairing/pairing_uri.dart';
import '../pairing/rate_limiter.dart';
import '../preview/preview_manager.dart';
import '../security/tls_identity.dart';
import '../store/project_store.dart';
import 'control_server.dart';
import 'delivery_hub.dart';
import 'host_agent_service.dart';
import 'kill_switch.dart';
import 'signal_watcher.dart';

/// Plik tokenu lokalnego kanału (w SecretStore).
const controlTokenPath = 'config/control_token';
const hostConfigPath = 'config/host-config.yaml';

/// Port, na którym naprawdę nasłuchuje lokalny kanał (może różnić się od
/// konfiguracji, gdy system zarezerwował ten port) — zapisywany przy starcie.
const controlPortPath = 'config/control_port';

/// Port lokalnego kanału działającego hosta, dla `rt` i drugiej kopii aplikacji.
int resolveControlPort(HostConfig config) {
  try {
    return int.tryParse(File(controlPortPath).readAsStringSync().trim()) ?? config.controlPort;
  } on FileSystemException {
    return config.controlPort;
  }
}

/// Domyślny katalog danych hosta: `REMOTEAPPTESTER_HOME`, a na Windows
/// `%LOCALAPPDATA%\RemoteAppTester` (to samo, czego używa aplikacja okienkowa).
String defaultHostHome() {
  final local = Platform.environment['LOCALAPPDATA'];
  var env = Platform.environment['REMOTEAPPTESTER_HOME'];
  if (env == null || env.isEmpty) {
    // Zmienna ze starszej instalacji: domyślny stary katalog i tak przenosimy niżej.
    final legacyEnv = Platform.environment['REMOTETESTER_HOME'];
    final isDefaultLegacy = local != null && legacyEnv != null && p.equals(legacyEnv, p.join(local, 'RemoteTester'));
    if (!isDefaultLegacy) env = legacyEnv;
  }
  if (env != null && env.isNotEmpty) return env;
  if (Platform.isWindows && local != null) {
    final home = p.join(local, 'RemoteAppTester');
    // Wcześniejsza nazwa aplikacji: dane przenosimy raz, w całości.
    final legacy = Directory(p.join(local, 'RemoteTester'));
    if (!Directory(home).existsSync() && legacy.existsSync()) {
      try {
        legacy.renameSync(home);
      } on FileSystemException {
        return legacy.path; // działa stara kopia — używamy danych tam, gdzie są
      }
    }
    return home;
  }
  final userHome = Platform.environment['HOME'];
  if (userHome != null && userHome.isNotEmpty) {
    return p.join(Platform.environment['XDG_DATA_HOME'] ?? p.join(userHome, '.local', 'share'), 'remoteapptester');
  }
  return Directory.current.path;
}

/// Stan serwera dla telefonów.
enum PhoneServerState { starting, waitingForTailscale, running, failed }

/// Rdzeń hosta RemoteAppTester — wspólny dla aplikacji okienkowej (Windows) i
/// usługi `rt s` (Linux): baza projektów, silnik buildów, dostawy, serwer gRPC
/// dla telefonów (WYŁĄCZNIE adres Tailscale, TLS z pinningiem, HMAC) i lokalny
/// kanał `127.0.0.1` dla `rt b`.
///
/// Wszystkie ścieżki są względem bieżącego katalogu procesu = katalog danych
/// (ustawiany przez wywołującego, jak `--home` w CLI).
class HostRuntime {
  HostRuntime._({
    required this.config,
    required this.store,
    required this.devices,
    required this.engine,
    required this.deliveries,
    required this.killSwitch,
    required this.tls,
    required this.signals,
    required this.previews,
    required HostAgentService service,
  }) : _service = service {
    // Zmiany od agenta AI: otwarty podgląd na telefonie sam się odświeża.
    _signalSub = signals.onSignal.listen((id) => unawaited(previews.reload(id)));
  }

  final HostConfig config;
  final ProjectStore store;
  final DeviceRegistry devices;
  final BuildEngine engine;
  final DeliveryHub deliveries;
  final KillSwitch killSwitch;
  final TlsIdentity tls;

  /// Sygnały agentów AI z folderów projektów.
  final SignalWatcher signals;

  /// Podglądy aplikacji web uruchomione z telefonu.
  final PreviewManager previews;
  final HostAgentService _service;
  late final StreamSubscription<String> _signalSub;

  /// Opcje projektu zmienione z telefonu.
  Stream<String> get onOptionsChanged => _service.onOptionsChanged;

  Server? _grpc;
  ControlServer? _control;
  Timer? _retry;
  bool _closed = false;

  final _stateChanges = StreamController<PhoneServerState>.broadcast();
  PhoneServerState phoneServerState = PhoneServerState.starting;
  String? phoneServerMessage;
  InternetAddress? tailscaleAddress;

  /// Zmiany stanu serwera dla telefonów (dla okna aplikacji).
  Stream<PhoneServerState> get onStateChange => _stateChanges.stream;
  int? get controlPort => _control?.port;

  /// Tworzy konfigurację przy pierwszym uruchomieniu (aplikacja okienkowa).
  static void ensureConfig({String? projectsRoot, int port = defaultListenPort}) {
    final file = File(hostConfigPath);
    if (file.existsSync()) return;
    file.parent.createSync(recursive: true);
    final root = projectsRoot ??
        p.join(Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.', 'RemoteAppTesterProjects');
    Directory(root).createSync(recursive: true);
    file.writeAsStringSync(HostConfig.render(projectsRoot: root, port: port));
  }

  static Future<HostRuntime> start({void Function()? onShow}) async {
    HostConfig.migrateLegacyDefaultPort(hostConfigPath);
    final config = HostConfig.load(hostConfigPath);
    final store = ProjectStore.open();
    // Nowsza wersja RemoteAppTestera = nowsze wytyczne dla agentów (np. `rt sg`).
    for (final project in store.projects()) {
      prepareAgentFiles(project.directory, project.name);
    }
    final devices = DeviceRegistry(File('config/paired_devices.json'));
    final operationLog = OperationLog(File('logs/operations.log'));
    final artifacts = ArtifactRegistry();
    final killSwitch = KillSwitch();
    final engine = BuildEngine(
      runner: CommandRunner(scriptDir: Directory(p.join(Directory.current.path, 'tmp'))),
      artifacts: artifacts,
      operationLog: operationLog,
      dataDir: Directory.current,
      store: store,
      maxParallel: config.maxParallelBuilds,
    );
    final deliveries = DeliveryHub(finished: engine.onFinished, devices: devices);
    final tls = TlsIdentity.loadOrGenerate(certFile: File('config/tls_cert.pem'), keyFile: File('config/tls_key.pem'));
    HostRuntime? self;
    final previews = PreviewManager(
      store: store,
      killSwitch: killSwitch,
      operationLog: operationLog,
      settings: config.preview,
      tailscaleAddress: () => self?.tailscaleAddress,
      tls: SecurityContext()
        ..useCertificateChainBytes(utf8.encode(tls.certificatePem))
        ..usePrivateKeyBytes(utf8.encode(tls.privateKeyPem)),
      scriptDir: Directory(p.join(Directory.current.path, 'tmp')),
    );
    final service = HostAgentService(
      store: store,
      engine: engine,
      deliveries: deliveries,
      devices: devices,
      operationLog: operationLog,
      artifacts: artifacts,
      rateLimiter: RateLimiter(maxRequestsPerMinutePerDevice: config.rateLimitPerDevicePerMinute),
      nonceStore: NonceStore(),
      killSwitch: killSwitch,
      creator: config.phoneAddProjects ? ProjectCreator(store, config.projectsRoot) : null,
      previews: previews,
    );
    final runtime = self = HostRuntime._(
      config: config,
      store: store,
      devices: devices,
      engine: engine,
      deliveries: deliveries,
      killSwitch: killSwitch,
      tls: tls,
      signals: SignalWatcher(
        store: store,
        engine: engine,
        killSwitch: killSwitch,
        operationLog: operationLog,
        deliveries: deliveries,
        devices: devices,
      ),
      previews: previews,
      service: service,
    );

    runtime._control = await ControlServer.start(
      port: config.controlPort,
      token: loadOrCreateControlToken(File(controlTokenPath)),
      store: store,
      engine: engine,
      killSwitch: killSwitch,
      onShow: onShow,
    );
    File(controlPortPath).writeAsStringSync('${runtime._control!.port}');
    await runtime._startPhoneServer();
    return runtime;
  }

  /// Serwer gRPC na adresie Tailscale. Brak Tailscale nie blokuje reszty
  /// (okno, buildy lokalne) — ponawiamy co 15 s, nigdy nie nasłuchując na
  /// innym adresie.
  Future<void> _startPhoneServer() async {
    if (_closed || _grpc != null) return;
    try {
      final address = await findTailscaleAddress();
      final server = Server.create(
        services: [_service],
        // Telefon pinguje co ~25 s; częstsze pingi to nadużycie.
        keepAliveOptions: const ServerKeepAliveOptions(
          minIntervalBetweenPingsWithoutData: Duration(seconds: 10),
          maxBadPings: 3,
        ),
      );
      await server.serve(
        address: address,
        port: config.listenPort,
        security: ServerTlsCredentials(
          certificate: utf8.encode(tls.certificatePem),
          privateKey: utf8.encode(tls.privateKeyPem),
        ),
      );
      _grpc = server;
      tailscaleAddress = address;
      _setState(PhoneServerState.running, tr('Telefony łączą się przez {0}:{1}', [address.address, config.listenPort]));
    } on TailscaleInterfaceNotFoundException {
      _setState(PhoneServerState.waitingForTailscale, tr('Czekam na Tailscale — uruchom i zaloguj aplikację Tailscale.'));
      _scheduleRetry();
    } on Object catch (e) {
      _setState(PhoneServerState.failed, tr('Serwer dla telefonów nie wystartował: {0}', [e]));
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (_closed) return;
    _retry = Timer(const Duration(seconds: 15), _startPhoneServer);
  }

  void _setState(PhoneServerState state, String message) {
    phoneServerState = state;
    phoneServerMessage = message;
    if (!_stateChanges.isClosed) _stateChanges.add(state);
  }

  /// Paruje nowy telefon — WYŁĄCZNIE lokalna akcja na tym komputerze.
  /// Zwraca urządzenie i link `remoteapptester://pair?...` do kodu QR.
  (PairedDevice, String) pair(String name) {
    final address = tailscaleAddress;
    if (address == null) {
      throw StateError('Brak połączenia z Tailscale — telefon nie miałby jak się połączyć.');
    }
    final device = devices.register(name);
    final uri = buildPairingUri(
      host: address.address,
      port: config.listenPort,
      device: device,
      certFingerprintSha256Hex: tls.fingerprintSha256Hex,
    );
    return (device, uri);
  }

  Future<void> shutdown() async {
    _closed = true;
    _retry?.cancel();
    await _signalSub.cancel();
    signals.close();
    await previews.close();
    await _control?.close();
    try {
      File(controlPortPath).deleteSync();
    } on FileSystemException {
      // już usunięty
    }
    await deliveries.close();
    await engine.close();
    await _grpc?.shutdown();
    await _stateChanges.close();
    store.close();
  }
}
