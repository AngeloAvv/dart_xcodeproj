// — unit tests for XcodeProject accessors and newObject.
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:io';
import 'dart:math' show Random;

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/project/uuid_generator.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

/// A valid 24-char uppercase hex UUID, as a tool would pin for idempotency.
const _customUuid = 'A1B2C3D4E5F60718293A4B5C';

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

      test('uses the caller-supplied uuid', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final group = project.newObject(
          (g, u) => PBXGroup(g, u),
          uuid: _customUuid,
        );
        expect(group.uuid, equals(_customUuid));
      });

      test(
        'throws on a uuid already in objectsByUuid and keeps the existing object',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
          final existing = project.rootObject;
          final takenUuid = existing.uuid;

          expect(
            () => project.newObject((g, u) => PBXGroup(g, u), uuid: takenUuid),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.toString(),
                'message',
                allOf(contains(takenUuid), contains('already')),
              ),
            ),
          );
          expect(project.objectsByUuid[takenUuid], same(existing));
        },
      );

      group('rejects an invalid caller-supplied uuid', () {
        const invalid = {
          'empty': '',
          'too short': 'A1B2C3',
          'lowercase': 'a1b2c3d4e5f60718293a4b5c',
          'RFC4122 with hyphens': '123E4567-E89B-12D3-A456-426614174000',
          'non-hex characters': 'G1B2C3D4E5F60718293A4B5C',
          'surrounding whitespace': ' A1B2C3D4E5F60718293A4B5C ',
          'trailing newline': 'A1B2C3D4E5F60718293A4B5C\n',
          '25 characters': 'A1B2C3D4E5F60718293A4B5C0',
        };

        invalid.forEach((description, uuid) {
          test(description, () async {
            final project = await XcodeProject.create(
              '/tmp/MyProject.xcodeproj',
            );
            final before = project.objectsByUuid.length;

            expect(
              () => project.newObject((g, u) => PBXGroup(g, u), uuid: uuid),
              throwsA(isA<ArgumentError>()),
            );
            expect(project.objectsByUuid, hasLength(before));
          });
        });
      });

      test(
        'generateUuid never hands out a supplied uuid that is not wired yet',
        () async {
          const draws = 400;
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');

          // The first candidate the injected RNG will produce.
          final reserved = UuidGenerator.generate(random: Random(42));
          project.uuidRandom = Random(42);
          project.newObject((g, u) => PBXGroup(g, u), uuid: reserved);

          final generated = [
            for (var i = 0; i < draws; i++) project.generateUuid(),
          ];
          expect(generated, isNot(contains(reserved)));
        },
      );

      test(
        'registers once wired, rejects reuse, and survives a save + open',
        () async {
          final tmp = Directory.systemTemp.createTempSync('xcodeproj_uuid_');
          addTearDown(() => tmp.deleteSync(recursive: true));
          final project = await XcodeProject.create(
            '${tmp.path}/MyProject.xcodeproj',
          );

          final group = project.newObject(
            (g, u) => PBXGroup(g, u),
            uuid: _customUuid,
          )..name = 'Pinned';
          project.mainGroup.children.add(group);

          expect(project.objectsByUuid[_customUuid], same(group));
          expect(
            () =>
                project.newObject((g, u) => PBXGroup(g, u), uuid: _customUuid),
            throwsA(isA<ArgumentError>()),
          );
          expect(project.objectsByUuid[_customUuid], same(group));

          await project.save();
          final reopened = await XcodeProject.open(
            '${tmp.path}/MyProject.xcodeproj',
          );
          final restored = reopened.objectsByUuid[_customUuid];
          expect(restored, isA<PBXGroup>());
          expect((restored! as PBXGroup).name, equals('Pinned'));
          expect(reopened.mainGroup.children.uuids, contains(_customUuid));
        },
      );

      test('a uuid freed by removeFromProject can be pinned again', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final first = project.newObject(
          (g, u) => PBXGroup(g, u),
          uuid: _customUuid,
        );
        project.mainGroup.children.add(first);
        first.removeFromProject();
        expect(project.objectsByUuid, isNot(contains(_customUuid)));

        final second = project.newObject(
          (g, u) => PBXGroup(g, u),
          uuid: _customUuid,
        );
        project.mainGroup.children.add(second);
        expect(project.objectsByUuid[_customUuid], same(second));
      });

      test('accepts a valid 32-char (deterministic) uuid', () async {
        final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');
        final uuid = UuidGenerator.generateDeterministic(
          'some/structural/path',
        );
        final group = project.newObject((g, u) => PBXGroup(g, u), uuid: uuid);
        expect(group.uuid, equals(uuid));
      });
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

      test(
        'drops candidates repeated within a batch and across batches',
        () async {
          final project = await XcodeProject.create('/tmp/MyProject.xcodeproj');

          // Batch 1 repeats id 1 within itself; batch 2 repeats ids 1 and 2,
          // which were already accepted in batch 1. Later batches are fresh.
          final script = <int>[
            1, 1, 2, ..._range(100, 98), // batch 1 (101 candidates)
            1, 2, 3, ..._range(200, 98), // batch 2 (101 candidates)
          ];
          project.uuidRandom = _ScriptedRandom(script, freshFrom: 1000);

          final generated = [
            for (var i = 0; i < draws; i++) project.generateUuid(),
          ];

          for (final id in [1, 2, 3]) {
            final uuid = _ScriptedRandom.uuidFor(id);
            expect(
              generated.where((u) => u == uuid),
              hasLength(1),
              reason: 'candidate $id must be handed out exactly once',
            );
          }
          expect(generated.toSet(), hasLength(generated.length));
        },
      );
    });
  });
}

List<int> _range(int start, int count) => [
  for (var i = 0; i < count; i++) start + i,
];

/// A [Random] whose UUID candidates are scripted: candidate `n` is built from
/// the `n`-th id of [script] (then from an increasing counter starting at
/// [freshFrom]). An id is encoded in the first two bytes of the UUID.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this.script, {required this.freshFrom});

  final List<int> script;
  int freshFrom;
  int _candidate = 0;
  int _call = 0;
  int _id = 0;

  static String uuidFor(int id) =>
      UuidGenerator.generate(random: _ScriptedRandom([id], freshFrom: 0));

  @override
  int nextInt(int max) {
    if (_call == 0) {
      _id = _candidate < script.length ? script[_candidate] : freshFrom++;
    }
    final byte = switch (_call) {
      0 => _id & 0xff,
      1 => (_id >> 8) & 0xff,
      _ => 0,
    };
    if (++_call == 12) {
      _call = 0;
      _candidate++;
    }
    return byte;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
