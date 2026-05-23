// ignore_for_file: avoid_print
// example/main.dart
// : demonstrates the dart_xcodeproj public API end-to-end.
// Run with:
// dart run example/main.dart
// This will create a temporary .xcodeproj in the system temp dir,
// add a native target and a file reference, then save to disk.

import 'dart:io';

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  // Use a scoped temp directory (never writes outside temp).
  final outDir = Directory.systemTemp.createTempSync('dart_xcodeproj_example_');
  final projectPath = p.join(outDir.path, 'Example.xcodeproj');

  // 1. Create a new empty project on disk.
  final project = await XcodeProject.create(projectPath);
  print('Created project at $projectPath');

  // 2. Add a file reference (Sources/main.swift) into the main group.
  final mainSwift = project.newFile('Sources/main.swift');
  print('Added file: ${mainSwift.path}');

  // 3. Add a native target via ProjectHelper.
  // ProductHelper expects the products group for the product file reference.
  final productsGroup = project.productsGroup;
  final target = ProjectHelper.newTarget(
    project,
    'application',
    'ExampleApp',
    'ios',
    '16.0',
    productsGroup,
    'swift',
    'ExampleApp',
  );
  print('Added target: ${target.name}');

  // 4. Wire the file reference into the target's Sources build phase.
  // ProjectHelper.newTarget creates a PBXSourcesBuildPhase for 'application'.
  final sourcesPhase = target.buildPhases
      .whereType<PBXSourcesBuildPhase>()
      .firstOrNull;
  if (sourcesPhase != null) {
    sourcesPhase.addFileReference(mainSwift);
    print('Wired ${mainSwift.path} into ${target.name} sources build phase.');
  }

  // 5. Save to disk.
  await project.save();
  print(
    'Saved. Targets: ${project.targets.length}, '
    'mainGroup children: ${project.mainGroup.children.length}',
  );

  // Verify the file was written.
  final pbxproj = File(p.join(projectPath, 'project.pbxproj'));
  print('project.pbxproj size: ${pbxproj.lengthSync()} bytes');

  // Clean up temp directory.
  outDir.deleteSync(recursive: true);
  print('Done — temp dir cleaned up.');
}
