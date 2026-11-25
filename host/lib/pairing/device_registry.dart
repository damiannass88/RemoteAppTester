import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../security/secret_store.dart';

/// Rejestr sparowanych urządzeń (docs/architektura-remote-build.md, sekcja 4a).
/// Każde urządzenie ma WŁASNY `pairingSecret` — odwołanie jednego nie
/// wpływa na pozostałe.
///
/// Plik na dysku (`config/paired_devices.json`) jest chroniony przez
/// [SecretStore]: DPAPI na Windows, plik `0600` na Linuxie — nie
/// plaintext JSON czytelny dla innych. Istniejące pliki plaintext sprzed Fazy
/// 4 są migrowane transparentnie przy pierwszym odczycie, patrz [_load].
///
/// Rejestr może być zmieniany przez DWA procesy naraz: działającą usługę
/// i lokalne CLI (`remoteapptester pair` / `remoteapptester revoke`). Stąd
/// ponowne wczytanie pliku, gdy zmienił się na dysku od naszego ostatniego
/// odczytu/zapisu — bez tego nowo sparowany telefon nie zostałby wpuszczony,
/// a odwołany nadal by przechodził, do czasu restartu usługi.
/// Ile ważny jest kod parowania (QR / link), jeśli telefon jeszcze go nie użył.
const pairingCodeValidity = Duration(hours: 1);

class PairedDevice {
  PairedDevice({
    required this.deviceId,
    required this.displayName,
    required this.pairingSecret,
    required this.createdAt,
    required this.lastSeenAt,
    this.revoked = false,
    this.pendingSecret,
    this.pairingExpiresAt,
  });

  final String deviceId;
  final String displayName;
  String pairingSecret;

  /// Nowy sekret wydany telefonowi. Zastępuje [pairingSecret] przy pierwszym
  /// żądaniu nim podpisanym — dzięki temu zerwane połączenie w trakcie zmiany
  /// nie odcina telefonu.
  String? pendingSecret;

  /// Do kiedy ważny jest kod parowania; `null` = telefon już go wymienił na własny sekret.
  DateTime? pairingExpiresAt;

  /// Czy telefon czeka jeszcze na pierwsze połączenie.
  bool get awaitingFirstUse => pairingExpiresAt != null;
  bool get pairingCodeExpired => pairingExpiresAt != null && DateTime.now().isAfter(pairingExpiresAt!);

  final DateTime createdAt;
  DateTime lastSeenAt;
  bool revoked;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'display_name': displayName,
        'pairing_secret': pairingSecret,
        'created_at': createdAt.toIso8601String(),
        'last_seen_at': lastSeenAt.toIso8601String(),
        'revoked': revoked,
        if (pendingSecret != null) 'pending_secret': pendingSecret,
        if (pairingExpiresAt != null) 'pairing_expires_at': pairingExpiresAt!.toIso8601String(),
      };

  static PairedDevice fromJson(Map<String, dynamic> json) => PairedDevice(
        deviceId: json['device_id'] as String,
        displayName: json['display_name'] as String,
        pairingSecret: json['pairing_secret'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
        revoked: (json['revoked'] as bool?) ?? false,
        pendingSecret: json['pending_secret'] as String?,
        pairingExpiresAt: json['pairing_expires_at'] == null ? null : DateTime.parse(json['pairing_expires_at'] as String),
      );
}

class DeviceRegistry {
  DeviceRegistry(this._storeFile, {SecretStore? secretStore})
      : _secretStore = secretStore ?? SecretStore.forPlatform() {
    _load();
  }

  final File _storeFile;
  final SecretStore _secretStore;
  DateTime? _lastSyncedModified;
  final Map<String, PairedDevice> _devices = {};
  final Random _random = Random.secure();

  void _load() {
    _devices.clear();
    if (!_storeFile.existsSync()) return;
    if (_storeFile.lengthSync() == 0) return;

    // Plik sprzed wprowadzenia ochrony — jeśli faktycznie wygląda na
    // plaintext JSON, SecretStore migruje go transparentnie zamiast tracić już
    // sparowane urządzenia; każdy INNY błąd propaguje się dalej.
    final bytes = _secretStore.read(_storeFile, isLegacyPlaintext: (raw) {
      final asText = utf8.decode(raw, allowMalformed: true).trim();
      return asText.startsWith('[') || asText.startsWith('{');
    });
    _lastSyncedModified = _storeFile.lastModifiedSync();
    final content = utf8.decode(bytes);
    if (content.trim().isEmpty) return;

    final list = jsonDecode(content) as List<dynamic>;
    for (final entry in list) {
      final device = PairedDevice.fromJson(entry as Map<String, dynamic>);
      _devices[device.deviceId] = device;
    }
  }

