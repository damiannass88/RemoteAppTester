import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../preview/preview_manager.dart';
import 'agent_signal.dart';
import 'build_profile.dart';

const agentGuideFileName = 'REMOTEAPPTESTER.md';
const _begin = '<!-- remoteapptester:begin -->';
const _end = '<!-- remoteapptester:end -->';
const _maxGuideBytes = 128 * 1024;

/// Stan pliku `REMOTEAPPTESTER.md` względem komend zapisanych w bazie.
enum GuideStatus {
  /// Brak pliku w folderze.
  missing,

  /// Blok komend zgodny z bazą albo już obsłużony (zaimportowany / odrzucony).
  inSync,

  /// Agent (albo człowiek) zmienił komendy — czekają na zatwierdzenie w aplikacji.
  proposal,

  /// Blok komend niepoprawny — RemoteAppTester nic z nim nie zrobi.
  invalid,
}

class GuideState {
  const GuideState(this.status, {this.profiles = const [], this.hash, this.error});
  final GuideStatus status;

  /// Propozycja z pliku (dla [GuideStatus.proposal]).
  final List<BuildProfile> profiles;

  /// Skrót bloku komend — zapamiętywany po imporcie/odrzuceniu.
  final String? hash;
  final String? error;
}

File agentGuideFile(Directory projectDir) => File(p.join(projectDir.path, agentGuideFileName));

/// Treść `REMOTEAPPTESTER.md`: wytyczne dla agentów AI pracujących w folderze i
/// blok z komendami do uzupełnienia/poprawienia.
///
/// Bezpieczeństwo: plik jest TYLKO propozycją. RemoteAppTester nigdy nie
/// uruchamia komend prosto z niego — po zmianie pokazuje je w aplikacji i
/// zapisuje do zaszyfrowanej bazy dopiero po zatwierdzeniu przez użytkownika.
String renderAgentGuide(String projectName, List<BuildProfile> profiles) {
  final yamlBlock = StringBuffer('profiles:\n');
  for (final profile in profiles) {
    yamlBlock
      ..writeln('  - name: ${_yamlString(profile.name)}')
      ..writeln('    steps:');
    for (final step in profile.steps) {
      yamlBlock
        ..writeln('      - name: ${_yamlString(step.name)}')
        ..writeln('        run: ${_yamlString(step.run)}');
    }
    yamlBlock.writeln('    artifact: ${_yamlString(profile.artifact)}');
  }
  return '''
# RemoteAppTester — jak zbudować „$projectName”

Ten folder jest przypisany do **RemoteAppTester**: aplikacja buduje z niego instalkę Android (APK)
i wysyła ją na telefon testowy, gdzie jest instalowana i (opcjonalnie) uruchamiana.

## Dla agentów AI pracujących w tym folderze

1. Utrzymuj poniższy blok `remoteapptester` aktualny: komendy, które budują **aktualny stan**
   projektu do pliku APK, oraz ścieżkę do tego pliku.
2. Zasady bloku:
   - `steps` — kolejne kroki; każdy `run` to **jedna linia** polecenia
     (${Platform.isWindows ? 'cmd.exe na Windows' : 'bash na Linuxie'}), uruchamiana w tym folderze;
   - `artifact` — ścieżka pliku `.apk` względem tego folderu; `*` = dowolna nazwa w katalogu,
     `**` = dowolna głębokość (np. `build/**/app-debug.apk`);
   - kilka wariantów (np. Debug / Release) = kilka pozycji na liście `profiles`;
   - buduj tylko pod architekturę telefonu (Flutter: `--target-platform android-arm64`) —
     bez tego instalka zawiera 3 silniki i jest ~2× większa;
   - bez sekretów (haseł, kluczy, tokenów) w komendach.
3. **Po skończonej pracy daj znać RemoteAppTesterowi.** W tym folderze leży plik
   `$agentSignalFileName` z opisanym wzorem — ustaw w nim:
   ```yaml
   build: true                       # zbuduj i wyślij nową wersję na telefon
   message: "Dodano ekran logowania" # krótko: co zmieniono
   ```
   i zapisz plik. Albo uruchom w tym folderze: `rt sg -m "co zmieniono" --build`.
   RemoteAppTester odczyta sygnał w ciągu kilku sekund, przywróci wzór, oznaczy projekt jako
   „nowe zmiany” na komputerze i telefonie i — jeśli pozwalają opcje projektu (domyślnie tak) —
   zbuduje i wyśle aplikację. `build: false` z samą notatką = tylko informacja, bez builda.
   To tylko sygnał: nie daje dostępu do RemoteAppTestera, a build zawsze idzie
   zatwierdzonymi komendami z aplikacji, nie z tego pliku. Notatka ma być krótka
   (do $maxAgentNoteLength znaków) i bez sekretów — pokazuje się na telefonie.
   Dodaj `--wait`, żeby poczekać na wynik builda (kod wyjścia 0 = wysłane na telefon).
4. **Sam zbudowałeś APK?** Wyślij go na telefon testowy bez builda w RemoteAppTesterze:
   ```sh
   rt push build/app/outputs/flutter-apk/app-debug.apk -m "co zmieniono" --wait --json
   ```
   Bez ścieżki = najnowszy `build/**/*.apk`. Plik spoza tego folderu jest kopiowany do
   `$agentPushFileName`. Przyjmowany jest tylko podpisany `.apk` (np. debug), gdy opcja projektu
   „Agent może wysłać własną instalkę” jest włączona (domyślnie tak). `--installed` czeka też,
   aż telefon potwierdzi instalację.
5. **Wynik** zapisuje RemoteAppTester w `$agentStatusFileName` (JSON: `request`, `action`,
   `state` = queued | running | done | rejected | failed | cancelled, `message`, `devices`,
   `log_tail` przy błędzie). Odczyt: `rt st` (albo `rt st --json`). Kody wyjścia `--wait`:
   0 wysłane, 1 odrzucone lub błąd (przeczytaj `message` i `log_tail`, popraw i spróbuj
   ponownie), 2 przekroczony czas, 3 RemoteAppTester nie działa, 4 gotowe, ale żaden telefon
   nie dostał wersji (powiedz o tym użytkownikowi), 64 złe użycie.
6. Zmiany w bloku komend poniżej **nie działają od razu** — użytkownik zatwierdza je
   w aplikacji RemoteAppTester (bezpieczeństwo: nic z tego pliku nie uruchamia się bez jego zgody).
   Nie próbuj zatwierdzać ich sam (np. `rt pr import`) — to decyzja człowieka; poinformuj
   użytkownika, że w RemoteAppTester czeka propozycja komend.
7. Dopisz `$agentSignalFileName`, `$agentStatusFileName`, `$agentPushFileName` i
   `$previewFeedbackFileName` do `.gitignore` projektu (pliki są tymczasowe).
8. Aplikacja web? Użytkownik ogląda ją na telefonie (podgląd RemoteAppTester) i zgłasza
   problemy — trafiają do `$previewFeedbackFileName` (najnowsze na górze: opis, adres strony,
   konsola JS). Przeczytaj go na początku pracy; po poprawce usuń obsłużone wpisy. Po `rt sg`
   otwarty podgląd sam się odświeża.

## Komendy budowania

$_begin
```yaml
${yamlBlock.toString().trimRight()}
```
$_end
''';
}

