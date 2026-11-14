// — unit tests for XcodeProject accessors and newObject.
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:math' show Random;

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/project/uuid_generator.dart';
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
      // create() pre-fills the UUID pool with a secure batch, so draw enough
      // UUIDs to exhaust it and consume the batches produced by the injected
      // RNG.
      const draws = 400;

      test('skips a UUID already present in objectsByUuid', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');

        // Replay the deterministic RNG to learn which UUIDs it will produce.
        final replay = Random(42);
        final first = UuidGenerator.generate(random: replay);
        final second = UuidGenerator.generate(random: replay);

        // Occupy the first candidate with an existing object.
        project.objectsByUuid[first] = project.rootObject;
        project.uuidRandom = Random(42);

        final generated = [
          for (var i = 0; i < draws; i++) project.generateUuid(),
        ];

        expect(generated, isNot(contains(first)));
        // The neighbouring candidate is still handed out.
        expect(generated, contains(second));
      });

      test('never returns an existing or previously generated UUID', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');

        final replay = Random(7);
        final existing = {
          for (var i = 0; i < 20; i++) UuidGenerator.generate(random: replay),
        };
        for (final uuid in existing) {
          project.objectsByUuid[uuid] = project.rootObject;
        }
        project.uuidRandom = Random(7);

        final generated = <String>{};
        for (var i = 0; i < draws; i++) {
          final uuid = project.generateUuid();
          expect(existing, isNot(contains(uuid)));
          expect(generated.add(uuid), isTrue, reason: 'duplicate $uuid');
        }
      });
    });
  });
}
