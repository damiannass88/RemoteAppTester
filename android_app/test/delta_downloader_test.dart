import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:remotetester/generated/remote_tester.pbgrpc.dart';
import 'package:remotetester/transfer/artifact_downloader.dart';
import 'package:remotetester/transfer/delta_downloader.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Delta RTD1 w formacie hosta (host/lib/transfer/apk_delta.dart).
List<int> rtd(int size, List<(int op, int a, List<int> data)> ops) {
  final out = <int>[0x52, 0x54, 0x44, 0x31];
  void varint(int v) {
    while (v >= 0x80) {
      out.add((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.add(v);
  }

  varint(size);
  for (final (op, a, data) in ops) {
    out.add(op);
    if (op == 1) {
      varint(a);
      varint(data.length); // przy COPY: data służy tylko do długości
    } else {
      varint(data.length);
      out.addAll(data);
    }
  }
  out.add(0);
  return gzip.encode(out);
}

Stream<Chunk> serve(List<int> packed, List<int> target, {int from = 0}) async* {
  final rest = packed.sublist(from);
  final half = rest.length ~/ 2;
  yield Chunk(data: rest.sublist(0, half), offset: fixnum.Int64(from), totalSize: fixnum.Int64(packed.length));
  yield Chunk(data: rest.sublist(half), offset: fixnum.Int64(from + half), totalSize: fixnum.Int64(packed.length));
  yield Chunk(
    isLast: true,
    sha256FullFile: sha256.convert(packed).toString(),
    targetSha256: sha256.convert(target).toString(),
    targetSize: fixnum.Int64(target.length),
  );
}

void main() {
  late Directory temp;
  late Directory cache;
  late Directory base;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('delta_dl_');
    cache = Directory('${temp.path}/cache')..createSync();
    base = Directory('${temp.path}/apk');
    PathProviderPlatform.instance = _FakePathProvider(cache.path);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Never noFull(ArtifactRequest _) => throw StateError('nie powinno pobierać całości');

  Future<File> download(DownloadDeltaCall fn, {String build = 'b1'}) => downloadApkVia(
        deltaFn: fn,
        fullFn: noFull,
        projectId: 'proj',
        buildId: build,
        cacheDir: cache,
        baseDir: base,
      );

  test('first download is the whole APK; the next one rebuilds from the kept copy', () async {
    final v1 = List<int>.generate(5000, (i) => i % 251);
    final first = await download((r) {
      expect(r.baseSha256, isEmpty);
      return serve(rtd(v1.length, [(2, 0, v1)]), v1);
    });
    expect(await first.readAsBytes(), v1);

    final v2 = [...v1.sublist(0, 3000), 7, 7, 7, ...v1.sublist(3000)];
    final second = await download((r) {
      expect(r.baseSha256, sha256.convert(v1).toString());
      return serve(rtd(v2.length, [(1, 0, v1.sublist(0, 3000)), (2, 0, [7, 7, 7]), (1, 3000, v1.sublist(3000))]), v2);
    }, build: 'b2');
    expect(await second.readAsBytes(), v2);
    expect(cache.listSync(), isEmpty, reason: 'delta usunięta po złożeniu');
  });

  test('host without our base: falls back to the whole APK', () async {
    final v1 = [1, 2, 3];
    await download((_) => serve(rtd(3, [(2, 0, v1)]), v1));
    final v2 = [4, 5, 6, 7];
    final calls = <String>[];
    final file = await download((r) {
      calls.add(r.baseSha256);
      if (r.baseSha256.isNotEmpty) return Stream.error(GrpcError.failedPrecondition('brak'));
      return serve(rtd(4, [(2, 0, v2)]), v2);
    }, build: 'b2');
    expect(calls, [sha256.convert(v1).toString(), '']);
    expect(await file.readAsBytes(), v2);
  });

  test('a wrong result is rejected and the kept copy stays intact', () async {
    final v1 = [1, 2, 3];
    await download((_) => serve(rtd(3, [(2, 0, v1)]), v1));
    await expectLater(
      download((_) => serve(rtd(3, [(2, 0, [9, 9, 9])]), [1, 1, 1]), build: 'b2'),
      throwsA(isA<ArtifactIntegrityException>()),
    );
    expect(File('${base.path}/proj.apk').readAsBytesSync(), v1);
  });

  test('resumes a partly downloaded delta', () async {
    final v1 = List<int>.generate(3000, (i) => i % 7);
    final packed = rtd(v1.length, [(2, 0, v1)]);
    File('${cache.path}/b1-full.rtd').writeAsBytesSync(packed.sublist(0, 10));
    final file = await download((r) {
      expect(r.resumeFromByteOffset.toInt(), 10);
      return serve(packed, v1, from: 10);
    });
    expect(await file.readAsBytes(), v1);
  });

  test('older host without DownloadDelta: plain download, kept as the next base', () async {
    final v1 = Uint8List.fromList([5, 6, 7]);
    final file = await downloadApkVia(
      deltaFn: (_) => Stream.error(GrpcError.unimplemented('brak')),
      fullFn: (_) => Stream.value(Chunk(data: v1, isLast: true, sha256FullFile: sha256.convert(v1).toString())),
      projectId: 'proj',
      buildId: 'b1',
      cacheDir: cache,
      baseDir: base,
    );
    expect(await file.readAsBytes(), v1);
    expect(File('${base.path}/proj.sha256').readAsStringSync(), sha256.convert(v1).toString());
  });
}
