import 'package:flutter/material.dart';

import '../i18n.dart';
import '../security/app_lock.dart';

String appLockTimeoutLabel(int seconds) => switch (seconds) {
      0 => tr('Od razu po wyjściu z aplikacji'),
      60 => tr('Po 1 minucie w tle'),
      300 => tr('Po 5 minutach w tle'),
      _ => tr('Po 15 minutach w tle'),
    };

/// Ustawienia blokady odciskiem. Wszystko, co blokadę OSŁABIA (wyłączenie,
/// dłuższy czas w tle), wymaga potwierdzenia odciskiem palca / PIN-em telefonu.
class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> with WidgetsBindingObserver {
  LockCapability? _capability;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Powrót z ustawień Androida po dodaniu odcisku.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final capability = await AppLock.capability();
    if (mounted) setState(() => _capability = capability);
  }

  void _notConfirmed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('Nie potwierdzono — ustawienie bez zmian.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = _capability;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Blokada aplikacji'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (capability != null) _CapabilityCard(capability: capability),
          const SizedBox(height: 8),
          ValueListenableBuilder<bool>(
            valueListenable: AppLock.enabled,
            builder: (context, on, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint),
              title: Text(tr('Blokuj aplikację odciskiem palca')),
              subtitle: Text(tr('Przy uruchomieniu, po powrocie z tła i po 15 minutach bez dotykania ekranu. Wyłączenie wymaga odcisku palca.')),
              value: on,
              onChanged: (v) async {
                if (!await AppLock.setEnabled(v) && mounted) _notConfirmed();
              },
            ),
          ),
          const Divider(),
          ListenableBuilder(
            listenable: Listenable.merge([AppLock.enabled, AppLock.backgroundTimeout]),
            builder: (context, _) => RadioGroup<int>(
              groupValue: AppLock.backgroundTimeout.value,
              onChanged: (v) async {
                if (v == null || !AppLock.enabled.value) return;
                if (!await AppLock.setBackgroundTimeout(v) && mounted) _notConfirmed();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Kiedy blokować ponownie'), style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    tr('Dłuższy czas wymaga odcisku palca, krótszy — nie.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final seconds in AppLock.timeoutOptions)
                    RadioListTile<int>(
                      contentPadding: EdgeInsets.zero,
                      enabled: AppLock.enabled.value,
                      value: seconds,
                      title: Text(appLockTimeoutLabel(seconds)),
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: AppLock.enabled,
            builder: (context, on, _) => ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: on,
              leading: const Icon(Icons.lock_outline),
              title: Text(tr('Zablokuj teraz')),
              onTap: AppLock.lockNow,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stan zabezpieczeń telefonu i — jeśli trzeba — jak dodać odcisk palca.
class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capability});

  final LockCapability capability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color, text) = switch (capability) {
      LockCapability.biometric => (
          Icons.verified_user_outlined,
          scheme.primary,
          tr('Odcisk palca jest zapisany w telefonie — blokada działa.'),
        ),
      LockCapability.credentialOnly => (
          Icons.info_outline,
          scheme.tertiary,
          tr('Telefon ma PIN / wzór, ale nie ma odcisku palca. Blokada działa z PIN-em; odcisk będzie szybszy.'),
        ),
      LockCapability.none => (
          Icons.warning_amber_outlined,
          scheme.error,
          tr('Telefon nie ma odcisku palca ani blokady ekranu — blokada aplikacji nie ma czym Cię sprawdzić. Dodaj odcisk palca.'),
        ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(child: Text(text)),
              ],
            ),
            if (capability != LockCapability.biometric) ...[
              const SizedBox(height: 8),
              Text(
                tr('Ustawienia → Zabezpieczenia → Odcisk palca (nazwa zależy od producenta). Przycisk niżej otwiera ten ekran.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: AppLock.openEnrollment,
                  icon: const Icon(Icons.fingerprint),
                  label: Text(tr('Dodaj odcisk palca')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
