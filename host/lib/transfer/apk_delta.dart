import 'dart:io';
import 'dart:typed_data';

/// Format różnicy instalek „RTD1” (całość dodatkowo w gzip):
///
/// ```
/// "RTD1"  varint(rozmiar wyniku)
/// { 0x01 varint(offset w bazie) varint(długość) }   COPY — bajty z instalki, którą telefon już ma
/// { 0x02 varint(długość) bajty }                     DATA — nowe bajty
/// 0x00                                               koniec
/// ```
///
/// Instalka APK to archiwum ZIP, w którym większość wpisów (silnik Fluttera,
/// biblioteki, zasoby) między kolejnymi buildami się nie zmienia, tylko
/// przesuwa — dlatego przesyłamy wyłącznie zmienione fragmenty. Wynik telefon
/// sprawdza sumą SHA-256 całej instalki, więc błąd w delcie nie może dać
/// innej aplikacji niż zbudowana.
const deltaMagic = [0x52, 0x54, 0x44, 0x31]; // RTD1
const opEnd = 0x00;
const opCopy = 0x01;
const opData = 0x02;

const _block = 2048;

/// Liczy deltę [base] → [target] (bez kompresji). [base] może być pusty.
Uint8List computeDelta(Uint8List base, Uint8List target) {
  final out = BytesBuilder(copy: false)..add(deltaMagic);
  _varint(out, target.length);

  var literalStart = 0;
  void flushLiteral(int end) {
    if (end <= literalStart) return;
    out.addByte(opData);
    _varint(out, end - literalStart);
    out.add(Uint8List.sublistView(target, literalStart, end));
  }

  if (base.length >= _block && target.length >= _block) {
    final index = <int, int>{};
    for (var off = 0; off + _block <= base.length; off += _block) {
      index.putIfAbsent(_weak(base, off), () => off);
    }
    var i = 0;
    var a = 0, b = 0;
    void init(int at) {
      a = 0;
      b = 0;
      for (var k = 0; k < _block; k++) {
        a = (a + target[at + k]) & 0xffff;
        b = (b + (_block - k) * target[at + k]) & 0xffff;
      }
    }

    init(0);
    while (true) {
      final candidate = index[a | (b << 16)];
      if (candidate != null && _same(base, candidate, target, i, _block)) {
        var s = candidate, t = i;
        while (s > 0 && t > literalStart && base[s - 1] == target[t - 1]) {
          s--;
          t--;
        }
        var e = candidate + _block, u = i + _block;
        while (e < base.length && u < target.length && base[e] == target[u]) {
          e++;
          u++;
        }
        flushLiteral(t);
        out.addByte(opCopy);
        _varint(out, s);
        _varint(out, e - s);
        i = u;
        literalStart = u;
        if (i + _block > target.length) break;
        init(i);
        continue;
      }
      if (i + _block >= target.length) break;
      final gone = target[i], added = target[i + _block];
      a = (a - gone + added) & 0xffff;
      b = (b - _block * gone + a) & 0xffff;
      i++;
    }
  }
  flushLiteral(target.length);
  out.addByte(opEnd);
  return out.takeBytes();
}

/// Składa instalkę z [base] i (rozpakowanej) delty — używane w testach;
/// telefon ma własną, strumieniową wersję.
Uint8List applyDelta(Uint8List base, Uint8List delta) {
  var pos = 0;
  int varint() {
    var result = 0, shift = 0;
    while (true) {
      final byte = delta[pos++];
      result |= (byte & 0x7f) << shift;
      if (byte < 0x80) return result;
      shift += 7;
    }
  }

  for (var k = 0; k < 4; k++) {
    if (delta[pos++] != deltaMagic[k]) throw const FormatException('To nie jest delta RTD1.');
  }
  final size = varint();
  final out = BytesBuilder(copy: false);
  while (true) {
    final op = delta[pos++];
    if (op == opEnd) break;
    if (op == opCopy) {
      final off = varint(), len = varint();
      out.add(Uint8List.sublistView(base, off, off + len));
    } else if (op == opData) {
      final len = varint();
      out.add(Uint8List.sublistView(delta, pos, pos + len));
      pos += len;
    } else {
      throw FormatException('Nieznana operacja delty: $op');
    }
  }
  if (out.length != size) throw const FormatException('Delta dała plik o złym rozmiarze.');
  return out.takeBytes();
}

/// Delta gotowa do wysłania: plik gzip + jego suma i rozmiar.
class DeltaFile {
  const DeltaFile(this.path, this.sizeBytes, this.sha256Hex);
  final String path;
  final int sizeBytes;
  final String sha256Hex;
}

/// Liczy deltę plików [basePath] (null = brak bazy) → [targetPath] i zapisuje
/// ją skompresowaną do [outPath]. Ciężka praca — wołać w osobnym izolacie.
void writeDeltaFile({String? basePath, required String targetPath, required String outPath}) {
  final base = basePath == null ? Uint8List(0) : File(basePath).readAsBytesSync();
  final target = File(targetPath).readAsBytesSync();
  final packed = GZipCodec(level: 6).encode(computeDelta(base, target));
  final tmp = File('$outPath.part');
  tmp.parent.createSync(recursive: true);
  tmp.writeAsBytesSync(packed, flush: true);
  tmp.renameSync(outPath);
}

int _weak(Uint8List data, int off) {
  var a = 0, b = 0;
  for (var k = 0; k < _block; k++) {
    a = (a + data[off + k]) & 0xffff;
    b = (b + (_block - k) * data[off + k]) & 0xffff;
  }
  return a | (b << 16);
}

bool _same(Uint8List x, int xi, Uint8List y, int yi, int len) {
  for (var k = 0; k < len; k++) {
    if (x[xi + k] != y[yi + k]) return false;
  }
  return true;
}

void _varint(BytesBuilder out, int value) {
  while (value >= 0x80) {
    out.addByte((value & 0x7f) | 0x80);
    value >>= 7;
  }
  out.addByte(value);
}
