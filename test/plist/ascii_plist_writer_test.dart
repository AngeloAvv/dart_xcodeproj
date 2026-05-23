// Tests for AsciiPlistWriter — TDD RED phase
// Port of writer behavior tests

import 'package:test/test.dart';
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
    // Test 15: UUID-valued attributes get annotation from referenced object
    // -------------------------------------------------------------------------
    test(
      'Test 15: fileRef UUID gets annotation from referenced object name',
      () {
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
        expect(
          out,
          contains('fileRef = BBBBBBBBBBBBBBBBBBBBBBBB /* main.m */;'),
        );
      },
    );

    // -------------------------------------------------------------------------
    // Test 16: rootObject annotation is exactly "Project object"
    // -------------------------------------------------------------------------
    test('Test 16: rootObject value gets "Project object" annotation', () {
      final out = AsciiPlistWriter().write({
        'rootObject': 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'.substring(0, 24),
        'objects': {
          'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'.substring(0, 24): {
            'isa': 'PBXProject',
          },
        },
      });
      expect(
        out,
        contains('rootObject = XXXXXXXXXXXXXXXXXXXXXXXX /* Project object */;'),
      );
    });

    // -------------------------------------------------------------------------
    // Test 17: Object header annotation from name, then path; NO fallback to isa
    // -------------------------------------------------------------------------
    test(
      'Test 17: object header annotation uses name, then path; no isa fallback',
      () {
        // With name
        final out1 = AsciiPlistWriter().write({
          'objects': {
            'GGGGGGGGGGGGGGGGGGGGGGGG': {'isa': 'PBXGroup', 'name': 'Sources'},
          },
        });
        expect(out1, contains('GGGGGGGGGGGGGGGGGGGGGGGG /* Sources */ = {'));

        // With no name but has path
        final out2 = AsciiPlistWriter().write({
          'objects': {
            'GGGGGGGGGGGGGGGGGGGGGGGG': {'isa': 'PBXGroup', 'path': 'Sources'},
          },
        });
        expect(out2, contains('GGGGGGGGGGGGGGGGGGGGGGGG /* Sources */ = {'));

        // With neither name nor path — NO annotation (not even ISA fallback)
        // This matches real pbxproj files where root PBXGroup has no name/path
        final out3 = AsciiPlistWriter().write({
          'objects': {
            'GGGGGGGGGGGGGGGGGGGGGGGG': {'isa': 'PBXGroup'},
          },
        });
        // Object without name/path: UUID = { ... }; with no annotation
        expect(out3, contains('GGGGGGGGGGGGGGGGGGGGGGGG = {'));
        expect(out3, isNot(contains('GGGGGGGGGGGGGGGGGGGGGGGG /* ')));
      },
    );

    // -------------------------------------------------------------------------
    // Test 18: UUID elements inside arrays get annotation
    // -------------------------------------------------------------------------
    test('Test 18: UUID elements in children array get annotation', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'GGGGGGGGGGGGGGGGGGGGGGGG': {
            'isa': 'PBXGroup',
            'children': ['CCCCCCCCCCCCCCCCCCCCCCCC'],
          },
          'CCCCCCCCCCCCCCCCCCCCCCCC': {
            'isa': 'PBXFileReference',
            'path': 'AppDelegate.m',
          },
        },
      });
      expect(out, contains('CCCCCCCCCCCCCCCCCCCCCCCC /* AppDelegate.m */,'));
    });

    // -------------------------------------------------------------------------
    // Test 19: UUID-shaped string not in objects map gets NO annotation
    // -------------------------------------------------------------------------
    test('Test 19: UUID not in objects map gets no annotation', () {
      final out = AsciiPlistWriter().write({
        'objects': {
          'AAAAAAAAAAAAAAAAAAAAAAAA': {
            'isa': 'PBXBuildFile',
            'fileRef': 'NONEXISTENTNONEXISTENTNON'.substring(0, 24),
          },
        },
      });
      // NONEXISTENTNONEXISTENTNON (24 chars, but we use first 24)
      // The fileRef UUID is not in objects map, so no annotation
      final nonexistent = 'NONEXISTENTNONEXISTENTNON'.substring(0, 24);
      expect(out, contains('fileRef = $nonexistent;'));
      expect(out, isNot(contains('fileRef = $nonexistent /*')));
    });
  });
}
