// Tests for AbstractTarget — covers PBX-13 base.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_target_dependency.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

/// Minimal concrete subclass for testing AbstractTarget directly
/// (AbstractTarget is abstract and cannot be instantiated).
class _TestTarget extends AbstractTarget {
  static const String isaStatic = '_TestTarget';

  _TestTarget(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['XCConfigurationList'] = (g, u) => XCConfigurationList(g, u);
    isaRegistry['PBXSourcesBuildPhase'] = (g, u) => PBXSourcesBuildPhase(g, u);
    isaRegistry['PBXTargetDependency'] = (g, u) => PBXTargetDependency(g, u);
    isaRegistry['_TestTarget'] = (g, u) => _TestTarget(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // buildConfigurationList ref-counting
  // ---------------------------------------------------------------------------
  group('AbstractTarget.buildConfigurationList setter (PBX-13)', () {
    test(
      'AbstractTarget.buildConfigurationList setter ref counts XCConfigurationList',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final configList = graph.newObject((g, u) => XCConfigurationList(g, u));

        expect(configList.referrers.contains(target), isFalse);
        target.buildConfigurationList = configList;
        expect(configList.referrers.contains(target), isTrue);
      },
    );

    test(
      'AbstractTarget.buildConfigurationList setter decrements old referrer when reassigned',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final configList1 = graph.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        final configList2 = graph.newObject(
          (g, u) => XCConfigurationList(g, u),
        );

        target.buildConfigurationList = configList1;
        expect(configList1.referrers.contains(target), isTrue);

        target.buildConfigurationList = configList2;
        expect(configList1.referrers.contains(target), isFalse);
        expect(configList2.referrers.contains(target), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // buildPhases ObjectList
  // ---------------------------------------------------------------------------
  group('AbstractTarget.buildPhases (PBX-13)', () {
    test('AbstractTarget.buildPhases is ObjectList<AbstractBuildPhase>', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      expect(target.buildPhases, isA<ObjectList<AbstractBuildPhase>>());
    });

    test('AbstractTarget.buildPhases is empty initially', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      expect(target.buildPhases.uuids, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // dependencies ObjectList
  // ---------------------------------------------------------------------------
  group('AbstractTarget.dependencies (PBX-13)', () {
    test('AbstractTarget.dependencies is ObjectList<PBXTargetDependency>', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      expect(target.dependencies, isA<ObjectList<PBXTargetDependency>>());
    });

    test('AbstractTarget.dependencies is empty initially', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      expect(target.dependencies.uuids, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('AbstractTarget serialization (PBX-13)', () {
    test('AbstractTarget serializes name when non-null', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      target.name = 'MyApp';
      final hash = target.toHash();
      expect(hash['name'], equals('MyApp'));
    });

    test('AbstractTarget does not serialize name key when null', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      final hash = target.toHash();
      expect(hash.containsKey('name'), isFalse);
    });

    test(
      'AbstractTarget serializes buildConfigurationList as UUID when non-null',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final configList = graph.newObject((g, u) => XCConfigurationList(g, u));
        target.buildConfigurationList = configList;
        final hash = target.toHash();
        expect(hash['buildConfigurationList'], equals(configList.uuid));
      },
    );

    test(
      'AbstractTarget serializes buildPhases as UUID list (always emitted, even empty)',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final hash = target.toHash();
        expect(hash.containsKey('buildPhases'), isTrue);
        expect(hash['buildPhases'], isA<List<dynamic>>());
        expect(hash['buildPhases'], isEmpty);
      },
    );

    test(
      'AbstractTarget serializes buildPhases as UUID list with entries when phases added',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final phase = graph.newObject((g, u) => PBXSourcesBuildPhase(g, u));
        graph.objectsByUuid[phase.uuid] = phase;
        target.buildPhases.add(phase);
        final hash = target.toHash();
        expect(hash['buildPhases'], equals([phase.uuid]));
      },
    );

    test(
      'AbstractTarget serializes dependencies as UUID list (always emitted, even empty)',
      () {
        final target = graph.newObject((g, u) => _TestTarget(g, u));
        final hash = target.toHash();
        expect(hash.containsKey('dependencies'), isTrue);
        expect(hash['dependencies'], isA<List<dynamic>>());
        expect(hash['dependencies'], isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearRelationships
  // ---------------------------------------------------------------------------
  group('AbstractTarget.clearRelationships (PBX-13)', () {
    test('AbstractTarget.clearRelationships clears buildConfigurationList', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      final configList = graph.newObject((g, u) => XCConfigurationList(g, u));
      target.buildConfigurationList = configList;

      target.clearRelationships();
      expect(target.buildConfigurationList, isNull);
      expect(configList.referrers.contains(target), isFalse);
    });

    test('AbstractTarget.clearRelationships clears buildPhases', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      final phase = graph.newObject((g, u) => PBXSourcesBuildPhase(g, u));
      graph.objectsByUuid[phase.uuid] = phase;
      target.buildPhases.add(phase);

      target.clearRelationships();
      expect(target.buildPhases.uuids, isEmpty);
    });

    test('AbstractTarget.clearRelationships clears dependencies', () {
      final target = graph.newObject((g, u) => _TestTarget(g, u));
      final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
      graph.objectsByUuid[dep.uuid] = dep;
      target.dependencies.add(dep);

      target.clearRelationships();
      expect(target.dependencies.uuids, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // resolvedBuildSetting / commonResolvedBuildSetting ( TDD RED)
  // ---------------------------------------------------------------------------
  group('AbstractTarget.resolvedBuildSetting ( Plan 03)', () {
    test(
      'resolvedBuildSetting returns Map<String, String?> keyed by config name',
      () async {
        registerPhase3Types();
        registerPhase4Types();
        final project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
        final target = project.newObject((g, u) => PBXNativeTarget(g, u));
        target.name = 'MyApp';
        project.rootObject.targets.add(target);

        // Wire up a config list with Debug/Release configs
        final configList = project.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        target.buildConfigurationList = configList;
        final debug = project.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        debug.buildSettings['PRODUCT_NAME'] = 'MyApp';
        final release = project.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        release.buildSettings['PRODUCT_NAME'] = 'MyApp';
        configList.buildConfigurations.add(debug);
        configList.buildConfigurations.add(release);

        final result = target.resolvedBuildSetting('PRODUCT_NAME');
        expect(result, isA<Map<String, String?>>());
        expect(result.containsKey('Debug'), isTrue);
        expect(result.containsKey('Release'), isTrue);
      },
    );

    test(
      'resolvedBuildSetting falls back to project value when target has no override',
      () async {
        registerPhase3Types();
        registerPhase4Types();
        final project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
        final target = project.newObject((g, u) => PBXNativeTarget(g, u));
        target.name = 'MyApp';
        project.rootObject.targets.add(target);

        // Wire target config list with empty build settings
        final targetConfigList = project.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        target.buildConfigurationList = targetConfigList;
        final targetDebug = project.newObject(
          (g, u) => XCBuildConfiguration(g, u),
        );
        targetDebug.name = 'Debug';
        // No PRODUCT_NAME in target's debug settings
        targetConfigList.buildConfigurations.add(targetDebug);

        // Wire project config list with PRODUCT_NAME
        final projDebug = project.buildConfigurationList['Debug'];
        projDebug?.buildSettings['PRODUCT_NAME'] = 'ProjectApp';

        final result = target.resolvedBuildSetting('PRODUCT_NAME');
        expect(result['Debug'], equals('ProjectApp'));
      },
    );

    test(
      'resolvedBuildSetting expands \$(inherited) with project-level value',
      () async {
        registerPhase3Types();
        registerPhase4Types();
        final project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
        final target = project.newObject((g, u) => PBXNativeTarget(g, u));
        target.name = 'MyApp';
        project.rootObject.targets.add(target);

        final targetConfigList = project.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        target.buildConfigurationList = targetConfigList;
        final targetDebug = project.newObject(
          (g, u) => XCBuildConfiguration(g, u),
        );
        targetDebug.name = 'Debug';
        // Target value uses $(inherited)
        targetDebug.buildSettings['SWIFT_FLAGS'] = r'$(inherited) -Xfrontend';
        targetConfigList.buildConfigurations.add(targetDebug);

        // Project-level value
        final projDebug = project.buildConfigurationList['Debug'];
        projDebug?.buildSettings['SWIFT_FLAGS'] = '-enable-experimental';

        final result = target.resolvedBuildSetting('SWIFT_FLAGS');
        expect(result['Debug'], equals('-enable-experimental -Xfrontend'));
      },
    );

    test(
      'commonResolvedBuildSetting returns single String? when all configs agree',
      () async {
        registerPhase3Types();
        registerPhase4Types();
        final project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
        final target = project.newObject((g, u) => PBXNativeTarget(g, u));
        target.name = 'MyApp';
        project.rootObject.targets.add(target);

        final configList = project.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        target.buildConfigurationList = configList;
        final debug = project.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        debug.buildSettings['PRODUCT_NAME'] = 'MyApp';
        final release = project.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        release.buildSettings['PRODUCT_NAME'] = 'MyApp';
        configList.buildConfigurations.add(debug);
        configList.buildConfigurations.add(release);

        final result = target.commonResolvedBuildSetting('PRODUCT_NAME');
        expect(result, equals('MyApp'));
      },
    );

    test(
      'commonResolvedBuildSetting throws StateError when configs have different values',
      () async {
        registerPhase3Types();
        registerPhase4Types();
        final project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
        final target = project.newObject((g, u) => PBXNativeTarget(g, u));
        target.name = 'MyApp';
        project.rootObject.targets.add(target);

        final configList = project.newObject(
          (g, u) => XCConfigurationList(g, u),
        );
        target.buildConfigurationList = configList;
        final debug = project.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        debug.buildSettings['PRODUCT_NAME'] = 'MyAppDebug';
        final release = project.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        release.buildSettings['PRODUCT_NAME'] = 'MyAppRelease';
        configList.buildConfigurations.add(debug);
        configList.buildConfigurations.add(release);

        expect(
          () => target.commonResolvedBuildSetting('PRODUCT_NAME'),
          throwsStateError,
        );
      },
    );
  });
}
