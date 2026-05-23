// Security: — resolveProjectPath normalizes the path.
// NEVER import package:yaml/ — only yaml_writer is used for encoding.

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:yaml_writer/yaml_writer.dart';

import '../project/xcode_project.dart';
import '_project_path.dart';

/// Subcommand `show` — prints an overview of an Xcode project as YAML.
/// Port of Ruby `Xcodeproj::Command::Show`.
class ShowCommand extends Command<void> {
  static const _validFormats = ['hash', 'tree_hash', 'raw'];

  @override
  final String name = 'show';

  @override
  final String description =
      'Shows an overview of a project in YAML. '
      'If no PROJECT is specified, searches the current directory.';

  ShowCommand() {
    argParser.addOption(
      'format',
      allowed: _validFormats,
      help: 'Output format (default: pretty_print)',
    );
  }

  @override
  Future<void> run() async {
    final projectPath = resolveProjectPath(argResults!.rest, usage);
    final project = await XcodeProject.open(projectPath);
    final format = argResults!['format'] as String?;
    final logger = Logger();
    final writer = YamlWriter();

    switch (format) {
      case 'hash':
        logger.info(writer.write(project.toHash()));
      case 'tree_hash':
        logger.info(writer.write(project.toTreeHash()));
      case 'raw':
        logger.info(writer.write(project.toHash()));
      default:
        logger.info(writer.write(project.prettyPrint()));
    }
  }
}
