// XcodeprojRunner — registers all four CLI subcommands.
// executable name MUST be 'dart_xcodeproj' (matches package name).

import 'package:args/command_runner.dart';

import 'config_dump_command.dart';
import 'project_diff_command.dart';
import 'show_command.dart';
import 'sort_command.dart';

/// CommandRunner that registers all four dart_xcodeproj subcommands.
class XcodeprojRunner extends CommandRunner<void> {
  XcodeprojRunner()
    : super('dart_xcodeproj', 'Xcode project manipulation tool.') {
    addCommand(ShowCommand());
    addCommand(SortCommand());
    addCommand(ProjectDiffCommand());
    addCommand(ConfigDumpCommand());
  }
}
