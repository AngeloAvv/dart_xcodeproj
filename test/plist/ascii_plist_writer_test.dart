// Tests for AsciiPlistWriter — TDD RED phase
// Port of writer behavior tests

import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/annotated_nodes.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_writer.dart';

void main() {
  group('AsciiPlistWriter', () {
    // -------------------------------------------------------------------------
    // Test 1: UTF8 magic header
    // -------------------------------------------------------------------------
    test(
      'Test 1: write({}) starts with exactly // !\$*UTF8*\$!\\n (first 14 bytes)',
      () {
        final out = AsciiPlistWriter().write({});
        expect(out.substring(0, 14), equals('// !\$*UTF8*\$!\n'));
      },
    );

    // -------------------------------------------------------------------------
    // Test 2: Tab-indented key = value
    // -------------------------------------------------------------------------
    test('Test 2: write({a: b}) contains tab-indented key = value', () {
      final out = AsciiPlistWriter().write({'a': 'b'});
      expect(out, contains('\ta = b;\n'));
    });

    // -------------------------------------------------------------------------
    // Test 3: Values with spaces are quoted
    // -------------------------------------------------------------------------
    test('Test 3: write({k: "value with space"}) quotes value', () {
      final out = AsciiPlistWriter().write({'k': 'value with space'});
      expect(out, contains('k = "value with space";'));
    });

    // -------------------------------------------------------------------------
    // Test 4: Empty string is quoted
    // -------------------------------------------------------------------------
    test('Test 4: write({k: ""}) emits empty quoted string', () {
      final out = AsciiPlistWriter().write({'k': ''});
      expect(out, contains('k = "";'));
    });

    // -------------------------------------------------------------------------
    // Test 5: Strings starting with ___ are quoted
    // -------------------------------------------------------------------------
    test('Test 5: write({k: "___foo"}) quotes string starting with ___', () {
      final out = AsciiPlistWriter().write({'k': '___foo'});
      expect(out, contains('k = "___foo";'));
    });

    // -------------------------------------------------------------------------
    // Test 6: Arrays with trailing commas and tab indentation
    // -------------------------------------------------------------------------
    test('Test 6: write({arr: [a, b]}) produces correct array format', () {
      final out = AsciiPlistWriter().write({
        'arr': ['a', 'b'],
      });
      expect(out, contains('arr = (\n\t\ta,\n\t\tb,\n\t);'));
    });

    // -------------------------------------------------------------------------
    // Test 7: Data blobs written as hex between < >
    // Ruby inserts a space every 4 hex chars (2 bytes) — so 4 bytes = 8 hex chars
    // with a space at position 4: "dead beef"
    // -------------------------------------------------------------------------
    test(
      'Test 7: write({data: [0xde, 0xad, 0xbe, 0xef]}) contains <dead beef>',
      () {
        final out = AsciiPlistWriter().write({
          'data': [0xde, 0xad, 0xbe, 0xef],
        });
        // Ruby: chars each_with_index: space at i>0 && i%4==0
        // 8 hex chars: d,e,a,d,b,e,e,f → space at index 4 → "dead beef"
        expect(out, contains('data = <dead beef>;'));
      },
    );

    // -------------------------------------------------------------------------
    // Test 8: Within an object dict, isa key emits FIRST
    // -------------------------------------------------------------------------
    test('Test 8: isa key sorts first in object dict', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {'path': 'p', 'isa': 'PBXFileReference'},
        },
      });
      // isa must appear before path in the single-line flat output
      final isaIdx = out.indexOf('isa = PBXFileReference');
      final pathIdx = out.indexOf('path = p');
      expect(
        isaIdx,
        lessThan(pathIdx),
        reason: 'isa key must appear before path in object dict',
      );
    });

    // -------------------------------------------------------------------------
    // Test 9: PBXBuildFile is flat (single-line)
    // -------------------------------------------------------------------------
    test('Test 9: PBXBuildFile uses flat single-line format', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {
            'isa': 'PBXBuildFile',
            'fileRef': 'BBBBBBBBBBBBBBBBBBBBBBBB',
          },
        },
      });
      // The entry must be on a single line — no newline inside { ... }
      final entryStart = out.indexOf('AAAAAAAAAAAAAAAAAAAAAAAA');
      final entryEnd = out.indexOf(';', entryStart);
      final entryText = out.substring(entryStart, entryEnd + 1);
      expect(
        entryText,
        isNot(contains('\n')),
        reason: 'PBXBuildFile entry must be flat (no internal newlines)',
      );
      expect(
        entryText,
        contains('{isa = PBXBuildFile;'),
        reason: 'PBXBuildFile must have isa first in flat format',
      );
    });

    // -------------------------------------------------------------------------
    // Test 10: PBXFileReference is flat (single-line)
    // -------------------------------------------------------------------------
    test('Test 10: PBXFileReference uses flat single-line format', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'CCCCCCCCCCCCCCCCCCCCCCCC': {
            'isa': 'PBXFileReference',
            'path': 'main.m',
          },
        },
      });
      final entryStart = out.indexOf('CCCCCCCCCCCCCCCCCCCCCCCC');
      final entryEnd = out.indexOf(';', entryStart);
      final entryText = out.substring(entryStart, entryEnd + 1);
      expect(
        entryText,
        isNot(contains('\n')),
        reason: 'PBXFileReference entry must be flat (no internal newlines)',
      );
    });

    // -------------------------------------------------------------------------
    // Test 11: PBXGroup is pretty (multi-line)
    // -------------------------------------------------------------------------
    test('Test 11: PBXGroup uses pretty multi-line format', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'DDDDDDDDDDDDDDDDDDDDDDDD': {'isa': 'PBXGroup'},
        },
      });
      expect(
        out,
        contains('\n\t\t\tisa = PBXGroup;\n'),
        reason: 'PBXGroup must use tab-indented multi-line format',
      );
    });

    // -------------------------------------------------------------------------
    // Test 12: ISA section comments emitted in alphabetical order
    // -------------------------------------------------------------------------
    test('Test 12: ISA section comments emitted alphabetically', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {'isa': 'PBXBuildFile'},
          'GGGGGGGGGGGGGGGGGGGGGGGG': {'isa': 'PBXGroup'},
        },
      });
      expect(out, contains('/* Begin PBXBuildFile section */'));
      expect(out, contains('/* End PBXBuildFile section */'));
      expect(out, contains('/* Begin PBXGroup section */'));
      expect(out, contains('/* End PBXGroup section */'));
      // PBXBuildFile must appear before PBXGroup (alphabetical)
      final buildFileIdx = out.indexOf('/* Begin PBXBuildFile section */');
      final groupIdx = out.indexOf('/* Begin PBXGroup section */');
      expect(
        buildFileIdx,
        lessThan(groupIdx),
        reason: 'PBXBuildFile section must come before PBXGroup section',
      );
    });

    // -------------------------------------------------------------------------
    // Test 13: Within ISA section, UUIDs sorted lexicographically
    // -------------------------------------------------------------------------
    test('Test 13: UUIDs within ISA section are sorted lexicographically', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'BBBBBBBBBBBBBBBBBBBBBBBB': {'isa': 'PBXBuildFile'},
          'AAAAAAAAAAAAAAAAAAAAAAAA': {'isa': 'PBXBuildFile'},
        },
      });
      final aaaIdx = out.indexOf('AAAAAAAAAAAAAAAAAAAAAAAA');
      final bbbIdx = out.indexOf('BBBBBBBBBBBBBBBBBBBBBBBB');
      expect(
        aaaIdx,
        lessThan(bbbIdx),
        reason: 'AAAA... UUID must appear before BBBB... UUID',
      );
    });

    // -------------------------------------------------------------------------
    // Test 14: Indentation uses tab characters
    // -------------------------------------------------------------------------
    test('Test 14: output uses tab indentation, not spaces', () {
      final out = AsciiPlistWriter().write({'archiveVersion': '1'});
      final lines = out.split('\n');
      final tabIndented = lines.where((l) => l.startsWith('\t')).length;
      expect(
        tabIndented,
        greaterThan(0),
        reason: 'At least one tab-indented line required',
      );
      final spaceIndented = lines.where((l) => l.startsWith(' ')).length;
      expect(
        spaceIndented,
        equals(0),
        reason: 'No 4-space indented lines allowed',
      );
    });

    // -------------------------------------------------------------------------
    // Test 15: only AnnotatedString values carry an annotation
    // -------------------------------------------------------------------------
    test('Test 15: AnnotatedString value is written with its annotation', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {
            'isa': 'PBXBuildFile',
            'fileRef': const AnnotatedString(
              'BBBBBBBBBBBBBBBBBBBBBBBB',
              ' main.m ',
            ),
          },
        },
      });
      expect(out, contains('fileRef = BBBBBBBBBBBBBBBBBBBBBBBB /* main.m */;'));
    });

    test('Test 15b: plain UUID strings are never annotated (no sniffing)', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {
            'isa': 'PBXBuildFile',
            'fileRef': 'BBBBBBBBBBBBBBBBBBBBBBBB',
          },
          'BBBBBBBBBBBBBBBBBBBBBBBB': {
            'isa': 'PBXFileReference',
            'name': 'main.m',
          },
        },
      });
      expect(out, contains('fileRef = BBBBBBBBBBBBBBBBBBBBBBBB;'));
      // Neither the key nor the value is annotated, even though the
      // referenced object has a name.
      expect(out, isNot(contains('BBBBBBBBBBBBBBBBBBBBBBBB /*')));
      expect(out, isNot(contains('AAAAAAAAAAAAAAAAAAAAAAAA /*')));
    });

    test('Test 15c: null or empty annotation writes no comment', () {
      final out = AsciiPlistWriter().write({
        'a': const AnnotatedString('x'),
        'b': const AnnotatedString('y', ''),
        'c': const AnnotatedString('z', null),
      });
      expect(out, contains('a = x;'));
      expect(out, contains('b = y;'));
      expect(out, contains('c = z;'));
    });

    test('Test 15d: annotated value is quoted when needed', () {
      final out = AsciiPlistWriter().write({
        'k': const AnnotatedString('has space', ' note '),
      });
      expect(out, contains('k = "has space" /* note */;'));
    });

    // -------------------------------------------------------------------------
    // Test 16: rootObject carries the annotation it is given
    // -------------------------------------------------------------------------
    test('Test 16: rootObject annotation is the one the node carries', () {
      const root = 'XXXXXXXXXXXXXXXXXXXXXXXX';
      final annotated = AsciiPlistWriter().write({
        'rootObject': const AnnotatedString(root, ' Project object '),
        'objects': {
          root: {'isa': 'PBXProject'},
        },
      });
      expect(annotated, contains('rootObject = $root /* Project object */;'));

      final plain = AsciiPlistWriter().write({
        'rootObject': root,
        'objects': {
          root: {'isa': 'PBXProject'},
        },
      });
      expect(plain, contains('rootObject = $root;'));
    });

    // -------------------------------------------------------------------------
    // Test 17: object header annotation comes from AnnotatedDictionary only
    // -------------------------------------------------------------------------
    test('Test 17: object header annotation comes from the entry itself', () {
      const uuid = 'GGGGGGGGGGGGGGGGGGGGGGGG';
      final annotated = AsciiPlistWriter().write({
        'objects': {
          uuid: const AnnotatedDictionary({
            'isa': 'PBXGroup',
            'name': 'Sources',
          }, ' Sources '),
        },
      });
      expect(annotated, contains('$uuid /* Sources */ = {'));
      // The annotation moves to the key; the dictionary itself has none.
      expect(annotated, isNot(contains('} /*')));

      // A plain map is never annotated, whatever its name or path.
      final plain = AsciiPlistWriter().write({
        'objects': {
          uuid: {'isa': 'PBXGroup', 'name': 'Sources', 'path': 'Sources'},
        },
      });
      expect(plain, contains('$uuid = {'));
      expect(plain, isNot(contains('$uuid /* ')));
    });

    // -------------------------------------------------------------------------
    // Test 18: annotated elements inside arrays
    // -------------------------------------------------------------------------
    test('Test 18: annotated array elements are written, plain ones not', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'GGGGGGGGGGGGGGGGGGGGGGGG': {
            'isa': 'PBXGroup',
            'children': [
              const AnnotatedString(
                'CCCCCCCCCCCCCCCCCCCCCCCC',
                ' AppDelegate.m ',
              ),
              'DDDDDDDDDDDDDDDDDDDDDDDD',
            ],
          },
        },
      });
      expect(out, contains('CCCCCCCCCCCCCCCCCCCCCCCC /* AppDelegate.m */,'));
      expect(out, contains('DDDDDDDDDDDDDDDDDDDDDDDD,'));
    });

    // -------------------------------------------------------------------------
    // Test 19: a string that merely contains a UUID is never annotated
    // -------------------------------------------------------------------------
    test('Test 19: plain strings holding a UUID get no annotation', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {
            'isa': 'PBXContainerItemProxy',
            'remoteGlobalIDString': 'AAAAAAAAAAAAAAAAAAAAAAAA',
          },
        },
      });
      expect(out, contains('remoteGlobalIDString = AAAAAAAAAAAAAAAAAAAAAAAA;'));
    });
  });
}
