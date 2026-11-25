import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

import 'secret_store.dart';

/// Samopodpisany certyfikat TLS agenta, generowany raz przy pierwszym
/// uruchomieniu i trzymany na dysku (docs/architektura-remote-build.md,
/// sekcja 6.3). Odcisk (fingerprint) SHA-256 jest tym, co telefon
/// faktycznie "pina" przy parowaniu (przenoszony w kodzie QR — patrz
/// `pairing/pairing_uri.dart`) — źródło zaufania NIEZALEŻNE od Tailscale.
///
/// Certyfikat (`config/tls_cert.pem`) zostaje w plaintext — jest z definicji
/// publiczny, wysyłany telefonowi przy każdym połączeniu TLS. Klucz prywatny
/// (`config/tls_key.pem`) jest chroniony przez [SecretStore] — na
/// Windows nieczytelny blob DPAPI związany z kontem Windows, na Linuxie plik
/// `0600` dostępny wyłącznie dla użytkownika agenta.
class TlsIdentity {
  TlsIdentity._({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.fingerprintSha256Hex,
  });

  final String certificatePem;
  final String privateKeyPem;

  /// Odcisk SHA-256 certyfikatu (nad bajtami DER, nie nad tekstem PEM) —
  /// zapisywany małymi literami hex, bez separatorów. To dokładnie ta
  /// wartość, którą klient musi zobaczyć w kodzie QR i przypiąć.
  final String fingerprintSha256Hex;

  static TlsIdentity loadOrGenerate({
    required File certFile,
    required File keyFile,
    SecretStore? secretStore,
  }) {
    final store = secretStore ?? SecretStore.forPlatform();
    if (certFile.existsSync() && keyFile.existsSync()) {
      final certPem = certFile.readAsStringSync();
      return TlsIdentity._(
        certificatePem: certPem,
        privateKeyPem: _loadPrivateKey(keyFile, store),
        fingerprintSha256Hex: _fingerprintOf(certPem),
      );
    }

    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;

    final csrPem = X509Utils.generateRsaCsrPem(
      {'CN': 'remote-build-agent'},
      privateKey,
      publicKey,
    );
    // 10 lat — pinning nie ma jeszcze mechanizmu rotacji; długa
    // ważność jest tu bezpieczniejsza niż ryzyko wygaśnięcia bez wygodnego
    // sposobu ponownego sparowania wszystkich urządzeń.
    final certPem = X509Utils.generateSelfSignedCertificate(privateKey, csrPem, 3650);
    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privateKey);

    certFile.parent.createSync(recursive: true);
    certFile.writeAsStringSync(certPem);
    store.write(keyFile, Uint8List.fromList(utf8.encode(keyPem)));

    return TlsIdentity._(
      certificatePem: certPem,
      privateKeyPem: keyPem,
      fingerprintSha256Hex: _fingerprintOf(certPem),
    );
  }

  /// Odczytuje klucz prywatny spod ochrony [SecretStore]. Plik będący zwykłym
  /// plaintext PEM (sprzed wprowadzenia szyfrowania) jest jednorazowo i
  /// transparentnie migrowany przez store. Każdy INNY błąd (uszkodzony blob,
  /// inne konto Windows, zbyt szerokie uprawnienia pliku na Linuxie)
  /// propaguje się dalej — nie ma go czym bezpiecznie "naprawić" po cichu.
  static String _loadPrivateKey(File keyFile, SecretStore store) {
    final bytes = store.read(keyFile, isLegacyPlaintext: (raw) {
      return utf8.decode(raw, allowMalformed: true).trimLeft().startsWith('-----BEGIN');
    });
    return utf8.decode(bytes);
  }

  static String _fingerprintOf(String certPem) {
    final der = _pemToDer(certPem);
    return sha256.convert(der).toString();
  }

  static List<int> _pemToDer(String pem) {
    // split('\n') zostawia końcowe '\r' na Windows, co base64.decode
    // odrzuca jako nieprawidłowy znak — stąd trim() per linia, nie tylko
    // odcięcie nagłówka/stopki. Zweryfikowane empirycznie (padło na
    // realnie wygenerowanym certyfikacie, nie na przykładzie z palca).
    final lines = pem
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('-----'))
        .join();
    return base64.decode(lines);
  }
}
