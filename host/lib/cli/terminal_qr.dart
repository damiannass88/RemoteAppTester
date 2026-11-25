import 'package:qr/qr.dart';

/// Rysuje kod QR znakami Unicode, żeby host bez ekranu (VPS przez SSH,
/// konsola webowa dostawcy) mógł pokazać kod parowania bez ekranu
/// graficznego — odpowiednik QR z `ui/pairing_screen.dart`.
///
/// Jeden znak = dwa moduły w pionie (półbloki `▀`/`▄`/`█`), więc kod jest
/// kwadratowy w typowej czcionce terminala. Domyślnie "jasne" moduły i
/// margines rysowane są pełnym znakiem, a "ciemne" spacją — tak kod jest
/// poprawny (ciemne na jasnym) w terminalu z ciemnym tłem, czyli w
/// większości konsol SSH. [invert] odwraca to dla terminali z jasnym tłem.
String renderQrForTerminal(String data, {bool invert = false, int quietZone = 2}) {
  final qr = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L));
  final size = qr.moduleCount + quietZone * 2;

  bool drawn(int row, int col) {
    final r = row - quietZone;
    final c = col - quietZone;
    final inCode = r >= 0 && c >= 0 && r < qr.moduleCount && c < qr.moduleCount;
    final dark = inCode && qr.isDark(r, c);
    return invert ? dark : !dark;
  }

  final out = StringBuffer();
  for (var row = 0; row < size; row += 2) {
    for (var col = 0; col < size; col++) {
      final top = drawn(row, col);
      final bottom = row + 1 < size ? drawn(row + 1, col) : !invert;
      out.write(switch ((top, bottom)) {
        (true, true) => '█',
        (true, false) => '▀',
        (false, true) => '▄',
        (false, false) => ' ',
      });
    }
    out.writeln();
  }
  return out.toString();
}
