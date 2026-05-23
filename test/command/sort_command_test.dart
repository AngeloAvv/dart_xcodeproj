import 'dart:io';

import 'package:dart_xcodeproj/src/command/runner.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SortCommand', () {
    late Directory tmp;
    late String xcodeprojPath;

    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
      tmp = Directory.systemTemp.createTempSync('xcodeproj_p7_cmd_');
      final xcodeproj = Directory(p.join(tmp.path, 'Runner.xcodeproj'))
        ..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync(p.join(xcodeproj.path, 'project.pbxproj'));
      xcodeprojPath = xcodeproj.path;
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('sorts project and saves to disk', () async {
      final runner = XcodeprojRunner();
      await runner.run(['sort', xcodeprojPath]);
      expect(
        File(p.join(xcodeprojPath, 'project.pbxproj')).existsSync(),
        isTrue,
      );
    });

    test('runs with --group-option=above', () async {
      final runner = XcodeprojRunner();
      await runner.run(['sort', '--group-option=above', xcodeprojPath]);
    });

    test('runs with --group-option=below', () async {
      final runner = XcodeprojRunner();
      await runner.run(['sort', '--group-option=below', xcodeprojPath]);
    });
  });
}
