// Security: — paths normalized; — output only under outputPath.
// NEVER mutate buildSettings in place; NEVER call project.save().

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../config/xc_config.dart';
import '../pbx/xc_build_configuration.dart';
import '../project/xcode_project.dart';
import '_project_path.dart';

/// Subcommand `config-dump` — dumps build settings of all targets as
/// .xcconfig files (one per target per configuration).
/// Port of Ruby `Xcodeproj::Command::ConfigDump`.
class ConfigDumpCommand extends Command<void> {
  @override
  final String name = 'config-dump';

  @override
  final String description =
      'Dumps build settings of all targets as .xcconfig files.';

  @override
  Future<void> run() async {
    final rest = argResults!.rest;
    final projectPath = resolveProjectPath(rest, usage);
    final outputPath = rest.length > 1
        ? p.normalize(rest[1])
        : Directory.current.path;

    // validate output dir exists before writing.
    if (!Directory(outputPath).existsSync()) {
      throw UsageException(
        'Output path must be an existing directory: $outputPath',
        usage,
      );
    }

    final project = await XcodeProject.open(projectPath);

    // Dump project-level configurations.
    await _dumpAllConfigs(
      project.buildConfigurationList.buildConfigurations.toList(),
      'Project',
      outputPath,
    );

    // Dump per-target configurations.
    for (final target in project.targets) {
      final list = target.buildConfigurationList;
      if (list == null) continue;
      await _dumpAllConfigs(
        list.buildConfigurations.toList(),
        target.name ?? 'Unnamed',
        outputPath,
      );
    }

    // NEVER call project.save() in config-dump.
    Logger().success('Config dump complete → $outputPath');
  }

  /// Port of Ruby dump_all_configs + extract_common_settings!.
  /// works on COPIES of buildSettings — never mutates in-memory objects.
  Future<void> _dumpAllConfigs(
    List<XCBuildConfiguration> configs,
    String name,
    String outputPath,
  ) async {
    if (configs.isEmpty) return;

    // build copies — never touch the originals.
    final settingsCopies = <String, Map<String, dynamic>>{
      for (final c in configs)
        (c.name ?? 'default'): Map<String, dynamic>.from(c.buildSettings),
    };

    // Extract settings common to ALL configurations with the same value.
    final commonSettings = _extractCommonSettings(
      settingsCopies.values.toList(),
    );

    // Remove common keys from each per-config copy.
    for (final copy in settingsCopies.values) {
      for (final k in commonSettings.keys) {
        copy.remove(k);
      }
    }

    // all writes go under outputPath/<name>/.
    final targetDir = p.join(outputPath, name);
    await Directory(targetDir).create(recursive: true);

    // Write base xcconfig with common settings.
    final baseXc = XcConfig.create(p.join(targetDir, '${name}_base.xcconfig'));
    commonSettings.forEach((k, v) => baseXc.attributes[k] = _stringify(v));
    await baseXc.save();

    // Write per-configuration xcconfigs that include the base.
    for (final c in configs) {
      final configKey = c.name ?? 'default';
      final cn = configKey.toLowerCase();
      final xc = XcConfig.create(p.join(targetDir, '${name}_$cn.xcconfig'));
      xc.includes.add('${name}_base.xcconfig');
      settingsCopies[configKey]!.forEach(
        (k, v) => xc.attributes[k] = _stringify(v),
      );
      await xc.save();
    }
  }

  /// Intersection of all maps: keys present in ALL maps with the same value.
  Map<String, dynamic> _extractCommonSettings(
    List<Map<String, dynamic>> allSettings,
  ) {
    if (allSettings.isEmpty) return {};
    final result = Map<String, dynamic>.from(allSettings.first);
    for (final other in allSettings.skip(1)) {
      result.removeWhere((k, v) => other[k] != v);
    }
    return result;
  }

  /// Converts a dynamic build setting value to a String for XcConfig.attributes.
  String _stringify(dynamic v) => v is List ? v.join(' ') : v.toString();
}
