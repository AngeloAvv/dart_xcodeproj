// Behaviour of the group and project lookups that Ruby cannot tell: how they
// read, and what Dart does differently (see lookups_ruby_parity_test.dart for
// the comparison with xcodeproj).

import 'dart:io';

import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _macos = 'test/fixtures/annotations/macos.xcodeproj/project.pbxproj';

/// The macOS Flutter project, opened from `<tmp>/dir/Runner.xcodeproj`.
Future<XcodeProject> _open(Directory tmp, {String? asPath}) async {
  final bundle = Directory('${tmp.path}/dir/Runner.xcodeproj')
    ..createSync(recursive: true);
  File(_macos).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(asPath ?? bundle.path);
}

void main() {
  late Directory tmp;
  late XcodeProject project;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('lookups_test_');
    project = await _open(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('PBXGroup.findSubpath', () {
    test('finds nested groups and files by display name', () {
      final runner = project.mainGroup.findSubpath('Runner')! as PBXGroup;
      expect(runner.path, 'Runner');
      expect(
        project.mainGroup.findSubpath('Runner/Configs/Debug.xcconfig'),
        isA<PBXFileReference>().having((f) => f.path, 'path', 'Debug.xcconfig'),
      );
      // Matched by the name of a group that has one, not by its path.
      expect(
        runner.findSubpath('Resources'),
        isA<PBXGroup>().having((g) => g.path, 'path', '..'),
      );
    });

    test('returns this group for a null path and null for a missing one', () {
      expect(project.mainGroup.findSubpath(null), same(project.mainGroup));
      expect(project.mainGroup.findSubpath('Runner/Missing'), isNull);
    });

    test('create: adds the missing groups and finds them the next time', () {
      final before = project.groups.length;
      final created =
          project.mainGroup.findSubpath('Runner/New/Nested', create: true)!
              as PBXGroup;

      expect(created.name, 'Nested');
      expect(created.path, isNull);
      expect(created.sourceTree, '<group>');
      expect(project.groups.length, before + 2);
      expect(project.mainGroup.findSubpath('Runner/New/Nested'), same(created));
      expect(
        project.mainGroup.findSubpath('Runner/New/Nested', create: true),
        same(created),
      );
      expect(project.groups.length, before + 2);
    });

    test('create: the new groups are saved with the project', () async {
      project.mainGroup.findSubpath('Brand/New', create: true);
      await project.save();

      final reopened = await XcodeProject.open(project.path);
      expect(reopened.mainGroup.findSubpath('Brand/New'), isA<PBXGroup>());
    });

    test('throws a StateError when a name before the last is a file', () {
      final before = project.groups.length;
      expect(
        () => project.mainGroup.findSubpath(
          'Runner/AppDelegate.swift/New',
          create: true,
        ),
        throwsStateError,
      );
      expect(project.groups.length, before);
    });
  });

  group('PBXGroup.findFileByPath', () {
    test('matches the path of a direct child file exactly', () {
      final runner = project.mainGroup.findSubpath('Runner')! as PBXGroup;
      expect(runner.findFileByPath('AppDelegate.swift')?.path, isNotNull);
      expect(runner.findFileByPath('Configs'), isNull); // a group
      expect(runner.findFileByPath('Debug.xcconfig'), isNull); // not direct
      expect(runner.findFileByPath('appdelegate.swift'), isNull);
    });
  });

  group('PBXGroup.recursiveChildren', () {
    test('lists each child before its own children', () {
      final configs =
          project.mainGroup.findSubpath('Runner/Configs')! as PBXGroup;
      expect(
        configs.recursiveChildren,
        orderedEquals(configs.children.toList()),
      );
      final runner = project.mainGroup.findSubpath('Runner')! as PBXGroup;
      final names = runner.recursiveChildren.map((c) => c.displayName).toList();
      expect(
        names.indexOf('Configs'),
        lessThan(names.indexOf('AppInfo.xcconfig')),
      );
      expect(
        names.indexOf('AppInfo.xcconfig'),
        lessThan(names.indexOf('Warnings.xcconfig')),
      );
    });
  });

  group('XcodeProject.nativeTargets', () {
    test('leaves the aggregate targets out of targets', () {
      expect(project.targets.map((t) => t.name), contains('Flutter Assemble'));
      expect(project.nativeTargets.map((t) => t.name), [
        'Runner',
        'RunnerTests',
      ]);
      expect(project.nativeTargets, everyElement(isA<PBXNativeTarget>()));
    });
  });

  group('XcodeProject.referenceForPath', () {
    test('finds a file by its absolute real path', () {
      final dir = '${tmp.path}/dir';
      // Runner/Resources has the path `..`, so `Runner/Info.plist` is relative
      // to the project directory, not to Runner.
      expect(
        project.referenceForPath('$dir/Runner/Info.plist')?.name,
        'Info.plist',
      );
      expect(project.referenceForPath('$dir/Runner/Missing.swift'), isNull);
    });

    test('throws an ArgumentError for a relative path', () {
      expect(
        () => project.referenceForPath('Runner/Info.plist'),
        throwsArgumentError,
      );
    });

    test('works on a project opened from a relative path', () async {
      final relative = p.relative('${tmp.path}/dir/Runner.xcodeproj');
      final opened = await _open(tmp, asPath: relative);

      final dir = p.dirname(p.normalize(p.absolute(relative)));
      expect(opened.referenceForPath('$dir/Runner/Info.plist'), isNotNull);
    });

    test('keeps the directory the project was opened in when the working '
        'directory changes, like Ruby\'s absolute project_dir', () async {
      final relative = p.relative('${tmp.path}/dir/Runner.xcodeproj');
      final opened = await _open(tmp, asPath: relative);
      final dir = p.dirname(p.normalize(p.absolute(relative)));
      final other = Directory('${tmp.path}/other')..createSync();

      final original = Directory.current;
      addTearDown(() => Directory.current = original);
      // Everything above is done: the working directory is changed only for
      // the lookup, as it is process-wide.
      Directory.current = other;
      final found = opened.referenceForPath('$dir/Runner/Info.plist');
      Directory.current = original;

      expect(found, isNotNull);
    });
  });
}
