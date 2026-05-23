// — unit tests for OtherLinkerFlagsParser ().
// TDD RED phase: these tests are written BEFORE the implementation.

import 'package:dart_xcodeproj/src/config/other_linker_flags_parser.dart';
import 'package:test/test.dart';

void main() {
  group('OtherLinkerFlagsParser', () {
    group('parse()', () {
      test('-framework UIKit → frameworks={UIKit}', () {
        final result = OtherLinkerFlagsParser.parse('-framework UIKit');
        expect(result.frameworks, equals({'UIKit'}));
        expect(result.weakFrameworks, isEmpty);
        expect(result.libraries, isEmpty);
        expect(result.argFiles, isEmpty);
        expect(result.forceLoad, isEmpty);
        expect(result.simple, isEmpty);
      });

      test('-weak_framework SwiftUI → weakFrameworks={SwiftUI}', () {
        final result = OtherLinkerFlagsParser.parse('-weak_framework SwiftUI');
        expect(result.weakFrameworks, equals({'SwiftUI'}));
        expect(result.frameworks, isEmpty);
      });

      test('-lz → libraries={z} (inline -l<X> split)', () {
        final result = OtherLinkerFlagsParser.parse('-lz');
        expect(result.libraries, equals({'z'}));
      });

      test('-lzip → libraries={zip}', () {
        final result = OtherLinkerFlagsParser.parse('-lzip');
        expect(result.libraries, equals({'zip'}));
      });

      test('-l foo (separate tokens) → libraries={foo}', () {
        final result = OtherLinkerFlagsParser.parse('-l foo');
        expect(result.libraries, equals({'foo'}));
      });

      test('@file.args → argFiles={file.args} (inline @<X> split)', () {
        final result = OtherLinkerFlagsParser.parse('@file.args');
        expect(result.argFiles, equals({'file.args'}));
      });

      test('-force_load path/to/lib.a → forceLoad={path/to/lib.a}', () {
        final result = OtherLinkerFlagsParser.parse(
          '-force_load path/to/lib.a',
        );
        expect(result.forceLoad, equals({'path/to/lib.a'}));
      });

      test('-ObjC (bare flag) → simple={-ObjC}', () {
        final result = OtherLinkerFlagsParser.parse('-ObjC');
        expect(result.simple, equals({'-ObjC'}));
      });

      test('combined: all flag types populate all five sets correctly', () {
        final result = OtherLinkerFlagsParser.parse(
          '-framework UIKit -weak_framework SwiftUI -lz -force_load libfoo.a -ObjC',
        );
        expect(result.frameworks, equals({'UIKit'}));
        expect(result.weakFrameworks, equals({'SwiftUI'}));
        expect(result.libraries, equals({'z'}));
        expect(result.forceLoad, equals({'libfoo.a'}));
        expect(result.simple, equals({'-ObjC'}));
      });

      test('empty string → all sets empty', () {
        final result = OtherLinkerFlagsParser.parse('');
        expect(result.frameworks, isEmpty);
        expect(result.weakFrameworks, isEmpty);
        expect(result.libraries, isEmpty);
        expect(result.argFiles, isEmpty);
        expect(result.forceLoad, isEmpty);
        expect(result.simple, isEmpty);
      });
    });
  });
}
