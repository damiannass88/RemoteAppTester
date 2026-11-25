// RemoteAppTester host — CLI dla Windows i Linuxa (Ubuntu VPS). Kompilacja do
// pojedynczej binarki, także z Windows na Linuxa:
//   dart compile exe bin/remoteapptester.dart -o build/remoteapptester-linux-x64 --target-os linux --target-arch x64
import 'dart:io';

import 'package:remotetester_host/cli/remotetester_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
