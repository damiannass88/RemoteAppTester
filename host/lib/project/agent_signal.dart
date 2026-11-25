import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../build/log_redactor.dart';
import 'agent_guide.dart';

/// Plik sygnału w folderze projektu. RemoteAppTester trzyma w nim zawsze opisany
/// wzór, więc agent AI widzi go w folderze i wie, co zrobić: po skończonej
/// pracy ustawia `build` i `message` i zapisuje plik (albo `rt sg`).
/// RemoteAppTester odczytuje zmianę w ciągu kilku sekund i przywraca wzór.
///
/// Bezpieczeństwo: to WYŁĄCZNIE sygnał — agent nie dostaje żadnego dostępu
/// do RemoteAppTestera (bazy, tokenu, połączenia). Z pliku bierzemy tylko:
/// - `message` — krótki tekst do wyświetlenia (przycięty, bez znaków sterujących),
/// - `build: true` — prośbę o build, spełnianą tylko gdy pozwalają na to
///   opcje projektu, i to komendami z zaszyfrowanej bazy, nigdy z pliku,
/// - `deliver: <ścieżka .apk>` — instalkę zbudowaną przez samego agenta (`rt push`),
///   przyjmowaną tylko z folderu projektu i tylko gdy pozwala na to opcja projektu,
/// - `request` — identyfikator, pod którym RemoteAppTester zapisze wynik w
///   [agentStatusFileName] (agent czyta go bez dostępu do RemoteAppTestera).
const agentSignalFileName = '.remoteapptester-signal';

/// Wynik ostatniego sygnału (JSON) — zapisuje RemoteAppTester, czyta agent (`rt st`, `--wait`).
const agentStatusFileName = '.remoteapptester-status.json';

/// Kopia instalki spoza folderu projektu, zostawiana przez `rt push`.
const agentPushFileName = '.remoteapptester-push.apk';
const _maxDeliverPathLength = 512;
const _maxSignalBytes = 4096;
const maxAgentNoteLength = 300;

class AgentSignal {
  const AgentSignal({this.build = false, this.message, this.deliver, this.request});
  final bool build;
  final String? message;

  /// Ścieżka instalki zbudowanej przez agenta, względem folderu projektu (niezaufana).
  final String? deliver;

  /// Identyfikator zlecenia dla pliku wyniku ([agentStatusFileName]).
  final String? request;

  /// Wzór bez zmian (`build: false`, pusta notatka) nie jest sygnałem.
  bool get isSignal => build || message != null || deliver != null;
}

File agentSignalFile(Directory projectDir) => File(p.join(projectDir.path, agentSignalFileName));

/// Wzór pliku sygnału — instrukcja dla agenta jest w samym pliku.
String agentSignalTemplate({DateTime? lastReceived}) => '''
# RemoteAppTester — sygnał od agenta AI dla tego folderu (szczegóły: REMOTEAPPTESTER.md).
#
# Po skończonej pracy daj znać RemoteAppTesterowi: zmień dwie wartości poniżej i zapisz plik
# (albo uruchom w tym folderze: rt sg -m "co zmieniono" --build --wait).
#   message — krótko, co zmieniono (do $maxAgentNoteLength znaków, bez sekretów; widać to na telefonie)
#   build   — true = zbuduj i wyślij nową wersję na telefon testowy
#             (zatwierdzonymi komendami z RemoteAppTestera, jeśli pozwalają opcje projektu)
# Instalkę zbudowaną samodzielnie wysyłasz na telefon tak: rt push <plik.apk> -m "co zmieniono" --wait
# (albo dopisz tu: deliver: "ścieżka/do/pliku.apk" względem tego folderu).
# RemoteAppTester odczyta sygnał w ciągu kilku sekund i przywróci ten wzór;
# wynik zapisze w $agentStatusFileName (albo: rt st).
# Nie usuwaj tego pliku; dodaj go do .gitignore (razem z $agentStatusFileName i $agentPushFileName).
${lastReceived == null ? '' : '# Ostatni przyjęty sygnał: ${_stamp(lastReceived)}\n'}
build: false
message: ""
''';

/// Tworzy wzór, jeśli go brak; podmienia dowiązania i katalogi o tej nazwie.
void ensureAgentSignalFile(Directory projectDir) {
  if (!projectDir.existsSync()) return;
  final file = agentSignalFile(projectDir);
  final type = FileSystemEntity.typeSync(file.path, followLinks: false);
  if (type == FileSystemEntityType.file) return;
  try {
    _removeEntity(file.path, type);
    file.writeAsStringSync(agentSignalTemplate());
  } on FileSystemException {
    // Folder tylko do odczytu albo plik zajęty — spróbujemy w kolejnym obiegu.
  }
}

