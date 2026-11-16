// Tests for the build phase helpers of AbstractTarget / PBXNativeTarget
// (resourcesBuildPhase, sourceBuildPhase, addFileReferences, ...), on the
// pristine `flutter create` iOS and macOS projects. Byte-for-byte parity with
// Ruby lives in build_phase_helpers_ruby_parity_test.dart.

import 'dart:io';

import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
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

/// The names of the shell script and copy files phases of `Runner`, in order.
const _shellScriptNames = {
  'ios': ['Run Script', 'Thin Binary'],
  'macos': [null],
};
const _copyFilesNames = {
  'ios': ['Embed Frameworks'],
  'macos': ['Bundle Framework'],
};

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

      group('buildConfigurations', () {
        test('are those of the configuration list of the target', () {
          expect(
            runner.buildConfigurations,
            same(runner.buildConfigurationList!.buildConfigurations),
          );
          expect(runner.buildConfigurations.map((c) => c.name), [
            'Debug',
            'Release',
            'Profile',
          ]);
        });

        test('throw a StateError for a target without a list', () {
          final bare = project.newObject((g, u) => PBXAggregateTarget(g, u));

          expect(() => bare.buildConfigurations, throwsStateError);
        });
      });

      group('shellScriptBuildPhases', () {
        test('are the shell script phases of the target, in order', () {
          expect(
            runner.shellScriptBuildPhases.map((p) => p.name),
            _shellScriptNames[name],
          );
        });

        test('are empty for a target without any', () {
          expect(bareTarget(project).shellScriptBuildPhases, isEmpty);
        });
      });

      group('copyFilesBuildPhases', () {
        test('are the copy files phases of the target, in order', () {
          expect(
            runner.copyFilesBuildPhases.map((p) => p.name),
            _copyFilesNames[name],
          );
        });
      });

      group('newShellScriptBuildPhase', () {
        test('appends a named phase with the default script', () {
          final before = runner.buildPhases.toList();

          final phase = runner.newShellScriptBuildPhase('Run Foo');

          expect(runner.buildPhases.toList(), [...before, phase]);
          expect(phase.name, 'Run Foo');
          expect(phase.shellPath, '/bin/sh');
          expect(
            phase.shellScript,
            '# Type a script or drag a script file from your workspace to '
            'insert its path.\n',
          );
          expect(phase.files, isEmpty);
          expect(phase.referrers, contains(runner));
          expect(runner.shellScriptBuildPhases.last, same(phase));
        });

        test('appends a nameless phase', () {
          final phase = runner.newShellScriptBuildPhase();

          expect(phase.name, isNull);
          expect(phase.displayName, 'ShellScript');
        });

        test('appends a new phase every time', () {
          final first = runner.newShellScriptBuildPhase('Run Foo');
          final second = runner.newShellScriptBuildPhase('Run Foo');

          expect(second, isNot(same(first)));
          expect(runner.shellScriptBuildPhases, containsAll([first, second]));
        });

        test('works on any target, as in Ruby', () {
          final aggregate = project.newObject(
            (g, u) => PBXAggregateTarget(g, u),
          );

          final phase = aggregate.newShellScriptBuildPhase('Only');

          expect(aggregate.buildPhases.toList(), [phase]);
        });
      });

      group('newCopyFilesBuildPhase', () {
        test('appends a named phase copying to the resources', () {
          final before = runner.buildPhases.toList();

          final phase = runner.newCopyFilesBuildPhase('Copy Foo');

          expect(runner.buildPhases.toList(), [...before, phase]);
          expect(phase.name, 'Copy Foo');
          expect(phase.dstSubfolderSpec, '7');
          expect(phase.dstPath, '');
          expect(phase.referrers, contains(runner));
          expect(runner.copyFilesBuildPhases.last, same(phase));
        });

        test('appends a nameless phase', () {
          final phase = runner.newCopyFilesBuildPhase();

          expect(phase.name, isNull);
          expect(phase.displayName, 'CopyFiles');
        });
      });

      group('addFileReferences', () {
        test(
          'adds a source file to the sources phase and returns its build file',
          () {
            final swift = project.newFile('Runner/Baz.swift');
            final phase = runner.sourceBuildPhase;

            final buildFiles = runner.addFileReferences([swift]);

            expect(buildFiles, hasLength(1));
            expect(buildFiles.single.fileRef, same(swift));
            expect(phase.files.last, same(buildFiles.single));
          },
        );

        test('returns the build files in the order of the references', () {
          final a = project.newFile('Runner/A.m');
          final b = project.newFile('Runner/B.swift');

          final buildFiles = runner.addFileReferences([b, a]);

          expect(buildFiles.map((f) => f.fileRef), [b, a]);
        });

        test('adds headers to the headers phase, whatever the case', () {
          final lower = project.newFile('Runner/Foo.h');
          final upper = project.newFile('Runner/Bar.HPP');
          final sources = runner.sourceBuildPhase.files.length;

          final buildFiles = runner.addFileReferences([lower, upper]);

          expect(runner.headersBuildPhase.files.toList(), buildFiles);
          expect(runner.sourceBuildPhase.files, hasLength(sources));
        });

        test('treats a file without extension as a source', () {
          final ref = project.newFile('Runner/Makefile');

          final buildFile = runner.addFileReferences([ref]).single;

          expect(runner.sourceBuildPhase.files, contains(buildFile));
        });

        test('reuses the build file a reference already has in the phase', () {
          final existing = runner.sourceBuildPhase.files.first;
          final count = runner.sourceBuildPhase.files.length;

          final buildFiles = runner.addFileReferences([
            existing.fileRef! as PBXFileReference,
          ]);

          expect(buildFiles.single, same(existing));
          expect(runner.sourceBuildPhase.files, hasLength(count));
        });

        test('reuses the build file for a reference given twice', () {
          final ref = project.newFile('Runner/Dup.swift');

          final buildFiles = runner.addFileReferences([ref, ref]);

          expect(buildFiles.first, same(buildFiles.last));
          expect(
            runner.sourceBuildPhase.files.where((f) => f.fileRef == ref),
            hasLength(1),
          );
        });

        test(
          'adds a file to a phase that has a build file of another phase',
          () {
            final ref = project.newFile('Runner/Shared.m');
            runner.addResources([ref]);

            final buildFile = runner.addFileReferences([ref]).single;

            expect(runner.sourceBuildPhase.files, contains(buildFile));
            expect(
              runner.resourcesBuildPhase.files,
              isNot(contains(buildFile)),
            );
          },
        );

        test('sets the compiler flags of a source file', () {
          final ref = project.newFile('Runner/Foo.m');

          final buildFile = runner.addFileReferences([
            ref,
          ], compilerFlags: '-fobjc-arc').single;

          expect(buildFile.settings, {'COMPILER_FLAGS': '-fobjc-arc'});
        });

        test('appends the flags to those the build file already has', () {
          final ref = project.newFile('Runner/Foo.m');
          runner.addFileReferences([ref], compilerFlags: '-fobjc-arc');

          final buildFile = runner.addFileReferences([
            ref,
          ], compilerFlags: '-Wall').single;

          expect(buildFile.settings, {'COMPILER_FLAGS': '-fobjc-arc -Wall'});
        });

        test('appends the same flags again, like Ruby', () {
          final ref = project.newFile('Runner/Foo.m');
          runner.addFileReferences([ref], compilerFlags: '-fobjc-arc');

          final buildFile = runner.addFileReferences([
            ref,
          ], compilerFlags: '-fobjc-arc').single;

          expect(buildFile.settings, {
            'COMPILER_FLAGS': '-fobjc-arc -fobjc-arc',
          });
        });

        test('keeps the other settings of an existing build file', () {
          final ref = project.newFile('Runner/Foo.m');
          runner.addFileReferences([ref]).single.settings = {
            'ATTRIBUTES': ['Public'],
          };

          final buildFile = runner.addFileReferences([
            ref,
          ], compilerFlags: '-Wall').single;

          expect(buildFile.settings, {
            'ATTRIBUTES': ['Public'],
            'COMPILER_FLAGS': '-Wall',
          });
        });

        test('appends the flags to those read from the project file', () async {
          // Written by Ruby: Foo.m has COMPILER_FLAGS "-fobjc-arc -Wall".
          final tmp = Directory.systemTemp.createTempSync('build_phases_');
          addTearDown(() => tmp.deleteSync(recursive: true));
          final bundle = Directory('${tmp.path}/Runner.xcodeproj')
            ..createSync();
          File(
            'test/fixtures/build_phases/$name.add_file_references.pbxproj',
          ).copySync('${bundle.path}/project.pbxproj');
          final opened = await XcodeProject.open(bundle.path);
          final target = _target(opened, 'Runner');
          final foo =
              target.sourceBuildPhase.files
                      .firstWhere((f) => f.displayName == 'Foo.m')
                      .fileRef!
                  as PBXFileReference;

          final buildFile = target.addFileReferences([
            foo,
          ], compilerFlags: '-O').single;

          expect(buildFile.settings, {'COMPILER_FLAGS': '-fobjc-arc -Wall -O'});
        });

        test('leaves the settings alone without compiler flags', () {
          final a = project.newFile('Runner/A.m');
          final b = project.newFile('Runner/B.m');

          expect(runner.addFileReferences([a]).single.settings, isNull);
          expect(
            runner.addFileReferences([b], compilerFlags: '').single.settings,
            isNull,
          );
        });

        test('ignores the compiler flags of a header', () {
          final header = project.newFile('Runner/Foo.h');

          final buildFile = runner.addFileReferences([
            header,
          ], compilerFlags: '-fobjc-arc').single;

          expect(buildFile.settings, isNull);
        });

        test('calls back with the build file of each reference', () {
          final existing = runner.sourceBuildPhase.files.first;
          final fresh = project.newFile('Runner/Foo.m');
          final seen = <PBXBuildFile>[];

          final buildFiles = runner.addFileReferences([
            existing.fileRef! as PBXFileReference,
            fresh,
          ], onBuildFile: seen.add);

          expect(seen, buildFiles);
          expect(seen.first, same(existing));
        });

        test('throws, and adds nothing, for a reference without a path', () {
          final ok = project.newFile('Runner/Foo.m');
          final pathless = project.newObject((g, u) => PBXFileReference(g, u));
          final before = runner.sourceBuildPhase.files.length;

          expect(
            () => runner.addFileReferences([ok, pathless]),
            throwsArgumentError,
          );
          expect(runner.sourceBuildPhase.files, hasLength(before));
        });

        test('does nothing, not even creating a phase, for no references', () {
          final bare = bareTarget(project);

          expect(bare.addFileReferences([]), isEmpty);
          expect(bare.buildPhases, isEmpty);
        });

        test('creates the sources phase when the target has none', () {
          final bare = bareTarget(project);

          bare.addFileReferences([project.newFile('Runner/Baz.swift')]);

          expect(bare.buildPhases.single, isA<PBXSourcesBuildPhase>());
        });
      });

      group('addResources', () {
        test('adds a build file per reference to the resources phase', () {
          final first = project.newFile('Runner/a.png');
          final second = project.newFile('Runner/b.json');
          final phase = runner.resourcesBuildPhase;
          final before = phase.files.length;

          runner.addResources([first, second]);

          final added = phase.files.skip(before).toList();
          expect(added.map((f) => f.fileRef), [first, second]);
          expect(first.referrers, contains(added.first));
        });

        test('skips a reference that is already in the phase', () {
          final ref = project.newFile('Runner/a.png');
          runner.addResources([ref]);
          final count = runner.resourcesBuildPhase.files.length;

          runner.addResources([ref]);

          expect(runner.resourcesBuildPhase.files, hasLength(count));
        });

        test('skips a resource the project already had', () {
          final phase = runner.resourcesBuildPhase;
          final existing = phase.files.first.fileRef!;
          final count = phase.files.length;

          runner.addResources([existing]);

          expect(phase.files, hasLength(count));
        });

        test('adds a reference given twice only once', () {
          final ref = project.newFile('Runner/a.png');
          final count = runner.resourcesBuildPhase.files.length;

          runner.addResources([ref, ref]);

          expect(runner.resourcesBuildPhase.files, hasLength(count + 1));
        });

        test('creates the resources phase when the target has none', () {
          final bare = bareTarget(project);

          bare.addResources([project.newFile('Runner/a.png')]);

          final phase = bare.buildPhases.single as PBXResourcesBuildPhase;
          expect(phase.files, hasLength(1));
        });

        test(
          'does nothing, not even creating the phase, for no references',
          () {
            final bare = bareTarget(project);

            bare.addResources([]);

            expect(bare.buildPhases, isEmpty);
          },
        );
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
