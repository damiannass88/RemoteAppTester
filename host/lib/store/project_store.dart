import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../discovery/project_traits.dart';
import '../generated/remote_tester.pbenum.dart';
import '../project/agent_guide.dart';
import '../project/agent_signal.dart';
import '../project/build_profile.dart';
import '../project/templates.dart';
import '../security/secret_store.dart';

const projectDbPath = 'data/remotetester.db';
const projectDbKeyPath = 'config/db_key';

enum InstallPolicy { auto, ask, off }

/// Wpis w `targets` oznaczający „żaden telefon” (pusta lista = wszystkie).
const noPhonesTarget = '-';

/// Projekt = folder świadomie przypisany do RemoteAppTestera, z własnymi opcjami.
class ProjectRecord {
  ProjectRecord({
    required this.id,
    required this.name,
    required this.path,
    required this.kind,
    required this.profiles,
    this.install = InstallPolicy.ask,
    this.launch = true,
    this.targets = const [],
    this.phoneTrigger = true,
    this.localTrigger = true,
    this.defaultProfile,
    this.guideHandledHash,
    this.createdAt,
    this.agentBuild = true,
    this.agentPush = true,
    this.changesAt,
    this.agentNote,
    this.agentNoteAt,
    this.preview = true,
    this.previewCommand,
  });

  /// Nieprzezroczysty, losowy identyfikator — jedyne, co o projekcie zna telefon.
  final String id;
  String name;

  /// Kanoniczna ścieżka folderu (nigdy nie trafia na telefon).
  final String path;
  ProjectKind kind;
  List<BuildProfile> profiles;
  InstallPolicy install;
  bool launch;

  /// Docelowe telefony (`device_id`); pusta lista = wszystkie sparowane.
  List<String> targets;
  bool phoneTrigger;
  bool localTrigger;
  String? defaultProfile;
  String? guideHandledHash;
  final DateTime? createdAt;

  /// Opcja: sygnał agenta z prośbą o build sam uruchamia build i wysyłkę.
  bool agentBuild;

  /// Opcja: agent może wysłać na telefony instalkę zbudowaną samodzielnie (`rt push`).
  bool agentPush;

  /// Agent zgłosił zmiany, których nie ma jeszcze w żadnym udanym buildzie.
  final DateTime? changesAt;

  /// Ostatnia notatka agenta (niezaufany tekst — tylko do wyświetlenia).
  final String? agentNote;
  final DateTime? agentNoteAt;

  /// Opcja: telefon może uruchomić podgląd aplikacji web (komendą z bazy hosta).
  bool preview;

  /// Komenda podglądu wpisana na komputerze (`{port}` = port); `null` = rozpoznana automatycznie.
  String? previewCommand;

  bool get changesPending => changesAt != null;

  Directory get directory => Directory(path);

  BuildProfile? profile([String? name]) {
    final wanted = name ?? defaultProfile;
    return profiles.where((p) => p.name == wanted).firstOrNull ?? profiles.firstOrNull;
  }

  bool deliversTo(String deviceId) => targets.isEmpty || targets.contains(deviceId);

  /// Włącza / wyłącza dostawy na jeden telefon. [allDevices] — aktywne telefony
  /// (potrzebne, gdy projekt wysyła „na wszystkie” i jeden trzeba wykluczyć).
  void setDeliversTo(String deviceId, bool on, Iterable<String> allDevices) {
    if (on == deliversTo(deviceId)) return;
    final explicit = targets.isEmpty ? allDevices.toSet() : targets.where((t) => t != noPhonesTarget).toSet();
    on ? explicit.add(deviceId) : explicit.remove(deviceId);
    targets = explicit.isEmpty ? [noPhonesTarget] : (explicit.toList()..sort());
  }
}

/// Wpis historii buildów.
class BuildHistoryEntry {
  const BuildHistoryEntry({
    required this.buildId,
    required this.projectId,
    required this.profile,
    required this.requester,
    required this.startedAt,
    required this.finishedAt,
    required this.phase,
    this.artifactPath,
    this.sha256,
    this.sizeBytes,
  });

  final String buildId;
  final String projectId;
  final String profile;
  final String requester;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String phase;
  final String? artifactPath;
  final String? sha256;
  final int? sizeBytes;
}

