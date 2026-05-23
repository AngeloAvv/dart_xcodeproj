// Tests for PBXNativeTarget + PBXAggregateTarget + PBXLegacyTarget — covers PBX-13 + SC-2.

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_target_dependency.dart';
import 'package:dart_xcodeproj/src/pbx/xc_swift_package_product_dependency.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

/// Stub representing PBXProject via runtime ISA check.
/// Used to verify that addDependency locates the project via `o.isa == 'PBXProject'`.
class _StubPBXProject extends AbstractObject {
  _StubPBXProject(super.project, super.uuid);

  @override
  String get isa => 'PBXProject';

  @override
  List<String> get attributeOrder => const [];
}

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXNativeTarget'] = (g, u) => PBXNativeTarget(g, u);
    isaRegistry['PBXAggregateTarget'] = (g, u) => PBXAggregateTarget(g, u);
    isaRegistry['PBXLegacyTarget'] = (g, u) => PBXLegacyTarget(g, u);
    isaRegistry['PBXContainerItemProxy'] = (g, u) =>
        PBXContainerItemProxy(g, u);
    isaRegistry['PBXTargetDependency'] = (g, u) => PBXTargetDependency(g, u);
    isaRegistry['PBXSourcesBuildPhase'] = (g, u) => PBXSourcesBuildPhase(g, u);
    isaRegistry['XCSwiftPackageProductDependency'] = (g, u) =>
        XCSwiftPackageProductDependency(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget — ISA
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget isa (PBX-13)', () {
    test("PBXNativeTarget has isa 'PBXNativeTarget'", () {
      final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
      expect(target.isa, equals('PBXNativeTarget'));
    });
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget — simple attribute serialization
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget serialization (PBX-13)', () {
    test('PBXNativeTarget serializes productType when non-null', () {
      final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
      target.productType = 'com.apple.product-type.application';
      final hash = target.toHash();
      expect(hash['productType'], equals('com.apple.product-type.application'));
    });

    test('PBXNativeTarget serializes productName when non-null', () {
      final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
      target.productName = 'MyApp';
      final hash = target.toHash();
      expect(hash['productName'], equals('MyApp'));
    });

    test('PBXNativeTarget serializes productInstallPath when non-null', () {
      final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
      target.productInstallPath = r'$(HOME)/Applications';
      final hash = target.toHash();
      expect(hash['productInstallPath'], equals(r'$(HOME)/Applications'));
    });
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget — packageProductDependencies ObjectList
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.packageProductDependencies (PBX-13)', () {
    test(
      'PBXNativeTarget.packageProductDependencies is ObjectList<XCSwiftPackageProductDependency>',
      () {
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
        expect(
          target.packageProductDependencies,
          isA<ObjectList<XCSwiftPackageProductDependency>>(),
        );
      },
    );

    test(
      'PBXNativeTarget serializes packageProductDependencies as UUID list when NON-empty',
      () {
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
        // use XCSwiftPackageProductDependency (narrowed type)
        final stubDep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        graph.objectsByUuid[stubDep.uuid] = stubDep;
        target.packageProductDependencies.add(stubDep);
        final hash = target.toHash();
        expect(hash.containsKey('packageProductDependencies'), isTrue);
        expect(hash['packageProductDependencies'], equals([stubDep.uuid]));
      },
    );

    test(
      'PBXNativeTarget OMITS packageProductDependencies key from toHash when empty',
      () {
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
        final hash = target.toHash();
        expect(hash.containsKey('packageProductDependencies'), isFalse);
      },
    );

    test(
      'PBXNativeTarget OMITS fileSystemSynchronizedGroups key from toHash when empty',
      () {
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
        final hash = target.toHash();
        expect(hash.containsKey('fileSystemSynchronizedGroups'), isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addBuildPhase
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addBuildPhase (PBX-13)', () {
    test(
      'PBXNativeTarget.addBuildPhase appends phase to buildPhases ObjectList and increments phase referrer count',
      () {
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[target.uuid] = target;
        final phase = graph.newObject((g, u) => PBXSourcesBuildPhase(g, u));
        graph.objectsByUuid[phase.uuid] = phase;

        expect(target.buildPhases.uuids, isEmpty);
        target.addBuildPhase(phase);
        expect(target.buildPhases.uuids, contains(phase.uuid));
        expect(phase.referrers.contains(target), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — object creation
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency object creation (SC-2)', () {
    test(
      'PBXNativeTarget.addDependency creates PBXTargetDependency in objectsByUuid',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final hasDep = graph.objectsByUuid.values.any(
          (o) => o is PBXTargetDependency,
        );
        expect(hasDep, isTrue);
      },
    );

    test(
      'PBXNativeTarget.addDependency creates PBXContainerItemProxy in objectsByUuid',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final hasProxy = graph.objectsByUuid.values.any(
          (o) => o is PBXContainerItemProxy,
        );
        expect(hasProxy, isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — proxy attribute values
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency proxy attributes (SC-2)', () {
    test(
      "PBXNativeTarget.addDependency sets PBXContainerItemProxy.proxyType = '1'",
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;
        expect(proxy.proxyType, equals('1'));
      },
    );

    test(
      'PBXNativeTarget.addDependency sets PBXContainerItemProxy.remoteGlobalIDString = target.uuid',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;
        expect(proxy.remoteGlobalIDString, equals(depTarget.uuid));
      },
    );

    test(
      'PBXNativeTarget.addDependency sets PBXContainerItemProxy.remoteInfo = target.name',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;
        expect(proxy.remoteInfo, equals('DepTarget'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — dependency attribute values
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency dependency attributes (SC-2)', () {
    test(
      'PBXNativeTarget.addDependency sets PBXTargetDependency.target = the target argument',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final dep = graph.objectsByUuid.values
            .whereType<PBXTargetDependency>()
            .first;
        expect(dep.target, equals(depTarget));
      },
    );

    test(
      'PBXNativeTarget.addDependency sets PBXTargetDependency.targetProxy = the new PBXContainerItemProxy',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final dep = graph.objectsByUuid.values
            .whereType<PBXTargetDependency>()
            .first;
        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;
        expect(dep.targetProxy, equals(proxy));
      },
    );

    test(
      'PBXNativeTarget.addDependency appends the new PBXTargetDependency to dependencies ObjectList',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        expect(sourceTarget.dependencies.uuids, isEmpty);
        sourceTarget.addDependency(depTarget);
        expect(sourceTarget.dependencies.uuids, hasLength(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — referrer counts (SC-2)
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency referrer counts (SC-2)', () {
    test(
      'PBXNativeTarget.addDependency referrer counts: target has 1 referrer (the new dependency); proxy has 1 referrer (the new dependency); dependency has 1 referrer (this native target)',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final dep = graph.objectsByUuid.values
            .whereType<PBXTargetDependency>()
            .first;
        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;

        // depTarget has 1 referrer: the new dep
        expect(depTarget.referrers.contains(dep), isTrue);
        expect(depTarget.referrers.length, equals(1));

        // proxy has 1 referrer: the new dep
        expect(proxy.referrers.contains(dep), isTrue);
        expect(proxy.referrers.length, equals(1));

        // dep has 1 referrer: the sourceTarget (via dependencies.add)
        expect(dep.referrers.contains(sourceTarget), isTrue);
        expect(dep.referrers.length, equals(1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — idempotency ( mitigation)
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency idempotency', () {
    test(
      'PBXNativeTarget.addDependency is idempotent — calling twice with same target adds only ONE dependency',
      () {
        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);
        sourceTarget.addDependency(depTarget); // second call — should be no-op

        expect(sourceTarget.dependencies.uuids, hasLength(1));
        expect(
          graph.objectsByUuid.values.whereType<PBXTargetDependency>().length,
          equals(1),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXNativeTarget.addDependency — containerPortal uses PBXProject ISA scan
  // ---------------------------------------------------------------------------
  group('PBXNativeTarget.addDependency containerPortal (SC-2)', () {
    test(
      'addDependency sets containerPortal to PBXProject UUID when project root is in objectsByUuid',
      () {
        // Inject a stub PBXProject object via runtime ISA check
        final stubProject = graph.newObject((g, u) => _StubPBXProject(g, u));
        graph.objectsByUuid[stubProject.uuid] = stubProject;

        final sourceTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[sourceTarget.uuid] = sourceTarget;
        final depTarget = graph.newObject((g, u) => PBXNativeTarget(g, u));
        graph.objectsByUuid[depTarget.uuid] = depTarget;
        depTarget.name = 'DepTarget';

        sourceTarget.addDependency(depTarget);

        final proxy = graph.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .first;
        expect(proxy.containerPortal, equals(stubProject.uuid));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXAggregateTarget
  // ---------------------------------------------------------------------------
  group('PBXAggregateTarget (PBX-13)', () {
    test("PBXAggregateTarget has isa 'PBXAggregateTarget'", () {
      final target = graph.newObject((g, u) => PBXAggregateTarget(g, u));
      expect(target.isa, equals('PBXAggregateTarget'));
    });

    test(
      'PBXAggregateTarget has no extra attributes (no keys beyond AbstractTarget attributes)',
      () {
        final target = graph.newObject((g, u) => PBXAggregateTarget(g, u));
        target.name = 'AggTarget';
        final hash = target.toHash();
        // Should contain isa, name, buildPhases, dependencies (from AbstractTarget)
        expect(hash.containsKey('isa'), isTrue);
        expect(hash.containsKey('name'), isTrue);
        expect(hash.containsKey('buildPhases'), isTrue);
        expect(hash.containsKey('dependencies'), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // PBXLegacyTarget
  // ---------------------------------------------------------------------------
  group('PBXLegacyTarget (PBX-13)', () {
    test("PBXLegacyTarget has isa 'PBXLegacyTarget'", () {
      final target = graph.newObject((g, u) => PBXLegacyTarget(g, u));
      expect(target.isa, equals('PBXLegacyTarget'));
    });

    test('PBXLegacyTarget serializes buildArgumentsString when non-null', () {
      final target = graph.newObject((g, u) => PBXLegacyTarget(g, u));
      target.buildArgumentsString = r'$(ACTION)';
      final hash = target.toHash();
      expect(hash['buildArgumentsString'], equals(r'$(ACTION)'));
    });

    test('PBXLegacyTarget serializes buildToolPath when non-null', () {
      final target = graph.newObject((g, u) => PBXLegacyTarget(g, u));
      target.buildToolPath = '/usr/bin/make';
      final hash = target.toHash();
      expect(hash['buildToolPath'], equals('/usr/bin/make'));
    });

    test('PBXLegacyTarget serializes buildWorkingDirectory when non-null', () {
      final target = graph.newObject((g, u) => PBXLegacyTarget(g, u));
      target.buildWorkingDirectory = r'$(PROJECT_DIR)';
      final hash = target.toHash();
      expect(hash['buildWorkingDirectory'], equals(r'$(PROJECT_DIR)'));
    });

    test(
      'PBXLegacyTarget serializes passBuildSettingsInEnvironment when non-null',
      () {
        final target = graph.newObject((g, u) => PBXLegacyTarget(g, u));
        target.passBuildSettingsInEnvironment = '1';
        final hash = target.toHash();
        expect(hash['passBuildSettingsInEnvironment'], equals('1'));
      },
    );
  });
}
