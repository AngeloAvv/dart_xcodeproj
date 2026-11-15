// Tests that the pbxproj writer takes its annotations from the object model
// (`toAsciiPlist` / `asciiPlistAnnotation`), not from the shape of strings.
// Expected annotations were cross-checked against Ruby xcodeproj 1.27.0.

import 'dart:io';

import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_container_item_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_exception_set.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_root_group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_reference_proxy.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_target_dependency.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/plist/annotated_nodes.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late XcodeProject project;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('ascii_plist_model_');
    project = await XcodeProject.create('${tmp.path}/Foo.xcodeproj');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  PBXNativeTarget addTarget(String name) {
    final target = project.newObject((g, u) => PBXNativeTarget(g, u))
      ..name = name;
    target.buildConfigurationList = project.newObject(
      (g, u) => XCConfigurationList(g, u),
    );
    project.rootObject.targets.add(target);
    return target;
  }

  group('main group', () {
    test('has no annotation', () {
      expect(project.mainGroup.asciiPlistAnnotation, isNull);
    });

    test('is written without a comment, other groups with one', () async {
      final group = project.newGroup('Sources');
      await project.save();
      final text = File('${project.path}/project.pbxproj').readAsStringSync();
      expect(text, contains('${project.mainGroup.uuid} = {'));
      expect(text, contains('${group.uuid} /* Sources */ = {'));
      expect(text, contains('mainGroup = ${project.mainGroup.uuid};'));
    });

    test('other groups are annotated by name or path basename', () {
      expect(
        project.newGroup('G', path: 'some/dir').asciiPlistAnnotation,
        ' G ',
      );
      final byPath = project.newObject((g, u) => PBXGroup(g, u))
        ..path = 'some/dir';
      project.mainGroup.children.add(byPath);
      expect(byPath.asciiPlistAnnotation, ' dir ');
      final bare = project.newObject((g, u) => PBXGroup(g, u));
      project.mainGroup.children.add(bare);
      // Ruby: " #{nil} " — blank, not the ISA.
      expect(bare.asciiPlistAnnotation, '  ');
    });
  });

  group('PBXReferenceProxy annotation', () {
    PBXReferenceProxy proxy({String? name, String? path}) {
      final p = project.newObject((g, u) => PBXReferenceProxy(g, u))
        ..name = name
        ..path = path;
      project.mainGroup.children.add(p);
      return p;
    }

    test('uses the basename when the path has directories', () {
      expect(
        proxy(path: 'build/Foo.framework').asciiPlistAnnotation,
        ' Foo.framework ',
      );
    });

    test('prefers the name over the path', () {
      expect(proxy(name: 'Bar', path: 'x/y').asciiPlistAnnotation, ' Bar ');
    });

    test('is blank without a name or path', () {
      expect(proxy().asciiPlistAnnotation, '  ');
    });
  });

  group('XCConfigurationList annotation', () {
    test('names the project it belongs to', () {
      expect(
        project.rootObject.buildConfigurationList!.asciiPlistAnnotation,
        ' Build configuration list for PBXProject "Foo" ',
      );
    });

    test('names the target it belongs to', () {
      final target = addTarget('App');
      expect(
        target.buildConfigurationList!.asciiPlistAnnotation,
        ' Build configuration list for PBXNativeTarget "App" ',
      );
    });

    test('has a placeholder when no target owns it', () {
      final orphan = project.newObject((g, u) => XCConfigurationList(g, u));
      expect(
        orphan.asciiPlistAnnotation,
        ' Build configuration list for <deleted target> ',
      );
    });
  });

  group('toAsciiPlist', () {
    test(
      'annotates object references only, with the referenced annotation',
      () {
        final target = addTarget('App');
        final hash = target.toAsciiPlistHash();
        final list = target.buildConfigurationList!;
        expect(
          hash['buildConfigurationList'],
          AnnotatedString(
            list.uuid,
            ' Build configuration list for PBXNativeTarget "App" ',
          ),
        );
        // Plain attributes stay plain.
        expect(hash['name'], 'App');
        expect(hash['isa'], 'PBXNativeTarget');
        // To-many references are lists of annotated strings.
        expect(hash['buildPhases'], isA<List<dynamic>>());
      },
    );

    test('toAsciiPlist carries the object\'s own annotation', () {
      final target = addTarget('App');
      expect(target.toAsciiPlist().annotation, ' App ');
      expect(project.mainGroup.toAsciiPlist().annotation, isNull);
    });

    test('toHash is unchanged and holds plain UUID strings', () {
      final target = addTarget('App');
      expect(
        target.toHash()['buildConfigurationList'],
        target.buildConfigurationList!.uuid,
      );
    });

    test('a string attribute holding a UUID is never annotated', () async {
      final target = addTarget('App');
      final other = addTarget('Other');
      final proxy = project.newObject((g, u) => PBXContainerItemProxy(g, u))
        ..containerPortal = project.rootObject.uuid
        ..proxyType = '1'
        ..remoteGlobalIDString = other.uuid
        ..remoteInfo = 'Other';
      final dependency = project.newObject((g, u) => PBXTargetDependency(g, u))
        ..target = other
        ..targetProxy = proxy;
      target.dependencies.add(dependency);

      expect(proxy.toAsciiPlistHash()['remoteGlobalIDString'], other.uuid);

      await project.save();
      final text = File('${project.path}/project.pbxproj').readAsStringSync();
      expect(text, contains('remoteGlobalIDString = ${other.uuid};'));
      // The reference to the same object is annotated.
      expect(text, contains('target = ${other.uuid} /* Other */;'));
      expect(
        text,
        contains(
          'containerPortal = ${project.rootObject.uuid} /* Project object */;',
        ),
      );
    });

    test('a remote container portal is annotated with its file name', () {
      final file = project.newObject((g, u) => PBXFileReference(g, u))
        ..path = 'Sub/Other.xcodeproj'
        ..sourceTree = '<group>';
      project.mainGroup.children.add(file);
      final proxy = project.newObject((g, u) => PBXContainerItemProxy(g, u))
        ..containerPortal = file.uuid
        ..proxyType = '2'
        ..remoteGlobalIDString = 'ABC'
        ..remoteInfo = 'X';
      final portal = proxy.toAsciiPlistHash()['containerPortal'];
      expect(portal, AnnotatedString(file.uuid, ' Other.xcodeproj '));
    });
  });

  group('file-system-synchronized groups', () {
    test('annotations follow the folder, target and build phase', () async {
      final target = addTarget('App');
      final folder = project.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      )..path = 'Sources';
      project.mainGroup.children.add(folder);
      final buildFileSet = project.newObject(
        (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
      )..target = target;
      final phase = project.newObject((g, u) => PBXCopyFilesBuildPhase(g, u))
        ..name = 'Copy Headers';
      target.buildPhases.add(phase);
      final membershipSet = project.newObject(
        (g, u) =>
            PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
              g,
              u,
            ),
      )..buildPhase = phase;
      folder.exceptions
        ..add(buildFileSet)
        ..add(membershipSet);

      expect(folder.asciiPlistAnnotation, ' Sources ');
      expect(
        buildFileSet.asciiPlistAnnotation,
        ' Exceptions for "Sources" folder in "App" target ',
      );
      expect(
        membershipSet.asciiPlistAnnotation,
        ' Exceptions for "Sources" folder in "Copy Headers" build phase ',
      );

      await project.save();
      final text = File('${project.path}/project.pbxproj').readAsStringSync();
      expect(text, contains('${folder.uuid} /* Sources */ = {'));
      expect(
        text,
        contains(
          '${buildFileSet.uuid} /* Exceptions for "Sources" folder in "App" '
          'target */ = {',
        ),
      );
      expect(
        text,
        contains(
          '${membershipSet.uuid} /* Exceptions for "Sources" folder in '
          '"Copy Headers" build phase */,',
        ),
      );
    });

    test('detached sets fall back to the ISA-derived name', () {
      final folder = project.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      expect(folder.displayName, 'FileSystemSynchronizedRootGroup');
      final buildFileSet = project.newObject(
        (g, u) => PBXFileSystemSynchronizedBuildFileExceptionSet(g, u),
      );
      expect(
        buildFileSet.displayName,
        'FileSystemSynchronizedBuildFileExceptionSet',
      );
      final membershipSet = project.newObject(
        (g, u) =>
            PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
              g,
              u,
            ),
      );
      expect(
        membershipSet.displayName,
        'FileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet',
      );
    });
  });
}
