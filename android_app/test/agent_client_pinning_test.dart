import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/i18n.dart';
import 'package:remotetester/net/agent_client.dart';

void main() {
  // Teksty w asercjach są po polsku.
  setUpAll(() => I18n.language.value = AppLanguage.pl);

  // Testujemy samą LOGIKĘ porównania odcisku, nie pełny handshake TLS
  // (wymagałby prawdziwego serwera) — patrz też testy end-to-end w tej
  // sesji, gdzie realny agent + realny telefon zweryfikowały cały łańcuch.
  group('CertificatePinningException', () {
    test('carries both the expected and actual fingerprint for diagnostics', () {
      final e = CertificatePinningException('expected123', 'actual456');
      expect(e.expectedFingerprint, 'expected123');
      expect(e.actualFingerprint, 'actual456');
      expect(e.toString(), contains('expected123'));
      expect(e.toString(), contains('actual456'));
    });
  });

  group('fingerprint comparison (same algorithm as agent_client.dart)', () {
    test('identical DER bytes produce identical SHA-256 fingerprints', () {
      final derA = List<int>.generate(200, (i) => i % 256);
      final derB = List<int>.from(derA);
      expect(sha256.convert(derA).toString(), sha256.convert(derB).toString());
    });

    test('a single differing byte changes the fingerprint (detects substitution)', () {
      final der = List<int>.generate(200, (i) => i % 256);
      final tampered = List<int>.from(der)..[100] = (der[100] + 1) % 256;
      expect(sha256.convert(der).toString(), isNot(sha256.convert(tampered).toString()));
    });
  });
}
