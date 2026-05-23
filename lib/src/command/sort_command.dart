// Security: — resolveProjectPath normalizes the path.

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../project/groups_position.dart';
import '../project/xcode_project.dart';
import '_project_path.dart';

/// Subcommand `sort` — sorts the given Xcode project in-place.
/// Port of Ruby `Xcodeproj::Command::Sort`.
class SortCommand extends Command<void> {
  @override
  final String name = 'sort';

  @override
  final String description = 'Sorts the given Xcode project in-place.';

  SortCommand() {
    argParser.addOption(
      'group-option',
      allowed: ['above', 'below'],
      help:
          'Position of groups when sorting. '
          'If omitted, groups and files are interleaved.',
    );
  }

  @override
  Future<void> run() async {
    final projectPath = resolveProjectPath(argResults!.rest, usage);
    final groupOptionRaw = argResults!['group-option'] as String?;
    final groupsPosition = switch (groupOptionRaw) {
      'above' => GroupsPosition.above,
      'below' => GroupsPosition.below,
      _ => null,
    };

    final project = await XcodeProject.open(projectPath);
    project.sort(groupsPosition: groupsPosition);
    await project.save();

    Logger().success('The "${p.basename(projectPath)}" project was sorted.');
  }
}
