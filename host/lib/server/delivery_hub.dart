import 'dart:async';

import 'package:fixnum/fixnum.dart' as fixnum;

import '../build/build_engine.dart';
import '../generated/remote_tester.pb.dart';
import '../pairing/device_registry.dart';
import '../store/project_store.dart';

/// Co ile host wysyła heartbeat na strumieniu dostaw — telefon po ~3
/// brakujących uznaje połączenie za martwe i łączy się od nowa (np. po
/// zmianie sieci, której TCP sam nie zauważy).
const Duration deliveryHeartbeatInterval = Duration(seconds: 20);

/// Rozsyła gotowe buildy do telefonów (docs/PROJECT_ASSUMPTIONS.md, sekcja 6).
///
/// - Odbiorcy: aktywne (nieodwołane) sparowane telefony wybrane dla builda
///   (okno aplikacji) albo z opcji projektu; zlecający z telefonu instaluje
///   sam ze swojego ekranu builda, więc nie dostaje drugiej, zdublowanej dostawy.
/// - Instalacja `off` w opcjach projektu = bez dostaw, chyba że w oknie
///   aplikacji jawnie wybrano telefony dla tego builda.
/// - Telefon offline: trzymamy tylko NAJNOWSZĄ dostawę per (projekt, urządzenie),
///   do potwierdzenia przez `AckDelivery`. Wyłącznie w pamięci — restart
///   hosta zaczyna od zera (artefaktów i tak nie przechowujemy między restartami).
class DeliveryHub {
  /// [finished] — zakończone buildy, zwykle `BuildEngine.onFinished`.
  DeliveryHub({required Stream<BuildRecord> finished, required this.devices}) {
    _sub = finished.listen(_onBuildFinished);
  }

  final DeviceRegistry devices;
  late final StreamSubscription<BuildRecord> _sub;

  /// (projectId, deviceId) -> zaległa dostawa.
  final Map<(String, String), Delivery> _pending = {};
  final Map<String, Set<StreamController<DeliveryEvent>>> _watchers = {};
  final _acks = StreamController<(String deviceId, String buildId)>.broadcast(sync: true);

  /// Telefon obsłużył dostawę (zainstalował albo użytkownik ją zamknął).
  Stream<(String deviceId, String buildId)> get onAck => _acks.stream;

  int watcherCount(String deviceId) => _watchers[deviceId]?.length ?? 0;

  void _onBuildFinished(BuildRecord record) {
    final artifact = record.artifact;
    if (record.phase != BuildPhase.DONE || artifact == null) return;
    final project = record.project;
    if (project.install == InstallPolicy.off && record.targets == null) return;

    final delivery = Delivery(
      buildId: record.buildId,
      projectId: record.projectId,
      projectName: project.name,
      sizeBytes: fixnum.Int64(artifact.sizeBytes),
      sha256: artifact.sha256Hex,
      install: project.install == InstallPolicy.ask ? InstallMode.ASK : InstallMode.AUTO,
      launch: project.launch,
      builtUnixMs: fixnum.Int64((record.finishedAt ?? DateTime.now()).millisecondsSinceEpoch),
      methodId: record.profile.name,
    );
    for (final device in devices.all) {
      if (device.revoked || device.deviceId == record.requester) continue;
      if (!record.deliversTo(device.deviceId)) continue;
      record.deliveredTo.add(device.deviceId);
      _pending[(record.projectId, device.deviceId)] = delivery;
      for (final watcher in List.of(_watchers[device.deviceId] ?? const <StreamController<DeliveryEvent>>{})) {
        watcher.add(DeliveryEvent(delivery: delivery));
      }
    }
  }

  /// Czy telefon ma teraz otwarty strumień dostaw (jest „online”).
  bool isOnline(String deviceId) => watcherCount(deviceId) > 0;

  /// Strumień dla jednego urządzenia: zaległe dostawy, potem nowe i heartbeat.
  Stream<DeliveryEvent> watch(String deviceId) {
    late final StreamController<DeliveryEvent> controller;
    Timer? heartbeat;
    controller = StreamController<DeliveryEvent>(
      onListen: () {
        _watchers.putIfAbsent(deviceId, () => {}).add(controller);
        controller.add(_heartbeat());
        for (final entry in _pending.entries) {
          if (entry.key.$2 == deviceId) controller.add(DeliveryEvent(delivery: entry.value));
        }
        heartbeat = Timer.periodic(deliveryHeartbeatInterval, (_) => controller.add(_heartbeat()));
      },
      onCancel: () {
        heartbeat?.cancel();
        _watchers[deviceId]?.remove(controller);
      },
    );
    return controller.stream;
  }

  /// `false`, gdy tej dostawy nie było (już potwierdzona albo cudza).
  bool ack(String deviceId, String buildId) {
    final key = _pending.entries.where((e) => e.key.$2 == deviceId && e.value.buildId == buildId).firstOrNull?.key;
    if (key == null) return false;
    _pending.remove(key);
    if (!_acks.isClosed) _acks.add((deviceId, buildId));
    return true;
  }

  Future<void> close() async {
    await _sub.cancel();
    await _acks.close();
    for (final set in _watchers.values) {
      for (final c in List.of(set)) {
        await c.close();
      }
    }
  }

  static DeliveryEvent _heartbeat() =>
      DeliveryEvent(heartbeatUnixMs: fixnum.Int64(DateTime.now().millisecondsSinceEpoch));
}
