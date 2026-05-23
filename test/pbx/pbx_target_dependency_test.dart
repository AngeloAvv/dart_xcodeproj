// Tests for PBXTargetDependency — covers PBX-11.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart'
    show AbstractTarget;
import 'package:dart_xcodeproj/src/pbx/pbx_target_dependency.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

/// Minimal stub used in tests for the `target` field of [PBXTargetDependency].
/// Now extends AbstractTarget ( narrowed target type from AbstractObject? to AbstractTarget?).
class _StubTarget extends AbstractTarget {
  _StubTarget(super.project, super.uuid);

  @override
  String get isa => 'StubTarget';
}

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXContainerItemProxy'] = (g, u) =>
        PBXContainerItemProxy(g, u);
    isaRegistry['PBXTargetDependency'] = (g, u) => PBXTargetDependency(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency isa (PBX-11)', () {
    test("PBXTargetDependency has isa 'PBXTargetDependency'", () {
      final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
      expect(dep.isa, equals('PBXTargetDependency'));
    });
  });

  // ---------------------------------------------------------------------------
  // target ref-counting
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency target ref-counting (PBX-11)', () {
    test(
      'PBXTargetDependency.target setter increments referrer count on assigned target',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target = graph.newObject((g, u) => _StubTarget(g, u));

        expect(target.referrers.contains(dep), isFalse);
        dep.target = target;
        expect(target.referrers.contains(dep), isTrue);
      },
    );

    test(
      'PBXTargetDependency.target setter decrements old referrer when reassigned',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target1 = graph.newObject((g, u) => _StubTarget(g, u));
        final target2 = graph.newObject((g, u) => _StubTarget(g, u));

        dep.target = target1;
        expect(target1.referrers.contains(dep), isTrue);

        dep.target = target2;
        expect(target1.referrers.contains(dep), isFalse);
        expect(target2.referrers.contains(dep), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // targetProxy ref-counting
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency targetProxy ref-counting (PBX-11)', () {
    test(
      'PBXTargetDependency.targetProxy setter increments referrer count on PBXContainerItemProxy',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));

        expect(proxy.referrers.contains(dep), isFalse);
        dep.targetProxy = proxy;
        expect(proxy.referrers.contains(dep), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency serialization (PBX-11)', () {
    test(
      'PBXTargetDependency serializes target as UUID string when non-null',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target = graph.newObject((g, u) => _StubTarget(g, u));
        dep.target = target;
        final hash = dep.toHash();
        expect(hash.containsKey('target'), isTrue);
        expect(hash['target'], equals(target.uuid));
      },
    );

    test(
      'PBXTargetDependency serializes targetProxy as UUID string when non-null',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        dep.targetProxy = proxy;
        final hash = dep.toHash();
        expect(hash.containsKey('targetProxy'), isTrue);
        expect(hash['targetProxy'], equals(proxy.uuid));
      },
    );

    test('PBXTargetDependency serializes name when non-null', () {
      final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
      dep.name = 'MyFramework';
      final hash = dep.toHash();
      expect(hash.containsKey('name'), isTrue);
      expect(hash['name'], equals('MyFramework'));
    });
  });

  // ---------------------------------------------------------------------------
  // toTreeHash — cycle prevention
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency toTreeHash cycle prevention (PBX-11)', () {
    test(
      'PBXTargetDependency.toTreeHash does NOT recurse into target (cycle prevention)',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target = graph.newObject((g, u) => _StubTarget(g, u));
        dep.target = target;

        final treeHash = dep.toTreeHash();
        // The returned hash must NOT contain a 'target' key with a nested isa map
        // (cycle prevention: targets can be mutually dependent)
        expect(treeHash.containsKey('target'), isFalse);
      },
    );

    test('PBXTargetDependency.toTreeHash DOES recurse into targetProxy', () {
      final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
      final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      proxy.remoteInfo = 'SomeTarget';
      dep.targetProxy = proxy;

      final treeHash = dep.toTreeHash();
      // targetProxy must be recursed (expanded inline)
      expect(treeHash.containsKey('targetProxy'), isTrue);
      final proxyMap = treeHash['targetProxy'] as Map<String, dynamic>;
      expect(proxyMap['isa'], equals('PBXContainerItemProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // clearRelationships and removeReference
  // ---------------------------------------------------------------------------
  group('PBXTargetDependency clearRelationships / removeReference (PBX-11)', () {
    test(
      'PBXTargetDependency.clearRelationships nulls both target and targetProxy',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target = graph.newObject((g, u) => _StubTarget(g, u));
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        dep.target = target;
        dep.targetProxy = proxy;

        dep.clearRelationships();
        expect(dep.target, isNull);
        expect(dep.targetProxy, isNull);
        expect(target.referrers.contains(dep), isFalse);
        expect(proxy.referrers.contains(dep), isFalse);
      },
    );

    test(
      'PBXTargetDependency.removeReference clears the matching target field',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final target = graph.newObject((g, u) => _StubTarget(g, u));
        dep.target = target;

        dep.removeReference(target);
        expect(dep.target, isNull);
      },
    );

    test(
      'PBXTargetDependency.removeReference clears the matching targetProxy field',
      () {
        final dep = graph.newObject((g, u) => PBXTargetDependency(g, u));
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        dep.targetProxy = proxy;

        dep.removeReference(proxy);
        expect(dep.targetProxy, isNull);
      },
    );
  });
}
