import 'dart:io';

import 'package:path/path.dart' as p;

import 'build_profile.dart';

/// Katalogi, w które wyszukiwanie z `**` nie schodzi (ogromne i bez instalek).
const _skipDirs = {'.git', '.dart_tool', 'node_modules', '.gradle', '.idea', '.vscode'};

/// Najnowszy plik pasujący do wzorca [pattern] (`*` w segmencie, `**` dowolna
/// głębokość) wewnątrz [projectDir]. Wynik zawsze leży w folderze projektu —
/// wzorzec jest walidowany ([BuildProfile.validateArtifactPattern]), a ścieżka
/// kanonizowana i sprawdzana po rozwiązaniu dowiązań.
File? findArtifact(Directory projectDir, String pattern) {
  BuildProfile.validateArtifactPattern(pattern);
  final segments = pattern.trim().replaceAll(r'\', '/').split('/').where((s) => s.isNotEmpty && s != '.').toList();
  final matches = <File>[];
  _walk(projectDir, segments, 0, matches);

  final root = p.normalize(projectDir.resolveSymbolicLinksSync());
  final inside = matches.where((f) {
    final real = p.normalize(f.resolveSymbolicLinksSync());
    return p.isWithin(root, real);
  }).toList()
    // Niepodpisany release (`*-unsigned.apk`) nie da się zainstalować.
    ..removeWhere((f) => p.basename(f.path).contains('unsigned'))
    ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  return inside.isEmpty ? null : inside.first;
}

void _walk(Directory dir, List<String> segments, int index, List<File> out) {
  if (index >= segments.length) return;
  final segment = segments[index];
  final last = index == segments.length - 1;
  if (segment == '**') {
    // `**` = zero albo więcej katalogów.
    _walk(dir, segments, index + 1, out);
    for (final sub in _subdirs(dir)) {
      _walk(sub, segments, index, out);
    }
    return;
  }
  final rx = _segmentRegex(segment);
  List<FileSystemEntity> entries;
  try {
    entries = dir.listSync(followLinks: false);
  } on FileSystemException {
    return;
  }
  for (final e in entries) {
    if (!rx.hasMatch(p.basename(e.path))) continue;
    if (last && e is File) out.add(e);
    if (!last && e is Directory) _walk(e, segments, index + 1, out);
  }
}

Iterable<Directory> _subdirs(Directory dir) {
  try {
    return dir
        .listSync(followLinks: false)
        .whereType<Directory>()
        .where((d) => !_skipDirs.contains(p.basename(d.path)));
  } on FileSystemException {
    return const [];
  }
}

RegExp _segmentRegex(String segment) {
  final buffer = StringBuffer('^');
  for (final ch in segment.split('')) {
    buffer.write(switch (ch) {
      '*' => '[^/]*',
      '?' => '[^/]',
      _ => RegExp.escape(ch),
    });
  }
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: !Platform.isWindows);
}

/// Największa instalka, jaką przyjmujemy od agenta (`rt push`).
const maxPushedArtifactBytes = 1024 * 1024 * 1024;

/// Instalka wskazana przez agenta ([relativePath] z pliku sygnału — niezaufana).
/// Przyjmujemy wyłącznie zwykły plik `.apk` (archiwum ZIP) leżący — także po
/// rozwiązaniu dowiązań — w folderze projektu. Rzuca [ProfileException] z
/// komunikatem dla agenta.
File resolvePushedArtifact(Directory projectDir, String relativePath) {
  final rel = relativePath.trim().replaceAll(r'\', '/');
  if (rel.isEmpty || p.isAbsolute(rel) || p.windows.isAbsolute(rel) || rel.split('/').contains('..')) {
    throw ProfileException('Ścieżka instalki musi być względna i leżeć w folderze projektu: $relativePath');
  }
  if (!rel.toLowerCase().endsWith('.apk')) throw ProfileException('To nie jest plik .apk: $relativePath');
  final file = File(p.join(projectDir.path, rel));
  if (FileSystemEntity.typeSync(file.path) != FileSystemEntityType.file) {
    throw ProfileException('Nie ma takiego pliku w folderze projektu: $relativePath');
  }
  final root = p.normalize(projectDir.resolveSymbolicLinksSync());
  final real = p.normalize(file.resolveSymbolicLinksSync());
  if (!p.isWithin(root, real)) throw ProfileException('Instalka prowadzi poza folder projektu: $relativePath');
  if (p.basename(real).contains('unsigned')) {
    throw ProfileException('Niepodpisanej instalki nie da się zainstalować: $relativePath');
  }
  final size = File(real).lengthSync();
  if (size == 0 || size > maxPushedArtifactBytes) {
    throw ProfileException('Instalka ma nieprawidłowy rozmiar ($size B): $relativePath');
  }
  final raf = File(real).openSync();
  try {
    final magic = raf.readSync(4);
    if (magic.length < 4 || magic[0] != 0x50 || magic[1] != 0x4B || magic[2] != 0x03 || magic[3] != 0x04) {
      throw ProfileException('Plik nie jest instalką APK (brak nagłówka ZIP): $relativePath');
    }
  } finally {
    raf.closeSync();
  }
  return File(real);
}