/// Podmienia w istniejącym pliku tylko wytyczne (wszystko przed blokiem
/// komend) na aktualne — blok komend, ewentualna propozycja agenta i to, co
/// po bloku, zostają bez zmian. Zwraca `true`, gdy plik zmieniono.
bool refreshGuideInstructions(Directory projectDir, String projectName) {
  final file = agentGuideFile(projectDir);
  try {
    if (!file.existsSync() || file.lengthSync() > _maxGuideBytes) return false;
    final text = file.readAsStringSync();
    final at = text.indexOf(_begin);
    if (at < 0) return false;
    final fresh = renderAgentGuide(projectName, const []);
    final updated = fresh.substring(0, fresh.indexOf(_begin)) + text.substring(at);
    if (updated == text) return false;
    file.writeAsStringSync(updated);
    return true;
  } on FileSystemException {
    return false;
  }
}

const _pointerBegin = '<!-- remoteapptester:agents:begin -->';
const _pointerEnd = '<!-- remoteapptester:agents:end -->';

/// Pliki instrukcji, które agenci AI czytają sami przy starcie pracy w folderze
/// (Claude Code: CLAUDE.md; Codex, Cursor i inni: AGENTS.md).
const agentInstructionFiles = ['CLAUDE.md', 'AGENTS.md'];

String _pointerBlock() => '''
$_pointerBegin
## RemoteAppTester — po skończonej pracy daj znać

Ten folder jest budowany i instalowany na telefonie testowym przez RemoteAppTester.
**Gdy skończysz zmiany gotowe do przetestowania**, wyślij sygnał: w pliku `.remoteapptester-signal`
w tym folderze ustaw `message` (krótko: co zmieniono) i `build: true`, zapisz plik.
Zamiast tego możesz uruchomić: `rt sg -m "co zmieniono" --build --wait`.
RemoteAppTester sam zbuduje aplikację i wyśle ją na telefon.
Jeśli APK zbudowałeś sam: `rt push <plik.apk> -m "co zmieniono" --wait --json` (kod 0 = wysłane na telefon).
Wynik ostatniego zlecenia: `rt st --json`. Komendy budowania, kody wyjścia i zasady: `REMOTEAPPTESTER.md`.
$_pointerEnd
''';

/// Pliki z czasów poprzedniej nazwy aplikacji: wytyczne przenosimy z zachowaniem
/// bloku komend i ewentualnej propozycji agenta, stary plik sygnału usuwamy.
void migrateLegacyAgentFiles(Directory projectDir) {
  if (!projectDir.existsSync()) return;
  try {
    final legacyGuide = File(p.join(projectDir.path, 'REMOTETESTER.md'));
    if (legacyGuide.existsSync()) {
      final target = agentGuideFile(projectDir);
      if (!target.existsSync()) {
        target.writeAsStringSync(legacyGuide
            .readAsStringSync()
            .replaceAll('<!-- remotetester:begin -->', _begin)
            .replaceAll('<!-- remotetester:end -->', _end));
      }
      legacyGuide.deleteSync();
    }
    final legacySignal = File(p.join(projectDir.path, '.remotetester-signal'));
    if (legacySignal.existsSync()) legacySignal.deleteSync();
  } on FileSystemException {
    // Plik zajęty albo tylko do odczytu — spróbujemy przy kolejnym starcie.
  }
}

