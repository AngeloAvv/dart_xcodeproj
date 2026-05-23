// — integration test for XcodeProject.open() and save() round-trip.
// Uses test/fixtures/runner.pbxproj (same fixture as phase4_round_trip_test.dart).
// Constructs a temporary .xcodeproj bundle directory, copies the fixture into it,
// then opens it via XcodeProject.open() and verifies the resulting project state.
// Pattern mirrors test/integration/phase4_round_trip_test.dart for setUp/tearDown.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  group('XcodeProject.open(', () {
    late Directory tmp;
    late Directory xcodeproj;

    setUp(() {
      // Register all types before each test (paired with tearDown clear).
      registerPhase3Types();
      registerPhase4Types();

      // Create a .xcodeproj bundle directory containing the fixture.
      tmp = Directory.systemTemp.createTempSync('xcodeproj_open_');
      xcodeproj = Directory('${tmp.path}/Runner.xcodeproj')..createSync();

      // Copy runner.pbxproj fixture — same path used in phase4_round_trip_test.dart.
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync('${xcodeproj.path}/project.pbxproj');
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    // -------------------------------------------------------------------------
    // Test 1: loads without error
    // -------------------------------------------------------------------------

    test('loads runner.pbxproj without error', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      expect(project, isNotNull);
      expect(project.objectsByUuid, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 2: targets is non-empty
    // -------------------------------------------------------------------------

    test('targets is non-empty after open', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      expect(
        project.targets,
        isNotEmpty,
        reason: 'Flutter Runner.xcodeproj must have at least one build target',
      );
    });

    // -------------------------------------------------------------------------
    // Test 3: mainGroup is non-null
    // -------------------------------------------------------------------------

    test('mainGroup is non-null after open', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      expect(project.mainGroup, isNotNull);
      expect(project.mainGroup, isA<PBXGroup>());
    });

    // -------------------------------------------------------------------------
    // Test 4: objectsByUuid contains PBXProject
    // -------------------------------------------------------------------------

    test('objectsByUuid contains PBXProject after open', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      final hasPbxProject = project.objectsByUuid.values.any(
        (o) => o.isa == 'PBXProject',
      );
      expect(
        hasPbxProject,
        isTrue,
        reason: 'Every .pbxproj must have exactly one PBXProject root object',
      );
    });

    // -------------------------------------------------------------------------
    // Test 5: rootObject is a PBXProject
    // -------------------------------------------------------------------------

    test('rootObject is a PBXProject', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      expect(project.rootObject, isA<PBXProject>());
    });

    // -------------------------------------------------------------------------
    // Test 6: objectsByUuid is non-empty (proxy for versions being set)
    // -------------------------------------------------------------------------

    test(
      'objectsByUuid is non-empty (archiveVersion and objectVersion set)',
      () async {
        final project = await XcodeProject.open(xcodeproj.path);
        // Indirect proxy: if versions parse correctly, all objects load correctly.
        expect(project.objectsByUuid.isNotEmpty, isTrue);
      },
    );

    // -------------------------------------------------------------------------
    // Test 7: save() writes to disk without error (no-mutation round-trip)
    // -------------------------------------------------------------------------

    test('save() writes to disk without error', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      await project.save();
      final pbxprojFile = File('${xcodeproj.path}/project.pbxproj');
      expect(pbxprojFile.existsSync(), isTrue);
      expect(pbxprojFile.lengthSync(), greaterThan(0));
    });

    test('save() output starts with UTF8 magic header', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      await project.save();
      final content = File(
        '${xcodeproj.path}/project.pbxproj',
      ).readAsStringSync();
      expect(content, startsWith('// !\$*UTF8*\$!'));
    });

    test('save() output contains rootObject UUID', () async {
      final project = await XcodeProject.open(xcodeproj.path);
      await project.save();
      final content = File(
        '${xcodeproj.path}/project.pbxproj',
      ).readAsStringSync();
      expect(content, contains(project.rootObject.uuid));
    });
  });
}
