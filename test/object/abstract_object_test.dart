import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/object_graph.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

/// Bare-bones concrete subclass used only for testing AbstractObject lifecycle.
class _TestObject extends AbstractObject {
  static const String isaConst = 'PBXTest';
  final List<AbstractObject> removeReferenceCalls = [];

  _TestObject(super.project, super.uuid, {this.isaOverride});
  final String? isaOverride;

  @override
  String get isa => isaOverride ?? isaConst;

  @override
  void removeReference(AbstractObject obj) {
    removeReferenceCalls.add(obj);
    // A real subclass nulls out the field and calls obj.removeReferrer(this).
    // We simulate that here to satisfy the assert in removeFromProject.
    obj.removeReferrer(this);
  }
}

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
  });

  group('ObjectGraph.newObject (OBJ-01)', () {
    test('assigns a 24-char hex UUID', () {
      final obj = graph.newObject<_TestObject>(
        (g, uuid) => _TestObject(g, uuid),
      );
      expect(obj.uuid.length, equals(24));
      expect(RegExp(r'^[0-9A-F]{24}$').hasMatch(obj.uuid), isTrue);
    });

    test('does NOT register in objectsByUuid', () {
      final obj = graph.newObject<_TestObject>(
        (g, uuid) => _TestObject(g, uuid),
      );
      expect(graph.objectsByUuid.containsKey(obj.uuid), isFalse);
      expect(graph.isDirty, isFalse);
    });

    test('sets project field on the new object', () {
      final obj = graph.newObject<_TestObject>(
        (g, uuid) => _TestObject(g, uuid),
      );
      expect(identical(obj.project, graph), isTrue);
    });
  });

  group('AbstractObject.addReferrer (OBJ-01)', () {
    test('addReferrer registers object in objectsByUuid', () {
      final obj = _TestObject(graph, 'AAAAAAAAAAAAAAAAAAAAAAAA');
      obj.addReferrer('owner1');
      expect(graph.objectsByUuid['AAAAAAAAAAAAAAAAAAAAAAAA'], same(obj));
    });

    test('addReferrer idempotent (Set semantics, )', () {
      final obj = _TestObject(graph, 'BBBBBBBBBBBBBBBBBBBBBBBB');
      obj.addReferrer('owner1');
      obj.addReferrer('owner1');
      obj.addReferrer('owner1');
      expect(obj.referrers.length, equals(1));
      expect(graph.objectsByUuid['BBBBBBBBBBBBBBBBBBBBBBBB'], same(obj));
    });

    test('addReferrer accumulates distinct referrers', () {
      final obj = _TestObject(graph, 'CCCCCCCCCCCCCCCCCCCCCCCC');
      obj.addReferrer('owner1');
      obj.addReferrer('owner2');
      obj.addReferrer('owner3');
      expect(obj.referrers.length, equals(3));
    });
  });

  group('AbstractObject.removeReferrer (OBJ-01)', () {
    test('removeReferrer GCs object when last referrer dropped', () {
      final obj = _TestObject(graph, 'DDDDDDDDDDDDDDDDDDDDDDDD');
      obj.addReferrer('owner1');
      expect(
        graph.objectsByUuid.containsKey('DDDDDDDDDDDDDDDDDDDDDDDD'),
        isTrue,
      );
      obj.removeReferrer('owner1');
      expect(
        graph.objectsByUuid.containsKey('DDDDDDDDDDDDDDDDDDDDDDDD'),
        isFalse,
      );
      expect(graph.isDirty, isTrue);
    });

    test(
      'NEGATIVE: removeReferrer must NOT GC when other referrers remain',
      () {
        final obj = _TestObject(graph, 'EEEEEEEEEEEEEEEEEEEEEEEE');
        obj.addReferrer('owner1');
        obj.addReferrer('owner2');
        graph.isDirty =
            false; // reset to verify no markDirty on partial removal
        obj.removeReferrer('owner1');
        expect(graph.objectsByUuid['EEEEEEEEEEEEEEEEEEEEEEEE'], same(obj));
        expect(obj.referrers.length, equals(1));
        expect(
          graph.isDirty,
          isFalse,
          reason: 'markDirty should fire only on last-referrer transition',
        );
      },
    );

    test('removeReferrer of non-existent referrer is safe', () {
      final obj = _TestObject(graph, 'FFFFFFFFFFFFFFFFFFFFFFFF');
      expect(() => obj.removeReferrer('stranger'), returnsNormally);
    });

    test('re-add after GC restores registration', () {
      final obj = _TestObject(graph, '111111111111111111111111');
      obj.addReferrer('owner1');
      obj.removeReferrer('owner1');
      expect(
        graph.objectsByUuid.containsKey('111111111111111111111111'),
        isFalse,
      );
      obj.addReferrer('owner1');
      expect(graph.objectsByUuid['111111111111111111111111'], same(obj));
    });
  });

  group('AbstractObject.removeFromProject (OBJ-01)', () {
    test('removes from objectsByUuid and asks referrers to drop reference', () {
      final target = _TestObject(graph, '222222222222222222222222');
      final referrer = _TestObject(graph, '333333333333333333333333');
      target.addReferrer(referrer);
      // The referrer is an AbstractObject — removeFromProject should call
      // referrer.removeReference(target), which our _TestObject records.
      target.removeFromProject();
      expect(
        graph.objectsByUuid.containsKey('222222222222222222222222'),
        isFalse,
      );
      expect(referrer.removeReferenceCalls, contains(target));
      expect(graph.isDirty, isTrue);
    });
  });

  group('AbstractObject.displayName (OBJ-01)', () {
    test('strips PBX prefix from isa', () {
      final obj = _TestObject(
        graph,
        '444444444444444444444444',
        isaOverride: 'PBXBuildFile',
      );
      expect(obj.displayName, equals('BuildFile'));
    });

    test('strips XC prefix from isa', () {
      final obj = _TestObject(
        graph,
        '555555555555555555555555',
        isaOverride: 'XCBuildConfiguration',
      );
      expect(obj.displayName, equals('BuildConfiguration'));
    });

    test('returns isa unchanged when no PBX/XC prefix', () {
      final obj = _TestObject(
        graph,
        '666666666666666666666666',
        isaOverride: 'RandomThing',
      );
      expect(obj.displayName, equals('RandomThing'));
    });
  });

  group('AbstractObject.asciiPlistAnnotation (OBJ-01)', () {
    test('returns space-bracketed displayName', () {
      final obj = _TestObject(
        graph,
        '777777777777777777777777',
        isaOverride: 'PBXFoo',
      );
      expect(obj.asciiPlistAnnotation, equals(' Foo '));
    });
  });

  group('AbstractObject.attributeOrder (OBJ-01 base)', () {
    test('base implementation returns empty list', () {
      final obj = _TestObject(graph, '888888888888888888888888');
      expect(obj.attributeOrder, isEmpty);
    });
  });

  group('MockObjectGraph (test infrastructure)', () {
    test('implements ObjectGraph', () {
      expect(graph, isA<ObjectGraph>());
    });

    test('reset() clears state', () {
      graph.objectsByUuid['xxx'] = _TestObject(graph, 'xxx');
      graph.isDirty = true;
      graph.reset();
      expect(graph.objectsByUuid, isEmpty);
      expect(graph.isDirty, isFalse);
    });
  });
}
