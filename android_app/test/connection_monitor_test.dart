import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/net/connection_monitor.dart';

void main() {
  test('starts as checking, then connected once the first ping succeeds', () async {
    final monitor = ConnectionMonitor.withPingFn(
      () async {},
      interval: const Duration(hours: 1), // nie chcemy tu tickować w tle
    );
    addTearDown(monitor.dispose);

    expect(monitor.status, ConnectionStatus.checking);
    // Pierwsze sprawdzenie odpala się synchronicznie w konstruktorze, ale
    // samo `ping()` jest asynchroniczne — pozwól mikrotaskom się rozwiązać.
    await Future<void>.delayed(Duration.zero);

    expect(monitor.status, ConnectionStatus.connected);
  });

  test('becomes disconnected if the ping throws', () async {
    final monitor = ConnectionMonitor.withPingFn(
      () async => throw Exception('unreachable'),
      interval: const Duration(hours: 1),
    );
    addTearDown(monitor.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(monitor.status, ConnectionStatus.disconnected);
  });

  test('notifies listeners only when the status actually changes', () async {
    var notifications = 0;
    var succeed = true;
    final monitor = ConnectionMonitor.withPingFn(
      () async {
        if (!succeed) throw Exception('down');
      },
      interval: const Duration(milliseconds: 20),
    );
    addTearDown(monitor.dispose);
    await Future<void>.delayed(Duration.zero); // primeruje pierwszy check -> connected

    monitor.addListener(() => notifications++);

    // Kilka kolejnych tików z tym samym wynikiem (connected) — bez zmiany
    // stanu, więc bez powiadomień.
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(notifications, 0);

    succeed = false;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(notifications, greaterThanOrEqualTo(1));
    expect(monitor.status, ConnectionStatus.disconnected);
  });

  test('recovers back to connected after the ping starts succeeding again', () async {
    var succeed = false;
    final monitor = ConnectionMonitor.withPingFn(
      () async {
        if (!succeed) throw Exception('down');
      },
      interval: const Duration(milliseconds: 20),
    );
    addTearDown(monitor.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(monitor.status, ConnectionStatus.disconnected);

    succeed = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(monitor.status, ConnectionStatus.connected);
  });
}
