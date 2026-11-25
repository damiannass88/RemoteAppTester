import 'dart:convert';
import 'dart:io';

import '../config/host_config.dart';
import '../net/tailscale_interface.dart';
import '../i18n.dart';

enum CheckStatus { ok, warning, failed }

/// Główna wersja Javy z pierwszej linii `java -version`, np.
/// `openjdk version "17.0.20.1"` → 17, `java version "1.8.0_451"` → 8
/// (stary schemat "1.x"). 0, gdy nie da się odczytać.
int parseJavaMajorVersion(String versionLine) {
  final match = RegExp(r'version "(\d+)(?:\.(\d+))?').firstMatch(versionLine);
  if (match == null) return 0;
  final major = int.parse(match.group(1)!);
  if (major == 1) return int.tryParse(match.group(2) ?? '') ?? 0;
  return major;
}

/// Czy wynik `netsh advfirewall firewall show rule name=all dir=in verbose`
/// zawiera włączoną regułę przychodzącą TCP typu "Allow", obejmującą [port]
/// (lista portów, zakres "a-b" albo "Any") i dotyczącą procesu hosta —
/// reguły przypisane do INNEGO programu (np. "Teams, dowolny port") nie
/// wpuszczają ruchu do hosta, więc się nie liczą. [hostExecutableNames] to
/// nazwy plików procesu hosta (małe litery), np. `remoteapptester.exe`.
bool hasInboundTcpAllowRuleForPort(String netshOutput, int port,
    {Set<String> hostExecutableNames = const {'remoteapptester.exe', 'remoteapptester-windows-x64.exe'}}) {
  final blocks = netshOutput.split(RegExp(r'^Rule Name:', multiLine: true)).skip(1);
  for (final block in blocks) {
    String? field(String name) =>
        RegExp('^$name:\\s*(.+)\$', multiLine: true).firstMatch(block)?.group(1)?.trim();
    if (field('Enabled') != 'Yes' || field('Direction') != 'In' || field('Action') != 'Allow') continue;
    if (field('Protocol') != 'TCP') continue;
    final program = field('Program');
    if (program != null && program != 'Any') {
      final fileName = program.replaceAll('/', r'\').split(r'\').last.toLowerCase();
      if (!hostExecutableNames.contains(fileName)) continue;
    }
    final localPort = field('LocalPort');
    if (localPort == null) continue;
    for (final part in localPort.split(',').map((p) => p.trim())) {
      if (part == 'Any' || part == '$port') return true;
      final range = RegExp(r'^(\d+)-(\d+)$').firstMatch(part);
      if (range != null && int.parse(range.group(1)!) <= port && port <= int.parse(range.group(2)!)) {
        return true;
      }
    }
  }
  return false;
}

class CheckResult {
  const CheckResult(this.name, this.status, this.message);
  final String name;
  final CheckStatus status;

  /// Komunikat prostym językiem — dla osoby, która nie zna terminala
  /// (priorytet "prostota", docs/PROJECT_ASSUMPTIONS.md).
  final String message;
}

/// `remoteapptester doctor` — diagnostyka wymagań hosta. Każde sprawdzenie
/// uruchamia wyłącznie stałe polecenia (`--version`) — żadnych danych z sieci.
class Doctor {
  Doctor({this.configPath = 'config/host-config.yaml'});

  final String configPath;

  Future<List<CheckResult>> runAll() async => [
        await _tailscale(),
        _config(),
        await _tool('Git', 'git', ['--version'], hint: tr('Zainstaluj Git (instalator robi to automatycznie).')),
        await _tool('Flutter', 'flutter', ['--version'],
            hint: tr('Zainstaluj Flutter (instalator robi to automatycznie).')),
        await _java(),
        _androidSdk(),
        await _listening(),
        if (Platform.isWindows) await _windowsFirewall(),
      ];

  Future<CheckResult> _tailscale() async {
    try {
      final addr = await findTailscaleAddress();
      return CheckResult('Tailscale', CheckStatus.ok, tr('Połączony, adres {0}.', [addr.address]));
    } on TailscaleInterfaceNotFoundException {
      return CheckResult('Tailscale', CheckStatus.failed,
          tr('Brak połączenia z Tailscale. Uruchom "sudo tailscale up" i zaloguj się linkiem.'));
    }
  }

  CheckResult _config() {
    try {
      final config = HostConfig.load(configPath);
      return CheckResult(tr('Konfiguracja'), CheckStatus.ok,
          tr('Port {0}, projekty w {1}.', [config.listenPort, config.projectsRoot.path]));
    } on StateError catch (e) {
      return CheckResult(tr('Konfiguracja'), CheckStatus.failed, e.message);
    }
  }

  /// Flutter/Gradle wymagają JDK 17+. Na Windows Flutter zwykle używa JDK
  /// dołączonego do Android Studio (nie tego z PATH), więc tam starsza Java
  /// w PATH to tylko ostrzeżenie; na serwerze instalator stawia JDK 17.
  Future<CheckResult> _java() async {
    final result = await _tool('Java (JDK)', 'java', ['-version'], hint: tr('Zainstaluj JDK 17 lub nowszy.'));
    if (result.status != CheckStatus.ok) return result;
    if (parseJavaMajorVersion(result.message) >= 17) return result;
    return CheckResult('Java (JDK)', CheckStatus.warning,
        tr('{0} — do budowania aplikacji Android potrzebny jest JDK 17 lub nowszy.', [result.message]));
  }

  CheckResult _androidSdk() {
    final sdk = Platform.environment['ANDROID_HOME'] ?? Platform.environment['ANDROID_SDK_ROOT'];
    if (sdk != null && Directory(sdk).existsSync()) {
      return CheckResult('Android SDK', CheckStatus.ok, tr('Znaleziony w {0}.', [sdk]));
    }
    return CheckResult('Android SDK', CheckStatus.failed,
        tr('Nie znaleziono Android SDK (zmienna ANDROID_HOME). Bez niego nie zbudujemy aplikacji na telefon.'));
  }

  Future<CheckResult> _listening() async {
    try {
      final config = HostConfig.load(configPath);
      final addr = await findTailscaleAddress();
      final socket = await Socket.connect(addr, config.listenPort, timeout: const Duration(seconds: 2));
      socket.destroy();
      return CheckResult(tr('Usługa RemoteAppTester'), CheckStatus.ok, tr('Działa i czeka na telefon.'));
    } on Object {
      return CheckResult(tr('Usługa RemoteAppTester'), CheckStatus.warning, Platform.isWindows
          ? tr('Nie nasłuchuje. Uruchom aplikację RemoteAppTester; bez okna: "rt s".')
          : tr('Nie nasłuchuje. Na serwerze: "sudo systemctl start remoteapptester"; ręcznie: "rt s".'));
    }
  }

  /// Windows Firewall domyślnie po cichu blokuje połączenia przychodzące od
  /// innego urządzenia w tailnecie — w pierwszym teście z prawdziwym telefonem
  /// (2026-09-28) brak reguły dał "Connection timed out" mimo działającego
  /// Tailscale. Tylko odczyt; regułę tworzy właściciel komputera w
  /// PowerShell jako administrator (docs/SECURITY.md).
  Future<CheckResult> _windowsFirewall() async {
    int port;
    try {
      port = HostConfig.load(configPath).listenPort;
    } on StateError {
      return CheckResult(tr('Zapora Windows'), CheckStatus.warning, tr('Nie sprawdzono (brak konfiguracji).'));
    }
    // `netsh` (nie `Get-NetFirewall*`): cmdlety PowerShell bez uprawnień
    // administratora dostają "Odmowa dostępu" — a połknięty błąd wyglądałby
    // jak "brak reguł". `netsh ... show rule` czyta reguły jako zwykły
    // użytkownik. Etykiety pól są po angielsku niezależnie od języka systemu.
    final result = await _runQuiet(
        'netsh', ['advfirewall', 'firewall', 'show', 'rule', 'name=all', 'dir=in', 'verbose'],
        viaShell: false, systemEncoding: true);
    if (result == null || result.exitCode != 0) {
      return CheckResult(tr('Zapora Windows'), CheckStatus.warning, tr('Nie udało się odczytać reguł zapory.'));
    }
    if (hasInboundTcpAllowRuleForPort(result.stdout as String, port)) {
      return CheckResult(tr('Zapora Windows'), CheckStatus.ok, tr('Reguła przychodząca dla portu {0} istnieje.', [port]));
    }
    return CheckResult(tr('Zapora Windows'), CheckStatus.failed,
        tr('Brak reguły wpuszczającej telefon na port {0} — Windows po cichu blokuje połączenie (telefon pokaże "Nie można połączyć się"). Uruchom ponownie install.cmd i zgódź się na regułę albo w PowerShell jako administrator: New-NetFirewallRule -DisplayName "RemoteAppTester (Tailscale only)" -Direction Inbound -Protocol TCP -LocalPort {1} -RemoteAddress 100.64.0.0/10 -Program "{2}" -Action Allow', [port, port, Platform.resolvedExecutable]));
  }

  Future<CheckResult> _tool(String name, String exe, List<String> args, {required String hint}) async {
    final result = await _runQuiet(exe, args);
    if (result == null || result.exitCode != 0) {
      return CheckResult(name, CheckStatus.failed, tr('Nie znaleziono. {0}', [hint]).trim());
    }
    final firstLine = '${result.stdout}${result.stderr}'.trim().split('\n').first.trim();
    return CheckResult(name, CheckStatus.ok, firstLine);
  }

  /// `runInShell` tylko na Windows — `flutter` to tam `.bat`.
  /// Argumenty zawsze stałe (patrz komentarz klasy).
  static Future<ProcessResult?> _runQuiet(String exe, List<String> args,
      {bool viaShell = true, bool systemEncoding = false}) async {
    // Narzędzia systemowe Windows (netsh) piszą w stronie kodowej konsoli,
    // narzędzia deweloperskie (flutter, git) — w UTF-8.
    final encoding = systemEncoding ? const SystemEncoding() : utf8;
    try {
      return await Process.run(exe, args,
              runInShell: viaShell && Platform.isWindows, stdoutEncoding: encoding, stderrEncoding: encoding)
          .timeout(const Duration(seconds: 30));
    } on Object {
      return null;
    }
  }
}
