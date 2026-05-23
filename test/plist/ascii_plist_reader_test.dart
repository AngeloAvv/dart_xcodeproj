import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_reader.dart';
import 'package:dart_xcodeproj/src/plist/plist_format.dart';
import 'package:dart_xcodeproj/src/plist/plist_parse_error.dart';

void main() {
  group('AsciiPlistReader', () {
    group('detectFormat', () {
      test('Test 1: detects binary format from bplist prefix', () {
        expect(
          AsciiPlistReader.detectFormat('bplist00...'),
          equals(PlistFormat.binary),
        );
      });

      test('Test 2: detects xml format from <?xml prefix', () {
        expect(
          AsciiPlistReader.detectFormat('<?xml version="1.0"...'),
          equals(PlistFormat.xml),
        );
      });

      test('Test 3: detects ascii format for anything else', () {
        expect(
          AsciiPlistReader.detectFormat('{ a = b; }'),
          equals(PlistFormat.ascii),
        );
      });
    });

    group('parse', () {
      test('Test 4: parses simple unquoted key-value dict', () {
        final result = AsciiPlistReader('{ a = b; }').parse();
        expect(result, equals({'a': 'b'}));
      });

      test('Test 5: parses quoted string value', () {
        final result = AsciiPlistReader('{ key = "quoted value"; }').parse();
        expect(result, equals({'key': 'quoted value'}));
      });

      test('Test 6: parses array value', () {
        final result = AsciiPlistReader('{ list = ( a, b, c, ); }').parse();
        expect(
          result,
          equals({
            'list': ['a', 'b', 'c'],
          }),
        );
      });

      test('Test 7: parses nested dict — all scalars are strings', () {
        final result = AsciiPlistReader('{ nested = { inner = 1; }; }').parse();
        expect(
          result,
          equals({
            'nested': {'inner': '1'},
          }),
        );
      });

      test('Test 8: skips inline comments without throwing', () {
        final result = AsciiPlistReader(
          '{ /* note */ a /* uuid_anno */ = b /* val_anno */; }',
        ).parse();
        expect(result, equals({'a': 'b'}));
      });

      test('Test 9: parses simple.pbxproj fixture successfully', () {
        final contents = File(
          'test/fixtures/simple.pbxproj',
        ).readAsStringSync();
        final result = AsciiPlistReader(contents).parse();
        expect(result, isA<Map<String, dynamic>>());
        expect(
          result.keys,
          containsAll([
            'archiveVersion',
            'classes',
            'objectVersion',
            'objects',
            'rootObject',
          ]),
        );
      });

      test(
        'Test 10: parses runner.pbxproj fixture — objects key is a non-empty Map',
        () {
          final contents = File(
            'test/fixtures/runner.pbxproj',
          ).readAsStringSync();
          final result = AsciiPlistReader(contents).parse();
          expect(result, isA<Map<String, dynamic>>());
          expect(result.containsKey('objects'), isTrue);
          expect(result['objects'], isA<Map<String, dynamic>>());
          final objects = result['objects'] as Map<String, dynamic>;
          expect(objects.length, greaterThanOrEqualTo(1));
        },
      );

      test('Test 11: malformed input throws PlistParseError', () {
        expect(
          () => AsciiPlistReader('{ a = ;').parse(),
          throwsA(isA<PlistParseError>()),
        );
      });

      test(
        'Test 12: quoted string with escape sequence decoded via Unicode.unquotify',
        () {
          // r'{ a = "line\nbreak"; }' — raw string so Dart doesn't interpret \n
          final result = AsciiPlistReader(r'{ a = "line\nbreak"; }').parse();
          expect(result['a'], equals('line\nbreak'));
        },
      );

      test('Test 13: data blob parsed as List<int>', () {
        final result = AsciiPlistReader('{ d = <DEADBEEF>; }').parse();
        expect(result['d'], equals([0xde, 0xad, 0xbe, 0xef]));
      });
    });
  });
}