class ProjectStoreException implements Exception {
  ProjectStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Zaszyfrowana baza SQLite RemoteAppTestera (SQLite3MultipleCiphers).
///
/// Bezpieczeństwo (docs/SECURITY.md): klucz bazy leży w SecretStore (Windows
/// DPAPI / plik 0600 użytkownika usługi), więc pliku bazy nie przeczyta ani
/// nie zmodyfikuje nic poza RemoteAppTesterem działającym na tym koncie — szyfr
/// uwierzytelnia strony, więc ręczna zmiana pliku = błąd otwarcia, nie ciche
/// podmienienie komend. Komendy budowania zmieniają się wyłącznie przez API
/// tej klasy, wywoływane lokalnymi akcjami użytkownika.
class ProjectStore {
  ProjectStore._(this._db);

  final Database _db;

  /// Otwiera (tworzy) bazę w [home] z kluczem z SecretStore.
  static ProjectStore open({String home = '.', SecretStore? secrets}) {
    final dbFile = File(p.join(home, projectDbPath));
    dbFile.parent.createSync(recursive: true);
    final key = _loadOrCreateKey(File(p.join(home, projectDbKeyPath)), secrets ?? SecretStore.forPlatform());
    _requireCipher();
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute("PRAGMA key = '$key';"); // klucz: 64 znaki hex, bez cudzysłowów
      db.execute('PRAGMA busy_timeout = 5000;');
      db.execute('PRAGMA journal_mode = WAL;');
      db.execute('PRAGMA foreign_keys = ON;');
      _migrate(db);
    } on SqliteException catch (e) {
      db.close();
      throw ProjectStoreException('Nie można otworzyć bazy RemoteAppTestera (${e.message}) — '
          'plik uszkodzony albo zmieniony poza aplikacją: ${dbFile.path}');
    }
    return ProjectStore._(db);
  }

  void close() => _db.close();

  /// Bez wbudowanego szyfrowania `PRAGMA key` zostałby po cichu zignorowany i powstałaby
  /// jawna baza — odmawiamy startu (np. program zbudowany bez `source: sqlite3mc`).
  static void _requireCipher() {
    final probe = sqlite3.openInMemory();
    try {
      probe.select('SELECT sqlite3mc_version()');
    } on SqliteException {
      throw ProjectStoreException('Ta kopia RemoteAppTester nie ma szyfrowanej bazy (SQLite3MultipleCiphers) — '
          'odmowa startu, żeby nie zapisać komend jawnym tekstem.');
    } finally {
      probe.close();
    }
  }

  static String _loadOrCreateKey(File file, SecretStore secrets) {
    if (file.existsSync()) return utf8.decode(secrets.read(file));
    final random = Random.secure();
    final key = List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    file.parent.createSync(recursive: true);
    secrets.write(file, Uint8List.fromList(utf8.encode(key)));
    return key;
  }

  static void _migrate(Database db) {
    final version = db.select('PRAGMA user_version').first.columnAt(0) as int;
    if (version < 1) {
      db.execute('''
        CREATE TABLE projects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          path TEXT NOT NULL UNIQUE,
          kind INTEGER NOT NULL,
          profiles TEXT NOT NULL,
          install TEXT NOT NULL DEFAULT 'auto',
          launch INTEGER NOT NULL DEFAULT 1,
          targets TEXT NOT NULL DEFAULT '[]',
          phone_trigger INTEGER NOT NULL DEFAULT 1,
          local_trigger INTEGER NOT NULL DEFAULT 1,
          default_profile TEXT,
          guide_handled_hash TEXT,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE builds (
          id TEXT PRIMARY KEY,
          project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
          profile TEXT NOT NULL,
          requester TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          finished_at INTEGER,
          phase TEXT NOT NULL,
          artifact_path TEXT,
          sha256 TEXT,
          size_bytes INTEGER
        );
        CREATE INDEX builds_by_project ON builds(project_id, started_at DESC);
        PRAGMA user_version = 1;
      ''');
    }
    if (version < 2) {
      db.execute('''
        ALTER TABLE projects ADD COLUMN agent_build INTEGER NOT NULL DEFAULT 0;
        ALTER TABLE projects ADD COLUMN changes_at INTEGER;
        ALTER TABLE projects ADD COLUMN agent_note TEXT;
        ALTER TABLE projects ADD COLUMN agent_note_at INTEGER;
        PRAGMA user_version = 2;
      ''');
    }
    if (version < 3) {
      // „Sygnał agenta uruchamia build” — domyślnie włączone (także dla istniejących projektów).
      db.execute('''
        UPDATE projects SET agent_build = 1;
        PRAGMA user_version = 3;
      ''');
    }
    if (version < 4) {
      // „Agent może wysłać własną instalkę” (`rt push`) — domyślnie włączone, jak build na sygnał.
      db.execute('''
        ALTER TABLE projects ADD COLUMN agent_push INTEGER NOT NULL DEFAULT 1;
        PRAGMA user_version = 4;
      ''');
    }
    if (version < 5) {
      // Podgląd aplikacji web z telefonu — domyślnie dozwolony, jak budowanie z telefonu.
      db.execute('''
        ALTER TABLE projects ADD COLUMN preview INTEGER NOT NULL DEFAULT 1;
        ALTER TABLE projects ADD COLUMN preview_command TEXT;
        PRAGMA user_version = 5;
      ''');
    }
  }

