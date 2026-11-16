// Tests for the build phase helpers of AbstractTarget / PBXNativeTarget
// (resourcesBuildPhase, sourceBuildPhase, addFileReferences, ...), on the
// pristine `flutter create` iOS and macOS projects. Byte-for-byte parity with
// Ruby lives in build_phase_helpers_ruby_parity_test.dart.

import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

import 'helpers/bare_target.dart';

const _fixtures = 'test/fixtures/annotations';

/// Opens a pristine Flutter project, `ios` or `macos`.
Future<XcodeProject> _open(String name) =>
    XcodeProject.open('$_fixtures/$name.xcodeproj');

PBXNativeTarget _target(XcodeProject project, String name) => project.targets
    .whereType<PBXNativeTarget>()
    .firstWhere((t) => t.name == name);

void main() {
  for (final name in ['ios', 'macos']) {
    group('$name project:', () {
      late XcodeProject project;
      late PBXNativeTarget runner;

      setUp(() async {
        project = await _open(name);
        runner = _target(project, 'Runner');
      });

      group('sourceBuildPhase', () {
        test('returns the sources phase of the target', () {
          final existing = runner.buildPhases
              .whereType<PBXSourcesBuildPhase>()
              .single;

          expect(runner.sourceBuildPhase, same(existing));
        });

        test('does not create a second phase', () {
          final before = runner.buildPhases.length;

          runner.sourceBuildPhase;

          expect(runner.buildPhases, hasLength(before));
        });
      });

      group('resourcesBuildPhase', () {
        test('returns the resources phase of the target', () {
          final existing = runner.buildPhases
              .whereType<PBXResourcesBuildPhase>()
              .single;

          expect(runner.resourcesBuildPhase, same(existing));
        });

        test('creates the phase when the target has none', () {
          final bare = bareTarget(project);

          final phase = bare.resourcesBuildPhase;

          expect(bare.buildPhases.toList(), [phase]);
          expect(bare.resourcesBuildPhase, same(phase));
        });
      });

      group('headersBuildPhase', () {
        test('creates the phase after the existing ones, then reuses it', () {
          final before = runner.buildPhases.toList();
          expect(before.whereType<PBXHeadersBuildPhase>(), isEmpty);

          final phase = runner.headersBuildPhase;

          expect(runner.buildPhases.toList(), [...before, phase]);
          expect(runner.headersBuildPhase, same(phase));
        });
      });

      group('frameworksBuildPhase', () {
        late PBXNativeTarget tests;

        setUp(() => tests = bareTarget(project));

        test('creates the phase when the target has none', () {
          expect(
            tests.buildPhases.whereType<PBXFrameworksBuildPhase>(),
            isEmpty,
          );

          final phase = tests.frameworksBuildPhase;

          expect(tests.buildPhases.last, same(phase));
          expect(phase.referrers, contains(tests));
          expect(phase.files, isEmpty);
        });

        test('returns the phase it created the next time', () {
          final phase = tests.frameworksBuildPhase;

          expect(tests.frameworksBuildPhase, same(phase));
          expect(
            tests.buildPhases.whereType<PBXFrameworksBuildPhase>(),
            hasLength(1),
          );
        });

        test('returns the existing phase of the target', () {
          final existing = runner.buildPhases
              .whereType<PBXFrameworksBuildPhase>()
              .single;

          expect(runner.frameworksBuildPhase, same(existing));
        });

        test('creates a new phase after the previous one was removed', () {
          final phase = tests.frameworksBuildPhase;
          tests.buildPhases.remove(phase);

          expect(tests.frameworksBuildPhase, isNot(same(phase)));
        });
      });
    });
  }
}
