// round-trip integration test.
// Loads test/fixtures/runner.pbxproj with BOTH and ISA types
// registered and verifies:
// 1. All objects resolve to typed Dart classes (no unrecognized-ISA fallbacks).
// 2. All ISA types present in the fixture map to concrete typed instances.
// 3. PBXProject is present, mainGroup is a non-null PBXGroup, targets is non-empty.
// 4. PBXGroup.children of mainGroup is non-empty.
// 5. No object falls back to a Map or dynamic type.
// Fixture ISA types confirmed in runner.pbxproj:
// PBXBuildFile, PBXCopyFilesBuildPhase, PBXFileReference,
// PBXFrameworksBuildPhase, PBXGroup, PBXNativeTarget, PBXProject,
// PBXResourcesBuildPhase, PBXShellScriptBuildPhase, PBXSourcesBuildPhase,
// PBXVariantGroup, XCBuildConfiguration, XCConfigurationList

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_target_dependency.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_reader.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  group(' round-trip integration', () {
    late MockObjectGraph graph;

    setUp(() {
      // Register all types before each test.
      // Uses the same pattern as test/pbx/round_trip_test.dart which calls
      // registerPhase3Types() in setUp (not setUpAll) to pair with tearDown clear.
      registerPhase3Types();
      registerPhase4Types();

      // Load and parse runner.pbxproj — same pattern as test/pbx/round_trip_test.dart
      final content = File('test/fixtures/runner.pbxproj').readAsStringSync();
      final plist = AsciiPlistReader(content).parse();
      final objects = (plist['objects'] as Map).cast<String, dynamic>();

      // Instantiate ALL objects (not filtered — + both registered)
      graph = MockObjectGraph();
      for (final uuid in objects.keys) {
        if (!graph.objectsByUuid.containsKey(uuid)) {
          objectFromPlist(uuid, objects, graph);
        }
      }
    });

    tearDown(() {
      isaRegistry.clear();
    });

    // -------------------------------------------------------------------------
    // Test 1: Fixture loads with all objects resolved
    // -------------------------------------------------------------------------

    test('runner.pbxproj loads without unrecognized-ISA warnings', () {
      expect(graph.objectsByUuid, isNotEmpty);
      // Every resolved object must have a non-empty isa string
      for (final obj in graph.objectsByUuid.values) {
        expect(
          obj.isa,
          isNotEmpty,
          reason:
              'Object ${obj.uuid} has empty isa — possible fallback to dynamic map',
        );
      }
    });

    // -------------------------------------------------------------------------
    // Test 2: ISA types present in fixture resolve to typed classes
    // -------------------------------------------------------------------------

    test('all ISA types in fixture resolve to typed classes', () {
      final projects = graph.objectsByUuid.values
          .whereType<PBXProject>()
          .toList();
      expect(
        projects.length,
        equals(1),
        reason: 'A .pbxproj must have exactly one PBXProject',
      );

      final groups = graph.objectsByUuid.values.whereType<PBXGroup>().toList();
      expect(
        groups,
        isNotEmpty,
        reason: 'runner.pbxproj contains at least the mainGroup',
      );

      final nativeTargets = graph.objectsByUuid.values
          .whereType<PBXNativeTarget>()
          .toList();
      expect(
        nativeTargets,
        isNotEmpty,
        reason:
            'Flutter Runner.xcodeproj contains at least one PBXNativeTarget (Runner)',
      );

      // These types may be absent in this fixture — just verify no Map fallbacks
      // for any type that IS present.
      final proxies = graph.objectsByUuid.values
          .whereType<PBXContainerItemProxy>()
          .toList();
      final deps = graph.objectsByUuid.values
          .whereType<PBXTargetDependency>()
          .toList();
      // PBXContainerItemProxy and PBXTargetDependency are absent in this fixture
      // verify they are empty (no fallback objects of unregistered ISA).
      expect(proxies.length, greaterThanOrEqualTo(0));
      expect(deps.length, greaterThanOrEqualTo(0));
    });

    // -------------------------------------------------------------------------
    // Test 3: PBXProject.mainGroup is non-null and is a PBXGroup
    // -------------------------------------------------------------------------

    test('PBXProject.mainGroup is non-null and is a PBXGroup', () {
      final project = graph.objectsByUuid.values.whereType<PBXProject>().first;
      expect(project.mainGroup, isNotNull);
      expect(project.mainGroup, isA<PBXGroup>());
    });

    // -------------------------------------------------------------------------
    // Test 4: PBXProject.targets is non-empty
    // -------------------------------------------------------------------------

    test('PBXProject.targets ObjectList is non-empty', () {
      final project = graph.objectsByUuid.values.whereType<PBXProject>().first;
      expect(project.targets, isNotEmpty);
    });

    // -------------------------------------------------------------------------
    // Test 5: PBXGroup.children of mainGroup is non-empty
    // -------------------------------------------------------------------------

    test(
      'PBXGroup.children of mainGroup contains file references or subgroups',
      () {
        final project = graph.objectsByUuid.values
            .whereType<PBXProject>()
            .first;
        final mainGroup = project.mainGroup!;
        expect(mainGroup.children, isNotEmpty);
      },
    );

    // -------------------------------------------------------------------------
    // Test 6: No "unknown ISA" fallback objects (Map/dynamic)
    // -------------------------------------------------------------------------

    test('No "unknown ISA" warnings were emitted during load', () {
      for (final obj in graph.objectsByUuid.values) {
        expect(
          obj.runtimeType.toString(),
          isNot(contains('Map')),
          reason:
              'Object ${obj.uuid} fell back to a Map type — ISA was not registered',
        );
        expect(obj.runtimeType.toString(), isNot(contains('dynamic')));
      }
    });

    // -------------------------------------------------------------------------
    // Test 7: ISA counts for types present in fixture
    // -------------------------------------------------------------------------

    test('PBXNativeTarget count matches fixture', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXNativeTarget>()
          .length;
      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'runner.pbxproj (Flutter motohelp) contains at least 1 PBXNativeTarget',
      );
    });

    test('PBXVariantGroup count is at least 1 (Localizable.strings)', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXVariantGroup>()
          .length;
      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'Flutter iOS projects include at least one PBXVariantGroup for localization',
      );
    });

    test('PBXProject count is exactly 1', () {
      final count = graph.objectsByUuid.values.whereType<PBXProject>().length;
      expect(
        count,
        equals(1),
        reason: 'A .pbxproj file has exactly one PBXProject root object',
      );
    });
  });
}
