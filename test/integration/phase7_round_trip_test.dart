// : round-trip gate.
// Loads test/fixtures/runner.pbxproj via the PUBLIC barrel import,
// saves it back to disk, and asserts byte-identical output.
// This is the final phase gate test for v1.0.

import 'dart:io';

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group(' round-trip', () {
    late Directory tmpInput;

    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
      tmpInput = Directory.systemTemp.createTempSync('xcodeproj_p7_rt_');
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmpInput.existsSync()) tmpInput.deleteSync(recursive: true);
    });

    test('byte-identical round-trip via barrel import', () async {
      final xcodeproj = Directory(p.join(tmpInput.path, 'Runner.xcodeproj'))
        ..createSync();
      const fixturePath = 'test/fixtures/runner.pbxproj';
      File(fixturePath).copySync(p.join(xcodeproj.path, 'project.pbxproj'));

      final original = File(fixturePath).readAsStringSync();

      final project = await XcodeProject.open(xcodeproj.path);
      await project.save();

      final saved = File(
        p.join(xcodeproj.path, 'project.pbxproj'),
      ).readAsStringSync();

      expect(
        saved,
        equals(original),
        reason: ': Round-trip must produce byte-identical output',
      );
    });

    test(
      'Differ.projectDiff on two open()s of same fixture returns null (DIFF-01 cross-check)',
      () async {
        final xcodeprojA = Directory(p.join(tmpInput.path, 'A.xcodeproj'))
          ..createSync();
        final xcodeprojB = Directory(p.join(tmpInput.path, 'B.xcodeproj'))
          ..createSync();
        File(
          'test/fixtures/runner.pbxproj',
        ).copySync(p.join(xcodeprojA.path, 'project.pbxproj'));
        File(
          'test/fixtures/runner.pbxproj',
        ).copySync(p.join(xcodeprojB.path, 'project.pbxproj'));

        final projA = await XcodeProject.open(xcodeprojA.path);
        final projB = await XcodeProject.open(xcodeprojB.path);

        final diff = Differ.projectDiff(projA, projB);
        expect(
          diff,
          isNull,
          reason: 'Two open()s of the same fixture must diff to null',
        );
      },
    );
  });
}
