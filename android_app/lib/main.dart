import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'delivery/delivery_service.dart';
import 'net/agent_client.dart';
import 'net/friendly_errors.dart';
import 'settings/agent_settings.dart';
import 'settings/sounds.dart';
import 'security/app_lock.dart';
import 'ui/app_lock_gate.dart';
import 'ui/project_list_screen.dart';
import 'i18n.dart';
import 'ui/app_theme.dart';
import 'ui/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();
  await I18n.load();
  await Sounds.load();
  await AppLock.load();
  runApp(const RemoteAppTesterApp());
}

class RemoteAppTesterApp extends StatelessWidget {
  const RemoteAppTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppTheme.mode, I18n.language]),
      builder: (context, _) => MaterialApp(
        title: 'RemoteAppTester',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppTheme.mode.value,
        locale: I18n.locale,
        supportedLocales: [for (final code in supportedLanguageCodes) Locale(code)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // Zmiana języka przebudowuje cały interfejs (teksty z tr()).
        // Blokada odciskiem palca nad całą aplikacją (security/app_lock.dart).
        builder: (context, child) => AppLockGate(child: KeyedSubtree(key: ValueKey(I18n.code), child: child!)),
        home: const _StartupGate(),
      ),
    );
  }
}

/// Jeśli mamy już zapisany adres hosta i dane parowania — od razu próbujemy
/// połączyć i pokazać listę projektów; w przeciwnym razie ekran ustawień.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _checked = false;
  AgentClient? _client;
  DeliveryService? _deliveries;

  /// Powód, dla którego zapisane połączenie nie zadziałało — pokazujemy go na
  /// ekranie połączenia, zamiast zostawiać użytkownika bez wyjaśnienia.
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _tryAutoConnect();
  }

  @override
  void dispose() {
    _deliveries?.dispose();
    super.dispose();
  }

  Future<void> _tryAutoConnect() async {
    final address = await AgentAddress.load();
    final device = await DeviceCredentials.load();
    final certificate = await PinnedCertificate.load();
    if (address != null && device != null && certificate != null) {
      try {
        _client = await AgentClient.connect(address, device, certificate);
        await _client!.rotateSecretIfDue();
        _deliveries = DeliveryService.startFor(_client!);
      } catch (e) {
        _client = null;
        _startupError = friendlyErrorMessage(e);
      }
    }
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final client = _client;
    if (client == null) {
      return SettingsScreen(startupError: _startupError);
    }
    return ProjectListScreen(client: client, deliveries: _deliveries);
  }
}
