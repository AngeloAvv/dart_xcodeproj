import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/object_dictionary.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

class _TestObject extends AbstractObject {
  _TestObject(super.project, super.uuid);
  @override
  String get isa => 'PBXTest';
}

class _Owner extends AbstractObject {
  _Owner(super.project, super.uuid);
  @override
  String get isa => 'Owner';
}

void main() {
  late MockObjectGraph graph;
  late _Owner owner;
  late ObjectList<_TestObject> list;

  setUp(() {
    graph = MockObjectGraph();
    owner = _Owner(graph, 'OWNEROWNEROWNEROWNEROWNE');
    list = ObjectList<_TestObject>(owner);
  });

  group('ObjectList.add (OBJ-05)', () {
    test('add appends, increments referrer, marks dirty', () {
      final obj = _TestObject(graph, 'AAAAAAAAAAAAAAAAAAAAAAAA');
      list.add(obj);
      expect(list.length, equals(1));
      expect(list[0], same(obj));
      expect(obj.referrers, contains(owner));
      expect(graph.isDirty, isTrue);
    });

    test('adding same object twice produces 2 list entries but 1 referrer', () {
      final obj = _TestObject(graph, 'BBBBBBBBBBBBBBBBBBBBBBBB');
      list.add(obj);
      list.add(obj);
      expect(list.length, equals(2));
      expect(
        obj.referrers.length,
        equals(1),
        reason: 'AbstractObject._referrers is a Set — owner counted once',
      );
    });
  });

  group('ObjectList.insert (OBJ-05)', () {
    test('insert at 0 prepends with addReferrer', () {
      final a = _TestObject(graph, 'CCCCCCCCCCCCCCCCCCCCCCCC');
      final b = _TestObject(graph, 'DDDDDDDDDDDDDDDDDDDDDDDD');
      list.add(a);
      list.insert(0, b);
      expect(list[0], same(b));
      expect(list[1], same(a));
      expect(b.referrers, contains(owner));
    });

    test('insert at length appends', () {
      final a = _TestObject(graph, 'EEEEEEEEEEEEEEEEEEEEEEEE');
      list.insert(0, a);
      expect(list[0], same(a));
    });
  });

  group('ObjectList.addAll (OBJ-05)', () {
    test('addAll adds every item with referrer', () {
      final a = _TestObject(graph, '111111111111111111111111');
      final b = _TestObject(graph, '222222222222222222222222');
      list.addAll([a, b]);
      expect(list.length, equals(2));
      expect(a.referrers, contains(owner));
      expect(b.referrers, contains(owner));
    });
  });

  group('ObjectList.prepend (OBJ-05)', () {
    test('prepend inserts at index 0', () {
      final a = _TestObject(graph, '333333333333333333333333');
      final b = _TestObject(graph, '444444444444444444444444');
      list.add(a);
      list.prepend(b);
      expect(list[0], same(b));
    });
  });

  group('ObjectList.remove (OBJ-05)', () {
    test('remove returns true and decrements referrer', () {
      final obj = _TestObject(graph, '555555555555555555555555');
      list.add(obj);
      final result = list.remove(obj);
      expect(result, isTrue);
      expect(list.length, equals(0));
      expect(obj.referrers.contains(owner), isFalse);
    });

    test('remove returns false when not present', () {
      final obj = _TestObject(graph, '666666666666666666666666');
      expect(list.remove(obj), isFalse);
    });
  });

  group('ObjectList.removeAt (OBJ-05)', () {
    test('removeAt removes by index and returns the removed value', () {
      final a = _TestObject(graph, '777777777777777777777777');
      final b = _TestObject(graph, '888888888888888888888888');
      list.add(a);
      list.add(b);
      final removed = list.removeAt(0);
      expect(removed, same(a));
      expect(list.length, equals(1));
      expect(a.referrers.contains(owner), isFalse);
      expect(b.referrers, contains(owner));
    });
  });

  group('ObjectList.clear (OBJ-05)', () {
    test('clear decrements every item and empties list', () {
      final a = _TestObject(graph, '999999999999999999999999');
      final b = _TestObject(graph, 'AAAAAAAAAAAAAAAAAAAAAAAB');
      list.add(a);
      list.add(b);
      list.clear();
      expect(list.isEmpty, isTrue);
      expect(a.referrers.contains(owner), isFalse);
      expect(b.referrers.contains(owner), isFalse);
    });
  });

  group('ObjectList.move (OBJ-05): no ref-count change', () {
    test('move does NOT call addReferrer/removeReferrer', () {
      final obj = _TestObject(graph, 'BBBBBBBBBBBBBBBBBBBBBBBC');
      list.add(obj);
      // Object has exactly 1 referrer (owner) — if move accidentally
      // calls removeReferrer it would drop to 0 and be GC'd from objectsByUuid.
      expect(
        graph.objectsByUuid.containsKey('BBBBBBBBBBBBBBBBBBBBBBBC'),
        isTrue,
      );
      final referrersBefore = Set.of(obj.referrers);
      list.move(obj, 0); // no-op on single-element list
      list.add(_TestObject(graph, 'CCCCCCCCCCCCCCCCCCCCCCCD'));
      list.move(obj, 1);
      expect(
        obj.referrers,
        equals(referrersBefore),
        reason: 'move must not alter referrer set',
      );
      expect(
        graph.objectsByUuid.containsKey('BBBBBBBBBBBBBBBBBBBBBBBC'),
        isTrue,
        reason: 'object must NOT be GC\'d mid-move',
      );
    });

    test('move reorders the list correctly', () {
      final a = _TestObject(graph, 'DDDDDDDDDDDDDDDDDDDDDDDE');
      final b = _TestObject(graph, 'EEEEEEEEEEEEEEEEEEEEEEEF');
      final c = _TestObject(graph, 'FFFFFFFFFFFFFFFFFFFFFFFA');
      list.addAll([a, b, c]);
      list.move(a, 2); // move a from 0 to 2
      expect(list[0], same(b));
      expect(list[1], same(c));
      expect(list[2], same(a));
    });

    test('move marks owner dirty', () {
      final a = _TestObject(graph, '101010101010101010101010');
      final b = _TestObject(graph, '111111111111111111111110');
      list.addAll([a, b]);
      graph.isDirty = false;
      list.move(a, 1);
      expect(graph.isDirty, isTrue);
    });
  });

  group('ObjectList.sortBy (OBJ-05)', () {
    test('sorts in place and marks dirty', () {
      final a = _TestObject(graph, '202020202020202020202020');
      final b = _TestObject(graph, '121212121212121212121212');
      final c = _TestObject(graph, '303030303030303030303030');
      list.addAll([a, b, c]);
      graph.isDirty = false;
      list.sortBy((x, y) => x.uuid.compareTo(y.uuid));
      expect(list[0].uuid, equals('121212121212121212121212'));
      expect(list[1].uuid, equals('202020202020202020202020'));
      expect(list[2].uuid, equals('303030303030303030303030'));
      expect(graph.isDirty, isTrue);
    });
  });

  group('ObjectList.sortInPlace ( Plan 03 — TDD RED)', () {
    test('sortInPlace sorts items by comparator', () {
      final a = _TestObject(graph, '202020202020202020202020');
      final b = _TestObject(graph, '121212121212121212121212');
      final c = _TestObject(graph, '303030303030303030303030');
      list.addAll([a, b, c]);
      list.sortInPlace((x, y) => x.uuid.compareTo(y.uuid));
      expect(list[0].uuid, equals('121212121212121212121212'));
      expect(list[1].uuid, equals('202020202020202020202020'));
      expect(list[2].uuid, equals('303030303030303030303030'));
    });

    test('sortInPlace does not change list length', () {
      final a = _TestObject(graph, '111111111111111111111111');
      final b = _TestObject(graph, '222222222222222222222222');
      list.addAll([a, b]);
      list.sortInPlace((x, y) => x.uuid.compareTo(y.uuid));
      expect(list.length, equals(2));
    });

    test(
      'sortInPlace does NOT change referrer counts (no add/remove called)',
      () {
        final a = _TestObject(graph, '111111111111111111111111');
        final b = _TestObject(graph, '222222222222222222222222');
        list.addAll([a, b]);
        final aRefsBefore = a.referrers.length;
        final bRefsBefore = b.referrers.length;
        list.sortInPlace((x, y) => x.uuid.compareTo(y.uuid));
        expect(a.referrers.length, equals(aRefsBefore));
        expect(b.referrers.length, equals(bRefsBefore));
      },
    );

    test('sortInPlace calls markDirty', () {
      final a = _TestObject(graph, '222222222222222222222222');
      final b = _TestObject(graph, '111111111111111111111111');
      list.addAll([a, b]);
      graph.isDirty = false;
      list.sortInPlace((x, y) => x.uuid.compareTo(y.uuid));
      expect(graph.isDirty, isTrue);
    });
  });

  group('ObjectList.uuids (OBJ-05)', () {
    test('returns UUIDs of contained AbstractObjects in order', () {
      list.add(_TestObject(graph, '131313131313131313131313'));
      list.add(_TestObject(graph, '141414141414141414141414'));
      expect(
        list.uuids,
        equals(['131313131313131313131313', '141414141414141414141414']),
      );
    });
  });

  group('ObjectList iteration (OBJ-05)', () {
    test('for-in works', () {
      final a = _TestObject(graph, '151515151515151515151515');
      final b = _TestObject(graph, '161616161616161616161616');
      list.addAll([a, b]);
      final collected = <AbstractObject>[];
      for (final obj in list) {
        collected.add(obj);
      }
      expect(collected, equals([a, b]));
    });

    test('where/whereType work', () {
      list.add(_TestObject(graph, '171717171717171717171717'));
      list.add(_TestObject(graph, '181818181818181818181818'));
      expect(list.where((o) => o.uuid.startsWith('17')).length, equals(1));
      expect(list.whereType<_TestObject>().length, equals(2));
    });

    test('length and isEmpty are O(1)', () {
      expect(list.isEmpty, isTrue);
      expect(list.length, equals(0));
      list.add(_TestObject(graph, '191919191919191919191919'));
      expect(list.isEmpty, isFalse);
      expect(list.length, equals(1));
    });
  });

  group('ObjectList composition (OBJ-05 / )', () {
    test('NEGATIVE: ObjectList is NOT a List<T>', () {
      expect(
        list is List,
        isFalse,
        reason: ' mandates composition over List inheritance',
      );
    });

    test('ObjectList IS an Iterable<T>', () {
      expect(list, isA<Iterable<_TestObject>>());
    });
  });

  group(
    'ObjectList<ObjectDictionary> propagation (OBJ-05+OBJ-06 integration)',
    () {
      test('adding ObjectDictionary propagates addReferrer to its values', () {
        final valueA = _TestObject(graph, '212121212121212121212121');
        final valueB = _TestObject(graph, '222222222222222222222222');
        final dict = ObjectDictionary({
          'a': _TestObject,
          'b': _TestObject,
        }, owner);
        dict['a'] = valueA;
        dict['b'] = valueB;
        // Pre-condition: valueA/B have owner as referrer (from dict []=).
        expect(valueA.referrers, contains(owner));
        // Add dict to a different list (with a different owner) — propagation
        // should add THAT new owner as a referrer on each value.
        final otherOwner = _Owner(graph, '232323232323232323232323');
        final otherList = ObjectList<ObjectDictionary>(otherOwner);
        otherList.add(dict);
        expect(valueA.referrers, contains(otherOwner));
        expect(valueB.referrers, contains(otherOwner));
      });

      test(
        'removing ObjectDictionary propagates removeReferrer to its values',
        () {
          final valueA = _TestObject(graph, '242424242424242424242424');
          final dict = ObjectDictionary({'a': _TestObject}, owner);
          dict['a'] = valueA;
          final otherOwner = _Owner(graph, '252525252525252525252525');
          final otherList = ObjectList<ObjectDictionary>(otherOwner);
          otherList.add(dict);
          otherList.remove(dict);
          expect(valueA.referrers.contains(otherOwner), isFalse);
        },
      );
    },
  );
}
