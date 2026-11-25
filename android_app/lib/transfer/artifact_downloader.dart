import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';
import 'package:path_provider/path_provider.dart';

import '../generated/remote_tester.pbgrpc.dart';
import '../net/agent_client.dart';

/// Sygnatura [AgentClient.downloadArtifact] wystarczająca do pobrania
/// artefaktu — wydzielona osobno, żeby logikę wznawiania dało się
/// przetestować bez żywego połączenia gRPC (fałszywa implementacja zamiast
/// prawdziwego [AgentClient]).
typedef DownloadArtifactCall = Stream<Chunk> Function(ArtifactRequest request);

/// Wyjątek rzucany, gdy suma kontrolna pobranego pliku nie zgadza się z tą
/// zadeklarowaną przez agenta w ostatnim chunku — integralność w obrębie
/// już uwierzytelnionego kanału (docs/architektura-remote-build.md, sekcja 6.1:
/// "SHA-256 pozostaje jako kontrola integralności w obrębie już zaufanego
/// kanału").
class ArtifactIntegrityException implements Exception {
  ArtifactIntegrityException(this.expectedSha256, this.actualSha256);
  final String expectedSha256;
  final String actualSha256;
  @override
  String toString() =>
      'ArtifactIntegrityException: oczekiwano SHA-256 $expectedSha256, otrzymano $actualSha256';
}

/// Pobiera artefakt strumieniowo do prywatnego cacheDir aplikacji (bez
/// `WRITE_EXTERNAL_STORAGE`) i weryfikuje SHA-256 przed zwróceniem pliku
/// (docs/architektura-remote-build.md, sekcja 5).
///
/// Wznawialne: jeśli częściowy plik z POPRZEDNIEJ, przerwanej próby
/// (np. WiFi↔LTE) już leży w cacheDir pod tą samą nazwą (zawiera `buildId`,
/// więc nigdy nie miesza się z innym buildem), pobieranie kontynuuje od
/// jego długości przez `resume_from_byte_offset` zamiast zaczynać od zera —
/// serwer wspiera to (`host_agent_service.dart`,
/// `downloadArtifact`). Suma SHA-256 liczona jest zawsze nad CAŁYM plikiem
/// na dysku po zakończeniu, nie tylko nad bajtami z tej sesji.
Future<File> downloadArtifact({
  required AgentClient client,
  required String buildId,
  required String fileNameHint,
  void Function(int bytesReceived)? onProgress,
}) {
  return downloadArtifactVia(
    downloadFn: client.downloadArtifact,
    buildId: buildId,
    fileNameHint: fileNameHint,
    onProgress: onProgress,
  );
}

/// Sama logika (bez zależności od żywego [AgentClient]) — patrz
/// [downloadArtifact] dla dokumentacji zachowania.
Future<File> downloadArtifactVia({
  required DownloadArtifactCall downloadFn,
  required String buildId,
  required String fileNameHint,
  void Function(int bytesReceived)? onProgress,
}) async {
  final cacheDir = await getTemporaryDirectory();
  final safeName = fileNameHint.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${cacheDir.path}/$safeName-$buildId.apk');

  try {
    return await _downloadOnce(downloadFn: downloadFn, buildId: buildId, file: file, onProgress: onProgress);
  } on GrpcError catch (e) {
    // Częściowy plik na dysku jest dłuższy niż to, co agent faktycznie ma
    // (np. inny build pod tym samym ID po ręcznym wyczyszczeniu artefaktów
    // na agencie) — serwer odrzuca taki offset jako invalidArgument. Zamiast
    // utknąć w pętli błędów: skasuj i spróbuj RAZ jeszcze od zera.
    if (e.code != StatusCode.invalidArgument) rethrow;
    if (await file.exists()) await file.delete();
    return _downloadOnce(downloadFn: downloadFn, buildId: buildId, file: file, onProgress: onProgress);
  }
}

Future<File> _downloadOnce({
  required DownloadArtifactCall downloadFn,
  required String buildId,
  required File file,
  void Function(int bytesReceived)? onProgress,
}) async {
  final startOffset = await file.exists() ? await file.length() : 0;
  final sink = file.openWrite(mode: startOffset > 0 ? FileMode.append : FileMode.write);
  var received = startOffset;
  String? declaredSha256;

  try {
    final request = ArtifactRequest(buildId: buildId, resumeFromByteOffset: fixnum.Int64(startOffset));
    await for (final chunk in downloadFn(request)) {
      sink.add(chunk.data);
      received += chunk.data.length;
      onProgress?.call(received);
      if (chunk.isLast) {
        declaredSha256 = chunk.sha256FullFile;
      }
    }
  } finally {
    await sink.close();
  }

  if (declaredSha256 == null || declaredSha256.isEmpty) {
    throw StateError('Agent nie wysłał sumy SHA-256 w ostatnim chunku.');
  }
  final actualSha256 = (await sha256.bind(file.openRead()).single).toString();

  if (actualSha256 != declaredSha256) {
    await file.delete();
    throw ArtifactIntegrityException(declaredSha256, actualSha256);
  }

  return file;
}
