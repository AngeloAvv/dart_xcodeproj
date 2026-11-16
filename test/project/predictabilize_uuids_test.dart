// Tests for XcodeProject.predictabilizeUuids, the port of Ruby's
// `Project#predictabilize_uuids` (xcodeproj 1.27.0).
//
// That the output is byte-identical to Ruby's is checked in
// predictabilize_uuids_ruby_parity_test.dart; these tests pin down the
// behaviour that does not show in a file: what the paths are, which objects
// and strings are rewritten, and what happens when the project is not tidy.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/object_dictionary.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_exception_set.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_root_group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/project/uuid_generator.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures';

String _md5(String path) => UuidGenerator.generateDeterministic(path);

/// Opens the pbxproj at [input] from a `Runner.xcodeproj` bundle.
Future<XcodeProject> _open(String input) async {
  final tmp = Directory.systemTemp.createTempSync('predictabilize_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final bundle = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
  File(input).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(bundle.path);
}

void main() {
  group('XcodeProject.predictabilizeUuids', () {
    group('on a new project', () {
      late XcodeProject project;

      setUp(() async {
        project = await XcodeProject.create('/tmp/Test.xcodeproj');
      });

      test('derives the root and its to-one children from their path', () {
        project.predictabilizeUuids();

        expect(project.rootObject.uuid, _md5('Test.xcodeproj'));
        expect(project.mainGroup.uuid, _md5('Test.xcodeproj/mainGroup'));
      });

      test('gives an object the path it is first found with', () {
        // The Products group is the project's productRefGroup, but to-one
        // references are followed first and the main group reaches it as one
        // of its children before productRefGroup is looked at.
        final products = project.productsGroup;

        final paths = UuidGenerator.structuralPaths(
          project.rootObject,
          'Test.xcodeproj',
        );

        expect(
          paths[products],
          startsWith('Test.xcodeproj/mainGroup/children/'),
        );
      });

      test('names the group a file reference is in after its hierarchy', () {
        final group = project.newGroup('Sources');
        final file = project.newFile('Main.swift');
        group.children.add(file);
        project.mainGroup.children.remove(file);

        final paths = UuidGenerator.structuralPaths(
          project.rootObject,
          'Test.xcodeproj',
        );

        expect(paths[file], endsWith('/Sources/Main.swift'));
      });

      test('names the references of a dictionary after their key', () {
        final reference = ObjectDictionary({
          'ProjectRef': PBXFileReference,
          'ProductGroup': PBXGroup,
        }, project.rootObject);
        reference['ProjectRef'] = project.newObject(
          (g, u) => PBXFileReference(g, u)..path = 'Sub.xcodeproj',
        );
        reference['ProductGroup'] = project.newObject(
          (g, u) => PBXGroup(g, u)..name = 'Products',
        );
        project.rootObject.projectReferences.add(reference);

        final paths = UuidGenerator.structuralPaths(
          project.rootObject,
          'Test.xcodeproj',
        );

        expect(
          paths[reference['ProjectRef']],
          startsWith('Test.xcodeproj/projectReferences/k:project_ref/'),
        );
        // Neither has a group for a parent, so the hierarchy is the project's.
        expect(
          paths[reference['ProductGroup']],
          allOf(
            startsWith('Test.xcodeproj/projectReferences/k:product_group/'),
            endsWith('Test/Products'),
          ),
        );
      });

      test('registers every object under its new UUID', () {
        final objects = project.objectsByUuid.values.toList();

        project.predictabilizeUuids();

        expect(project.objectsByUuid.values, unorderedEquals(objects));
        for (final entry in project.objectsByUuid.entries) {
          expect(entry.key, entry.value.uuid);
          expect(UuidGenerator.isValid(entry.key), isTrue);
          expect(entry.key, hasLength(32));
        }
      });

      test(
        'gives the same UUIDs to the same project, whatever the old ones',
        () async {
          final other = await XcodeProject.create('/elsewhere/Test.xcodeproj');
          for (final p in [project, other]) {
            p.newGroup('Sources');
            p.predictabilizeUuids();
          }

          expect(
            project.objectsByUuid.keys.toSet(),
            equals(other.objectsByUuid.keys.toSet()),
          );
        },
      );

      test('seeds the paths with the name of the bundle', () async {
        final other = await XcodeProject.create('/tmp/Other.xcodeproj');

        project.predictabilizeUuids();
        other.predictabilizeUuids();

        expect(project.rootObject.uuid, isNot(other.rootObject.uuid));
        expect(other.rootObject.uuid, _md5('Other.xcodeproj'));
      });

      test('keeps the project usable: new objects get a random UUID', () {
        project.predictabilizeUuids();

        final group = project.newGroup('Later');

        expect(group.uuid, hasLength(24));
        expect(project.objectsByUuid[group.uuid], same(group));
      });

      test('keeps an object that is not reachable from the root', () {
        final orphan = project.newObject((g, u) => PBXGroup(g, u));
        orphan.addReferrer(project);
        final oldUuid = orphan.uuid;

        project.predictabilizeUuids();

        expect(orphan.uuid, oldUuid);
        expect(project.objectsByUuid[oldUuid], same(orphan));
      });

      test('gives two objects with the same path the same UUID', () {
        // Two groups of the same name in the same group look the same.
        final first = project.newGroup('Same');
        final second = project.newGroup('Same');

        project.predictabilizeUuids();

        expect(first.uuid, second.uuid);
        // Like Ruby, the later one found stands for both.
        expect(project.objectsByUuid[first.uuid], same(second));
      });
    });

    group('on the Flutter iOS project', () {
      late XcodeProject project;

      setUp(() async {
        project = await _open(
          '$_fixtures/annotations/ios.xcodeproj/project.pbxproj',
        );
      });

      test('rewrites the strings that hold the UUID of an object', () {
        final proxies = project.objectsByUuid.values
            .whereType<PBXContainerItemProxy>()
            .toList();
        expect(proxies, isNotEmpty);
        final targets = {
          for (final target in project.rootObject.targets) target.uuid: target,
        };
        // Where the proxies point at, before the UUIDs change.
        final remoteTargets = {
          for (final proxy in proxies)
            proxy: targets[proxy.remoteGlobalIDString],
        };
        expect(remoteTargets.values, everyElement(isNotNull));

        project.predictabilizeUuids();

        for (final proxy in proxies) {
          expect(proxy.containerPortal, project.rootObject.uuid);
          expect(proxy.remoteGlobalIDString, remoteTargets[proxy]!.uuid);
        }
      });

      test('rewrites the target UUIDs of the target attributes', () {
        final targetAttributes =
            project.rootObject.attributes['TargetAttributes'] as Map;
        final testTarget = project.rootObject.targets.firstWhere(
          (t) => t.name == 'RunnerTests',
        );
        final runner = project.rootObject.targets.firstWhere(
          (t) => t.name == 'Runner',
        );
        expect(
          (targetAttributes[testTarget.uuid] as Map)['TestTargetID'],
          runner.uuid,
          reason: 'the fixture has no test target ID to rewrite',
        );

        project.predictabilizeUuids();

        final rewritten =
            project.rootObject.attributes['TargetAttributes'] as Map;
        expect(rewritten.keys, containsAll([testTarget.uuid, runner.uuid]));
        expect(
          (rewritten[testTarget.uuid] as Map)['TestTargetID'],
          runner.uuid,
        );
        // The other attributes are left as they were.
        expect(
          (rewritten[runner.uuid] as Map)['CreatedOnToolsVersion'],
          isNotNull,
        );
      });

      test(
        'is not affected by a second call on a project without proxies',
        () async {
          final simple = await XcodeProject.create('/tmp/Test.xcodeproj');
          simple.predictabilizeUuids();
          final once = simple.objectsByUuid.keys.toList();

          simple.predictabilizeUuids();

          expect(simple.objectsByUuid.keys.toList(), equals(once));
        },
      );
    });

    group('on a project that references another one', () {
      late XcodeProject project;

      setUp(() async {
        project = await _open('$_fixtures/subproject.pbxproj');
      });

      test(
        'rewrites the references of a dictionary and the strings that follow them',
        () {
          final reference = project.rootObject.projectReferences.first;
          final projectRef = reference['ProjectRef']!;
          final proxy = project.objectsByUuid.values
              .whereType<PBXContainerItemProxy>()
              .firstWhere((p) => p.containerPortal == projectRef.uuid);
          final remote = proxy.remoteGlobalIDString;

          project.predictabilizeUuids();

          expect(project.objectsByUuid[projectRef.uuid], same(projectRef));
          expect(
            project.objectsByUuid[reference['ProductGroup']!.uuid],
            same(reference['ProductGroup']),
          );
          expect(proxy.containerPortal, projectRef.uuid);
          // The remote target is in the other project, not here.
          expect(proxy.remoteGlobalIDString, remote);
        },
      );
    });

    group('on a project with a synchronized folder', () {
      test('does not loop on the target an exception set points at', () async {
        // Ruby overflows its stack here: the target holds the folder, the
        // folder its exception sets, and an exception set its target.
        final project = await _open(
          '$_fixtures/predictabilized/kitchen_sink.pbxproj',
        );
        final target = project.rootObject.targets
            .whereType<PBXNativeTarget>()
            .firstWhere((t) => t.name == 'App');
        final folder =
            target.fileSystemSynchronizedGroups.single
                as PBXFileSystemSynchronizedRootGroup;
        final exceptions = project.newObject(
          (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
        )..target = target;
        folder.exceptions.add(exceptions);

        project.predictabilizeUuids();

        expect(exceptions.uuid, hasLength(32));
        expect(project.objectsByUuid[exceptions.uuid], same(exceptions));
      });
    });
  });
}
