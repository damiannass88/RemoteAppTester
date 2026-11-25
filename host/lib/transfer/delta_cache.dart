import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'apk_delta.dart';

/// Gotowe delty instalek (`artifacts/<projekt>/deltas/<build>-<baza>.rtd`).
///
/// Liczone na żądanie telefonu w osobnym izolacie (okno i serwer działają
/// dalej), raz na parę (build, baza) — kolejne pobrania i wznowienia
/// czytają gotowy plik. Sprzątane razem z instalkami (`BuildEngine`).
class DeltaCache {
  final _inflight = <String, Future<DeltaFile>>{};

  Future<DeltaFile> get({
    required String buildId,
    required String targetPath,
    String? basePath,
    String? baseSha256,
  }) {
    final name = '$buildId-${baseSha256 == null ? 'full' : baseSha256.substring(0, 16)}.rtd';
    final outPath = p.join(p.dirname(targetPath), 'deltas', name);
    // Blok `{}`: callback zwracający usunięty Future kazałby whenComplete czekać na samego siebie.
    return _inflight[outPath] ??= _make(outPath, targetPath, basePath).whenComplete(() {
      _inflight.remove(outPath);
    });
  }

  Future<DeltaFile> _make(String outPath, String targetPath, String? basePath) async {
    final out = File(outPath);
    if (!out.existsSync()) {
      await _inIsolate(basePath, targetPath, outPath);
    }
    final digest = await sha256.bind(out.openRead()).single;
    return DeltaFile(outPath, out.lengthSync(), digest.toString());
  }
}

/// Funkcja najwyższego poziomu, żeby domknięcie wysyłane do izolatu nie złapało `this`.
Future<void> _inIsolate(String? basePath, String targetPath, String outPath) =>
    Isolate.run(() => writeDeltaFile(basePath: basePath, targetPath: targetPath, outPath: outPath));

/// Usuwa delty instalek, których już nie ma w katalogu projektu.
void pruneDeltas(Directory projectArtifacts) {
  final deltas = Directory(p.join(projectArtifacts.path, 'deltas'));
  if (!deltas.existsSync()) return;
  final builds = {
    for (final f in projectArtifacts.listSync().whereType<File>())
      if (f.path.endsWith('.apk')) p.basenameWithoutExtension(f.path),
  };
  for (final f in deltas.listSync().whereType<File>()) {
    final name = p.basename(f.path);
    final dash = name.indexOf('-');
    if (dash > 0 && builds.contains(name.substring(0, dash)) && !name.endsWith('.part')) continue;
    try {
      f.deleteSync();
    } on FileSystemException {
      // W trakcie wysyłania — usuniemy przy następnym sprzątaniu.
    }
  }
}