/// Odczytuje sygnał; `null` = brak (wzór bez zmian albo plik jeszcze zapisywany).
/// Po odczycie przywraca wzór. [settle] — ile plik ma „odpocząć” po zapisie,
/// żeby nie czytać go w połowie.
AgentSignal? consumeAgentSignal(Directory projectDir, {Duration settle = const Duration(seconds: 1)}) {
  final file = agentSignalFile(projectDir);
  final type = FileSystemEntity.typeSync(file.path, followLinks: false);
  if (type == FileSystemEntityType.notFound) {
    ensureAgentSignalFile(projectDir);
    return null;
  }
  try {
    if (type != FileSystemEntityType.file) {
      ensureAgentSignalFile(projectDir); // dowiązanie / katalog — nie czytamy
      return null;
    }
    if (DateTime.now().difference(file.lastModifiedSync()) < settle) return null;
    final AgentSignal signal;
    if (file.lengthSync() > _maxSignalBytes) {
      signal = const AgentSignal(message: '(sygnał za duży — pominięto treść)');
    } else {
      signal = parseAgentSignal(file.readAsStringSync());
      if (!signal.isSignal) return null;
    }
    // Przez usunięcie: na serwerze plik mógł zapisać inny użytkownik (agent).
    file.deleteSync();
    file.writeAsStringSync(agentSignalTemplate(lastReceived: DateTime.now()));
    return signal;
  } on FileSystemException {
    return null; // zajęty (agent jeszcze pisze) — w kolejnym obiegu
  }
}

/// `build: true` / `message: "..."` (YAML albo JSON) albo zwykły tekst (= notatka).
AgentSignal parseAgentSignal(String raw) {
  final text = raw.replaceFirst('\uFEFF', '');
  Object? doc;
  try {
    doc = loadYaml(text);
  } on YamlException {
    doc = null;
  }
  if (doc is YamlMap) {
    final message = doc['message'];
    final deliver = doc['deliver'];
    final request = doc['request']?.toString();
    return AgentSignal(
      build: doc['build'] == true,
      message: message == null ? null : sanitizeAgentNote(message.toString()),
      deliver: deliver is String && deliver.trim().isNotEmpty && deliver.length <= _maxDeliverPathLength
          ? deliver.trim()
          : null,
      request: request != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(request) ? request : null,
    );
  }
  final plain = text.split('\n').where((l) => !l.trimLeft().startsWith('#')).join(' ');
  return AgentSignal(message: sanitizeAgentNote(plain));
}

/// Tekst od agenta jest niezaufany: jedna linia, bez znaków sterujących, przycięty.
String? sanitizeAgentNote(String raw) {
  final clean = redactSecrets(raw)
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'[\x00-\x1F\x7F\u200B-\u200F\u202A-\u202E\u2066-\u2069]'), '')
      .replaceAll(RegExp(r' {2,}'), ' ')
      .trim();
  if (clean.isEmpty) return null;
  return clean.length <= maxAgentNoteLength ? clean : '${clean.substring(0, maxAgentNoteLength - 1)}…';
}

/// Folder projektu dla `rt signal`: najbliższy folder w górę z `REMOTEAPPTESTER.md`.
Directory? findProjectRoot(Directory start) {
  var dir = start.absolute;
  while (true) {
    if (agentGuideFile(dir).existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

/// Zapisuje sygnał (używane przez `rt signal` i `rt push` — bez dostępu do bazy hosta).
File writeAgentSignal(Directory projectDir, {bool build = false, String? message, String? deliver, String? request}) {
  final file = agentSignalFile(projectDir);
  final note = sanitizeAgentNote(message ?? '') ?? 'Zmiany gotowe';
  _removeEntity(file.path, FileSystemEntity.typeSync(file.path, followLinks: false));
  file.writeAsStringSync('build: $build\nmessage: ${_yamlString(note)}\n'
      '${deliver == null ? '' : 'deliver: ${_yamlString(deliver)}\n'}'
      '${request == null ? '' : 'request: ${_yamlString(request)}\n'}');
  return file;
}

/// Czy RemoteAppTester odebrał już sygnał [request] (plik wrócił do wzoru albo zawiera inny sygnał).
bool agentSignalConsumed(Directory projectDir, String request) {
  try {
    return !agentSignalFile(projectDir).readAsStringSync().contains(request);
  } on FileSystemException {
    return true;
  }
}

File agentStatusFile(Directory projectDir) => File(p.join(projectDir.path, agentStatusFileName));

/// Zapisuje wynik zlecenia agenta (przez plik tymczasowy, żeby agent nie czytał połowy).
void writeAgentStatus(Directory projectDir, Map<String, Object?> status) {
  final file = agentStatusFile(projectDir);
  final tmp = File('${file.path}.tmp');
  try {
    _removeEntity(tmp.path, FileSystemEntity.typeSync(tmp.path, followLinks: false));
    tmp.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(status)}\n');
    final type = FileSystemEntity.typeSync(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) _removeEntity(file.path, type);
    tmp.renameSync(file.path);
  } on FileSystemException {
    // Folder tylko do odczytu — wynik zostaje w historii i dzienniku RemoteAppTestera.
  }
}

/// Ostatni wynik zapisany przez RemoteAppTester; `null` = brak albo nieczytelny.
Map<String, Object?>? readAgentStatus(Directory projectDir) {
  final file = agentStatusFile(projectDir);
  try {
    if (FileSystemEntity.typeSync(file.path, followLinks: false) != FileSystemEntityType.file) return null;
    final doc = jsonDecode(file.readAsStringSync());
    return doc is Map<String, Object?> ? doc : null;
  } on Object {
    return null;
  }
}

void _removeEntity(String path, FileSystemEntityType type) {
  switch (type) {
    case FileSystemEntityType.directory:
      Directory(path).deleteSync(recursive: true);
    case FileSystemEntityType.link:
      Link(path).deleteSync();
    case FileSystemEntityType.notFound:
      break;
    default:
      File(path).deleteSync();
  }
}

String _yamlString(String value) => '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';

String _stamp(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
String _two(int v) => v.toString().padLeft(2, '0');
