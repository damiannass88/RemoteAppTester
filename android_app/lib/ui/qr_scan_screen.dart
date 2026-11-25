import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../pairing/pairing_uri.dart';
import '../i18n.dart';

/// Skanowanie kodu QR parowania wyświetlonego w terminalu komputera lub
/// serwera (`remoteapptester pair`). Zwraca [ParsedPairing] przez
/// `Navigator.pop`, albo `null` jeśli użytkownik anuluje.
///
/// Inne kody QR (strony www, bilety itd.) są odrzucane, ale Z KOMUNIKATEM —
/// wcześniej były ignorowane po cichu, co w pierwszym teście na prawdziwym
/// telefonie wyglądało jak "skaner nic nie czyta".
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;
  String? _lastRejected;
  DateTime _lastRejectedAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final parsed = tryParsePairingUri(raw);
      if (parsed != null) {
        _handled = true;
        Navigator.of(context).pop(parsed);
        return;
      }
      _showRejected(raw);
    }
  }

  /// Ten sam niepasujący kod jest widziany wiele razy na sekundę — komunikat
  /// pokazujemy najwyżej raz na 3 s dla danego kodu.
  void _showRejected(String raw) {
    final now = DateTime.now();
    if (raw == _lastRejected && now.difference(_lastRejectedAt) < const Duration(seconds: 3)) return;
    _lastRejected = raw;
    _lastRejectedAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr('Odczytano kod QR, ale to nie jest kod parowania RemoteAppTester.')),
        duration: Duration(seconds: 2),
      ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Skanuj kod QR'))),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        tr('Brak dostępu do aparatu: {0}\n\nUżyj zamiast tego "Wklej ze schowka" na ekranie ustawień (zeskanuj kod dowolną apką aparatu i skopiuj wynik).', [error.errorDetails?.message ?? error.errorCode]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const _WhereIsTheCode(),
        ],
      ),
    );
  }
}

/// Podpowiedź, skąd wziąć kod — pierwszy test pokazał, że nie jest to oczywiste.
class _WhereIsTheCode extends StatelessWidget {
  const _WhereIsTheCode();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Text(
          tr('Skąd wziąć kod?\n• Komputer Windows: w aplikacji RemoteAppTester → Telefony → Sparuj telefon\n• Serwer Linux: w terminalu serwera wpisz  sudo rt pair "Mój telefon"'),
          style: TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}
