// — unit tests for XcodeProject accessors and newObject.
// TDD RED phase: these tests are written BEFORE the implementation.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  group('XcodeProject', () {
    setUp(() {
      registerPhase3Types();
      registerPhase4Types();
    });

    tearDown(() {
      isaRegistry.clear();
    });

    // -------------------------------------------------------------------------
    // create() factory tests
    // -------------------------------------------------------------------------

    group('create()', () {
      test(
        'returns an XcodeProject whose objectsByUuid is non-empty',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
          expect(project.objectsByUuid, isNotEmpty);
        },
      );

      test('rootObject is a PBXProject', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        expect(project.rootObject, isA<PBXProject>());
      });

      test('buildConfigurationList has a Debug configuration', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final debugConfig = project.buildConfigurationList['Debug'];
        expect(debugConfig, isNotNull);
        expect(debugConfig!.name, equals('Debug'));
      });

      test('buildConfigurationList has a Release configuration', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final releaseConfig = project.buildConfigurationList['Release'];
        expect(releaseConfig, isNotNull);
        expect(releaseConfig!.name, equals('Release'));
      });

      test('mainGroup is a PBXGroup (not null)', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        expect(project.mainGroup, isA<PBXGroup>());
      });

      test(
        'does NOT throw when objectVersion is accessed indirectly',
        () async {
          expect(
            () => XcodeProject.create('/tmp/MyProject.xcodeproj'),
            returnsNormally,
          );
        },
      );
    });

    // -------------------------------------------------------------------------
    // newObject tests
    // -------------------------------------------------------------------------

    group('newObject()', () {
      test(
        'returns a PBXGroup NOT in objectsByUuid (registration requires wiring)',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
          final group = project.newObject((g, u) => PBXGroup(g, u));
          expect(project.objectsByUuid.containsKey(group.uuid), isFalse);
        },
      );
    });

    // -------------------------------------------------------------------------
    // generateUuid tests
    // -------------------------------------------------------------------------

    group('generateUuid()', () {
      test('returns a 24-char uppercase hex string', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final uuid = project.generateUuid();
        expect(uuid, matches(RegExp(r'^[0-9A-F]{24}$')));
      });

      test('called twice produces different values', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final uuid1 = project.generateUuid();
        final uuid2 = project.generateUuid();
        expect(uuid1, isNot(equals(uuid2)));
      });
    });

    // -------------------------------------------------------------------------
    // addBuildConfiguration tests
    // -------------------------------------------------------------------------

    group('addBuildConfiguration()', () {
      test('adds a new config to buildConfigurationList', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        project.addBuildConfiguration('Staging', BuildConfigType.release);
        expect(project.buildConfigurationList['Staging'], isNotNull);
      });

      test(
        'is idempotent — calling twice does NOT create a duplicate',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
          final first = project.addBuildConfiguration(
            'Staging',
            BuildConfigType.release,
          );
          final second = project.addBuildConfiguration(
            'Staging',
            BuildConfigType.release,
          );
          expect(identical(first, second), isTrue);
          // Count configs — only one 'Staging' should exist
          final count = project.buildConfigurations
              .where((c) => c.name == 'Staging')
              .length;
          expect(count, equals(1));
        },
      );

      test(
        'Debug duplication guard — calling addBuildConfiguration("Debug") twice',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
          // Debug is already created by create(); calling again is idempotent
          final debug1 = project.addBuildConfiguration(
            'Debug',
            BuildConfigType.debug,
          );
          final debug2 = project.addBuildConfiguration(
            'Debug',
            BuildConfigType.debug,
          );
          expect(identical(debug1, debug2), isTrue);
          final count = project.buildConfigurations
              .where((c) => c.name == 'Debug')
              .length;
          expect(count, equals(1));
        },
      );
    });

    // -------------------------------------------------------------------------
    // Accessor delegation tests
    // -------------------------------------------------------------------------

    group('accessors', () {
      late XcodeProject project;

      setUp(() async {
        project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
      });

      test(
        'targets delegates to rootObject.targets (same object identity)',
        () {
          expect(
            identical(project.targets, project.rootObject.targets),
            isTrue,
          );
        },
      );

      test(
        'mainGroup delegates to rootObject.mainGroup (same object identity)',
        () {
          expect(
            identical(project.mainGroup, project.rootObject.mainGroup),
            isTrue,
          );
        },
      );

      test(
        'buildConfigurationList delegates to rootObject.buildConfigurationList',
        () {
          expect(
            identical(
              project.buildConfigurationList,
              project.rootObject.buildConfigurationList,
            ),
            isTrue,
          );
        },
      );

      test(
        'buildConfigurations returns a List with at least Debug and Release',
        () {
          final names = project.buildConfigurations
              .map((c) => c.name)
              .whereType<String>()
              .toSet();
          expect(names, containsAll({'Debug', 'Release'}));
        },
      );

      test('buildSettings("Debug") returns a non-null Map', () {
        final settings = project.buildSettings('Debug');
        expect(settings, isNotNull);
        expect(settings, isA<Map<String, dynamic>>());
      });

      test('name returns basename without extension', () {
        expect(project.name, equals('MyProject'));
      });

      test('projectDir returns directory portion of path', () {
        expect(project.projectDir, equals('/tmp'));
      });
    });

    // -------------------------------------------------------------------------
    // open() argument validation
    // -------------------------------------------------------------------------

    group('open()', () {
      test(
        'throws ArgumentError when path does not end with .xcodeproj',
        () async {
          expect(
            () => XcodeProject.open('/tmp/SomeFile.txt'),
            throwsA(isA<ArgumentError>()),
          );
        },
      );
    });
  });
}