  // ---------------------------------------------------------------- projekty

  List<ProjectRecord> projects() =>
      [for (final row in _db.select('SELECT * FROM projects ORDER BY name COLLATE NOCASE')) _fromRow(row)];

  ProjectRecord? byId(String id) {
    final rows = _db.select('SELECT * FROM projects WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Projekt, w którego folderze (lub podfolderze) leży [path] — dla `rt b`.
  ProjectRecord? byPath(String path) {
    String canonical;
    try {
      canonical = _canonical(path);
    } on FileSystemException {
      return null;
    }
    ProjectRecord? best;
    for (final project in projects()) {
      if (_sameOrInside(canonical, project.path) && (best == null || project.path.length > best.path.length)) {
        best = project;
      }
    }
    return best;
  }

  /// Przypisuje folder do RemoteAppTestera: wykrywa typ, wpisuje domyślne komendy
  /// i tworzy `REMOTEAPPTESTER.md` (jeśli go nie ma). Istniejący plik zostaje —
  /// jego komendy pojawią się jako propozycja do zatwierdzenia.
  ProjectRecord add(Directory folder, {String? name}) {
    if (!folder.existsSync()) throw ProjectStoreException('Folder nie istnieje: ${folder.path}');
    final canonical = _canonical(folder.path);
    final existing = projects().where((pr) => _samePath(pr.path, canonical)).firstOrNull;
    if (existing != null) throw ProjectStoreException('Ten folder jest już projektem: ${existing.name}');

    final kind = ProjectTraits.detectKind(Directory(canonical));
    final record = ProjectRecord(
      id: _randomId(),
      name: (name == null || name.trim().isEmpty) ? p.basename(canonical) : name.trim(),
      path: canonical,
      kind: kind,
      profiles: templateProfiles(kind),
      createdAt: DateTime.now(),
    );
    record.defaultProfile = record.profiles.first.name;
    _db.execute(
      'INSERT INTO projects (id, name, path, kind, profiles, default_profile, install, agent_build, agent_push, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [record.id, record.name, record.path, kind.value, encodeProfiles(record.profiles), record.defaultProfile,
        record.install.name, record.agentBuild ? 1 : 0, record.agentPush ? 1 : 0, record.createdAt!.millisecondsSinceEpoch],
    );
    final guide = agentGuideFile(record.directory);
    if (!guide.existsSync()) writeAgentGuide(record);
    prepareAgentFiles(record.directory, record.name);
    return record;
  }

  /// Zapisuje opcje projektu (nazwa, instalacja, uruchamianie, telefony, wyzwalacze).
  void saveOptions(ProjectRecord r) {
    if (r.name.trim().isEmpty || r.name.length > 80) throw ProjectStoreException('Nazwa projektu: 1–80 znaków.');
    if (r.defaultProfile != null && !r.profiles.any((p) => p.name == r.defaultProfile)) {
      throw ProjectStoreException('Domyślny wariant nie istnieje: ${r.defaultProfile}');
    }
    _db.execute(
      'UPDATE projects SET name = ?, install = ?, launch = ?, targets = ?, phone_trigger = ?, local_trigger = ?, '
      'default_profile = ?, agent_build = ?, agent_push = ?, preview = ?, preview_command = ? WHERE id = ?',
      [r.name.trim(), r.install.name, r.launch ? 1 : 0, jsonEncode(r.targets), r.phoneTrigger ? 1 : 0,
        r.localTrigger ? 1 : 0, r.defaultProfile, r.agentBuild ? 1 : 0, r.agentPush ? 1 : 0, r.preview ? 1 : 0,
        (r.previewCommand?.trim().isEmpty ?? true) ? null : r.previewCommand!.trim(), r.id],
    );
  }

  /// Zapisuje komendy budowania (edycja w aplikacji = zgoda użytkownika).
  /// Waliduje, a [syncGuide] odświeża też `REMOTEAPPTESTER.md`, żeby agenci AI
  /// widzieli aktualne komendy.
  void saveProfiles(String projectId, List<BuildProfile> profiles, {bool syncGuide = true}) {
    validateProfiles(profiles);
    final record = byId(projectId) ?? (throw ProjectStoreException('Nieznany projekt.'));
    record.profiles = profiles;
    if (!profiles.any((pr) => pr.name == record.defaultProfile)) record.defaultProfile = profiles.first.name;
    _db.execute('UPDATE projects SET profiles = ?, default_profile = ? WHERE id = ?',
        [encodeProfiles(profiles), record.defaultProfile, projectId]);
    if (syncGuide) writeAgentGuide(record);
  }

  /// Stan `REMOTEAPPTESTER.md` (czy agent zaproponował zmiany).
  GuideState guideState(ProjectRecord r) =>
      readAgentGuide(r.directory, current: r.profiles, handledHash: r.guideHandledHash);

  /// Zatwierdzenie propozycji agenta: komendy z pliku trafiają do bazy.
  void importGuide(String projectId, GuideState state) {
    if (state.status != GuideStatus.proposal) throw ProjectStoreException('Brak propozycji do zaimportowania.');
    saveProfiles(projectId, state.profiles, syncGuide: false);
    _setHandledHash(projectId, state.hash);
  }

  /// Odrzucenie propozycji — nie pytamy o tę samą treść ponownie.
  void dismissGuide(String projectId, GuideState state) => _setHandledHash(projectId, state.hash);

  /// Zapisuje `REMOTEAPPTESTER.md` z bieżącymi komendami z bazy.
  void writeAgentGuide(ProjectRecord r) {
    agentGuideFile(r.directory).writeAsStringSync(renderAgentGuide(r.name, r.profiles));
    final state = readAgentGuide(r.directory, current: r.profiles);
    _setHandledHash(r.id, state.hash);
  }

  void _setHandledHash(String projectId, String? hash) =>
      _db.execute('UPDATE projects SET guide_handled_hash = ? WHERE id = ?', [hash, projectId]);

  /// Sygnał agenta: w folderze są zmiany do zbudowania (+ opcjonalna notatka).
  void recordSignal(String projectId, {String? note, DateTime? at}) {
    final when = (at ?? DateTime.now()).millisecondsSinceEpoch;
    _db.execute(
      'UPDATE projects SET changes_at = ?, agent_note = COALESCE(?, agent_note), '
      'agent_note_at = CASE WHEN ? IS NULL THEN agent_note_at ELSE ? END WHERE id = ?',
      [when, note, note, when, projectId],
    );
  }

  /// Udany build objął zmiany zgłoszone przed [before].
  void clearChanges(String projectId, {required DateTime before}) => _db.execute(
      'UPDATE projects SET changes_at = NULL WHERE id = ? AND changes_at <= ?',
      [projectId, before.millisecondsSinceEpoch]);

  /// Typ projektu to tylko informacja — pusty folder mógł w międzyczasie
  /// stać się projektem Flutter. Zwraca `true`, gdy typ się zmienił.
  bool redetectKind(ProjectRecord r) {
    if (r.kind != ProjectKind.OTHER || !r.directory.existsSync()) return false;
    final kind = ProjectTraits.detectKind(r.directory);
    if (kind == r.kind) return false;
    _db.execute('UPDATE projects SET kind = ? WHERE id = ?', [kind.value, r.id]);
    return true;
  }

  /// Usuwa projekt z RemoteAppTestera (pliki na dysku zostają).
  void remove(String projectId) => _db.execute('DELETE FROM projects WHERE id = ?', [projectId]);

  // ---------------------------------------------------------------- historia

  void recordBuild(BuildHistoryEntry e) {
    _db.execute(
      'INSERT OR REPLACE INTO builds (id, project_id, profile, requester, started_at, finished_at, phase, '
      'artifact_path, sha256, size_bytes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [e.buildId, e.projectId, e.profile, e.requester, e.startedAt.millisecondsSinceEpoch,
        e.finishedAt?.millisecondsSinceEpoch, e.phase, e.artifactPath, e.sha256, e.sizeBytes],
    );
    // Historia: ostatnie 50 buildów na projekt.
    _db.execute(
      'DELETE FROM builds WHERE project_id = ? AND id NOT IN '
      '(SELECT id FROM builds WHERE project_id = ? ORDER BY started_at DESC LIMIT 50)',
      [e.projectId, e.projectId],
    );
  }

