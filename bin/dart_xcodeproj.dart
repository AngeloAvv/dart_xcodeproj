import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dart_xcodeproj/src/command/runner.dart';

Future<void> main(List<String> args) async {
  final runner = XcodeprojRunner();
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}
