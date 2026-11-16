// `XcodeProject.predictabilizeUuids` must write exactly what Ruby's
// `Project#predictabilize_uuids` followed by `save` writes.
//
// The expected files are the output of xcodeproj (see generate.rb in
// test/fixtures/predictabilized/, which also lists the gem version) for the
// pristine `flutter create` projects in test/fixtures/annotations/, for
// test/fixtures/subproject.pbxproj and for a project that has the kinds of
// object Flutter's do not (kitchen_sink.rb). Every input is opened from a bundle named
// `Runner.xcodeproj`, the seed of all the paths.

import 'dart:io';

import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures';
const _expectedDir = '$_fixtures/predictabilized';

/// Fixture name -> its input pbxproj.
const _inputs = {
  'ios': '$_fixtures/annotations/ios.xcodeproj/project.pbxproj',
  'macos': '$_fixtures/annotations/macos.xcodeproj/project.pbxproj',
  'ios_spm': '$_fixtures/annotations/ios_spm.xcodeproj/project.pbxproj',
  'macos_spm': '$_fixtures/annotations/macos_spm.xcodeproj/project.pbxproj',
  'edge': '$_fixtures/annotations/edge.xcodeproj/project.pbxproj',
  'subproject': '$_fixtures/subproject.pbxproj',
  'kitchen_sink': '$_expectedDir/kitchen_sink.pbxproj',
  // The remote target of a proxy into another project has the UUID of a local
  // target, and Ruby rewrites it like a local one.
  'foreign_proxy': '$_expectedDir/foreign_proxy.pbxproj',
};

/// The UUIDs that are not objects of the project and so are not rewritten: the
/// remote target a project reference points to belongs to the other project.
const _foreignUuids = {
  'subproject': {'E59D8E4D87B0A99DD2842F22'},
};

/// Opens [input] from a `Runner.xcodeproj` bundle in a temporary directory.
Future<XcodeProject> _open(String input) async {
  final tmp = Directory.systemTemp.createTempSync('predictabilize_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final bundle = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
  File(input).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(bundle.path);
}

String _saved(XcodeProject project) =>
    File('${project.path}/project.pbxproj').readAsStringSync();

void main() {
  for (final entry in _inputs.entries) {
    group('predictabilizeUuids of the ${entry.key} project', () {
      late String expected;

      setUp(() {
        expected = File(
          '$_expectedDir/${entry.key}.predictabilized.pbxproj',
        ).readAsStringSync();
      });

      test('writes the same file as Ruby', () async {
        final project = await _open(entry.value);

        project.predictabilizeUuids();
        await project.save();

        expect(_saved(project), equals(expected));
      });

      test('leaves no UUID that is not an object', () async {
        final project = await _open(entry.value);

        project.predictabilizeUuids();
        await project.save();

        final foreign = _foreignUuids[entry.key] ?? const <String>{};
        final uuids = project.objectsByUuid.keys.toSet();
        final saved = _saved(project);
        final random = RegExp(
          r'\b[0-9A-F]{24}\b',
        ).allMatches(saved).map((m) => m.group(0)!).toSet();
        expect(random, equals(foreign), reason: 'a random UUID is left');
        // Every 32-char UUID is an object of the project.
        final dangling = RegExp(r'\b[0-9A-F]{32}\b')
            .allMatches(saved)
            .map((m) => m.group(0)!)
            .where((uuid) => !uuids.contains(uuid))
            .toSet();
        expect(dangling, isEmpty);
      });
    });
  }
}