  /// Wczytuje plik ponownie, jeśli ktoś inny (drugi proces) zmienił go od
  /// naszego ostatniego odczytu/zapisu.
  void _reloadIfChangedOnDisk() {
    if (!_storeFile.existsSync()) return;
    if (_storeFile.lastModifiedSync() != _lastSyncedModified) _load();
  }

  void _persist() {
    final list = _devices.values.map((d) => d.toJson()).toList();
    final content = const JsonEncoder.withIndent('  ').convert(list);
    _secretStore.write(_storeFile, Uint8List.fromList(utf8.encode(content)));
    _lastSyncedModified = _storeFile.lastModifiedSync();
  }

  /// Parowanie nowego urządzenia — WYŁĄCZNIE wywoływane lokalnie (CLI/GUI na
  /// tej maszynie), nigdy przez sieć (docs/architektura-remote-build.md,
  /// sekcja 4a: "Nowe parowanie zawsze wymaga fizycznego dostępu do
  /// komputera").
  PairedDevice register(String displayName) {
    _reloadIfChangedOnDisk();
    final deviceId = _randomToken(16);
    final secret = _randomToken(32);
    final now = DateTime.now();
    final device = PairedDevice(
      deviceId: deviceId,
      displayName: displayName,
      pairingSecret: secret,
      createdAt: now,
      lastSeenAt: now,
      pairingExpiresAt: now.add(pairingCodeValidity),
    );
    _devices[deviceId] = device;
    _persist();
    return device;
  }

  /// Odwołanie POJEDYNCZEGO urządzenia — nie wpływa na pozostałe sparowane
  /// urządzenia (sekcja 6.5).
  bool revoke(String deviceId) {
    _reloadIfChangedOnDisk();
    final device = _devices[deviceId];
    if (device == null) return false;
    device.revoked = true;
    _persist();
    return true;
  }

  /// Zwraca urządzenie tylko jeśli istnieje i nie zostało odwołane;
  /// aktualizuje `last_seen_at`.
  PairedDevice? authenticate(String deviceId) {
    _reloadIfChangedOnDisk();
    final device = _devices[deviceId];
    if (device == null || device.revoked) return null;
    device.lastSeenAt = DateTime.now();
    _persist();
    return device;
  }

  /// Stan urządzenia bez aktualizacji `last_seen_at` (np. przed blokadą adresu).
  DeviceStatus status(String deviceId) {
    _reloadIfChangedOnDisk();
    final device = _devices[deviceId];
    if (device == null) return DeviceStatus.unknown;
    if (device.revoked) return DeviceStatus.revoked;
    // Z wydanym nowym sekretem telefon może jeszcze dokończyć wymianę.
    if (device.pairingCodeExpired && device.pendingSecret == null) return DeviceStatus.expired;
    return DeviceStatus.active;
  }

  /// Wydaje telefonowi nowy sekret (ten sam, dopóki telefon go nie użyje —
  /// utracona odpowiedź nie psuje wymiany).
  String beginRotation(String deviceId) {
    _reloadIfChangedOnDisk();
    final device = _devices[deviceId]!;
    final secret = device.pendingSecret ??= _randomToken(32);
    _persist();
    return secret;
  }

  /// Telefon podpisał żądanie nowym sekretem: stary (także kod z QR) przestaje działać.
  PairedDevice completeRotation(String deviceId) {
    _reloadIfChangedOnDisk();
    final device = _devices[deviceId]!;
    device
      ..pairingSecret = device.pendingSecret!
      ..pendingSecret = null
      ..pairingExpiresAt = null;
    _persist();
    return device;
  }

  List<PairedDevice> get all {
    _reloadIfChangedOnDisk();
    return _devices.values.toList(growable: false);
  }

  String _randomToken(int bytes) {
    final values = List<int>.generate(bytes, (_) => _random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }
}

enum DeviceStatus { unknown, active, revoked, expired }
