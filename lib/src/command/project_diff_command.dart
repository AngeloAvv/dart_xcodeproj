// Security: — all paths normalized via p.normalize.
// only yaml_writer used for encoding (never package:yaml/).
// uses toTreeHash(), never toHash(), for UUID-agnostic diff.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml_writer/yaml_writer.dart';

import '../differ/differ.dart';
import '../project/xcode_project.dart';

/// Subcommand `project-diff` — shows the UUID-agnostic diff between two
/// Xcode projects. Array order differences are ignored.
/// Port of Ruby `Xcodeproj::Command::ProjectDiff`.
class ProjectDiffCommand extends Command<void> {
  @override
  final String name = 'project-diff';

  @override
  final String description =
      'Shows the UUID-agnostic diff between two Xcode projects. '
      'Array order differences are ignored.';

  ProjectDiffCommand() {
    argParser.addMultiOption(
      'ignore',
      abbr: 'i',
      help: 'Key to ignore in comparison. Can be repeated.',
    );
  }

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    if (rest.length < 2) {
      throw UsageException('PROJECT1 and PROJECT2 are required.', usage);
    }

    // normalize and validate both paths.
    final path1 = p.normalize(rest[0]);
    final path2 = p.normalize(rest[1]);

    for (final path in [path1, path2]) {
      if (!path.endsWith('.xcodeproj') || !Directory(path).existsSync()) {
        throw UsageException(
          'Could not find a valid .xcodeproj at: $path',
          usage,
        );
      }
    }

    final keysToIgnore =
        (argResults!['ignore'] as List<dynamic>?)?.cast<String>() ?? <String>[];

    final project1 = await XcodeProject.open(path1);
    final project2 = await XcodeProject.open(path2);

    // use toTreeHash() — UUID-agnostic tree representation.
    final h1 = project1.toTreeHash();
    final h2 = project2.toTreeHash();

    final diff = Differ.diff(
      h1,
      h2,
      key1: path1,
      key2: path2,
      idKey: 'displayName',
      keysToIgnore: keysToIgnore,
    );

    final logger = Logger();
    if (diff == null) {
      logger.success('Projects are identical.');
    } else {
      logger.info(YamlWriter().write(diff));
    }
  }
}
