// Integration round-trip test for ISA types against runner.pbxproj.
// Verifies:
// 1. All ISA types deserialize from runner.pbxproj without error.
// 2. Expected ISA counts match the known fixture inventory.
// 3. XCBuildConfiguration attribute order (subclass-before-superclass) survives
// a parse → deserialize → serialize cycle (keys.first == 'name').
// 4. Spot-check: XCBuildConfiguration has non-empty name and buildSettings.
// 5. Spot-check: PBXFileReference has non-null path and sourceTree.
// ISA set only — types (PBXNativeTarget, PBXProject, PBXGroup,
// etc.) are not in the registry yet; objectFromPlist returns null for them (log
// warning — expected behavior).

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_reader.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

/// ISA strings — only these are filtered from the fixture for loading.
const _phase3Isas = {
  'PBXFileReference',
  'PBXBuildFile',
  'PBXBuildRule',
  'PBXHeadersBuildPhase',
  'PBXSourcesBuildPhase',
  'PBXFrameworksBuildPhase',
  'PBXResourcesBuildPhase',
  'PBXCopyFilesBuildPhase',
  'PBXShellScriptBuildPhase',
  'PBXRezBuildPhase',
  'XCBuildConfiguration',
  'XCConfigurationList',
};

void main() {
  late MockObjectGraph graph;
  late Map<String, dynamic> objects;

  setUp(() {
    registerPhase3Types();

    // Load and parse runner.pbxproj
    final content = File('test/fixtures/runner.pbxproj').readAsStringSync();
    final plist = AsciiPlistReader(content).parse();
    objects = (plist['objects'] as Map).cast<String, dynamic>();

    // Instantiate only ISA objects
    graph = MockObjectGraph();
    for (final entry in objects.entries) {
      final isaVal = (entry.value as Map?)?['isa'];
      if (isaVal is String && _phase3Isas.contains(isaVal)) {
        objectFromPlist(entry.key, objects, graph);
      }
    }
  });

  tearDown(() {
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA count assertions
  // ---------------------------------------------------------------------------

  group('runner.pbxproj ISA counts', () {
    test('PBXFileReference count is 18', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXFileReference>()
          .length;
      expect(
        count,
        equals(18),
        reason: 'runner.pbxproj has exactly 18 PBXFileReference entries',
      );
    });

    test('PBXBuildFile count is 8', () {
      final count = graph.objectsByUuid.values.whereType<PBXBuildFile>().length;
      expect(
        count,
        equals(8),
        reason: 'runner.pbxproj has exactly 8 PBXBuildFile entries',
      );
    });

    test('XCBuildConfiguration count is 6', () {
      final count = graph.objectsByUuid.values
          .whereType<XCBuildConfiguration>()
          .length;
      expect(
        count,
        equals(6),
        reason: 'runner.pbxproj has exactly 6 XCBuildConfiguration entries',
      );
    });

    test('PBXShellScriptBuildPhase count is 5', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXShellScriptBuildPhase>()
          .length;
      expect(
        count,
        equals(5),
        reason: 'runner.pbxproj has exactly 5 PBXShellScriptBuildPhase entries',
      );
    });

    test('XCConfigurationList count is 2', () {
      final count = graph.objectsByUuid.values
          .whereType<XCConfigurationList>()
          .length;
      expect(
        count,
        equals(2),
        reason: 'runner.pbxproj has exactly 2 XCConfigurationList entries',
      );
    });

    test('PBXSourcesBuildPhase count is 1', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXSourcesBuildPhase>()
          .length;
      expect(
        count,
        equals(1),
        reason: 'runner.pbxproj has exactly 1 PBXSourcesBuildPhase entry',
      );
    });

    test('PBXResourcesBuildPhase count is 1', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXResourcesBuildPhase>()
          .length;
      expect(
        count,
        equals(1),
        reason: 'runner.pbxproj has exactly 1 PBXResourcesBuildPhase entry',
      );
    });

    test('PBXFrameworksBuildPhase count is 1', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXFrameworksBuildPhase>()
          .length;
      expect(
        count,
        equals(1),
        reason: 'runner.pbxproj has exactly 1 PBXFrameworksBuildPhase entry',
      );
    });

    test('PBXCopyFilesBuildPhase count is 1', () {
      final count = graph.objectsByUuid.values
          .whereType<PBXCopyFilesBuildPhase>()
          .length;
      expect(
        count,
        equals(1),
        reason: 'runner.pbxproj has exactly 1 PBXCopyFilesBuildPhase entry',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Spot-check: XCBuildConfiguration
  // ---------------------------------------------------------------------------

  group('XCBuildConfiguration spot-check', () {
    test('name is non-null and non-empty', () {
      final config = graph.objectsByUuid.values
          .whereType<XCBuildConfiguration>()
          .first;
      expect(config.name, isNotNull);
      expect(config.name, isNotEmpty);
    });

    test('buildSettings is a non-empty Map', () {
      final config = graph.objectsByUuid.values
          .whereType<XCBuildConfiguration>()
          .first;
      expect(config.buildSettings, isA<Map<dynamic, dynamic>>());
      expect(config.buildSettings, isNotEmpty);
    });

    test('toHash() contains "buildSettings" key', () {
      final config = graph.objectsByUuid.values
          .whereType<XCBuildConfiguration>()
          .first;
      expect(config.toHash(), contains('buildSettings'));
    });
  });

  // ---------------------------------------------------------------------------
  // Attribute order: subclass-before-superclass survives deserialization
  // ---------------------------------------------------------------------------

  group('XCBuildConfiguration attribute order after deserialization', () {
    test(
      '"name" key appears before "buildSettings" key in toHash() after deserialization',
      () {
        final xcBuildConfig = graph.objectsByUuid.values
            .whereType<XCBuildConfiguration>()
            .first;
        final hash = xcBuildConfig.toHash();
        final keys = hash.keys.toList();
        // isa is always first (AbstractObject.toHash contract, ).
        // Subclass attributes follow: XCBuildConfiguration._ownAttributes is
        // [name, buildSettings, ...]. Verify the ordering is preserved after
        // parse → deserialize → serialize cycle.
        expect(
          keys.first,
          equals('isa'),
          reason: 'AbstractObject always emits "isa" first',
        );
        final nameIdx = keys.indexOf('name');
        final settingsIdx = keys.indexOf('buildSettings');
        expect(
          nameIdx,
          greaterThan(-1),
          reason: '"name" must be present in toHash()',
        );
        expect(
          settingsIdx,
          greaterThan(-1),
          reason: '"buildSettings" must be present in toHash()',
        );
        expect(
          nameIdx,
          lessThan(settingsIdx),
          reason:
              'XCBuildConfiguration subclass attribute "name" must appear before '
              '"buildSettings" — subclass-before-superclass attribute order must '
              'survive a parse → deserialize → serialize cycle',
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Spot-check: PBXFileReference
  // ---------------------------------------------------------------------------

  group('PBXFileReference spot-check', () {
    test('path is non-null', () {
      final ref = graph.objectsByUuid.values
          .whereType<PBXFileReference>()
          .first;
      expect(ref.path, isNotNull);
    });

    test('sourceTree is non-null', () {
      final ref = graph.objectsByUuid.values
          .whereType<PBXFileReference>()
          .first;
      expect(ref.sourceTree, isNotNull);
    });

    test('toHash() contains "isa" == "PBXFileReference"', () {
      final ref = graph.objectsByUuid.values
          .whereType<PBXFileReference>()
          .first;
      expect(ref.toHash()['isa'], equals('PBXFileReference'));
    });
  });
}
