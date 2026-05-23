import 'package:dart_xcodeproj/src/differ/differ.dart';
import 'package:test/test.dart';

void main() {
  group('Differ', () {
    group('diff()', () {
      group('scalar values', () {
        test('returns null when values are equal', () {
          expect(Differ.diff(1, 1), isNull);
          expect(Differ.diff('a', 'a'), isNull);
          expect(Differ.diff(null, null), isNull);
        });

        test('returns {key1: v1, key2: v2} when values differ', () {
          expect(
            Differ.diff('a', 'b'),
            equals(<String, dynamic>{'value_1': 'a', 'value_2': 'b'}),
          );
        });

        test('respects custom key1 and key2 names', () {
          expect(
            Differ.diff('a', 'b', key1: 'left', key2: 'right'),
            equals(<String, dynamic>{'left': 'a', 'right': 'b'}),
          );
        });
      });

      group('Map values', () {
        test('returns null for identical maps', () {
          expect(
            Differ.diff(
              <String, dynamic>{'a': 1, 'b': 2},
              <String, dynamic>{'a': 1, 'b': 2},
            ),
            isNull,
          );
        });

        test('returns only differing keys', () {
          expect(
            Differ.diff(<String, dynamic>{'a': 1}, <String, dynamic>{'a': 2}),
            equals(<String, dynamic>{
              'a': {'value_1': 1, 'value_2': 2},
            }),
          );
        });

        test(
          'filters unchanged top-level keys, returns only changed nested keys',
          () {
            final result = Differ.diff(
              <String, dynamic>{'a': 1, 'b': 2},
              <String, dynamic>{'a': 1, 'b': 99},
            );
            expect(result, isNotNull);
            expect(result!.containsKey('a'), isFalse);
            expect(result.containsKey('b'), isTrue);
          },
        );

        test('reports added key', () {
          final result = Differ.diff(
            <String, dynamic>{'a': 1},
            <String, dynamic>{'a': 1, 'b': 2},
          );
          expect(result, isNotNull);
          expect(result!['b'], equals({'value_1': null, 'value_2': 2}));
        });
      });

      group('List values (DIFF-03 — array ordering)', () {
        test('returns null for same elements in different order', () {
          expect(Differ.diff([1, 2, 3], [3, 2, 1]), isNull);
        });

        test('handles duplicate elements correctly — extra in v1', () {
          // [1,1,2] vs [1,2]: v1 has one extra 1
          expect(
            Differ.diff([1, 1, 2], [1, 2]),
            equals(<String, dynamic>{
              'value_1': [1],
            }),
          );
        });

        test('handles duplicate elements correctly — extra in v2', () {
          // [1,2] vs [1,1,2]: v2 has one extra 1
          expect(
            Differ.diff([1, 2], [1, 1, 2]),
            equals(<String, dynamic>{
              'value_2': [1],
            }),
          );
        });

        test('idKey matching: diffs matched elements by id (DIFF-03)', () {
          // Both sides have displayName='A'; x differs.
          // only1 and only2 are both empty after matching → returns matched_diff directly.
          final result = Differ.diff(
            [
              <String, dynamic>{'displayName': 'A', 'x': 1},
            ],
            [
              <String, dynamic>{'displayName': 'A', 'x': 2},
            ],
            idKey: 'displayName',
          );
          expect(result, isNotNull);
          expect(result!['A'], isNotNull);
          expect(result['A']['x'], equals({'value_1': 1, 'value_2': 2}));
        });

        test('idKey matching: matched elements reported under idKey value', () {
          final result = Differ.diff(
            [
              <String, dynamic>{
                'displayName': 'Target',
                'isa': 'PBXNativeTarget',
                'v': 1,
              },
            ],
            [
              <String, dynamic>{
                'displayName': 'Target',
                'isa': 'PBXNativeTarget',
                'v': 2,
              },
            ],
            idKey: 'displayName',
          );
          expect(result, isNotNull);
          expect(result!.containsKey('Target'), isTrue);
        });
      });

      group('keysToIgnore (DIFF-02)', () {
        test('removes key before diff — equal after removal returns null', () {
          expect(
            Differ.diff(
              <String, dynamic>{'a': 1, 'b': 2},
              <String, dynamic>{'a': 99, 'b': 2},
              keysToIgnore: ['a'],
            ),
            isNull,
          );
        });

        test('removes key recursively from nested maps', () {
          expect(
            Differ.diff(
              <String, dynamic>{
                'outer': <String, dynamic>{'a': 1},
              },
              <String, dynamic>{
                'outer': <String, dynamic>{'a': 2},
              },
              keysToIgnore: ['a'],
            ),
            isNull,
          );
        });

        test('removes key from maps inside lists', () {
          expect(
            Differ.diff(
              <String, dynamic>{
                'xs': [
                  <String, dynamic>{'a': 1, 'b': 2},
                ],
              },
              <String, dynamic>{
                'xs': [
                  <String, dynamic>{'a': 9, 'b': 2},
                ],
              },
              keysToIgnore: ['a'],
            ),
            isNull,
          );
        });

        test('multiple keys to ignore', () {
          expect(
            Differ.diff(
              <String, dynamic>{'a': 1, 'b': 2, 'c': 3},
              <String, dynamic>{'a': 9, 'b': 8, 'c': 3},
              keysToIgnore: ['a', 'b'],
            ),
            isNull,
          );
        });
      });
    });

    group('projectDiff() (DIFF-01)', () {
      test('returns null for identical map content', () {
        expect(
          Differ.projectDiff(
            <String, dynamic>{'foo': 'bar'},
            <String, dynamic>{'foo': 'bar'},
          ),
          isNull,
        );
      });

      test('returns null when targets have same displayName and content', () {
        expect(
          Differ.projectDiff(
            <String, dynamic>{
              'targets': [
                <String, dynamic>{'displayName': 'A', 'isa': 'PBXNativeTarget'},
              ],
            },
            <String, dynamic>{
              'targets': [
                <String, dynamic>{'displayName': 'A', 'isa': 'PBXNativeTarget'},
              ],
            },
          ),
          isNull,
        );
      });

      test('reports diff when second map has different target displayName', () {
        final result = Differ.projectDiff(
          <String, dynamic>{
            'targets': [
              <String, dynamic>{'displayName': 'A', 'isa': 'PBXNativeTarget'},
            ],
          },
          <String, dynamic>{
            'targets': [
              <String, dynamic>{'displayName': 'B', 'isa': 'PBXNativeTarget'},
            ],
          },
        );
        expect(result, isNotNull);
        expect(result!.containsKey('targets'), isTrue);
      });
    });
  });
}
