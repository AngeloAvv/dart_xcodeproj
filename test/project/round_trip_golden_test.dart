// Golden round-trip tests: opening and saving a pristine Flutter
// `project.pbxproj` must not change it, beyond the lines on which Ruby's own
// open + save (xcodeproj 1.27.0) changes it.
//
// The inputs are the `flutter create` projects in test/fixtures/annotations/
// (iOS and macOS, with and without Swift Package Manager integration). The
// Ruby output is stored next to them in test/fixtures/golden/ and regenerated
// by test/fixtures/golden/generate.rb. Ruby itself differs from the input on
// the few lines where it normalises something Xcode wrote differently (the
// quoting of `path = "fx.app"` and the name of a local Swift package).

import 'dart:io';

import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

const _inputDir = 'test/fixtures/annotations';
const _goldenDir = 'test/fixtures/golden';

/// The number of lines on which Ruby's open + save differs from the input.
const _rubyDiffCounts = {'ios': 0, 'macos': 1, 'ios_spm': 2, 'macos_spm': 3};

/// The (1-based) numbers of the lines of [output] that differ from [input].
/// Both are expected to have the same number of lines.
Set<int> _changedLines(String input, String output) {
  final a = input.split('\n');
  final b = output.split('\n');
  expect(b.length, equals(a.length), reason: 'line count changed');
  return {
    for (var i = 0; i < a.length; i++)
      if (a[i] != b[i]) i + 1,
  };
}

void main() {
  for (final entry in _rubyDiffCounts.entries) {
    final name = entry.key;

    group('open + save of the pristine Flutter $name project', () {
      late String input;
      late String ruby;
      late String saved;

      setUpAll(() async {
        input = File(
          '$_inputDir/$name.xcodeproj/project.pbxproj',
        ).readAsStringSync();
        ruby = File('$_goldenDir/$name.ruby_saved.pbxproj').readAsStringSync();

        // Flutter's bundle is called Runner.xcodeproj; the name shows up in
        // the "Build configuration list for PBXProject" annotation.
        final dir = Directory.systemTemp.createTempSync('round_trip_golden_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final bundle = Directory('${dir.path}/Runner.xcodeproj')..createSync();
        File('${bundle.path}/project.pbxproj').writeAsStringSync(input);
        await (await XcodeProject.open(bundle.path)).save();
        saved = File('${bundle.path}/project.pbxproj').readAsStringSync();
      });

      test('the Ruby baseline is not vacuous', () {
        expect(_changedLines(input, ruby), hasLength(entry.value));
      });

      test('differs from the input only where Ruby differs', () {
        final rubyLines = _changedLines(input, ruby);
        final dartLines = _changedLines(input, saved);
        expect(
          dartLines.difference(rubyLines),
          isEmpty,
          reason: 'lines changed by Dart but not by Ruby',
        );
      });

      test('is identical to what Ruby writes', () {
        expect(saved, equals(ruby));
      });

      test('never annotates string attributes that hold a UUID', () {
        expect(
          saved,
          contains(
            RegExp(
              r'^\t+(remoteGlobalIDString|TestTargetID) = [0-9A-F]{24};$',
              multiLine: true,
            ),
          ),
          reason: 'fixture must contain such attributes',
        );
        expect(
          saved,
          isNot(
            contains(RegExp(r'(remoteGlobalIDString|TestTargetID) = \S+ /\*')),
          ),
        );
      });
    });
  }
}
