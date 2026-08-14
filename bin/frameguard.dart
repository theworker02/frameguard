import 'dart:io';

import 'package:frameguard/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  exit(await runFrameGuardCli(args));
}
