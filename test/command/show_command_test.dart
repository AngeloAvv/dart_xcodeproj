import 'dart:io';

import 'package:dart_xcodeproj/src/command/runner.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ShowCommand', () {
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

    test(
      'runs with no --format and exits cleanly (default pretty_print)',
      () async {
        final runner = XcodeprojRunner();
        await runner.run(['show', xcodeprojPath]);
      },
    );

    test('runs with --format=hash', () async {
      final runner = XcodeprojRunner();
      await runner.run(['show', '--format=hash', xcodeprojPath]);
    });

    test('runs with --format=tree_hash', () async {
      final runner = XcodeprojRunner();
      await runner.run(['show', '--format=tree_hash', xcodeprojPath]);
    });

    test('throws UsageException on bad path', () async {
      final runner = XcodeprojRunner();
      expect(
        () => runner.run(['show', '/nonexistent/Bad.xcodeproj']),
        throwsA(isA<Exception>()),
      );
    });
  });
}
