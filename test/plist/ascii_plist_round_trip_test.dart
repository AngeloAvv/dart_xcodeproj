import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_reader.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_writer.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';

void main() {
  group('ASCII plist round-trip', () {
    // The writer prints only the annotations it is given, and the parser drops
    // comments, so a raw parse -> write round trip is structural, not byte-wise.
    // Byte-identity (comments included) is covered by the XcodeProject
    // round trip below and by test/project/round_trip_golden_test.dart.
    for (final name in ['simple', 'runner']) {
      test('$name.pbxproj parse -> write -> parse yields the same plist', () {
        final original = File('test/fixtures/$name.pbxproj').readAsStringSync();
        final parsed = AsciiPlistReader(original).parse();
        final written = AsciiPlistWriter().write(parsed);
        expect(AsciiPlistReader(written).parse(), equals(parsed));
        expect(
          written,
          isNot(contains('/* Project object */')),
          reason: 'plain strings must never get a sniffed annotation',
        );
      });
    }

    test(
      'runner.pbxproj open -> save through XcodeProject is byte-identical',
      () async {
        final original = File(
          'test/fixtures/runner.pbxproj',
        ).readAsStringSync();
        final dir = Directory.systemTemp.createTempSync('ascii_plist_rt_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final bundle = Directory('${dir.path}/Runner.xcodeproj')..createSync();
        File('${bundle.path}/project.pbxproj').writeAsStringSync(original);

        final project = await XcodeProject.open(bundle.path);
        await project.save();

        expect(
          File('${bundle.path}/project.pbxproj').readAsStringSync(),
          equals(original),
        );
      },
    );

    test('runner.pbxproj output starts with UTF8 magic comment', () {
      final original = File('test/fixtures/runner.pbxproj').readAsStringSync();
      final written = AsciiPlistWriter().write(
        AsciiPlistReader(original).parse(),
      );
      expect(written.substring(0, 14), equals('// !\$*UTF8*\$!\n'));
    });

    test('runner.pbxproj output uses tab indentation, never four-space', () {
      final original = File('test/fixtures/runner.pbxproj').readAsStringSync();
      final written = AsciiPlistWriter().write(
        AsciiPlistReader(original).parse(),
      );
      // Count indented lines: tab-indented vs 4-space-indented
      final lines = written.split('\n');
      final tabIndentedLines = lines.where((l) => l.startsWith('\t')).length;
      final spaceIndentedLines = lines.where((l) => l.startsWith(' ')).length;
      expect(
        tabIndentedLines,
        greaterThan(10),
        reason: 'Output must use tab indentation extensively',
      );
      expect(
        spaceIndentedLines,
        equals(0),
        reason: 'Output must never use 4-space indentation (Nanaimo uses tabs)',
      );
    });
  });
}
