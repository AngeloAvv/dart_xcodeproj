// Tests for PBXFileSystemSynchronizedBuildFileExceptionSet and
// PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet — covers PBX-18.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_exception_set.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXFileSystemSynchronizedBuildFileExceptionSet'] = (g, u) =>
        PBXFileSystemSynchronizedBuildFileExceptionSet(g, u);
    isaRegistry['PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet'] =
        (g, u) =>
            PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
              g,
              u,
            );
    isaRegistry['PBXNativeTarget'] = (g, u) => PBXNativeTarget(g, u);
    isaRegistry['PBXSourcesBuildPhase'] = (g, u) => PBXSourcesBuildPhase(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // PBXFileSystemSynchronizedBuildFileExceptionSet
  // ---------------------------------------------------------------------------
  group('PBXFileSystemSynchronizedBuildFileExceptionSet isa (PBX-18)', () {
    test(
      "PBXFileSystemSynchronizedBuildFileExceptionSet has isa 'PBXFileSystemSynchronizedBuildFileExceptionSet'",
      () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        expect(
          exc.isa,
          equals('PBXFileSystemSynchronizedBuildFileExceptionSet'),
        );
      },
    );
  });

  group(
    'PBXFileSystemSynchronizedBuildFileExceptionSet serialization (PBX-18)',
    () {
      test('serializes target (has_one AbstractTarget) UUID', () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));

        exc.target = target;
        final hash = exc.toHash();
        expect(hash['target'], equals(target.uuid));
      });

      test('does NOT serialize target when null', () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        final hash = exc.toHash();
        expect(hash.containsKey('target'), isFalse);
      });

      test('serializes membershipExceptions when non-null', () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        exc.membershipExceptions = ['file1.swift', 'file2.swift'];
        final hash = exc.toHash();
        expect(
          hash['membershipExceptions'],
          equals(['file1.swift', 'file2.swift']),
        );
      });

      test('does NOT serialize membershipExceptions when null', () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        final hash = exc.toHash();
        expect(hash.containsKey('membershipExceptions'), isFalse);
      });

      test('target setter ref-counts correctly', () {
        final exc = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        );
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));

        exc.target = target;
        expect(target.referrers.contains(exc), isTrue);

        exc.target = null;
        expect(target.referrers.contains(exc), isFalse);
      });
    },
  );

  // ---------------------------------------------------------------------------
  // PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
  // ---------------------------------------------------------------------------
  group(
    'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet isa (PBX-18)',
    () {
      test(
        "PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet has isa 'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet'",
        () {
          final exc = graph.newObject(
            (g, u) =>
                PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
                  g,
                  u,
                ),
          );
          expect(
            exc.isa,
            equals(
              'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet',
            ),
          );
        },
      );
    },
  );

  group(
    'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet serialization (PBX-18)',
    () {
      test(
        'serializes buildPhase (has_one AbstractBuildPhase) UUID + membershipExceptions',
        () {
          final exc = graph.newObject(
            (g, u) =>
                PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
                  g,
                  u,
                ),
          );
          final phase = graph.newObject((g, u) => PBXSourcesBuildPhase(g, u));

          exc.buildPhase = phase;
          exc.membershipExceptions = ['Sources/excluded.swift'];

          final hash = exc.toHash();
          expect(hash['buildPhase'], equals(phase.uuid));
          expect(
            hash['membershipExceptions'],
            equals(['Sources/excluded.swift']),
          );
        },
      );

      test('buildPhase setter ref-counts correctly', () {
        final exc = graph.newObject(
          (g, u) =>
              PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
                g,
                u,
              ),
        );
        final phase = graph.newObject((g, u) => PBXSourcesBuildPhase(g, u));

        exc.buildPhase = phase;
        expect(phase.referrers.contains(exc), isTrue);

        exc.buildPhase = null;
        expect(phase.referrers.contains(exc), isFalse);
      });
    },
  );

  group(
    'Both exception set types round-trip via toHash -> configureWithPlist (PBX-18)',
    () {
      test('PBXFileSystemSynchronizedBuildFileExceptionSet round-trips', () {
        const excUuid = 'AABBCCDDEEFF001122334400';
        const targetUuid = 'AABBCCDDEEFF001122334411';

        final target = PBXNativeTarget(graph, targetUuid);
        graph.objectsByUuid[targetUuid] = target;

        final plist = <String, dynamic>{
          excUuid: {
            'isa': 'PBXFileSystemSynchronizedBuildFileExceptionSet',
            'target': targetUuid,
            'membershipExceptions': ['Excluded.swift'],
          },
          targetUuid: {
            'isa': 'PBXNativeTarget',
            'name': 'MyTarget',
            'buildPhases': <String>[],
            'dependencies': <String>[],
            'buildRules': <String>[],
          },
        };

        final exc = PBXFileSystemSynchronizedBuildFileExceptionSet(
          graph,
          excUuid,
        );
        graph.objectsByUuid[excUuid] = exc;
        exc.configureWithPlist(plist);

        expect(exc.target, isNotNull);
        expect(exc.target!.uuid, equals(targetUuid));
        expect(exc.membershipExceptions, equals(['Excluded.swift']));
      });

      test(
        'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet round-trips',
        () {
          const excUuid = 'AABBCCDDEEFF001122334422';
          const phaseUuid = 'AABBCCDDEEFF001122334433';

          final phase = PBXSourcesBuildPhase(graph, phaseUuid);
          graph.objectsByUuid[phaseUuid] = phase;

          final plist = <String, dynamic>{
            excUuid: {
              'isa':
                  'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet',
              'buildPhase': phaseUuid,
              'membershipExceptions': ['Excluded.swift'],
            },
            phaseUuid: {
              'isa': 'PBXSourcesBuildPhase',
              'files': <String>[],
              'buildActionMask': '2147483647',
              'runOnlyForDeploymentPostprocessing': '0',
            },
          };

          final exc =
              PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
                graph,
                excUuid,
              );
          graph.objectsByUuid[excUuid] = exc;
          exc.configureWithPlist(plist);

          expect(exc.buildPhase, isNotNull);
          expect(exc.buildPhase!.uuid, equals(phaseUuid));
          expect(exc.membershipExceptions, equals(['Excluded.swift']));
        },
      );
    },
  );
}
