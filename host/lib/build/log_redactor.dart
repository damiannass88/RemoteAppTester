/// Redakcja linii logu przed wysłaniem ich do telefonu
/// (docs/architektura-remote-build.md, sekcja 6.9; docs/SECURITY.md).
///
/// Celowo NIEZAWODNE tylko częściowo: to filtr wzorców, nie parser
/// semantyczny środowiska builda — eliminuje najbardziej oczywiste,
/// przypadkowe wycieki (zmienne środowiskowe/argumenty widoczne w logu
/// `flutter build`/`git`), nie gwarantuje wykrycia każdego możliwego
/// sekretu (np. losowego tokena wklejonego w treść commita).
library;

import 'dart:io';

const _hidden = '[REDACTED]';

/// `NAZWA_KEY=wartość`, `password: wartość`, `--token=wartość`,
/// `-Pandroid.injected.signing.store.password=wartość` — nazwa zostaje widoczna
/// (przydaje się przy diagnozie), wartość nie.
final RegExp _assignment = RegExp(
  r'''([A-Za-z0-9_.\-]*(?:PASSWORD|PASSWD|PWD|SECRET|TOKEN|CREDENTIALS?|APIKEY)|[A-Za-z0-9_.\-]*[_.\-](?:KEY|AUTH))'''
  r'''(\s*[=:]\s*)(['"]?)([^\s'"]+)(['"]?)''',
  caseSensitive: false,
);

/// `--password wartość`, `--token wartość` (flaga i wartość rozdzielone spacją).
final RegExp _flagValue = RegExp(
  r'''(--?[A-Za-z0-9\-]*(?:password|passwd|token|secret|api-?key)[A-Za-z0-9\-]*)(\s+)(['"]?)([^\s'"\-][^\s'"]*)(['"]?)''',
  caseSensitive: false,
);

/// `https://uzytkownik:haslo@host` i `https://token@host`.
final RegExp _urlCredentials = RegExp(r'([A-Za-z][A-Za-z0-9+.\-]*://)[^\s/@]+@');

/// `Authorization: Bearer abc`, `Bearer abc`, `Basic abc`.
final RegExp _bearer = RegExp(r'\b(Bearer|Basic)\s+[A-Za-z0-9\-._~+/]{8,}=*', caseSensitive: false);

/// Rozpoznawalne formaty tokenów (GitHub, OpenAI/Anthropic, AWS, Google, Slack, JWT, npm, GitLab).
final RegExp _knownTokens = RegExp(
  r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9\-_]{16,}|sk-[A-Za-z0-9\-_]{16,}'
  r'|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{30,}|xox[abprs]-[A-Za-z0-9\-]{10,}|npm_[A-Za-z0-9]{20,}'
  r'|eyJ[A-Za-z0-9\-_]{8,}\.eyJ[A-Za-z0-9\-_]{8,}\.[A-Za-z0-9\-_]+)\b',
);

/// Treść klucza prywatnego w logu.
final RegExp _privateKey = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*', caseSensitive: false);

/// Katalog domowy (w ścieżkach jest nazwa użytkownika systemu).
final List<String> _homes = [
  for (final name in const ['USERPROFILE', 'HOME'])
    if ((Platform.environment[name] ?? '').length > 1) Platform.environment[name]!,
];

/// Linia logu po usunięciu sekretów i nazwy użytkownika systemu. To filtr
/// wzorców: łapie typowe przypadki, nie gwarantuje wykrycia każdego sekretu.
String redactSecrets(String line) {
  var out = line
      .replaceAll(_privateKey, _hidden)
      .replaceAll(_knownTokens, _hidden)
      .replaceAllMapped(_urlCredentials, (m) => '${m.group(1)}$_hidden@')
      .replaceAllMapped(_bearer, (m) => '${m.group(1)} $_hidden')
      .replaceAllMapped(_flagValue, (m) => '${m.group(1)}${m.group(2)}${m.group(3)}$_hidden${m.group(5)}')
      .replaceAllMapped(_assignment, (m) => '${m.group(1)}${m.group(2)}${m.group(3)}$_hidden${m.group(5)}');
  for (final home in _homes) {
    out = out.replaceAll(RegExp(RegExp.escape(home), caseSensitive: !Platform.isWindows), '~');
  }
  return out;
}
