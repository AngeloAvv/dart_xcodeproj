import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';
import 'serialization_test.dart' show TestableObject;

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    // Ensure registry is clean for each test.
    isaRegistry.clear();
  });

  tearDown(() {
    isaRegistry.clear();
  });

  group('isaRegistry initial state (OBJ-03)', () {
    test('isaRegistry is empty by default ( ships empty)', () {
      // After setUp clear, registry must be empty.
      expect(isaRegistry, isEmpty);
    });

    test('isaRegistry is mutable ( must be able to register)', () {
      isaRegistry['Foo'] = (g, u) => TestableObject(g, u);
      expect(isaRegistry['Foo'], isNotNull);
    });
  });

  group('objectFromPlist with unknown ISA (OBJ-03 / )', () {
    test('returns null and does NOT throw on unknown ISA', () {
      final result = objectFromPlist('111111111111111111111111', {
        '111111111111111111111111': {'isa': 'CompletelyUnknownIsa'},
      }, graph);
      expect(result, isNull);
      expect(
        graph.objectsByUuid,
        isEmpty,
        reason: 'unknown ISA must not register anything',
      );
    });

    test('NEGATIVE: must NOT throw on unknown ISA', () {
      expect(
        () => objectFromPlist('222222222222222222222222', {
          '222222222222222222222222': {'isa': 'Unknown'},
        }, graph),
        returnsNormally,
      );
    });
  });

  group('objectFromPlist with known ISA (OBJ-03)', () {
    setUp(() {
      isaRegistry['TestablePBX'] = (g, u) => TestableObject(g, u);
    });

    test('creates, registers, and configures', () {
      final result = objectFromPlist('333333333333333333333333', {
        '333333333333333333333333': {
          'isa': 'TestablePBX',
          'name': 'configured',
          'children': <String>[],
        },
      }, graph);
      expect(result, isNotNull);
      expect(result, isA<TestableObject>());
      expect(
        (result as TestableObject).name,
        equals('configured'),
        reason: 'configureWithPlist must run after registration',
      );
      expect(graph.objectsByUuid['333333333333333333333333'], same(result));
    });
  });

  group('objectFromPlist failure paths (OBJ-03)', () {
    test('returns null when plist has no entry for the UUID', () {
      final result = objectFromPlist('XXXX', {
        'YYYY': {'isa': 'Foo'},
      }, graph);
      expect(result, isNull);
    });

    test('returns null when plist entry lacks an isa key', () {
      final result = objectFromPlist('444444444444444444444444', {
        '444444444444444444444444': {'name': 'no-isa'},
      }, graph);
      expect(result, isNull);
    });
  });

  group('objectFromPlist register-then-configure ordering (OBJ-03 / )', () {
    setUp(() {
      isaRegistry['TestablePBX'] = (g, u) => TestableObject(g, u);
    });

    test('cyclic plist terminates and produces correct graph', () {
      final aUuid = '555555555555555555555555';
      final bUuid = '666666666666666666666666';
      final plist = <String, dynamic>{
        aUuid: {'isa': 'TestablePBX', 'parent': bUuid, 'children': <String>[]},
        bUuid: {'isa': 'TestablePBX', 'parent': aUuid, 'children': <String>[]},
      };
      final a = objectFromPlist(aUuid, plist, graph);
      expect(a, isNotNull);
      expect(graph.objectsByUuid.containsKey(aUuid), isTrue);
      expect(graph.objectsByUuid.containsKey(bUuid), isTrue);
      expect((a as TestableObject).parent?.uuid, equals(bUuid));
    });
  });
}
