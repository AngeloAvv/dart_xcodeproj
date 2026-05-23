import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_reader.dart';
import 'package:dart_xcodeproj/src/plist/ascii_plist_writer.dart';

void main() {
  group('ASCII plist round-trip', () {
    test('simple.pbxproj parse → write produces byte-identical output', () {
      final original = File('test/fixtures/simple.pbxproj').readAsStringSync();
      final parsed = AsciiPlistReader(original).parse();
      final written = AsciiPlistWriter().write(parsed);
      expect(
        written,
        equals(original),
        reason: 'simple.pbxproj must round-trip byte-identically',
      );
    });

    test('runner.pbxproj parse → write produces byte-identical output', () {
      final original = File('test/fixtures/runner.pbxproj').readAsStringSync();
      final parsed = AsciiPlistReader(original).parse();
      final written = AsciiPlistWriter().write(parsed);
      // Compute a precise diff location on failure to aid debugging.
      if (written != original) {
        var idx = 0;
        while (idx < written.length &&
            idx < original.length &&
            written[idx] == original[idx]) {
          idx++;
        }
        final ctxStart = idx > 40 ? idx - 40 : 0;
        final ctxEnd = idx + 40 < written.length ? idx + 40 : written.length;
        final wctx = written.substring(ctxStart, ctxEnd);
        final octx = original.substring(
          ctxStart,
          ctxEnd > original.length ? original.length : ctxEnd,
        );
        fail(
          'runner.pbxproj round-trip mismatch at byte $idx\n'
          ' expected: ${octx.replaceAll('\n', '\\n').replaceAll('\t', '\\t')}\n'
          ' actual: ${wctx.replaceAll('\n', '\\n').replaceAll('\t', '\\t')}',
        );
      }
      expect(written, equals(original));
    });

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
