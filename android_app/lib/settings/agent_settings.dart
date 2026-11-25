import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adres agenta — NIE jest sekretem, zwykłe SharedPreferences wystarczą
/// (docs/PROJECT_ASSUMPTIONS.md, sekcja 8).
class AgentAddress {
  const AgentAddress({required this.host, required this.port});

  final String host;
  final int port;

  static const _hostKey = 'agent_host';
  static const _portKey = 'agent_port';

  static Future<AgentAddress?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString(_hostKey);
    final port = prefs.getInt(_portKey);
    if (host == null || port == null) return null;
    return AgentAddress(host: host, port: port);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
  }
}

/// `device_id` + `pairing_secret` otrzymane przy parowaniu (`remoteapptester pair`
/// na hoście) — trzymane w Android Keystore przez `flutter_secure_storage`,
/// NIGDY w SharedPreferences (docs/architektura-remote-build.md, sekcja 5/6.9).
/// `pairing_secret` podpisuje każde żądanie (HMAC z nonce/timestamp,
/// `pairing/hmac_auth.dart`).
class DeviceCredentials {
  const DeviceCredentials({required this.deviceId, required this.pairingSecret});

  final String deviceId;
  final String pairingSecret;

  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'device_id';
  static const _pairingSecretKey = 'pairing_secret';

  static Future<DeviceCredentials?> load() async {
    final deviceId = await _storage.read(key: _deviceIdKey);
    final pairingSecret = await _storage.read(key: _pairingSecretKey);
    if (deviceId == null || pairingSecret == null) return null;
    return DeviceCredentials(deviceId: deviceId, pairingSecret: pairingSecret);
  }

  Future<void> save() async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
    await _storage.write(key: _pairingSecretKey, value: pairingSecret);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _deviceIdKey);
    await _storage.delete(key: _pairingSecretKey);
  }
}

/// Odcisk SHA-256 certyfikatu TLS hosta, przypięty raz przy parowaniu —
/// źródło zaufania niezależne od Tailscale (docs/architektura-remote-build.md,
/// sekcja 6.3). Trzymany w Keystore jak reszta danych parowania —
/// to integralność, na której opiera się cała reszta bezpieczeństwa kanału,
/// więc traktujemy ją tak samo ostrożnie jak sam sekret.
class PinnedCertificate {
  const PinnedCertificate({required this.fingerprintSha256Hex});

  final String fingerprintSha256Hex;

  static const _storage = FlutterSecureStorage();
  static const _fingerprintKey = 'tls_cert_fingerprint';

  static Future<PinnedCertificate?> load() async {
    final fp = await _storage.read(key: _fingerprintKey);
    if (fp == null) return null;
    return PinnedCertificate(fingerprintSha256Hex: fp);
  }

  Future<void> save() async {
    await _storage.write(key: _fingerprintKey, value: fingerprintSha256Hex);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _fingerprintKey);
  }
}
