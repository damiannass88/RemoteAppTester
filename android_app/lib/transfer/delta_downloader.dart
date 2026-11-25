import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';

import '../generated/remote_tester.pbgrpc.dart';
import 'artifact_downloader.dart';
import '../i18n.dart';

typedef DownloadDeltaCall = Stream<Chunk> Function(DeltaRequest request);

/// Postęp pobierania: przesłane bajty i rozmiar całego transferu (0 = nieznany).
typedef DownloadProgress = void Function(int received, int total);

/// Oszczędne pobieranie instalki.
///
/// Telefon trzyma ostatnią pobraną instalkę każdego projektu (`baseDir`).
/// Host przysyła tylko różnicę między nią a nowym buildem (silnik Fluttera
/// i niezmienione zasoby nie lecą drugi raz), skompresowaną. Pierwsze
/// pobranie to cała instalka, ale też skompresowana.
///
/// Integralność dwa razy: SHA-256 przesłanego pliku (wznawianie) i SHA-256
/// złożonej instalki — musi zgadzać się z sumą builda podaną przez hosta.
Future<File> downloadApkVia({
  required DownloadDeltaCall deltaFn,
  required DownloadArtifactCall fullFn,
  required String projectId,
  required String buildId,
  required Directory cacheDir,
  required Directory baseDir,
  DownloadProgress? onProgress,
}) async {
  final safeId = projectId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final baseFile = File('${baseDir.path}/$safeId.apk');
  final baseShaFile = File('${baseDir.path}/$safeId.sha256');
  String? baseSha;
  if (baseFile.existsSync() && baseShaFile.existsSync()) {
    baseSha = baseShaFile.readAsStringSync().trim();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(baseSha)) baseSha = null;
  }

  try {
    try {
      return await _viaDelta(deltaFn, buildId, baseSha, baseFile, baseShaFile, cacheDir, onProgress);
    } on GrpcError catch (e) {
      // Host nie ma już naszej wersji — pobieramy całość (też skompresowaną).
      if (e.code != StatusCode.failedPrecondition || baseSha == null) rethrow;
      return await _viaDelta(deltaFn, buildId, null, baseFile, baseShaFile, cacheDir, onProgress);
    } on DeltaFormatException {
      if (baseSha == null) rethrow;
      return await _viaDelta(deltaFn, buildId, null, baseFile, baseShaFile, cacheDir, onProgress);
    }
  } on GrpcError catch (e) {
    // Starszy host bez DownloadDelta — zwykłe pobranie.
    if (e.code != StatusCode.unimplemented) rethrow;
    final file = await downloadArtifactVia(
      downloadFn: fullFn,
      buildId: buildId,
      fileNameHint: safeId,
      onProgress: onProgress == null ? null : (b) => onProgress(b, 0),
    );
    final sha = (await sha256.bind(file.openRead()).single).toString();
    baseDir.createSync(recursive: true);
    await file.copy(baseFile.path);
    await file.delete();
    baseShaFile.writeAsStringSync(sha);
    return baseFile;
  }
}

/// „1.2 / 8.0 MB” — przy delcie [total] jest dużo mniejszy niż sama instalka.
String transferLabel(int received, int total, {int fullSize = 0}) {
  String mb(int b) => (b / 1048576).toStringAsFixed(1);
  final base = total > 0 ? tr('{0} / {1} MB', [mb(received), mb(total)]) : tr('{0} MB', [mb(received)]);
  return fullSize > 0 && total > 0 && total < fullSize * 0.9 ? tr('{0} (zamiast {1} MB)', [base, mb(fullSize)]) : base;
}

class DeltaFormatException implements Exception {
  DeltaFormatException(this.message);
  final String message;
  @override
  String toString() => tr('Uszkodzona delta: {0}', [message]);
}

Future<File> _viaDelta(
  DownloadDeltaCall deltaFn,
  String buildId,
  String? baseSha,
  File baseFile,
  File baseShaFile,
  Directory cacheDir,
  DownloadProgress? onProgress,
) async {
  final deltaFile = File('${cacheDir.path}/$buildId-${baseSha?.substring(0, 16) ?? 'full'}.rtd');
  Chunk last;
  try {
    last = await _fetch(deltaFn, buildId, baseSha, deltaFile, onProgress);
  } on GrpcError catch (e) {
    // Częściowy plik nie pasuje do tego, co ma host — od zera, jeden raz.
    if (e.code != StatusCode.invalidArgument) rethrow;
    if (deltaFile.existsSync()) deltaFile.deleteSync();
    last = await _fetch(deltaFn, buildId, baseSha, deltaFile, onProgress);
  }

  final deltaSha = (await sha256.bind(deltaFile.openRead()).single).toString();
  if (deltaSha != last.sha256FullFile) {
    deltaFile.deleteSync();
    throw ArtifactIntegrityException(last.sha256FullFile, deltaSha);
  }

  baseFile.parent.createSync(recursive: true);
  // Osobny plik na każdy build — dwa składania nigdy nie dzielą pliku tymczasowego.
  final assembled = File('${baseFile.path}.$buildId.new');
  try {
    await applyDeltaFile(
      base: baseSha == null ? null : baseFile,
      delta: deltaFile.openRead().transform(gzip.decoder),
      out: assembled,
    );
  } on FormatException catch (e) {
    deltaFile.deleteSync();
    throw DeltaFormatException(e.message);
  }
  final actual = (await sha256.bind(assembled.openRead()).single).toString();
  if (actual != last.targetSha256) {
    assembled.deleteSync();
    deltaFile.deleteSync();
    throw ArtifactIntegrityException(last.targetSha256, actual);
  }
  if (baseFile.existsSync()) baseFile.deleteSync();
  assembled.renameSync(baseFile.path);
  baseShaFile.writeAsStringSync(actual);
  deltaFile.deleteSync();
  return baseFile;
}

