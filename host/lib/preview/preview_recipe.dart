import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Znacznik komendy „wbudowany serwer plików” (strona statyczna) zamiast procesu.
const staticPreviewPrefix = '@static';

/// Miejsce na port w komendzie podglądu (host wybiera wolny port przy starcie).
const previewPortPlaceholder = '{port}';

/// Jak uruchomić podgląd aplikacji web: rozpoznana technologia i komenda.
///
/// Komenda pochodzi WYŁĄCZNIE z tego pliku (receptury hosta) albo z bazy hosta
/// (wpisana na komputerze) — nigdy od telefonu. Serwer ma słuchać tylko na
/// `127.0.0.1:{port}`; do sieci Tailscale wystawia go proxy hosta z tokenem.
class PreviewRecipe {
  const PreviewRecipe({required this.kind, required this.command, this.prepare, this.prepareUnless});

  /// Nazwa technologii do wyświetlenia (np. „ASP.NET”).
  final String kind;

  /// Komenda z [previewPortPlaceholder] albo `@static <folder>`.
  final String command;

  /// Komenda przygotowania (np. `npm install`), uruchamiana tylko gdy brak [prepareUnless].
  final String? prepare;
  final String? prepareUnless;

  bool get isStatic => command.startsWith(staticPreviewPrefix);

  /// Folder strony statycznej względem folderu projektu.
  String get staticFolder => command.substring(staticPreviewPrefix.length).trim();
}

/// Rozpoznaje technologię po plikach w folderze projektu (bez uruchamiania czegokolwiek).
PreviewRecipe? detectPreviewRecipe(Directory dir, {bool? windows}) {
  final win = windows ?? Platform.isWindows;
  if (!dir.existsSync()) return null;
  File f(String rel) => File(p.join(dir.path, rel));

  final csproj = _findWebCsproj(dir);
  if (csproj != null) {
    final rel = p.relative(csproj.path, from: dir.path).replaceAll(r'\', '/');
    // `--urls` z linii komend ma pierwszeństwo przed launchSettings.json; `dotnet watch`
    // przebudowuje i przeładowuje stronę po zmianach w kodzie.
    return PreviewRecipe(
      kind: 'ASP.NET',
      command: 'dotnet watch run --project "$rel" --non-interactive --urls http://127.0.0.1:$previewPortPlaceholder',
    );
  }

  final pubspec = f('pubspec.yaml');
  if (_matches(pubspec, RegExp(r'^flutter\s*:', multiLine: true)) && Directory(p.join(dir.path, 'web')).existsSync()) {
    return const PreviewRecipe(
      kind: 'Flutter Web',
      command: 'flutter run -d web-server --web-hostname 127.0.0.1 --web-port $previewPortPlaceholder',
    );
  }

  final package = _json(f('package.json'));
  if (package != null) {
    final deps = {
      ...?(package['dependencies'] as Map?)?.cast<String, Object?>(),
      ...?(package['devDependencies'] as Map?)?.cast<String, Object?>(),
    };
    final scripts = (package['scripts'] as Map?)?.cast<String, Object?>() ?? const {};
    const install = 'npm install';
    PreviewRecipe node(String kind, String command) =>
        PreviewRecipe(kind: kind, command: command, prepare: install, prepareUnless: 'node_modules');
    if (deps.containsKey('next') && scripts.containsKey('dev')) {
      return node('Next.js', 'npm run dev -- --hostname 127.0.0.1 --port $previewPortPlaceholder');
    }
    if (deps.containsKey('@angular/core') && scripts.containsKey('start')) {
      return node('Angular', 'npm start -- --host 127.0.0.1 --port $previewPortPlaceholder');
    }
    if (deps.containsKey('vite') && scripts.containsKey('dev')) {
      return node('Vite', 'npm run dev -- --host 127.0.0.1 --port $previewPortPlaceholder --strictPort');
    }
    // Pozostałe (Express, CRA…) — port w zmiennej PORT, którą host zawsze ustawia.
    if (scripts.containsKey('dev')) return node('Node', 'npm run dev');
    if (scripts.containsKey('start')) return node('Node', 'npm start');
  }

  final python = win ? 'python' : 'python3';
  if (f('manage.py').existsSync()) {
    return PreviewRecipe(kind: 'Django', command: '$python manage.py runserver 127.0.0.1:$previewPortPlaceholder');
  }
  if (f('app.py').existsSync() && _matches(f('app.py'), RegExp(r'\bFlask\b'))) {
    return PreviewRecipe(kind: 'Flask', command: '$python -m flask run --host 127.0.0.1 --port $previewPortPlaceholder');
  }

  if (f('artisan').existsSync()) {
    return const PreviewRecipe(kind: 'Laravel', command: 'php artisan serve --host=127.0.0.1 --port=$previewPortPlaceholder');
  }
  if (f('index.php').existsSync()) {
    return const PreviewRecipe(kind: 'PHP', command: 'php -S 127.0.0.1:$previewPortPlaceholder');
  }

  for (final folder in const ['.', 'public', 'dist', 'build', 'www', 'site']) {
    if (File(p.join(dir.path, folder, 'index.html')).existsSync()) {
      return PreviewRecipe(kind: 'HTML', command: '$staticPreviewPrefix $folder');
    }
  }
  return null;
}

/// Projekt ASP.NET (SDK Web / Blazor WebAssembly) w folderze albo piętro niżej
/// (typowy układ: rozwiązanie w korzeniu, projekt w `src/App/`).
File? _findWebCsproj(Directory dir) {
  final sdk = RegExp(r'Sdk\s*=\s*"Microsoft\.NET\.Sdk\.(Web|BlazorWebAssembly)"');
  List<File> csprojIn(Directory d) {
    try {
      return d.listSync(followLinks: false).whereType<File>().where((f) => f.path.toLowerCase().endsWith('.csproj')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    } on FileSystemException {
      return const [];
    }
  }

  final candidates = [...csprojIn(dir)];
  if (candidates.isEmpty) {
    for (final top in ['.', 'src']) {
      final base = Directory(p.join(dir.path, top));
      if (!base.existsSync()) continue;
      for (final sub in base.listSync(followLinks: false).whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path))) {
        final name = p.basename(sub.path);
        if (name.startsWith('.') || const {'bin', 'obj', 'node_modules', 'test', 'tests'}.contains(name.toLowerCase())) continue;
        candidates.addAll(csprojIn(sub));
      }
    }
  }
  return candidates.where((f) => _matches(f, sdk) && !p.basename(f.path).toLowerCase().contains('test')).firstOrNull;
}

bool _matches(File file, RegExp pattern) {
  try {
    return file.existsSync() && file.lengthSync() < 2 * 1024 * 1024 && pattern.hasMatch(file.readAsStringSync());
  } on Object {
    return false;
  }
}

Map<String, Object?>? _json(File file) {
  try {
    if (!file.existsSync()) return null;
    final doc = jsonDecode(file.readAsStringSync());
    return doc is Map<String, Object?> ? doc : null;
  } on Object {
    return null;
  }
}
