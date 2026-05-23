// Shared project path resolution helper for CLI commands.
// Port of Ruby xcodeproj_path_argument pattern.
// Security: — every user-supplied path is normalized via p.normalize
// before Directory.existsSync / XcodeProject.open.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

/// Returns the .xcodeproj path from [rest] at [index], or searches the
/// current working directory if no positional argument was supplied.
/// Throws [UsageException] with [usage] text when no valid project is found.
/// Security: — all paths are normalized via [p.normalize].
String resolveProjectPath(List<String> rest, String usage, {int index = 0}) {
  if (rest.length > index) {
    final candidate = p.normalize(rest[index]);
    if (!candidate.endsWith('.xcodeproj') ||
        !Directory(candidate).existsSync()) {
      throw UsageException(
        'Could not find a valid .xcodeproj at: $candidate',
        usage,
      );
    }
    return candidate;
  }
  final entries = Directory.current.listSync();
  for (final entry in entries) {
    if (entry is Directory && entry.path.endsWith('.xcodeproj')) {
      return p.normalize(entry.path);
    }
  }
  throw UsageException(
    'No .xcodeproj found in current directory. '
    'Specify the project path as the first argument.',
    usage,
  );
}
