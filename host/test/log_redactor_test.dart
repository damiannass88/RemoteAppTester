import 'dart:io';

import 'package:remotetester_host/build/log_redactor.dart';
import 'package:test/test.dart';

void main() {
  test('redacts values assigned to *_KEY/*_TOKEN/*_PASSWORD/*_SECRET/*_CREDENTIALS', () {
    expect(redactSecrets('API_KEY=sk_live_abc123'), 'API_KEY=[REDACTED]');
    expect(redactSecrets('GITHUB_TOKEN: ghp_abcdef'), 'GITHUB_TOKEN: [REDACTED]');
    expect(redactSecrets('DB_PASSWORD="hunter2"'), 'DB_PASSWORD="[REDACTED]"');
    expect(redactSecrets('AWS_SECRET=abc/def+ghi'), 'AWS_SECRET=[REDACTED]');
    expect(redactSecrets('SERVICE_CREDENTIALS=xyz'), 'SERVICE_CREDENTIALS=[REDACTED]');
  });

  test('is case-insensitive on the variable name', () {
    expect(redactSecrets('api_key=abc123'), 'api_key=[REDACTED]');
  });

  test('leaves ordinary build output untouched', () {
    const line = 'Running Gradle task \'assembleDebug\'...';
    expect(redactSecrets(line), line);
    const line2 = 'Resolving dependencies...';
    expect(redactSecrets(line2), line2);
  });

  test('does not touch variable names that merely contain but do not end with a keyword', () {
    // "KEYBOARD_LAYOUT" nie kończy się na "_KEY" jako całe słowo-sufiks tej postaci,
    // ale zawiera "KEY" w środku — nie powinno być fałszywie wykryte.
    const line = 'KEYBOARD_LAYOUT=us';
    expect(redactSecrets(line), line);
  });

  test('redacts multiple secrets on the same line', () {
    expect(
      redactSecrets('API_KEY=abc DB_PASSWORD=def'),
      'API_KEY=[REDACTED] DB_PASSWORD=[REDACTED]',
    );
  });

  test('redacts credentials in URLs, bearer headers, flags and known token formats', () {
    expect(redactSecrets('Cloning https://user:hunter2@github.com/a/b.git'), 'Cloning https://[REDACTED]@github.com/a/b.git');
    expect(redactSecrets('Authorization: Bearer abcdefgh12345678'), contains('Bearer [REDACTED]'));
    expect(redactSecrets('gradle --token abcdef123 build'), 'gradle --token [REDACTED] build');
    expect(redactSecrets('-Pandroid.injected.signing.store.password=hunter2'), '-Pandroid.injected.signing.store.password=[REDACTED]');
    expect(redactSecrets('storePassword: hunter2'), 'storePassword: [REDACTED]');
    expect(redactSecrets('found ghp_abcdefghijklmnopqrstuvwxyz123456 in log'), 'found [REDACTED] in log');
    expect(redactSecrets('key sk-ant-abcdefghijklmnopqrstuvwx used'), 'key [REDACTED] used');
    expect(redactSecrets('AKIAIOSFODNN7EXAMPLE'), '[REDACTED]');
    expect(redactSecrets('-----BEGIN RSA PRIVATE KEY----- abc'), '[REDACTED]');
  });

  test('does not hide ordinary words near keywords', () {
    for (final line in ['MONKEY=1', 'Tokens: 123', 'Built build/app/outputs/flutter-apk/app-debug.apk (34.0MB)', 'keyAlias is set']) {
      expect(redactSecrets(line), line);
    }
  });

  test('hides the system user name in paths', () {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null) return;
    expect(redactSecrets('Running in $home${Platform.pathSeparator}project'), 'Running in ~${Platform.pathSeparator}project');
  });
}
