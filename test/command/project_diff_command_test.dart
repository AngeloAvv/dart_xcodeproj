import 'dart:io';

import 'package:dart_xcodeproj/src/command/runner.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ProjectDiffCommand', () {
    late Directory tmp;
    late String xcodeprojPath;
    late String xcodeprojPath2;

    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
      tmp = Directory.systemTemp.createTempSync('xcodeproj_p7_cmd_');

      final xcodeproj1 = Directory(p.join(tmp.path, 'Runner.xcodeproj'))
        ..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync(p.join(xcodeproj1.path, 'project.pbxproj'));
      xcodeprojPath = xcodeproj1.path;

      final xcodeproj2 = Directory(p.join(tmp.path, 'Runner2.xcodeproj'))
        ..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync(p.join(xcodeproj2.path, 'project.pbxproj'));
      xcodeprojPath2 = xcodeproj2.path;
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('reports no diff for identical projects', () async {
      final runner = XcodeprojRunner();
      await runner.run(['project-diff', xcodeprojPath, xcodeprojPath2]);
    });

    test('throws UsageException when only one path is supplied', () async {
      final runner = XcodeprojRunner();
      await expectLater(
        runner.run(['project-diff', xcodeprojPath]),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts --ignore=KEY repeated', () async {
      final runner = XcodeprojRunner();
      await runner.run([
        'project-diff',
        '--ignore=path',
        '--ignore=sourceTree',
        xcodeprojPath,
        xcodeprojPath2,
      ]);
    });
  });
}
