import 'dart:io';

import 'package:dart_xcodeproj/src/command/runner.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ConfigDumpCommand', () {
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

    test('writes per-target .xcconfig files', () async {
      final outDir = Directory(p.join(tmp.path, 'cfg-out'))..createSync();
      final runner = XcodeprojRunner();
      await runner.run(['config-dump', xcodeprojPath, outDir.path]);
      final xcconfigs = outDir
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.xcconfig'))
          .toList();
      expect(xcconfigs, isNotEmpty);
    });

    test('throws UsageException when output dir does not exist', () async {
      final runner = XcodeprojRunner();
      await expectLater(
        runner.run(['config-dump', xcodeprojPath, '/definitely/not/a/dir']),
        throwsA(isA<Exception>()),
      );
    });

    // config-dump must NOT mutate the source project on disk.
    test('does not mutate source project on disk', () async {
      final before = File(
        p.join(xcodeprojPath, 'project.pbxproj'),
      ).readAsBytesSync();
      final outDir = Directory(p.join(tmp.path, 'cfg-out2'))..createSync();
      final runner = XcodeprojRunner();
      await runner.run(['config-dump', xcodeprojPath, outDir.path]);
      final after = File(
        p.join(xcodeprojPath, 'project.pbxproj'),
      ).readAsBytesSync();
      expect(after, equals(before));
    });
  });
}
