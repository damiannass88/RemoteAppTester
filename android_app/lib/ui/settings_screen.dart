import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../delivery/delivery_service.dart';
import '../net/agent_client.dart';
import '../net/friendly_errors.dart';
import 'about_screen.dart';
import 'app_lock_settings_screen.dart';
import 'info_screen.dart';
import '../pairing/pairing_uri.dart';
import '../settings/agent_settings.dart';
import 'project_list_screen.dart';
import 'qr_scan_screen.dart';
import 'app_theme.dart';
import '../settings/sounds.dart';
import '../security/app_lock.dart';
import '../i18n.dart';

/// Ekran konfiguracji — adres hosta (Tailscale IP/hostname) + dane
/// parowania. Dwie ścieżki wypełnienia pól (docs/architektura-remote-build.md,
/// sekcja 4a — parowanie nadal wyłącznie lokalne na hoście):
///   - skan kodu QR z `remoteapptester pair` (wymaga CAMERA),
///   - wklejenie ze schowka wyniku zeskanowanego DOWOLNĄ zewnętrzną apką
///     (bez dodatkowych uprawnień).
/// Ręczne wpisanie pól wciąż działa jako trzecia opcja.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.startupError});

  /// Dlaczego nie udało się połączyć zapisanymi danymi przy starcie aplikacji.
  final String? startupError;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '47051');
  final _deviceIdController = TextEditingController();
  final _pairingSecretController = TextEditingController();
  final _certFingerprintController = TextEditingController();

  bool _loading = true;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.startupError;
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final address = await AgentAddress.load();
    final device = await DeviceCredentials.load();
    final certificate = await PinnedCertificate.load();
    if (address != null) {
      _hostController.text = address.host;
      _portController.text = address.port.toString();
    }
    if (device != null) {
      _deviceIdController.text = device.deviceId;
      _pairingSecretController.text = device.pairingSecret;
    }
    if (certificate != null) {
      _certFingerprintController.text = certificate.fingerprintSha256Hex;
    }
    setState(() => _loading = false);
  }

  Future<void> _scanQr() async {
    final parsed = await Navigator.of(context).push<ParsedPairing>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (parsed == null) return;
    _applyParsed(parsed);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null) {
      setState(() => _error = tr('Schowek jest pusty.'));
      return;
    }
    final parsed = tryParsePairingUri(text);
    if (parsed == null) {
      setState(() => _error =
          'Zawartość schowka nie wygląda na kod parowania (oczekiwano remoteapptester://pair?...).');
      return;
    }
    _applyParsed(parsed);
  }

  void _applyParsed(ParsedPairing parsed) {
    setState(() {
      _hostController.text = parsed.address.host;
      _portController.text = parsed.address.port.toString();
      _deviceIdController.text = parsed.device.deviceId;
      _pairingSecretController.text = parsed.device.pairingSecret;
      _certFingerprintController.text = parsed.certificate.fingerprintSha256Hex;
      _error = null;
    });
    _saveAndConnect();
  }

  Future<void> _saveAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _connecting = true;
      _error = null;
    });

    final address = AgentAddress(
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
    );
    final device = DeviceCredentials(
      deviceId: _deviceIdController.text.trim(),
      pairingSecret: _pairingSecretController.text.trim(),
    );
    final certificate = PinnedCertificate(
      fingerprintSha256Hex: _certFingerprintController.text.trim(),
    );

    try {
      final client = await AgentClient.connect(address, device, certificate);
      // Ping od razu weryfikuje, że adres i device_id są poprawne, zanim
      // użytkownik przejdzie dalej.
      await client.ping();

      await address.save();
      await device.save();
      await certificate.save();
      // Kod z QR jest jednorazowy: od razu wymieniamy go na własny sekret telefonu.
      await client.rotateSecretIfDue();

      if (!mounted) return;
      // Cały stos od nowa: stara lista projektów i jej usługa dostaw znikają, zamiast działać obok nowych.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ProjectListScreen(client: client, deliveries: DeliveryService.startFor(client))),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Połączenie z komputerem')),
        actions: [
          IconButton(
            tooltip: tr('Informacje'),
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
          ),
          IconButton(
            tooltip: tr('O aplikacji'),
            icon: const Icon(Icons.new_releases_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _connecting ? null : _scanQr,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(tr('Skanuj kod QR')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _connecting ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.paste),
                      label: Text(tr('Wklej ze schowka')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: Text(tr('— albo wpisz ręcznie —'))),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: tr('Adres komputera (Tailscale IP lub MagicDNS)'),
                  hintText: tr('np. 100.81.17.106 albo desktop.tailxxxx.ts.net'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Wymagane') : null,
              ),
              TextFormField(
                controller: _portController,
                decoration: InputDecoration(labelText: tr('Port')),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final port = int.tryParse(v ?? '');
                  return (port == null || port <= 0) ? tr('Nieprawidłowy port') : null;
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text(
                tr('device_id / pairing_secret (z "Paruj urządzenie" na agencie):'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: _deviceIdController,
                decoration: const InputDecoration(labelText: 'device_id'),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Wymagane') : null,
              ),
              TextFormField(
                controller: _pairingSecretController,
                decoration: const InputDecoration(labelText: 'pairing_secret'),
                obscureText: true,
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Wymagane') : null,
              ),
              TextFormField(
                controller: _certFingerprintController,
                decoration: InputDecoration(
                  labelText: tr('cert_fp (odcisk certyfikatu TLS komputera)'),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? tr('Wymagane') : null,
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              FilledButton(
                onPressed: _connecting ? null : _saveAndConnect,
                child: _connecting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr('Zapisz i połącz')),
              ),
              const SizedBox(height: 24),
              const Divider(),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.mode,
                builder: (context, mode, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(tr('Tryb ciemny')),
                  subtitle: Text(tr('Ciemny granatowy motyw aplikacji.')),
                  value: mode == ThemeMode.dark,
                  onChanged: AppTheme.setDark,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: Sounds.enabled,
                builder: (context, on, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: Text(tr('Odtwarzaj dźwięki')),
                  subtitle: Text(tr('Krótkie tony: koniec builda, instalacja, nowa wersja.')),
                  value: on,
                  onChanged: (v) async {
                    await Sounds.setEnabled(v);
                    if (v) await Sounds.play(SoundEvent.installed);
                  },
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([AppLock.enabled, AppLock.backgroundTimeout]),
                builder: (context, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fingerprint),
                  title: Text(tr('Blokada aplikacji')),
                  subtitle: Text(AppLock.enabled.value
                      ? appLockTimeoutLabel(AppLock.backgroundTimeout.value)
                      : tr('Wyłączona')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AppLockSettingsScreen())),
                ),
              ),
              ValueListenableBuilder<AppLanguage>(
                valueListenable: I18n.language,
                builder: (context, language, _) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language),
                  title: Text(tr('Język')),
                  trailing: DropdownButton<AppLanguage>(
                  value: language,
                  items: [
                    DropdownMenuItem(value: AppLanguage.system, child: Text(tr('Jak w systemie'))),
                    for (final entry in languageNames.entries) DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (v) => v == null ? null : I18n.set(v),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
