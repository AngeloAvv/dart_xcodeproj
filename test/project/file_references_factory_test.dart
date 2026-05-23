// Tests for FileReferencesFactory — (TDD RED)
// Covers: newReference dispatch, lastKnownFileType inference,
// sourceTree assignment, name from path, XCVersionGroup for .xcdatamodeld.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/project/file_references_factory.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  late XcodeProject project;
  late PBXGroup mainGroup;

  setUp(() async {
    registerPhase3Types();
    registerPhase4Types();
    project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
    mainGroup = project.mainGroup;
  });

  tearDown(() {
    isaRegistry.clear();
  });

  group('FileReferencesFactory', () {
    group('newReference', () {
      test('returns a PBXFileReference for a Swift file', () {
        final ref = FileReferencesFactory.newReference(
          mainGroup,
          'Sources/Main.swift',
          '<group>',
        );
        expect(ref, isA<PBXFileReference>());
      });

      test('sets lastKnownFileType = sourcecode.swift for .swift file', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Main.swift',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.lastKnownFileType, equals('sourcecode.swift'));
      });

      test('sets lastKnownFileType = sourcecode.c.objc for .m file', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'AppDelegate.m',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.lastKnownFileType, equals('sourcecode.c.objc'));
      });

      test('sets lastKnownFileType = folder.assetcatalog for .xcassets', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Assets.xcassets',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.lastKnownFileType, equals('folder.assetcatalog'));
      });

      test('adds reference to group.children', () {
        final initialCount = mainGroup.children.length;
        FileReferencesFactory.newReference(mainGroup, 'Main.swift', '<group>');
        expect(mainGroup.children.length, equals(initialCount + 1));
      });

      test('sets name = basename when path contains slash', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Sources/Main.swift',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.name, equals('Main.swift'));
      });

      test('does NOT set name when path has no slash', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Main.swift',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.name, isNull);
      });

      test('sets sourceTree on the file reference', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Main.swift',
                  'SOURCE_ROOT',
                )
                as PBXFileReference;
        expect(ref.sourceTree, equals('SOURCE_ROOT'));
      });

      test('sets includeInIndex = null for .framework files', () {
        final ref =
            FileReferencesFactory.newReference(
                  mainGroup,
                  'Runner.framework',
                  '<group>',
                )
                as PBXFileReference;
        expect(ref.includeInIndex, isNull);
      });

      test('returns XCVersionGroup for .xcdatamodeld extension', () {
        final ref = FileReferencesFactory.newReference(
          mainGroup,
          'MyModel.xcdatamodeld',
          '<group>',
        );
        expect(ref, isA<XCVersionGroup>());
      });
    });
  });
}
