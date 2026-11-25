import 'dart:convert';
import 'dart:io';

/// Ile wpisów trzymamy w pliku i ile pokazujemy w tabelce.
const int _maxStored = 50;
const int defaultShown = 8;

class HistoryEntry {
  const HistoryEntry(this.time, this.command, this.exitCode);

  final DateTime time;

  /// Pełne polecenie w formie skróconej, np. `rt b D:\Dev\app`.
  final String command;
  final int exitCode;

  Map<String, Object> toJson() => {'time': time.toIso8601String(), 'command': command, 'exit': exitCode};

  static HistoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final time = DateTime.tryParse('${json['time']}');
    final command = json['command'];
    final exit = json['exit'];
    if (time == null || command is! String || exit is! int) return null;
    return HistoryEntry(time, command, exit);
  }
}

/// Historia ostatnich poleceń (`rt h`, tabelka w `rt help`) — lokalny plik
/// w katalogu danych hosta (`logs/cli_history.json`).
///
/// Prywatność: polecenia RemoteAppTestera nie przyjmują sekretów w argumentach
/// (sekrety parowania tylko się wyświetlają, nigdy nie są wpisywane), więc
/// zapisujemy argumenty bez zmian — to ścieżki folderów i nazwy telefonów.
/// Plik leży obok logu operacji i jak on nie trafia do repozytorium.
class CommandHistory {
  CommandHistory(this._file);

  final File _file;

  List<HistoryEntry> load() {
    try {
      if (!_file.existsSync()) return const [];
      final list = jsonDecode(_file.readAsStringSync());
      if (list is! List) return const [];
      return list.map(HistoryEntry.fromJson).whereType<HistoryEntry>().toList();
    } on Object {
      // Uszkodzony plik historii nie może blokować żadnego polecenia.
      return const [];
    }
  }

  void record(String command, int exitCode) {
    try {
      final entries = [...load(), HistoryEntry(DateTime.now(), command, exitCode)];
      final kept = entries.length > _maxStored ? entries.sublist(entries.length - _maxStored) : entries;
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode([for (final e in kept) e.toJson()]));
    } on Object {
      // Brak zapisu historii (np. katalog tylko do odczytu) nie jest błędem polecenia.
    }
  }

  /// Tabelka ostatnich poleceń, najnowsze na górze. Pusta lista → `null`.
  String? renderTable({int count = defaultShown}) {
    final entries = load().reversed.take(count).toList();
    if (entries.isEmpty) return null;
    final width = entries.map((e) => e.command.length).fold(7, (a, b) => a > b ? a : b).clamp(7, 48);
    final buffer = StringBuffer()
      ..writeln('  Kiedy            ${'Polecenie'.padRight(width)}  Wynik')
      ..writeln('  ${'─' * 16} ${'─' * width}  ${'─' * 5}');
    for (final e in entries) {
      final command = e.command.length > width ? '${e.command.substring(0, width - 1)}…' : e.command;
      buffer.writeln('  ${_formatTime(e.time)} ${command.padRight(width)}  ${e.exitCode == 0 ? 'OK' : 'błąd ${e.exitCode}'}');
    }
    return buffer.toString();
  }

  static String _formatTime(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final l = t.toLocal();
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}
