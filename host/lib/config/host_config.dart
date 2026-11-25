import 'dart:io';

import 'package:yaml/yaml.dart';

import '../preview/preview_manager.dart';

/// Domyślny port dla telefonów — poniżej zakresu dynamicznego 49152–65535, w którym
/// Windows (Hyper-V, WSL, Docker) przy każdym starcie losowo rezerwuje porty
/// (bind kończy się wtedy błędem 10013). Lokalny kanał domyślnie o 1 wyżej.
const int defaultListenPort = 47051;

/// Domyślny port do wersji 0.6 — w zakresie dynamicznym, patrz [defaultListenPort].
const int legacyDefaultListenPort = 50051;

/// Konfiguracja hosta wczytana z `config/host-config.yaml`.
///
/// Sekrety (pairing_secret, klucz prywatny TLS, klucz bazy) NIGDY nie trafiają
/// tutaj — żyją wyłącznie w SecretStore (Windows DPAPI / plik 0600 na Linuxie).
/// Projekty i komendy budowania są w zaszyfrowanej bazie (`store/`), nie tutaj.
class HostConfig {
  HostConfig({
    required this.projectsRoot,
    required this.listenPort,
    required this.rateLimitPerDevicePerMinute,
    this.maxParallelBuilds = 2,
    this.phoneAddProjects = true,
    this.preview = const PreviewSettings(),
    int? controlPort,
  }) : controlPort = controlPort ?? listenPort + 1;

  /// Domyślne miejsce na NOWE foldery projektów (tworzone z aplikacji). Projekty
  /// to wyłącznie foldery świadomie przypisane do RemoteAppTestera — host nie
  /// skanuje dysku.
  final Directory projectsRoot;

  /// Port serwera gRPC — nasłuch WYŁĄCZNIE na adresie Tailscale.
  final int listenPort;

  /// Port lokalnego kanału (`rt b`, okno aplikacji) — WYŁĄCZNIE 127.0.0.1.
  final int controlPort;
  final int rateLimitPerDevicePerMinute;

  /// Ile różnych projektów buduje się naraz (Gradle mocno obciąża pamięć).
  /// Ten sam projekt zawsze buduje się pojedynczo.
  final int maxParallelBuilds;

  /// Czy sparowany telefon może dodać projekt: nowy folder albo istniejący folder,
  /// wyłącznie wewnątrz [projectsRoot] (sama nazwa, komendy z szablonów hosta).
  final bool phoneAddProjects;

  /// Podgląd aplikacji web z telefonu: porty w Tailscale i `tailscale serve`.
  final PreviewSettings preview;

  static HostConfig load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Brak pliku konfiguracyjnego: $path — utwórz go: rt i --projects-root <katalog>');
    }
    final doc = loadYaml(file.readAsStringSync()) as YamlMap;

    final rootPath = doc['projects_root'] as String?;
    if (rootPath == null || rootPath.isEmpty) {
      throw StateError('host-config.yaml: brak wymaganego pola projects_root');
    }
    final root = Directory(rootPath);
    if (!root.existsSync()) root.createSync(recursive: true);

    final listenPort = (doc['listen_port'] as int?) ?? 0;
    if (listenPort <= 0 || listenPort >= 65535) {
      throw StateError(
        'host-config.yaml: listen_port musi być ustawiony na konkretny port '
        '(ten sam port musi być wpisany w regule Tailscale ACL).',
      );
    }
    final parallel = (doc['max_parallel_builds'] as int?) ?? 2;

    return HostConfig(
      projectsRoot: root,
      listenPort: listenPort,
      rateLimitPerDevicePerMinute: (doc['rate_limit_per_device_per_minute'] as int?) ?? 120,
      maxParallelBuilds: parallel.clamp(1, 8),
      phoneAddProjects: (doc['phone_add_projects'] as bool?) ?? true,
      controlPort: doc['control_port'] as int?,
      preview: PreviewSettings(
        firstPort: ((doc['preview_port'] as int?) ?? 47100).clamp(1024, 65000),
        portCount: ((doc['preview_port_count'] as int?) ?? 10).clamp(1, 50),
        tailscaleServe: (doc['preview_tailscale_serve'] as bool?) ?? true,
        idleTimeout: Duration(minutes: ((doc['preview_idle_minutes'] as int?) ?? 30).clamp(1, 24 * 60)),
      ),
    );
  }

  /// Na Windows zamienia stary domyślny port (50051/50052) na [defaultListenPort] —
  /// inaczej po restarcie komputera serwer często nie wstaje. Telefon trzeba wtedy
  /// raz przestawić na nowy port. Zwraca `true`, jeśli plik został zmieniony.
  static bool migrateLegacyDefaultPort(String path, {bool? windows}) {
    if (!(windows ?? Platform.isWindows)) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    final text = file.readAsStringSync();
    final migrated = text
        .replaceFirstMapped(RegExp('^(listen_port:\\s*)$legacyDefaultListenPort\\b', multiLine: true),
            (m) => '${m[1]}$defaultListenPort')
        .replaceFirstMapped(RegExp('^(#?\\s*control_port:\\s*)${legacyDefaultListenPort + 1}\\b', multiLine: true),
            (m) => '${m[1]}${defaultListenPort + 1}');
    if (migrated == text) return false;
    file.writeAsStringSync(migrated);
    return true;
  }

  /// Treść nowego pliku konfiguracji (`rt i`, pierwsze uruchomienie aplikacji).
  static String render({required String projectsRoot, required int port}) {
    // Ścieżka w YAML w cudzysłowie z escapowaniem — pochodzi od lokalnego użytkownika.
    final quotedRoot = projectsRoot.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '''
# Konfiguracja hosta RemoteAppTester. Bez sekretów — te są w SecretStore.
# Projekty, komendy budowania i opcje są w zaszyfrowanej bazie (aplikacja / rt).
projects_root: "$quotedRoot"   # domyślne miejsce na nowe foldery projektów
listen_port: $port             # gRPC, tylko adres Tailscale
# control_port: ${port + 1}    # lokalny kanał "rt b" i okna aplikacji, tylko 127.0.0.1
max_parallel_builds: 2         # ile projektów buduje się naraz
phone_add_projects: true       # telefon może dodać projekt (tylko w projects_root)
rate_limit_per_device_per_minute: 120
# Podgląd aplikacji web z telefonu (porty w Tailscale: preview_port … +preview_port_count-1)
# preview_port: 47100
# preview_port_count: 10
# preview_tailscale_serve: true  # HTTPS *.ts.net przez "tailscale serve"; false = certyfikat hosta
# preview_idle_minutes: 30       # zatrzymaj nieużywany podgląd
''';
  }
}
