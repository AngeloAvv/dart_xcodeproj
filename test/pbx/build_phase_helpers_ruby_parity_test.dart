// The build phase helpers of PBXNativeTarget must write exactly what Ruby's
// xcodeproj writes.
//
// Each scenario below is the Dart twin of the one of the same name in
// test/fixtures/build_phases/generate.rb: it runs on a pristine `flutter create`
// project, then `predictabilizeUuids` (the new objects get random UUIDs
// otherwise) and `save`, and the result is compared with the file the Ruby
// script wrote. See test/fixtures/build_phases/README.md.

import 'dart:io';

import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

import 'helpers/bare_target.dart';

const _annotations = 'test/fixtures/annotations';
const _expectedDir = 'test/fixtures/build_phases';

PBXNativeTarget _runner(XcodeProject project) => project.targets
    .whereType<PBXNativeTarget>()
    .firstWhere((t) => t.name == 'Runner');

/// scenario name -> its steps, twin of `SCENARIOS` in generate.rb.
final Map<String, void Function(XcodeProject)> _scenarios = {
  'on_demand': (project) {
    final bare = bareTarget(project);
    bare.sourceBuildPhase;
    bare.frameworksBuildPhase;
    bare.resourcesBuildPhase;
    bare.headersBuildPhase;
    bare.sourceBuildPhase;
    _runner(project).headersBuildPhase;
  },
  'add_resources': (project) {
    final target = _runner(project);
    final first = project.newFile('Runner/Assets/a.png');
    final second = project.newFile('Runner/b.json');
    final third = project.newFile('Runner/c.txt');
    target.addResources([first, second]);
    target.addResources([first]);
    target.addResources([target.resourcesBuildPhase.files.first.fileRef!]);
    target.addResources([]);
    target.addResources([third, third]);
    bareTarget(project).addResources([first]);
  },
};

/// Opens the pristine project [name] from a `Runner.xcodeproj` bundle in a
/// temporary directory, as generate.rb does.
Future<XcodeProject> _open(String name) async {
  final tmp = Directory.systemTemp.createTempSync('build_phases_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final bundle = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
  File(
    '$_annotations/$name.xcodeproj/project.pbxproj',
  ).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(bundle.path);
}

void main() {
  for (final name in ['ios', 'macos']) {
    for (final entry in _scenarios.entries) {
      test(
        '${entry.key} on the $name project writes the same file as Ruby',
        () async {
          final project = await _open(name);

          entry.value(project);
          project.predictabilizeUuids();
          await project.save();

          expect(
            File('${project.path}/project.pbxproj').readAsStringSync(),
            equals(
              File(
                '$_expectedDir/$name.${entry.key}.pbxproj',
              ).readAsStringSync(),
            ),
          );
        },
      );
    }
  }
}
