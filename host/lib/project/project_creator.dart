import 'dart:io';

import 'package:path/path.dart' as p;

import '../discovery/project_traits.dart';
import '../generated/remote_tester.pbenum.dart';
import '../i18n.dart';
import '../store/project_store.dart';

/// Nazwa folderu projektu: litery, cyfry, spacje, `_ . -`, bez separatorów ścieżki.
final folderNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _.\-]{0,63}$');

const _windowsReserved = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

class ProjectCreationException implements Exception {
  const ProjectCreationException(this.message, {this.alreadyExists = false});
  final String message;
  final bool alreadyExists;
  @override
  String toString() => message;
}

/// Dodawanie projektów z telefonu: wyłącznie foldery bezpośrednio w [root], wskazane
/// samą nazwą. Komendy budowania wpisuje [ProjectStore.add] z szablonów hosta.
class ProjectCreator {
  ProjectCreator(this.store, this.root, {Future<ProcessResult> Function(List<String> args)? flutterCreate})
      : _flutterCreate = flutterCreate ?? _runFlutterCreate;

  final ProjectStore store;
  final Directory root;
  final Future<ProcessResult> Function(List<String> args) _flutterCreate;
  bool _busy = false;

  /// Foldery w [root], które nie są jeszcze projektami (bez ukrytych i dowiązań).
  List<(String, ProjectKind)> availableFolders() {
    if (!root.existsSync()) return const [];
    final taken = store.projects().map((r) => _canonical(r.path)).toSet();
    final result = <(String, ProjectKind)>[];
    for (final entity in root.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (!_validName(name) || taken.contains(_canonical(entity.path))) continue;
      result.add((name, ProjectTraits.detectKind(entity)));
    }
    result.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    return result;
  }

  Future<ProjectRecord> create(String name, ProjectTemplate template) async {
    if (!_validName(name)) {
      throw ProjectCreationException(tr('Nazwa folderu: 1–64 znaki, litery, cyfry, spacje, _ . - (bez ukośników).'));
    }
    if (_busy) throw ProjectCreationException(tr('Trwa tworzenie innego projektu — spróbuj za chwilę.'));
    _busy = true;
    try {
      final dir = Directory(p.join(root.path, name));
      switch (template) {
        case ProjectTemplate.EXISTING_FOLDER:
          if (!availableFolders().any((f) => f.$1 == name)) {
            throw ProjectCreationException(tr('Nie ma takiego wolnego folderu w katalogu projektów.'));
          }
          if (!p.isWithin(_canonical(root.path), _canonical(dir.path))) {
            throw ProjectCreationException(tr('Folder musi leżeć w katalogu projektów.'));
          }
          return store.add(dir, name: name);
        case ProjectTemplate.EMPTY_FOLDER || ProjectTemplate.FLUTTER_APP:
          if (FileSystemEntity.typeSync(dir.path, followLinks: false) != FileSystemEntityType.notFound) {
            throw ProjectCreationException(tr('Folder „{0}” już istnieje.', [name]), alreadyExists: true);
          }
          root.createSync(recursive: true);
          if (template == ProjectTemplate.EMPTY_FOLDER) {
            dir.createSync();
            return store.add(dir, name: name);
          }
          final result = await _flutterCreate(['create', '--project-name', _packageName(name), '--platforms', 'android', '--no-pub', dir.path]);
          if (result.exitCode != 0) {
            // Folder nie istniał przed chwilą — usuwamy tylko to, co zostawił nieudany `flutter create`.
            if (dir.existsSync()) dir.deleteSync(recursive: true);
            throw ProjectCreationException(tr('flutter create nie powiódł się: {0}', ['${result.stderr}'.trim()]));
          }
          return store.add(dir, name: name);
        default:
          throw ProjectCreationException(tr('Nieznany rodzaj projektu.'));
      }
    } on ProjectStoreException catch (e) {
      throw ProjectCreationException(e.message);
    } on ProcessException {
      // Brak Fluttera w PATH usługi (np. VPS zainstalowany bez Fluttera).
      throw ProjectCreationException(tr('Na komputerze/serwerze nie znaleziono Fluttera — zainstaluj go albo wybierz pusty folder.'));
    } on FileSystemException catch (e) {
      // Bez ścieżki systemowej w komunikacie dla telefonu — tylko przyczyna.
      final reason = e.osError?.message.trim() ?? '';
      throw ProjectCreationException(reason.isEmpty
          ? tr('Nie udało się utworzyć folderu w katalogu projektów (sprawdź uprawnienia na komputerze/serwerze).')
          : tr('Nie udało się utworzyć folderu w katalogu projektów: {0}', [reason]));
    } finally {
      _busy = false;
    }
  }

  static bool _validName(String name) {
    if (!folderNamePattern.hasMatch(name)) return false;
    // Windows obcina końcowe kropki i spacje oraz nie pozwala na nazwy urządzeń.
    if (name.endsWith('.') || name.endsWith(' ')) return false;
    return !_windowsReserved.contains(name.split('.').first.toUpperCase());
  }

  /// Nazwa pakietu Dart: małe litery, cyfry, podkreślenia, nie od cyfry.
  static String _packageName(String name) {
    final package = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_').replaceFirst(RegExp(r'^[0-9_]+'), '');
    return package.isEmpty ? 'app' : package;
  }

  static String _canonical(String path) {
    try {
      return Directory(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return p.normalize(p.absolute(path));
    }
  }

  static Future<ProcessResult> _runFlutterCreate(List<String> args) =>
      Process.run('flutter', args, runInShell: Platform.isWindows);
}
