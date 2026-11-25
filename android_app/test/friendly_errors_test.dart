import 'package:flutter_test/flutter_test.dart';
import 'package:remotetester/i18n.dart';
import 'package:grpc/grpc.dart';
import 'package:remotetester/net/friendly_errors.dart';

void main() {
  // Teksty w asercjach są po polsku.
  setUpAll(() => I18n.language.value = AppLanguage.pl);

  test('connection timeout (first real-phone test) explains what to check', () {
    final message = friendlyErrorMessage(const GrpcError.unavailable('Error connecting: SocketException: Connection timed out'));
    expect(message, contains('Nie można połączyć się'));
    expect(message, contains('Tailscale'));
    expect(message, isNot(contains('SocketException')));
  });

  test('revoked/unknown device asks to pair again', () {
    expect(friendlyErrorMessage(const GrpcError.unauthenticated()), contains('Sparuj telefon ponownie'));
  });

  test('rate limiting asks to wait', () {
    expect(friendlyErrorMessage(const GrpcError.resourceExhausted()), contains('Odczekaj'));
  });

  test('unknown errors fall back to a generic message, never raw exception text', () {
    expect(friendlyErrorMessage(StateError('x')), 'Wystąpił nieoczekiwany błąd. Spróbuj ponownie.');
  });
}
