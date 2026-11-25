/// Ochrona przed nadużyciem i brute-force (docs/architektura-remote-build.md,
/// sekcja 6.6; docs/SECURITY.md).
///
/// Dwa niezależne mechanizmy:
///   - **Rate limiting** per `device_id` — chroni przed jednym
///     nadgorliwym/wadliwym SPAROWANYM urządzeniem zajmującym zasoby agenta.
///   - **Lockout** per adres źródłowy (IP) — chroni przed zgadywaniem
///     `device_id` (device_id jest losowe i zmienia się między próbami przy
///     takim ataku, więc śledzenie po device_id nic by tu nie dało; adres IP
///     w obrębie tailnetu jest za to stabilny per urządzenie).
class RateLimitExceededException implements Exception {
  RateLimitExceededException(this.message);
  final String message;
  @override
  String toString() => 'RateLimitExceededException: $message';
}

class LockedOutException implements Exception {
  LockedOutException(this.message);
  final String message;
  @override
  String toString() => 'LockedOutException: $message';
}

class RateLimiter {
  RateLimiter({
    required this.maxRequestsPerMinutePerDevice,
    this.maxFailuresBeforeLockout = 5,
    this.failureWindow = const Duration(minutes: 1),
    this.lockoutDuration = const Duration(minutes: 5),
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  final int maxRequestsPerMinutePerDevice;
  final int maxFailuresBeforeLockout;
  final Duration failureWindow;
  final Duration lockoutDuration;
  final DateTime Function() _now;

  final Map<String, List<DateTime>> _requestTimestampsByDevice = {};
  final Map<String, List<DateTime>> _failureTimestampsBySource = {};
  final Map<String, DateTime> _lockedUntilBySource = {};
  final Map<String, DateTime> _lastLogByKey = {};

  /// Rzuca [LockedOutException], jeśli `sourceKey` jest aktualnie zablokowane
  /// po serii nieudanych prób uwierzytelnienia.
  void checkNotLockedOut(String sourceKey) {
    final until = _lockedUntilBySource[sourceKey];
    if (until != null && _now().isBefore(until)) {
      throw LockedOutException(
        'Zbyt wiele nieudanych prób — zablokowane do ${until.toIso8601String().substring(11, 19)}.',
      );
    }
  }

  /// Wywoływane po KAŻDEJ nieudanej próbie uwierzytelnienia (brak nagłówka,
  /// nieznane lub odwołane urządzenie). Po przekroczeniu progu w oknie
  /// czasowym blokuje `sourceKey` na [lockoutDuration].
  void recordAuthFailure(String sourceKey) {
    final now = _now();
    final timestamps = _failureTimestampsBySource.putIfAbsent(sourceKey, () => []);
    timestamps.add(now);
    timestamps.removeWhere((t) => now.difference(t) > failureWindow);

    if (timestamps.length >= maxFailuresBeforeLockout) {
      _lockedUntilBySource[sourceKey] = now.add(lockoutDuration);
    }
  }

  /// `true` najwyżej raz na [every] dla danego klucza — powtarzalne odrzucenia
  /// (telefon ponawiający co sekundę) nie zalewają logu audytowego.
  bool shouldLog(String key, {Duration every = const Duration(minutes: 5)}) {
    final now = _now();
    final last = _lastLogByKey[key];
    if (last != null && now.difference(last) < every) return false;
    _lastLogByKey[key] = now;
    return true;
  }

  /// Rzuca [RateLimitExceededException], jeśli sparowane urządzenie
  /// przekroczyło swój limit żądań/minutę.
  void checkRequestAllowed(String deviceId) {
    final now = _now();
    final timestamps = _requestTimestampsByDevice.putIfAbsent(deviceId, () => []);
    timestamps.removeWhere((t) => now.difference(t) > const Duration(minutes: 1));

    if (timestamps.length >= maxRequestsPerMinutePerDevice) {
      throw RateLimitExceededException(
        'Przekroczono limit $maxRequestsPerMinutePerDevice żądań/minutę dla tego urządzenia.',
      );
    }
    timestamps.add(now);
  }
}