/// Dopisuje (albo aktualizuje) krótki blok o RemoteAppTesterze w CLAUDE.md i
/// AGENTS.md — tworzy pliki, jeśli ich brak. Reszta treści plików zostaje.
void ensureAgentPointers(Directory projectDir) {
  if (!projectDir.existsSync()) return;
  final block = _pointerBlock();
  for (final name in agentInstructionFiles) {
    final file = File(p.join(projectDir.path, name));
    try {
      if (FileSystemEntity.typeSync(file.path, followLinks: false) == FileSystemEntityType.link) continue;
      if (!file.existsSync()) {
        file.writeAsStringSync(block);
        continue;
      }
      if (file.lengthSync() > _maxGuideBytes) continue;
      final text = file.readAsStringSync().replaceAll('remotetester:agents:', 'remoteapptester:agents:');
      final start = text.indexOf(_pointerBegin);
      final end = text.indexOf(_pointerEnd);
      final String updated;
      if (start >= 0 && end > start) {
        updated = text.substring(0, start) + block.trimRight() + text.substring(end + _pointerEnd.length);
      } else {
        updated = '${text.trimRight()}\n\n$block';
      }
      if (updated != text) file.writeAsStringSync(updated);
    } on FileSystemException {
      // Plik tylko do odczytu — agent znajdzie wskazówki w REMOTEAPPTESTER.md.
    }
  }
}

/// Odczytuje blok komend z pliku i porównuje go z bazą.
/// [current] — komendy w bazie; [handledHash] — skrót bloku już
/// zaimportowanego albo odrzuconego (nie pytamy o niego drugi raz).
GuideState readAgentGuide(Directory projectDir, {required List<BuildProfile> current, String? handledHash}) {
  final file = agentGuideFile(projectDir);
  if (!file.existsSync()) return const GuideState(GuideStatus.missing);
  try {
    if (file.lengthSync() > _maxGuideBytes) {
      return const GuideState(GuideStatus.invalid, error: 'Plik REMOTEAPPTESTER.md jest za duży.');
    }
    final text = file.readAsStringSync();
    final start = text.indexOf(_begin);
    final end = text.indexOf(_end);
    if (start < 0 || end < start) {
      return const GuideState(GuideStatus.invalid, error: 'Brak bloku komend (znaczniki remoteapptester:begin/end).');
    }
    var block = text.substring(start + _begin.length, end).trim();
    final fence = RegExp(r'^```[a-zA-Z]*\s*\n([\s\S]*?)\n```$').firstMatch(block);
    if (fence != null) block = fence.group(1)!;
    final hash = sha256.convert(utf8.encode(block.replaceAll('\r\n', '\n').trim())).toString();

    final profiles = parseGuideBlock(block);
    if (encodeProfiles(profiles) == encodeProfiles(current) || hash == handledHash) {
      return GuideState(GuideStatus.inSync, hash: hash);
    }
    return GuideState(GuideStatus.proposal, profiles: profiles, hash: hash);
  } on ProfileException catch (e) {
    return GuideState(GuideStatus.invalid, error: e.message);
  } on FileSystemException catch (e) {
    return GuideState(GuideStatus.invalid, error: 'Nie można odczytać pliku: ${e.message}');
  }
}

/// Parsuje blok YAML z `REMOTEAPPTESTER.md`; rzuca [ProfileException].
List<BuildProfile> parseGuideBlock(String block) {
  Object? doc;
  try {
    doc = loadYaml(block);
  } on YamlException catch (e) {
    throw ProfileException('Niepoprawny YAML w bloku komend: ${e.message}');
  }
  if (doc is! YamlMap || doc.keys.any((k) => k != 'profiles') || doc['profiles'] is! YamlList) {
    throw ProfileException('Blok komend musi zawierać wyłącznie listę "profiles".');
  }
  final profiles = <BuildProfile>[];
  for (final raw in doc['profiles'] as YamlList) {
    if (raw is! YamlMap || raw.keys.any((k) => !const {'name', 'steps', 'artifact'}.contains(k))) {
      throw ProfileException('Wariant może mieć tylko pola name, steps, artifact.');
    }
    final steps = raw['steps'];
    if (steps is! YamlList) throw ProfileException('Pole "steps" musi być listą.');
    for (final s in steps) {
      if (s is! YamlMap || s.keys.any((k) => k != 'name' && k != 'run')) {
        throw ProfileException('Krok może mieć tylko pola name i run.');
      }
    }
    profiles.add(BuildProfile.fromJson(jsonDecode(jsonEncode(raw))));
  }
  validateProfiles(profiles);
  return profiles;
}

String _yamlString(String value) => jsonEncode(value); // JSON string = poprawny skalar YAML
