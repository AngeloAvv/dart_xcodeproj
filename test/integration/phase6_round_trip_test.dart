// — Integration: cross-format round-trip tests.
// xcconfig + workspace + scheme (simple + complex) all round-trip byte-identically.

import 'dart:io';

import 'package:dart_xcodeproj/src/config/xc_config.dart';
import 'package:dart_xcodeproj/src/workspace/xc_workspace.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('phase6_round_trip_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // -------------------------------------------------------------------------
  // xcconfig round-trip (byte-identical)
  // -------------------------------------------------------------------------

  test(
    'xcconfig: open Base.xcconfig, save to tmp, bytes equal original',
    () async {
      const fixturePath = 'test/fixtures/config/Base.xcconfig';
      final orig = File(fixturePath).readAsBytesSync();

      // XcConfig.open is async, then save() to the fixture path copy in tmp
      final destPath = p.join(tmp.path, 'Base.xcconfig');
      await File(fixturePath).copy(destPath);
      final config = await XcConfig.open(destPath);
      await config.save();

      final saved = File(destPath).readAsBytesSync();
      expect(saved, equals(orig), reason: 'xcconfig byte-identical round-trip');
    },
  );

  // -------------------------------------------------------------------------
  // workspace round-trip (byte-identical)
  // -------------------------------------------------------------------------

  test(
    'workspace: open Sample.xcworkspace, save, bytes equal original',
    () async {
      const fixturePath =
          'test/fixtures/workspace/Sample.xcworkspace/contents.xcworkspacedata';
      final orig = File(fixturePath).readAsBytesSync();

      // Copy the workspace to tmp directory so we can save in-place
      final destWorkspacePath = p.join(tmp.path, 'Sample.xcworkspace');
      await Directory(destWorkspacePath).create();
      await File(
        fixturePath,
      ).copy(p.join(destWorkspacePath, 'contents.xcworkspacedata'));

      final workspace = await XCWorkspace.open(destWorkspacePath);
      await workspace.save();

      final saved = File(
        p.join(destWorkspacePath, 'contents.xcworkspacedata'),
      ).readAsBytesSync();
      expect(
        saved,
        equals(orig),
        reason: 'workspace byte-identical round-trip',
      );
    },
  );

  // -------------------------------------------------------------------------
  // scheme round-trip (simple Demo.xcscheme — byte-identical)
  // -------------------------------------------------------------------------

  test(
    'scheme (simple): open Demo.xcscheme, save, bytes equal original',
    () async {
      const fixturePath = 'test/fixtures/scheme/Demo.xcscheme';
      final orig = File(fixturePath).readAsBytesSync();

      final destPath = p.join(tmp.path, 'Demo.xcscheme');
      final scheme = await XCScheme.open(fixturePath);
      await scheme.saveAs(destPath);

      final saved = File(destPath).readAsBytesSync();
      expect(
        saved,
        equals(orig),
        reason: 'Demo.xcscheme byte-identical round-trip',
      );
    },
  );

  // -------------------------------------------------------------------------
  // scheme round-trip (complex Complex.xcscheme — byte-identical, SCH-08 gate)
  // -------------------------------------------------------------------------

  test(
    'scheme (complex): open Complex.xcscheme, save, bytes equal original',
    () async {
      const fixturePath = 'test/fixtures/scheme/Complex.xcscheme';
      final orig = File(fixturePath).readAsBytesSync();

      final destPath = p.join(tmp.path, 'Complex.xcscheme');
      final scheme = await XCScheme.open(fixturePath);
      await scheme.saveAs(destPath);

      final saved = File(destPath).readAsBytesSync();
      expect(
        saved,
        equals(orig),
        reason:
            'Complex.xcscheme byte-identical round-trip (SCH-08 acceptance gate)',
      );
    },
  );
}
