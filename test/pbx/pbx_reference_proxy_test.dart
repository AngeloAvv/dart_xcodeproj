// Tests for PBXReferenceProxy — covers PBX-12.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_reference_proxy.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXContainerItemProxy'] = (g, u) =>
        PBXContainerItemProxy(g, u);
    isaRegistry['PBXReferenceProxy'] = (g, u) => PBXReferenceProxy(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy isa (PBX-12)', () {
    test("PBXReferenceProxy has isa 'PBXReferenceProxy'", () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      expect(refProxy.isa, equals('PBXReferenceProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // remoteRef ref-counting
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy remoteRef ref-counting (PBX-12)', () {
    test(
      'PBXReferenceProxy.remoteRef setter ref counts PBXContainerItemProxy',
      () {
        final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final containerProxy = graph.newObject(
          (g, u) => PBXContainerItemProxy(g, u),
        );

        expect(containerProxy.referrers.contains(refProxy), isFalse);
        refProxy.remoteRef = containerProxy;
        expect(containerProxy.referrers.contains(refProxy), isTrue);
      },
    );

    test('remoteRef setter decrements old ref when reassigned', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final proxy1 = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      final proxy2 = graph.newObject((g, u) => PBXContainerItemProxy(g, u));

      refProxy.remoteRef = proxy1;
      expect(proxy1.referrers.contains(refProxy), isTrue);

      refProxy.remoteRef = proxy2;
      expect(proxy1.referrers.contains(refProxy), isFalse);
      expect(proxy2.referrers.contains(refProxy), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy serialization (PBX-12)', () {
    test('PBXReferenceProxy serializes path when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.path = 'Framework.framework';
      final hash = refProxy.toHash();
      expect(hash.containsKey('path'), isTrue);
      expect(hash['path'], equals('Framework.framework'));
    });

    test('PBXReferenceProxy serializes fileType when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.fileType = 'wrapper.framework';
      final hash = refProxy.toHash();
      expect(hash.containsKey('fileType'), isTrue);
      expect(hash['fileType'], equals('wrapper.framework'));
    });

    test('PBXReferenceProxy serializes sourceTree when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.sourceTree = 'BUILT_PRODUCTS_DIR';
      final hash = refProxy.toHash();
      expect(hash.containsKey('sourceTree'), isTrue);
      expect(hash['sourceTree'], equals('BUILT_PRODUCTS_DIR'));
    });

    test(
      'PBXReferenceProxy serializes remoteRef as UUID string when non-null',
      () {
        final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final containerProxy = graph.newObject(
          (g, u) => PBXContainerItemProxy(g, u),
        );
        refProxy.remoteRef = containerProxy;
        final hash = refProxy.toHash();
        expect(hash.containsKey('remoteRef'), isTrue);
        expect(hash['remoteRef'], equals(containerProxy.uuid));
      },
    );

    test('PBXReferenceProxy omits null attributes', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final hash = refProxy.toHash();
      expect(hash.containsKey('path'), isFalse);
      expect(hash.containsKey('fileType'), isFalse);
      expect(hash.containsKey('sourceTree'), isFalse);
      expect(hash.containsKey('remoteRef'), isFalse);
      expect(hash['isa'], equals('PBXReferenceProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip via configureWithPlist
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy round-trip (PBX-12)', () {
    test(
      'PBXReferenceProxy round-trips through toHash → configureWithPlist',
      () {
        const containerProxyUuid = 'CCCCCCCCCCCCCCCCCCCCCC01';
        const refProxyUuid = 'DDDDDDDDDDDDDDDDDDDDDD01';

        final plist = <String, dynamic>{
          containerProxyUuid: {
            'isa': 'PBXContainerItemProxy',
            'containerPortal': 'EEEEEEEEEEEEEEEEEEEEEE01',
            'proxyType': '2',
            'remoteGlobalIDString': 'FFFFFFFFFFFFFFFFFFFF0001',
            'remoteInfo': 'RemoteLib',
          },
          refProxyUuid: {
            'isa': 'PBXReferenceProxy',
            'path': 'libRemote.a',
            'fileType': 'archive.ar',
            'sourceTree': 'BUILT_PRODUCTS_DIR',
            'remoteRef': containerProxyUuid,
          },
        };

        final refProxy = PBXReferenceProxy(graph, refProxyUuid);
        graph.objectsByUuid[refProxyUuid] = refProxy;
        refProxy.configureWithPlist(plist);

        expect(refProxy.path, equals('libRemote.a'));
        expect(refProxy.fileType, equals('archive.ar'));
        expect(refProxy.sourceTree, equals('BUILT_PRODUCTS_DIR'));
        expect(refProxy.remoteRef, isNotNull);
        expect(refProxy.remoteRef, isA<PBXContainerItemProxy>());
        expect(refProxy.remoteRef!.uuid, equals(containerProxyUuid));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearRelationships
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy clearRelationships (PBX-12)', () {
    test('PBXReferenceProxy.clearRelationships nulls remoteRef', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final containerProxy = graph.newObject(
        (g, u) => PBXContainerItemProxy(g, u),
      );
      refProxy.remoteRef = containerProxy;
      expect(containerProxy.referrers.contains(refProxy), isTrue);

      refProxy.clearRelationships();
      expect(refProxy.remoteRef, isNull);
      expect(containerProxy.referrers.contains(refProxy), isFalse);
    });

    test('PBXReferenceProxy.removeReference nulls remoteRef when matching', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final containerProxy = graph.newObject(
        (g, u) => PBXContainerItemProxy(g, u),
      );
      refProxy.remoteRef = containerProxy;

      refProxy.removeReference(containerProxy);
      expect(refProxy.remoteRef, isNull);
    });
  });
}
