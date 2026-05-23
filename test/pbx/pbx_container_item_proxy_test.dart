// Tests for PBXContainerItemProxy — covers PBX-10.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXContainerItemProxy'] = (g, u) =>
        PBXContainerItemProxy(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXContainerItemProxy isa (PBX-10)', () {
    test("PBXContainerItemProxy has isa 'PBXContainerItemProxy'", () {
      final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      expect(proxy.isa, equals('PBXContainerItemProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // containerPortal is plain String (NOT has_one)
  // ---------------------------------------------------------------------------
  group('PBXContainerItemProxy containerPortal (PBX-10)', () {
    test(
      'PBXContainerItemProxy.containerPortal is a plain String (not a has_one)',
      () {
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        const someUuid = 'SOMEUUID000000000000000A';
        proxy.containerPortal = someUuid;
        expect(proxy.containerPortal, equals(someUuid));
      },
    );

    test('containerPortal assignment does not add referrers to any object', () {
      final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      // Assign a string UUID — no ref counting should occur
      proxy.containerPortal = 'AAAAAAAAAAAAAAAAAAAAAA01';
      // The proxy itself has no referrers at this point (newly created, never added to graph)
      // The point: no AbstractObject gets addReferrer called on it
      expect(proxy.referrers, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization — all 4 attributes
  // ---------------------------------------------------------------------------
  group('PBXContainerItemProxy serialization (PBX-10)', () {
    test(
      "PBXContainerItemProxy serializes containerPortal as 'containerPortal' plist key when non-null",
      () {
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        proxy.containerPortal = 'AAAAAAAAAAAAAAAAAAAAAA01';
        final hash = proxy.toHash();
        expect(hash.containsKey('containerPortal'), isTrue);
        expect(hash['containerPortal'], equals('AAAAAAAAAAAAAAAAAAAAAA01'));
      },
    );

    test(
      "PBXContainerItemProxy serializes proxyType as 'proxyType' when non-null",
      () {
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        proxy.proxyType = '1';
        final hash = proxy.toHash();
        expect(hash.containsKey('proxyType'), isTrue);
        expect(hash['proxyType'], equals('1'));
      },
    );

    test(
      "PBXContainerItemProxy serializes remoteGlobalIDString as exact key 'remoteGlobalIDString' (capital ID) when non-null",
      () {
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        proxy.remoteGlobalIDString = 'BBBBBBBBBBBBBBBBBBBBBB02';
        final hash = proxy.toHash();
        // Must be exact key 'remoteGlobalIDString' — NOT 'remoteGlobalIdString'
        expect(hash.containsKey('remoteGlobalIDString'), isTrue);
        expect(
          hash['remoteGlobalIDString'],
          equals('BBBBBBBBBBBBBBBBBBBBBB02'),
        );
      },
    );

    test(
      "PBXContainerItemProxy serializes remoteInfo as 'remoteInfo' when non-null",
      () {
        final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
        proxy.remoteInfo = 'MyApp';
        final hash = proxy.toHash();
        expect(hash.containsKey('remoteInfo'), isTrue);
        expect(hash['remoteInfo'], equals('MyApp'));
      },
    );

    test('PBXContainerItemProxy omits null attributes from toHash', () {
      final proxy = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      // All four attributes are null by default
      final hash = proxy.toHash();
      expect(hash.containsKey('containerPortal'), isFalse);
      expect(hash.containsKey('proxyType'), isFalse);
      expect(hash.containsKey('remoteGlobalIDString'), isFalse);
      expect(hash.containsKey('remoteInfo'), isFalse);
      // isa is always present
      expect(hash['isa'], equals('PBXContainerItemProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip via toHash → configureWithPlist
  // ---------------------------------------------------------------------------
  group('PBXContainerItemProxy round-trip (PBX-10)', () {
    test(
      'PBXContainerItemProxy round-trips all 4 attributes via toHash → configureWithPlist',
      () {
        const proxyUuid = 'CCCCCCCCCCCCCCCCCCCCCC01';

        final plist = <String, dynamic>{
          proxyUuid: {
            'isa': 'PBXContainerItemProxy',
            'containerPortal': 'DDDDDDDDDDDDDDDDDDDDDD01',
            'proxyType': '1',
            'remoteGlobalIDString': 'EEEEEEEEEEEEEEEEEEEEEE01',
            'remoteInfo': 'SomeTarget',
          },
        };

        final proxy = PBXContainerItemProxy(graph, proxyUuid);
        graph.objectsByUuid[proxyUuid] = proxy;
        proxy.configureWithPlist(plist);

        expect(proxy.containerPortal, equals('DDDDDDDDDDDDDDDDDDDDDD01'));
        expect(proxy.proxyType, equals('1'));
        expect(proxy.remoteGlobalIDString, equals('EEEEEEEEEEEEEEEEEEEEEE01'));
        expect(proxy.remoteInfo, equals('SomeTarget'));
      },
    );
  });
}
