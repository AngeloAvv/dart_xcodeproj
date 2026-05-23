// — integration test for XcodeProject.create() and save().
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  group('XcodeProject.create(', () {
    late Directory tmp;

    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
      tmp = Directory.systemTemp.createTempSync('xcodeproj_create_');
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('creates project with objectsByUuid non-empty', () async {
      final path = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(path);
      expect(project.objectsByUuid, isNotEmpty);
    });

    test('rootObject is PBXProject', () async {
      final path = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(path);
      expect(project.rootObject, isA<PBXProject>());
    });

    test('has Debug and Release build configurations', () async {
      final path = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(path);
      final names = project.buildConfigurations
          .map((c) => c.name)
          .whereType<String>()
          .toSet();
      expect(names, containsAll({'Debug', 'Release'}));
    });

    test('mainGroup is a PBXGroup', () async {
      final path = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(path);
      expect(project.mainGroup, isA<PBXGroup>());
    });

    test('save() writes project.pbxproj to disk', () async {
      final xcodeprojPath = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(xcodeprojPath);
      await project.save();
      final pbxprojFile = File('$xcodeprojPath/project.pbxproj');
      expect(pbxprojFile.existsSync(), isTrue);
      expect(pbxprojFile.lengthSync(), greaterThan(0));
    });

    test('save() produces valid UTF8 plist header', () async {
      final xcodeprojPath = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(xcodeprojPath);
      await project.save();
      final content = File('$xcodeprojPath/project.pbxproj').readAsStringSync();
      expect(content, startsWith('// !\$*UTF8*\$!'));
    });

    test('saved plist contains rootObject UUID', () async {
      final xcodeprojPath = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(xcodeprojPath);
      await project.save();
      final content = File('$xcodeprojPath/project.pbxproj').readAsStringSync();
      expect(content, contains(project.rootObject.uuid));
    });

    test('saved plist contains PBXProject isa', () async {
      final xcodeprojPath = '${tmp.path}/Test.xcodeproj';
      final project = await XcodeProject.create(xcodeprojPath);
      await project.save();
      final content = File('$xcodeprojPath/project.pbxproj').readAsStringSync();
      expect(content, contains('PBXProject'));
    });
  });
}
