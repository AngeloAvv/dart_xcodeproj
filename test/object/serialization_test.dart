import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

/// Synthetic concrete subclass exercising every attribute type.
class TestableObject extends AbstractObject {
  static const String isaConst = 'TestablePBX';

  static const String _kName = 'name';
  static const String _kSettings = 'settings';
  static const String _kParent = 'parent';
  static const String _kChildren = 'children';

  static const List<String> _ownAttributes = [
    _kName,
    _kSettings,
    _kParent,
    _kChildren,
  ];

  String? name;
  Map<String, dynamic>? settings;

  AbstractObject? _parent;
  AbstractObject? get parent => _parent;
  set parent(AbstractObject? value) {
    if (identical(_parent, value)) return;
    markProjectAsDirty();
    _parent?.removeReferrer(this);
    _parent = value;
    value?.addReferrer(this);
  }

  late final ObjectList<AbstractObject> children = ObjectList<AbstractObject>(
    this,
  );

  TestableObject(super.project, super.uuid);

  @override
  String get isa => isaConst;

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kSettings:
        if (settings != null) into[_kSettings] = settings;
      case _kParent:
        if (_parent != null) into[_kParent] = _parent!.uuid;
      case _kChildren:
        into[_kChildren] = children.uuids; // always emit (even empty)
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kSettings:
        if (settings != null) into[_kSettings] = settings;
      case _kParent:
        if (_parent != null) {
          into[_kParent] = visited.contains(_parent!.uuid)
              ? '<cycle: ${_parent!.uuid}>'
              : _parent!.toTreeHash(visited);
        }
      case _kChildren:
        into[_kChildren] = children
            .map(
              (c) => visited.contains(c.uuid)
                  ? '<cycle: ${c.uuid}>'
                  : c.toTreeHash(visited),
            )
            .toList();
    }
  }

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kName:
        name = value as String?;
      case _kSettings:
        settings = (value as Map?)?.cast<String, dynamic>();
      case _kParent:
        if (value is String) {
          final ref = objectWithUuid(value, objectsByUuidPlist);
          if (ref != null) parent = ref;
        }
      case _kChildren:
        if (value is List) {
          for (final v in value) {
            final ref = objectWithUuid(v as String, objectsByUuidPlist);
            if (ref != null) children.add(ref);
          }
        }
    }
  }

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_parent, obj)) _parent = null;
  }

  @override
  void clearRelationships() {
    if (_parent != null) {
      _parent!.removeReferrer(this);
      _parent = null;
    }
    children.clear();
  }
}

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['TestablePBX'] = (g, u) => TestableObject(g, u);
  });

  tearDown(() {
    isaRegistry.remove('TestablePBX');
  });

  group('AbstractObject.toHash (OBJ-02)', () {
    test('emits isa as the first key', () {
      final obj = TestableObject(graph, 'AAAAAAAAAAAAAAAAAAAAAAAA');
      final hash = obj.toHash();
      expect(hash.keys.first, equals('isa'));
      expect(hash['isa'], equals('TestablePBX'));
    });

    test('includes simple attribute in attribute order', () {
      final obj = TestableObject(graph, 'BBBBBBBBBBBBBBBBBBBBBBBB');
      obj.name = 'hello';
      final hash = obj.toHash();
      expect(hash['name'], equals('hello'));
    });

    test('omits null simple attribute', () {
      final obj = TestableObject(graph, 'CCCCCCCCCCCCCCCCCCCCCCCC');
      // name is null, settings is null
      final hash = obj.toHash();
      expect(hash.containsKey('name'), isFalse);
      expect(hash.containsKey('settings'), isFalse);
    });

    test('to-one: emits UUID; omits when null', () {
      final parent = TestableObject(graph, 'DDDDDDDDDDDDDDDDDDDDDDDD');
      final child = TestableObject(graph, 'EEEEEEEEEEEEEEEEEEEEEEEE');
      child.parent = parent;
      final hashWithParent = child.toHash();
      expect(hashWithParent['parent'], equals('DDDDDDDDDDDDDDDDDDDDDDDD'));

      final orphan = TestableObject(graph, 'FFFFFFFFFFFFFFFFFFFFFFFF');
      final hashWithoutParent = orphan.toHash();
      expect(hashWithoutParent.containsKey('parent'), isFalse);
    });

    test(
      'to-many: emits UUIDs as List<String>; emits empty list when empty',
      () {
        final p = TestableObject(graph, '111111111111111111111111');
        final c1 = TestableObject(graph, '222222222222222222222222');
        final c2 = TestableObject(graph, '333333333333333333333333');
        p.children.addAll([c1, c2]);
        final hash = p.toHash();
        expect(
          hash['children'],
          equals(['222222222222222222222222', '333333333333333333333333']),
        );

        final empty = TestableObject(graph, '444444444444444444444444');
        expect(
          empty.toHash()['children'],
          equals(<String>[]),
          reason: 'empty children must serialize as [] per ',
        );
      },
    );

    test('subclass-first attribute order', () {
      final obj = TestableObject(graph, '555555555555555555555555');
      obj.name = 'first';
      final keys = obj.toHash().keys.toList();
      // isa, then own attributes in declared order
      expect(keys.first, equals('isa'));
      expect(keys.indexOf('name') < keys.indexOf('children'), isTrue);
    });
  });

  group('AbstractObject.toHash stability (OBJ-04 / )', () {
    test('repeated calls return deeply-equal maps', () {
      final obj = TestableObject(graph, '666666666666666666666666');
      obj.name = 'stable';
      final h1 = obj.toHash();
      final h2 = obj.toHash();
      expect(h1, equals(h2));
      expect(
        h1.keys.toList(),
        equals(h2.keys.toList()),
        reason: 'key order must be identical',
      );
    });
  });

  group('AbstractObject.configureWithPlist (OBJ-03)', () {
    test('populates simple attribute from plist value', () {
      final obj = TestableObject(graph, '777777777777777777777777');
      obj.configureWithPlist({
        '777777777777777777777777': {
          'isa': 'TestablePBX',
          'name': 'loaded',
          'children': <String>[],
        },
      });
      expect(obj.name, equals('loaded'));
    });

    test('resolves to-one reference via objectWithUuid', () {
      final parentUuid = '888888888888888888888888';
      final childUuid = '999999999999999999999999';
      final child = TestableObject(graph, childUuid);
      graph.objectsByUuid[childUuid] =
          child; // pretend caller already registered
      final plist = <String, dynamic>{
        parentUuid: {
          'isa': 'TestablePBX',
          'parent': null,
          'children': <String>[],
        },
        childUuid: {
          'isa': 'TestablePBX',
          'parent': parentUuid,
          'children': <String>[],
        },
      };
      child.configureWithPlist(plist);
      expect(child.parent, isNotNull);
      expect(child.parent!.uuid, equals(parentUuid));
      // The parent was created on demand and registered:
      expect(graph.objectsByUuid.containsKey(parentUuid), isTrue);
    });

    test('populates to-many children', () {
      final parentUuid = 'AAAAAAAAAAAAAAAAAAAAAAAB';
      final c1 = 'BBBBBBBBBBBBBBBBBBBBBBBC';
      final c2 = 'CCCCCCCCCCCCCCCCCCCCCCCD';
      final parent = TestableObject(graph, parentUuid);
      graph.objectsByUuid[parentUuid] = parent;
      parent.configureWithPlist({
        parentUuid: {
          'isa': 'TestablePBX',
          'children': [c1, c2],
        },
        c1: {'isa': 'TestablePBX', 'children': <String>[]},
        c2: {'isa': 'TestablePBX', 'children': <String>[]},
      });
      expect(parent.children.length, equals(2));
      expect(parent.children.uuids, equals([c1, c2]));
    });

    test('NEGATIVE: ISA mismatch throws StateError', () {
      final obj = TestableObject(graph, 'DDDDDDDDDDDDDDDDDDDDDDDE');
      expect(
        () => obj.configureWithPlist({
          'DDDDDDDDDDDDDDDDDDDDDDDE': {
            'isa': 'WrongISA',
            'children': <String>[],
          },
        }),
        throwsStateError,
      );
    });

    test('warns (does NOT throw) on unknown plist keys', () {
      final obj = TestableObject(graph, 'EEEEEEEEEEEEEEEEEEEEEEEF');
      expect(
        () => obj.configureWithPlist({
          'EEEEEEEEEEEEEEEEEEEEEEEF': {
            'isa': 'TestablePBX',
            'children': <String>[],
            'futureKey1': 'value1',
            'futureKey2': 42,
          },
        }),
        returnsNormally,
      );
    });

    test('register-then-configure: cyclic plist terminates', () {
      final aUuid = 'FFFFFFFFFFFFFFFFFFFFFFFA';
      final bUuid = '101010101010101010101010';
      final plist = <String, dynamic>{
        aUuid: {'isa': 'TestablePBX', 'parent': bUuid, 'children': <String>[]},
        bUuid: {'isa': 'TestablePBX', 'parent': aUuid, 'children': <String>[]},
      };
      // Driver: load via objectFromPlist (the entry point that registers BEFORE configure).
      final a = objectFromPlist(aUuid, plist, graph);
      expect(a, isNotNull);
      expect(graph.objectsByUuid.containsKey(aUuid), isTrue);
      expect(graph.objectsByUuid.containsKey(bUuid), isTrue);
      final b = graph.objectsByUuid[bUuid];
      expect((a as TestableObject).parent, same(b));
      expect((b as TestableObject).parent, same(a));
    });
  });

  group('AbstractObject.objectWithUuid (OBJ-03)', () {
    test('returns memoized object when already registered', () {
      final existing = TestableObject(graph, '111111111111111111111110');
      graph.objectsByUuid['111111111111111111111110'] = existing;
      final caller = TestableObject(graph, '222222222222222222222221');
      final result = caller.objectWithUuid('111111111111111111111110', {});
      expect(result, same(existing));
    });

    test('creates via objectFromPlist when not memoized', () {
      final caller = TestableObject(graph, '333333333333333333333332');
      final result = caller.objectWithUuid('444444444444444444444443', {
        '444444444444444444444443': {
          'isa': 'TestablePBX',
          'children': <String>[],
        },
      });
      expect(result, isNotNull);
      expect(graph.objectsByUuid['444444444444444444444443'], same(result));
    });
  });

  group('AbstractObject.toTreeHash (OBJ-04)', () {
    test('emits displayName first, then isa', () {
      final obj = TestableObject(graph, '555555555555555555555554');
      final tree = obj.toTreeHash();
      final keys = tree.keys.toList();
      expect(keys[0], equals('displayName'));
      expect(keys[1], equals('isa'));
    });

    test('expands to-one reference recursively (no UUID strings)', () {
      final parent = TestableObject(graph, '666666666666666666666665');
      parent.name = 'parent_name';
      final child = TestableObject(graph, '777777777777777777777776');
      child.parent = parent;
      final tree = child.toTreeHash();
      expect(tree['parent'], isA<Map<String, dynamic>>());
      expect(
        (tree['parent'] as Map<String, dynamic>)['name'],
        equals('parent_name'),
      );
    });

    test('cycle guard: A↔B produces placeholder, no infinite loop', () {
      final a = TestableObject(graph, '888888888888888888888887');
      final b = TestableObject(graph, '999999999999999999999998');
      a.parent = b;
      b.parent = a;
      final tree = a.toTreeHash();
      expect(tree['parent'], isA<Map<String, dynamic>>());
      // The B's parent (A) is in the visited set, so it should be a cycle placeholder.
      final bTree = tree['parent'] as Map<String, dynamic>;
      expect(bTree['parent'], equals('<cycle: 888888888888888888888887>'));
    });
  });

  group('AbstractObject.toTreeHash stability (OBJ-04 / )', () {
    test('repeated calls return deeply-equal maps', () {
      final obj = TestableObject(graph, 'AAAAAAAAAAAAAAAAAAAAAAAA');
      obj.name = 'stable';
      final t1 = obj.toTreeHash();
      final t2 = obj.toTreeHash();
      expect(t1, equals(t2));
    });
  });

  group('AbstractObject.prettyPrint (OBJ-04)', () {
    test('default returns displayName', () {
      final obj = TestableObject(graph, 'BBBBBBBBBBBBBBBBBBBBBBBB');
      // displayName for 'TestablePBX' = isa stripped of PBX/XC prefix.
      // 'TestablePBX' has no PBX/XC prefix at start, so displayName == isa.
      expect(obj.prettyPrint(), equals(obj.displayName));
      expect(obj.prettyPrint(), isA<String>());
    });
  });
}
