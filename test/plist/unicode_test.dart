import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/unicode.dart';
import 'package:dart_xcodeproj/src/plist/plist_parse_error.dart';
import 'package:dart_xcodeproj/src/plist/plist_format.dart';

void main() {
  group('Unicode', () {
    group('quotify', () {
      test('Test 1: newline becomes \\n', () {
        expect(Unicode.quotify('\n'), equals(r'\n'));
      });

      test('Test 2: double quote becomes \\"', () {
        expect(Unicode.quotify('"'), equals(r'\"'));
      });

      test('Test 3: backslash becomes \\\\', () {
        expect(Unicode.quotify('\\'), equals(r'\\'));
      });

      test('Test 4: bell (\\x07) becomes \\a', () {
        expect(Unicode.quotify('\x07'), equals(r'\a'));
      });

      test('Test 5: NUL (\\x00) becomes \\U0000', () {
        expect(Unicode.quotify('\x00'), equals(r'\U0000'));
      });

      test('Test 6: plain ASCII passes through unchanged', () {
        expect(Unicode.quotify('plain ASCII'), equals('plain ASCII'));
      });

      test('Test 7: non-ASCII UTF-8 passes through unchanged', () {
        expect(Unicode.quotify('café'), equals('café'));
      });
    });

    group('unquotify', () {
      test('Test 8: \\n becomes newline', () {
        expect(Unicode.unquotify(r'\n'), equals('\n'));
      });

      test('Test 9: \\" becomes double quote', () {
        expect(Unicode.unquotify(r'\"'), equals('"'));
      });

      test('Test 10: \\U0041 becomes A', () {
        expect(Unicode.unquotify(r'\U0041'), equals('A'));
      });

      test('Test 11: round-trip for common characters', () {
        for (final s in ['\n', '\t', '"', 'mixed\n"text\\']) {
          expect(Unicode.unquotify(Unicode.quotify(s)), equals(s));
        }
      });
    });
  });

  group('PlistParseError', () {
    test('Test 12: toString contains message, line, and column', () {
      final error = const PlistParseError('oops', 3, 5);
      final str = error.toString();
      expect(str, contains('oops'));
      expect(str, contains('3'));
      expect(str, contains('5'));
    });
  });

  group('PlistFormat', () {
    test('Test 13: PlistFormat has exactly 3 values', () {
      expect(PlistFormat.values.length, equals(3));
    });
  });
}
