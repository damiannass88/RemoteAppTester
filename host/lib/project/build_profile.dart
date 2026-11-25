import 'dart:convert';

/// Błąd walidacji komend/profilu (pokazywany użytkownikowi).
class ProfileException implements Exception {
  ProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Jeden krok budowania: nazwa dla człowieka i JEDNA linia polecenia powłoki
/// (cmd na Windows, bash na Linuxie), uruchamiana w folderze projektu.
class BuildStep {
  const BuildStep(this.name, this.run);

  final String name;
  final String run;

  Map<String, String> toJson() => {'name': name, 'run': run};

  static BuildStep fromJson(Object? json) {
    if (json is! Map) throw ProfileException('Krok musi mieć pola "name" i "run".');
    final name = json['name'];
    final run = json['run'];
    if (name is! String || run is! String) throw ProfileException('Krok musi mieć pola "name" i "run" (tekst).');
    return BuildStep(name, run);
  }

  @override
  bool operator ==(Object other) => other is BuildStep && other.name == name && other.run == run;
  @override
  int get hashCode => Object.hash(name, run);
}

/// Wariant budowania projektu (np. „Debug”, „Release”, „Demo”): kroki i wzorzec
/// ścieżki gotowej instalki.
///
/// Bezpieczeństwo (docs/SECURITY.md): profile żyją WYŁĄCZNIE w zaszyfrowanej
/// bazie RemoteAppTestera i zmieniają się tylko lokalną akcją użytkownika (okno
/// aplikacji / `rt`) albo po jego jawnym zatwierdzeniu propozycji z
/// `REMOTEAPPTESTER.md`. Telefon nigdy ich nie wysyła ani nie zmienia.
class BuildProfile {
  BuildProfile({required this.name, required this.steps, required this.artifact});

  final String name;
  final List<BuildStep> steps;

  /// Wzorzec ścieżki pliku APK względem folderu projektu: `*` w obrębie
  /// segmentu, `**` dowolna głębokość, np. `build/**/app-debug.apk`.
  final String artifact;

  static const maxSteps = 20;

  /// Rzuca [ProfileException] z czytelnym komunikatem.
  void validate() {
    if (name.trim().isEmpty || name.length > 40) {
      throw ProfileException('Nazwa wariantu musi mieć 1–40 znaków.');
    }
    if (steps.isEmpty || steps.length > maxSteps) {
      throw ProfileException('Wariant "$name": potrzeba 1–$maxSteps kroków.');
    }
    for (final step in steps) {
      if (step.name.trim().isEmpty || step.name.length > 60) {
        throw ProfileException('Wariant "$name": nazwa kroku musi mieć 1–60 znaków.');
      }
      if (step.run.trim().isEmpty || step.run.length > 2000) {
        throw ProfileException('Wariant "$name", krok "${step.name}": pusta albo za długa komenda.');
      }
      if (step.run.contains('\n') || step.run.contains('\r') || step.run.contains('\u0000')) {
        throw ProfileException('Wariant "$name", krok "${step.name}": komenda musi być w jednej linii '
            '(kolejne polecenia dodaj jako osobne kroki).');
      }
    }
    validateArtifactPattern(artifact);
  }

  static void validateArtifactPattern(String pattern) {
    final p = pattern.trim().replaceAll(r'\', '/');
    if (p.isEmpty || p.length > 300) throw ProfileException('Podaj wzorzec pliku instalki (np. build/**/*.apk).');
    if (p.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(p)) {
      throw ProfileException('Wzorzec instalki musi być względny wobec folderu projektu.');
    }
    if (p.split('/').contains('..')) throw ProfileException('Wzorzec instalki nie może wychodzić poza folder projektu.');
    if (!p.toLowerCase().endsWith('.apk')) throw ProfileException('Instalka musi być plikiem .apk.');
  }

  Map<String, Object> toJson() => {
        'name': name,
        'steps': [for (final s in steps) s.toJson()],
        'artifact': artifact,
      };

  static BuildProfile fromJson(Object? json) {
    if (json is! Map) throw ProfileException('Wariant musi mieć pola name, steps, artifact.');
    final name = json['name'];
    final steps = json['steps'];
    final artifact = json['artifact'];
    if (name is! String || steps is! List || artifact is! String) {
      throw ProfileException('Wariant musi mieć pola name (tekst), steps (lista), artifact (tekst).');
    }
    return BuildProfile(name: name.trim(), steps: [for (final s in steps) BuildStep.fromJson(s)], artifact: artifact.trim());
  }

  /// Kanoniczna postać do porównań (czy propozycja agenta różni się od bazy).
  String get canonical => jsonEncode(toJson());

  BuildProfile copyWith({String? name, List<BuildStep>? steps, String? artifact}) =>
      BuildProfile(name: name ?? this.name, steps: steps ?? this.steps, artifact: artifact ?? this.artifact);
}

/// Waliduje listę wariantów: niepusta, unikalne nazwy, każdy poprawny.
void validateProfiles(List<BuildProfile> profiles) {
  if (profiles.isEmpty) throw ProfileException('Potrzebny co najmniej jeden wariant budowania.');
  if (profiles.length > 10) throw ProfileException('Najwyżej 10 wariantów budowania.');
  final names = <String>{};
  for (final p in profiles) {
    p.validate();
    if (!names.add(p.name.toLowerCase())) throw ProfileException('Powtórzona nazwa wariantu: ${p.name}.');
  }
}

String encodeProfiles(List<BuildProfile> profiles) => jsonEncode([for (final p in profiles) p.toJson()]);

List<BuildProfile> decodeProfiles(String json) {
  final list = jsonDecode(json);
  if (list is! List) throw ProfileException('Niepoprawna lista wariantów.');
  return [for (final p in list) BuildProfile.fromJson(p)];
}
