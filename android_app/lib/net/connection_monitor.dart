import 'dart:async';

import 'package:flutter/foundation.dart';

import 'agent_client.dart';

enum ConnectionStatus { checking, connected, disconnected }

/// Health-check: lekki `Ping` co kilka sekund, żeby UI wiedziało
/// "połączono"/"rozłączono" zamiast dowiadywać się o zerwaniu dopiero przy
/// kolejnej akcji użytkownika. Idzie przez ten sam uwierzytelniony
/// [AgentClient.ping] co każde inne wywołanie — TLS pinning + HMAC
/// obowiązują tu tak samo, żaden "lżejszy" tryb sprawdzania nie omija tych
/// warstw.
class ConnectionMonitor extends ChangeNotifier {
  ConnectionMonitor(AgentClient client, {Duration interval = const Duration(seconds: 5)})
      : this._(client.ping, interval: interval);

  /// Wariant do testów — pozwala podstawić fałszywe `ping()` bez żywego
  /// [AgentClient]/połączenia gRPC.
  ConnectionMonitor.withPingFn(Future<void> Function() pingFn, {Duration interval = const Duration(seconds: 5)})
      : this._(pingFn, interval: interval);

  ConnectionMonitor._(this._pingFn, {required this.interval}) {
    _check();
    _timer = Timer.periodic(interval, (_) => _check());
  }

  final Future<void> Function() _pingFn;
  final Duration interval;
  Timer? _timer;

  ConnectionStatus status = ConnectionStatus.checking;

  Future<void> _check() async {
    try {
      await _pingFn();
      _setStatus(ConnectionStatus.connected);
    } catch (_) {
      _setStatus(ConnectionStatus.disconnected);
    }
  }

  void _setStatus(ConnectionStatus next) {
    if (status == next) return;
    status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
