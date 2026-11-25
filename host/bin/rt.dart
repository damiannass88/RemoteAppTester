// Skrót: "rt" = "remoteapptester" (ten sam program, krótsza nazwa polecenia).
import 'dart:io';

import 'package:remotetester_host/cli/remotetester_cli.dart';

Future<void> main(List<String> args) async {
  exitCode = await runCli(args);
}
