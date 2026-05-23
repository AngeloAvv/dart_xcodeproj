// Tests for PlistReader unified dispatcher.
// Covers (XML plist read) and (binary plist read).

import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/plist_reader.dart';
import 'package:dart_xcodeproj/src/plist/plist_parse_error.dart';

void main() {
  group('PlistReader', () {
    // -------------------------------------------------------------------------
    // readFromString — ASCII dispatch
    // -------------------------------------------------------------------------

    test('readFromString parses ASCII plist', () {
      final result = PlistReader.readFromString('{ key = value; }');
      expect(result['key'], equals('value'));
    });

    test('readFromString parses ASCII plist with multiple keys', () {
      final result = PlistReader.readFromString(
        '{ archiveVersion = 1; objectVersion = 54; }',
      );
      expect(result['archiveVersion'], equals('1'));
      expect(result['objectVersion'], equals('54'));
    });

    // -------------------------------------------------------------------------
    // readFromPath — disk dispatch (all three formats)
    // -------------------------------------------------------------------------

    test('readFromPath reads ASCII pbxproj from disk', () {
      final result = PlistReader.readFromPath('test/fixtures/simple.pbxproj');
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

    test('readFromPath reads XML plist from disk', () {
      final result = PlistReader.readFromPath('test/fixtures/sample.xml.plist');
      expect(result['CFBundleName'], equals('TestApp'));
      expect(result['CFBundleVersion'], equals('1.0'));
      expect(result['LSRequiresIPhoneOS'], isTrue);
    });

    test('readFromPath reads binary plist from disk', () {
      final result = PlistReader.readFromPath(
        'test/fixtures/sample.binary.plist',
      );
      expect(result['CFBundleName'], equals('TestApp'));
      expect(result['CFBundleVersion'], equals('1.0'));
    });

    test('readFromPath reads runner.pbxproj (real Flutter project)', () {
      final result = PlistReader.readFromPath('test/fixtures/runner.pbxproj');
      expect(result.containsKey('objects'), isTrue);
      expect(result.containsKey('rootObject'), isTrue);
    });

    // -------------------------------------------------------------------------
    // Error cases
    // -------------------------------------------------------------------------

    test('throws PlistParseError on missing file', () {
      expect(
        () => PlistReader.readFromPath('test/fixtures/does_not_exist.plist'),
        throwsA(isA<PlistParseError>()),
      );
    });

    test('throws PlistParseError on merge conflict markers', () {
      const conflicted = '''
{
<<<<<<< HEAD
 key = old;
=======
 key = new;
>>>>>>> branch
}
''';
      expect(
        () => PlistReader.readFromString(conflicted),
        throwsA(isA<PlistParseError>()),
      );
    });

    test('readFromBytes rejects non-bplist bytes', () {
      expect(
        () => PlistReader.readFromBytes([0x00, 0x01, 0x02]),
        throwsA(isA<PlistParseError>()),
      );
    });

    test('readFromBytes rejects too-short byte sequence', () {
      expect(
        () => PlistReader.readFromBytes([0x62, 0x70]),
        throwsA(isA<PlistParseError>()),
      );
    });
  });
}
