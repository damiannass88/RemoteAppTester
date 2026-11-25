import 'package:remotetester_host/server/kill_switch.dart';
import 'package:test/test.dart';

void main() {
  test('starts not paused', () {
    expect(KillSwitch().isPaused, isFalse);
  });

  test('pause() sets isPaused and notifies listeners exactly once', () {
    final killSwitch = KillSwitch();
    var notifications = 0;
    killSwitch.addListener(() => notifications++);

    killSwitch.pause();

    expect(killSwitch.isPaused, isTrue);
    expect(notifications, 1);
  });

  test('pause() called twice in a row only notifies once (no-op the second time)', () {
    final killSwitch = KillSwitch();
    var notifications = 0;
    killSwitch.addListener(() => notifications++);

    killSwitch.pause();
    killSwitch.pause();

    expect(notifications, 1);
  });

  test('resume() clears isPaused and notifies listeners', () {
    final killSwitch = KillSwitch()..pause();
    var notifications = 0;
    killSwitch.addListener(() => notifications++);

    killSwitch.resume();

    expect(killSwitch.isPaused, isFalse);
    expect(notifications, 1);
  });

  test('resume() on an already-running switch is a no-op (no notification)', () {
    final killSwitch = KillSwitch();
    var notifications = 0;
    killSwitch.addListener(() => notifications++);

    killSwitch.resume();

    expect(notifications, 0);
  });

  test('toggle() flips state each call', () {
    final killSwitch = KillSwitch();
    expect(killSwitch.isPaused, isFalse);
    killSwitch.toggle();
    expect(killSwitch.isPaused, isTrue);
    killSwitch.toggle();
    expect(killSwitch.isPaused, isFalse);
  });
}