  List<BuildHistoryEntry> history(String projectId, {int limit = 20}) => [
        for (final row in _db.select(
            'SELECT * FROM builds WHERE project_id = ? ORDER BY started_at DESC LIMIT ?', [projectId, limit]))
          BuildHistoryEntry(
            buildId: row['id'] as String,
            projectId: row['project_id'] as String,
            profile: row['profile'] as String,
            requester: row['requester'] as String,
            startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at'] as int),
            finishedAt: row['finished_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(row['finished_at'] as int),
            phase: row['phase'] as String,
            artifactPath: row['artifact_path'] as String?,
            sha256: row['sha256'] as String?,
            sizeBytes: row['size_bytes'] as int?,
          ),
      ];

  // ---------------------------------------------------------------- pomocnicze

  ProjectRecord _fromRow(Row row) => ProjectRecord(
        id: row['id'] as String,
        name: row['name'] as String,
        path: row['path'] as String,
        kind: ProjectKind.valueOf(row['kind'] as int) ?? ProjectKind.OTHER,
        profiles: decodeProfiles(row['profiles'] as String),
        install: InstallPolicy.values.where((v) => v.name == row['install']).firstOrNull ?? InstallPolicy.auto,
        launch: row['launch'] == 1,
        targets: (jsonDecode(row['targets'] as String) as List).cast<String>(),
        phoneTrigger: row['phone_trigger'] == 1,
        localTrigger: row['local_trigger'] == 1,
        defaultProfile: row['default_profile'] as String?,
        guideHandledHash: row['guide_handled_hash'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        agentBuild: row['agent_build'] == 1,
        agentPush: row['agent_push'] == 1,
        changesAt: _time(row['changes_at']),
        agentNote: row['agent_note'] as String?,
        agentNoteAt: _time(row['agent_note_at']),
        preview: row['preview'] == 1,
        previewCommand: row['preview_command'] as String?,
      );

  static DateTime? _time(Object? ms) => ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static String _canonical(String path) => p.normalize(Directory(path).absolute.resolveSymbolicLinksSync());

  static bool _samePath(String a, String b) => Platform.isWindows ? a.toLowerCase() == b.toLowerCase() : a == b;

  static bool _sameOrInside(String path, String dir) {
    final a = Platform.isWindows ? path.toLowerCase() : path;
    final b = Platform.isWindows ? dir.toLowerCase() : dir;
    return a == b || p.isWithin(b, a);
  }

  static String _randomId() {
    final random = Random.secure();
    return List.generate(12, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Pliki dla agentów AI w folderze projektu: aktualne wytyczne w REMOTEAPPTESTER.md,
/// wzór `.remoteapptester-signal` i wskazówka w CLAUDE.md / AGENTS.md.
void prepareAgentFiles(Directory dir, String projectName) {
  migrateLegacyAgentFiles(dir);
  refreshGuideInstructions(dir, projectName);
  ensureAgentSignalFile(dir);
  ensureAgentPointers(dir);
}
