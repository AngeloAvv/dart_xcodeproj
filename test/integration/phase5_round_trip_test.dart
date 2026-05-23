// round-trip integration test.
// Validates the complete save path:
// XcodeProject.open(path) → project.save() → byte-identical .pbxproj output
// This is the definitive integration test for dart_xcodeproj's core promise:
// open a real Xcode project and save it back without any changes.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('phase5 round-trip', () {
    late Directory tmpInput;
    late Directory tmpOutput;

    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
      tmpInput = Directory.systemTemp.createTempSync('xcodeproj_p5_in_');
      tmpOutput = Directory.systemTemp.createTempSync('xcodeproj_p5_out_');
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmpInput.existsSync()) tmpInput.deleteSync(recursive: true);
      if (tmpOutput.existsSync()) tmpOutput.deleteSync(recursive: true);
    });

    // -------------------------------------------------------------------------
    // Test 1: Byte-identical round-trip (the phase gate)
    // -------------------------------------------------------------------------

    test('no-mutation round-trip produces byte-identical output', () async {
      // Setup: copy fixture into a .xcodeproj bundle directory
      final xcodeproj = Directory(p.join(tmpInput.path, 'Runner.xcodeproj'))
        ..createSync();
      const fixturePath = 'test/fixtures/runner.pbxproj';
      File(fixturePath).copySync(p.join(xcodeproj.path, 'project.pbxproj'));

      // Open
      final project = await XcodeProject.open(xcodeproj.path);

      // Save (writes to project.path/project.pbxproj = the temp copy)
      await project.save();

      // Compare
      final original = File(fixturePath).readAsStringSync();
      final saved = File(
        p.join(xcodeproj.path, 'project.pbxproj'),
      ).readAsStringSync();
      expect(
        saved,
        equals(original),
        reason: 'Round-trip must produce byte-identical output',
      );
    });

    // -------------------------------------------------------------------------
    // Test 2: Open loads all objects without unrecognized ISA errors
    // -------------------------------------------------------------------------

    test('open loads all objects without unrecognized ISA errors', () async {
      final xcodeproj = Directory(p.join(tmpInput.path, 'Runner.xcodeproj'))
        ..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync(p.join(xcodeproj.path, 'project.pbxproj'));

      final project = await XcodeProject.open(xcodeproj.path);

      expect(project.objectsByUuid, isNotEmpty);
      expect(project.targets, isNotEmpty);
      expect(project.mainGroup, isNotNull);
      // Verify PBXProject is in the graph
      final pbxProjectObjs = project.objectsByUuid.values
          .where((o) => o.isa == 'PBXProject')
          .toList();
      expect(pbxProjectObjs, hasLength(1));
    });

    // -------------------------------------------------------------------------
    // Test 3: Targets accessible by name after open
    // -------------------------------------------------------------------------

    test('targets are accessible by name after open', () async {
      final xcodeproj = Directory(p.join(tmpInput.path, 'Runner.xcodeproj'))
        ..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync(p.join(xcodeproj.path, 'project.pbxproj'));

      final project = await XcodeProject.open(xcodeproj.path);

      final targetNames = project.targets
          .map((t) => (t as dynamic).name as String?)
          .toList();
      expect(targetNames, contains('Runner'));
    });

    // -------------------------------------------------------------------------
    // Test 4: create + save produces a readable project
    // -------------------------------------------------------------------------

    test('create + save produces a readable project', () async {
      final outputDir = Directory(p.join(tmpOutput.path, 'New.xcodeproj'));
      final project = await XcodeProject.create(outputDir.path);
      await project.save();

      // Verify the file was written
      final pbxprojFile = File(p.join(outputDir.path, 'project.pbxproj'));
      expect(pbxprojFile.existsSync(), isTrue);
      expect(pbxprojFile.lengthSync(), greaterThan(0));

      // Verify it can be re-opened
      final reopened = await XcodeProject.open(outputDir.path);
      expect(reopened.objectsByUuid, isNotEmpty);
      expect(reopened.buildConfigurations, hasLength(2)); // Debug + Release
    });
  });
}
