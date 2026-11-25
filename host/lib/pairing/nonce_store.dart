/// Krótkotrwała pamięć widzianych nonce, żeby odrzucać duplikaty w oknie
/// ważności żądania (docs/architektura-remote-build.md, sekcja 6.4). Klucz
/// to `deviceId:nonce` — nonce jest losowe per żądanie, ale nie globalnie
/// unikalne między urządzeniami z definicji (każde ma własny licznik), więc
/// przestrzeń kluczy musi być per-device.
class NonceStore {
  NonceStore({
    this.retention = const Duration(minutes: 5),
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final Duration retention;
  final DateTime Function() _now;
  final Map<String, DateTime> _seenAt = {};

  /// Zwraca `true` i zapamiętuje nonce, jeśli nie był jeszcze widziany dla
  /// tego urządzenia; `false` jeśli to duplikat (replay).
  bool checkAndRecord(String deviceId, String nonceHex) {
    _evictExpired();
    final key = '$deviceId:$nonceHex';
    if (_seenAt.containsKey(key)) return false;
    _seenAt[key] = _now();
    return true;
  }

  void _evictExpired() {
    final cutoff = _now().subtract(retention);
    _seenAt.removeWhere((_, seenAt) => seenAt.isBefore(cutoff));
  }
}
