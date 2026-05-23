import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/object_dictionary.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

class _TypeA extends AbstractObject {
  _TypeA(super.project, super.uuid);
  @override
  String get isa => 'TypeA';
}

class _TypeB extends AbstractObject {
  _TypeB(super.project, super.uuid);
  @override
  String get isa => 'TypeB';
}

class _Owner extends AbstractObject {
  _Owner(super.project, super.uuid);
  @override
  String get isa => 'Owner';
}

void main() {
  late MockObjectGraph graph;
  late _Owner owner;
  late ObjectDictionary dict;

  setUp(() {
    graph = MockObjectGraph();
    owner = _Owner(graph, 'OWNEROWNEROWNEROWNEROWNE');
    dict = ObjectDictionary({'a': _TypeA, 'b': _TypeB}, owner);
  });

  group('ObjectDictionary[]= (OBJ-06)', () {
    test('sets value and adds referrer', () {
      final v = _TypeA(graph, 'AAAAAAAAAAAAAAAAAAAAAAAA');
      dict['a'] = v;
      expect(dict['a'], same(v));
      expect(v.referrers, contains(owner));
      expect(graph.isDirty, isTrue);
    });

    test('replacing value drops old referrer and adds new', () {
      final v1 = _TypeA(graph, '111111111111111111111111');
      final v2 = _TypeA(graph, '222222222222222222222222');
      dict['a'] = v1;
      dict['a'] = v2;
      expect(v1.referrers.contains(owner), isFalse);
      expect(v2.referrers.contains(owner), isTrue);
      expect(dict['a'], same(v2));
    });

    test('setting null removes referrer from previous value', () {
      final v = _TypeA(graph, '333333333333333333333333');
      dict['a'] = v;
      dict['a'] = null;
      expect(v.referrers.contains(owner), isFalse);
      expect(dict['a'], isNull);
    });

    test('NEGATIVE: disallowed key throws ArgumentError', () {
      final v = _TypeA(graph, '444444444444444444444444');
      expect(() => dict['nope'] = v, throwsArgumentError);
    });

    test(
      'RELAXED ( Plan 04 ): type-mismatched value is soft-accepted with a debug log, not thrown',
      () {
        // Ruby does not enforce strict type at the
        // ObjectDictionary level. The strict runtimeType check was replaced with
        // a developer.log warning + soft accept. This allows subclasses (e.g.,
        // PBXVariantGroup stored under a PBXGroup-typed slot) to be accepted.
        final v = _TypeB(graph, '555555555555555555555555');
        // Must NOT throw — soft accept
        expect(() => dict['a'] = v, returnsNormally);
        // The value is stored regardless
        expect(dict['a'], same(v));
      },
    );
  });

  group('ObjectDictionary.delete (OBJ-06)', () {
    test('removes value and drops referrer', () {
      final v = _TypeA(graph, '666666666666666666666666');
      dict['a'] = v;
      dict.delete('a');
      expect(dict['a'], isNull);
      expect(v.referrers.contains(owner), isFalse);
    });

    test('NEGATIVE: disallowed key throws ArgumentError', () {
      expect(() => dict.delete('nope'), throwsArgumentError);
    });

    test('delete on unset key is a safe no-op', () {
      expect(() => dict.delete('a'), returnsNormally);
    });
  });

  group('ObjectDictionary.clear (OBJ-06)', () {
    test('clears all values and drops every referrer', () {
      final va = _TypeA(graph, '777777777777777777777777');
      final vb = _TypeB(graph, '888888888888888888888888');
      dict['a'] = va;
      dict['b'] = vb;
      dict.clear();
      expect(dict.isEmpty, isTrue);
      expect(va.referrers.contains(owner), isFalse);
      expect(vb.referrers.contains(owner), isFalse);
    });
  });

  group('ObjectDictionary.addReferrer/removeReferrer propagation (OBJ-06)', () {
    test('addReferrer propagates to all non-null values', () {
      final va = _TypeA(graph, '999999999999999999999999');
      final vb = _TypeB(graph, 'AAAAAAAAAAAAAAAAAAAAAAAB');
      dict['a'] = va;
      dict['b'] = vb;
      final externalReferrer = Object();
      dict.addReferrer(externalReferrer);
      expect(va.referrers, contains(externalReferrer));
      expect(vb.referrers, contains(externalReferrer));
    });

    test('removeReferrer propagates to all non-null values', () {
      final va = _TypeA(graph, 'BBBBBBBBBBBBBBBBBBBBBBBC');
      final vb = _TypeB(graph, 'CCCCCCCCCCCCCCCCCCCCCCCD');
      dict['a'] = va;
      dict['b'] = vb;
      final externalReferrer = Object();
      dict.addReferrer(externalReferrer);
      dict.removeReferrer(externalReferrer);
      expect(va.referrers.contains(externalReferrer), isFalse);
      expect(vb.referrers.contains(externalReferrer), isFalse);
    });
  });

  group('ObjectDictionary.removeReference (OBJ-06)', () {
    test('nulls every key whose value matches the obj', () {
      final shared = _TypeA(graph, 'DDDDDDDDDDDDDDDDDDDDDDDD');
      // Use a wide dict where both keys allow _TypeA so we can shove `shared` in both.
      final wideDict = ObjectDictionary({'x': _TypeA, 'y': _TypeA}, owner);
      wideDict['x'] = shared;
      wideDict['y'] = shared;
      wideDict.removeReference(shared);
      expect(wideDict['x'], isNull);
      expect(wideDict['y'], isNull);
    });

    test('NEGATIVE: removeReference does NOT call removeReferrer on values', () {
      final v = _TypeA(graph, 'EEEEEEEEEEEEEEEEEEEEEEEE');
      dict['a'] = v;
      // v.referrers contains owner at this point.
      expect(v.referrers, contains(owner));
      dict.removeReference(v);
      // Per Ruby semantics: removeReference is called BY the value during its
      // own removeFromProject — the value's referrer set already reflects that.
      // We assert the referrer set is unchanged by removeReference itself.
      expect(
        v.referrers,
        contains(owner),
        reason: 'removeReference must NOT call removeReferrer on the value',
      );
    });
  });

  group('ObjectDictionary serialization toHash (OBJ-06)', () {
    test('returns {key: uuid} for each non-null entry', () {
      final va = _TypeA(graph, 'FFFFFFFFFFFFFFFFFFFFFFFF');
      final vb = _TypeB(graph, '101010101010101010101010');
      dict['a'] = va;
      dict['b'] = vb;
      expect(
        dict.toHash(),
        equals({
          'a': 'FFFFFFFFFFFFFFFFFFFFFFFF',
          'b': '101010101010101010101010',
        }),
      );
    });

    test('omits null entries', () {
      final va = _TypeA(graph, '121212121212121212121212');
      dict['a'] = va;
      dict['b'] = null;
      expect(dict.toHash(), equals({'a': '121212121212121212121212'}));
      expect(dict.toHash().containsKey('b'), isFalse);
    });

    test('preserves insertion order (stability per )', () {
      final wide = ObjectDictionary({
        'c': _TypeA,
        'a': _TypeA,
        'b': _TypeA,
      }, owner);
      wide['c'] = _TypeA(graph, '131313131313131313131313');
      wide['a'] = _TypeA(graph, '141414141414141414141414');
      wide['b'] = _TypeA(graph, '151515151515151515151515');
      expect(wide.toHash().keys.toList(), equals(['c', 'a', 'b']));
    });
  });

  group('ObjectDictionary allowedKeys (OBJ-06)', () {
    test('returns the classesByKey keys', () {
      expect(dict.allowedKeys, equals(['a', 'b']));
    });
  });

  group('ObjectDictionary isEmpty/length (OBJ-06)', () {
    test('empty dict: isEmpty true, length 0', () {
      expect(dict.isEmpty, isTrue);
      expect(dict.length, equals(0));
    });

    test('after set: isEmpty false, length 1', () {
      dict['a'] = _TypeA(graph, '161616161616161616161616');
      expect(dict.isEmpty, isFalse);
      expect(dict.length, equals(1));
    });

    test('after set then null: isEmpty true, length 0', () {
      dict['a'] = _TypeA(graph, '171717171717171717171717');
      dict['a'] = null;
      expect(dict.length, equals(0));
      expect(dict.isEmpty, isTrue);
    });
  });
}
