import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:remotetester/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester/transfer/artifact_downloader.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('artifact_downloader_test_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('downloads a fresh artifact in one go and verifies its SHA-256', () async {
    final bytes = List<int>.generate(500, (i) => i % 256);
    final digest = sha256.convert(bytes).toString();

    final file = await downloadArtifactVia(
      downloadFn: (request) {
        expect(request.resumeFromByteOffset.toInt(), 0);
        return Stream.value(
          Chunk(data: Uint8List.fromList(bytes), offset: fixnum.Int64(0), isLast: true, sha256FullFile: digest),
        );
      },
      buildId: 'build-1',
      fileNameHint: 'demo',
    );

    expect(await file.readAsBytes(), bytes);
  });

  test('resumes from the length of a partial file already on disk', () async {
    final full = List<int>.generate(1000, (i) => i % 256);
    final digest = sha256.convert(full).toString();

    final partialFile = File('${tempDir.path}/demo-build-2.apk');
    await partialFile.writeAsBytes(full.sublist(0, 400));

    var requestedOffset = -1;
    final file = await downloadArtifactVia(
      downloadFn: (request) {
        requestedOffset = request.resumeFromByteOffset.toInt();
        return Stream.value(
          Chunk(
            data: Uint8List.fromList(full.sublist(400)),
            offset: fixnum.Int64(400),
            isLast: true,
            sha256FullFile: digest,
          ),
        );
      },
      buildId: 'build-2',
      fileNameHint: 'demo',
    );

    expect(requestedOffset, 400, reason: 'musi poprosić o wznowienie od długości pliku na dysku, nie od zera');
    expect(await file.readAsBytes(), full);
  });

  test('progress callback reports the running total across a resumed download, not just the new bytes', () async {
    final full = List<int>.generate(1000, (i) => i % 256);
    final digest = sha256.convert(full).toString();
    final partialFile = File('${tempDir.path}/demo-build-3.apk');
    await partialFile.writeAsBytes(full.sublist(0, 400));

    final progressReports = <int>[];
    await downloadArtifactVia(
      downloadFn: (request) => Stream.value(
        Chunk(
          data: Uint8List.fromList(full.sublist(400)),
          offset: fixnum.Int64(400),
          isLast: true,
          sha256FullFile: digest,
        ),
      ),
      buildId: 'build-3',
      fileNameHint: 'demo',
      onProgress: progressReports.add,
    );

    expect(progressReports.last, 1000);
  });

  test('throws ArtifactIntegrityException and deletes the file on a SHA-256 mismatch', () async {
    final bytes = List<int>.generate(100, (i) => i);

    await expectLater(
      downloadArtifactVia(
        downloadFn: (request) => Stream.value(
          Chunk(
            data: Uint8List.fromList(bytes),
            offset: fixnum.Int64(0),
            isLast: true,
            sha256FullFile: 'deadbeef' * 8,
          ),
        ),
        buildId: 'build-4',
        fileNameHint: 'demo',
      ),
      throwsA(isA<ArtifactIntegrityException>()),
    );

    expect(File('${tempDir.path}/demo-build-4.apk').existsSync(), isFalse);
  });

  test('throws StateError if the stream ends without ever marking a chunk as last', () async {
    await expectLater(
      downloadArtifactVia(
        downloadFn: (request) => const Stream<Chunk>.empty(),
        buildId: 'build-5',
        fileNameHint: 'demo',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'a stale/invalid resume offset (invalidArgument) deletes the partial file and retries once from zero',
    () async {
      final full = List<int>.generate(300, (i) => i % 256);
      final digest = sha256.convert(full).toString();

      // Częściowy plik "za długi" względem tego, co serwer faktycznie ma —
      // symuluje np. wyczyszczone artefakty na agencie między próbami.
      final partialFile = File('${tempDir.path}/demo-build-6.apk');
      await partialFile.writeAsBytes(List<int>.filled(999, 0));

      var attempt = 0;
      final file = await downloadArtifactVia(
        downloadFn: (request) {
          attempt++;
          if (attempt == 1) {
            expect(request.resumeFromByteOffset.toInt(), 999);
            throw GrpcError.invalidArgument('Nieprawidłowy resume_from_byte_offset.');
          }
          expect(request.resumeFromByteOffset.toInt(), 0, reason: 'druga próba musi zacząć od zera');
          return Stream.value(
            Chunk(data: Uint8List.fromList(full), offset: fixnum.Int64(0), isLast: true, sha256FullFile: digest),
          );
        },
        buildId: 'build-6',
        fileNameHint: 'demo',
      );

      expect(attempt, 2);
      expect(await file.readAsBytes(), full);
    },
  );

  test('a non-invalidArgument GrpcError propagates without retrying', () async {
    var attempts = 0;
    await expectLater(
      downloadArtifactVia(
        downloadFn: (request) {
          attempts++;
          throw GrpcError.unauthenticated('nope');
        },
        buildId: 'build-7',
        fileNameHint: 'demo',
      ),
      throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)),
    );
    expect(attempts, 1);
  });
}