Future<Chunk> _fetch(
  DownloadDeltaCall deltaFn,
  String buildId,
  String? baseSha,
  File file,
  DownloadProgress? onProgress,
) async {
  file.parent.createSync(recursive: true);
  final start = file.existsSync() ? file.lengthSync() : 0;
  final raf = await file.open(mode: start > 0 ? FileMode.append : FileMode.write);
  Chunk? last;
  var received = start;
  try {
    final request = DeltaRequest(buildId: buildId, baseSha256: baseSha ?? '', resumeFromByteOffset: fixnum.Int64(start));
    await for (final chunk in deltaFn(request)) {
      if (chunk.data.isNotEmpty) {
        await raf.writeFrom(chunk.data);
        received += chunk.data.length;
      }
      onProgress?.call(received, chunk.totalSize.toInt());
      if (chunk.isLast) last = chunk;
    }
  } finally {
    await raf.close();
  }
  if (last == null || last.sha256FullFile.isEmpty || last.targetSha256.isEmpty) {
    throw StateError(tr('Komputer nie dokończył przesyłania (brak sum kontrolnych).'));
  }
  return last;
}

/// Składa instalkę z [base] i rozpakowanej delty RTD1 (format: host,
/// `lib/transfer/apk_delta.dart`). Strumieniowo — bez trzymania instalki w pamięci.
Future<void> applyDeltaFile({File? base, required Stream<List<int>> delta, required File out}) async {
  final reader = _Reader(delta);
  final baseRaf = base == null ? null : await base.open();
  final outRaf = await out.open(mode: FileMode.write);
  try {
    for (final m in const [0x52, 0x54, 0x44, 0x31]) {
      if (await reader.byte() != m) throw FormatException(tr('to nie jest delta RTD1'));
    }
    final size = await reader.varint();
    var written = 0;
    while (true) {
      final op = await reader.byte();
      if (op == 0) break;
      if (op == 1) {
        final offset = await reader.varint();
        var length = await reader.varint();
        if (baseRaf == null) throw FormatException(tr('delta wymaga poprzedniej wersji'));
        await baseRaf.setPosition(offset);
        while (length > 0) {
          final data = await baseRaf.read(min(length, 1 << 20));
          if (data.isEmpty) throw FormatException(tr('odwołanie poza poprzednią wersję'));
          await outRaf.writeFrom(data);
          length -= data.length;
          written += data.length;
        }
      } else if (op == 2) {
        final length = await reader.varint();
        await reader.copyTo(outRaf, length);
        written += length;
      } else {
        throw FormatException(tr('nieznana operacja {0}', [op]));
      }
      if (written > size) throw FormatException(tr('za dużo danych'));
    }
    if (written != size) throw FormatException(tr('zły rozmiar wyniku'));
  } finally {
    await baseRaf?.close();
    await outRaf.close();
    await reader.cancel();
  }
}

class _Reader {
  _Reader(Stream<List<int>> stream) : _it = StreamIterator(stream);
  final StreamIterator<List<int>> _it;
  List<int> _buf = const [];
  int _pos = 0;

  Future<void> _fill() async {
    while (_pos >= _buf.length) {
      if (!await _it.moveNext()) throw FormatException(tr('delta urwana'));
      _buf = _it.current;
      _pos = 0;
    }
  }

  Future<int> byte() async {
    await _fill();
    return _buf[_pos++];
  }

  Future<int> varint() async {
    var result = 0, shift = 0;
    while (true) {
      final b = await byte();
      result |= (b & 0x7f) << shift;
      if (b < 0x80) return result;
      shift += 7;
      if (shift > 56) throw FormatException(tr('zła liczba'));
    }
  }

  Future<void> copyTo(RandomAccessFile out, int length) async {
    while (length > 0) {
      await _fill();
      final take = min(length, _buf.length - _pos);
      await out.writeFrom(_buf, _pos, _pos + take);
      _pos += take;
      length -= take;
    }
  }

  Future<void> cancel() => _it.cancel();
}
