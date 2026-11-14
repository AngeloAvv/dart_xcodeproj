// Regression tests for PBXGroup.clear / removeChildrenRecursively /
// removeFromProject (issue #9): removing a group removes its descendants and
// every build file that points to the group or to them.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

/// Drops every `/* ... */` annotation: the comments Dart emits for unrelated
/// object kinds differ from Ruby's, which is out of scope for this issue.
String _withoutComments(String plist) =>
    plist.replaceAll(RegExp(r' ?/\*[^*]*\*/'), '');

void main() {
  group('PBXGroup removal (issue #9)', () {
    late MockObjectGraph graph;

    setUp(() {
      graph = MockObjectGraph();
      registerPhase3Types();
      registerPhase4Types();
    });

    tearDown(() {
      graph.reset();
      isaRegistry.clear();
    });

    T add<T extends Object>(T obj) {
      final o = obj as dynamic;
      graph.objectsByUuid[o.uuid as String] = o;
      return obj;
    }

    PBXGroup newGroup(String uuid) => add(PBXGroup(graph, uuid));
    PBXVariantGroup newVariant(String uuid) =>
        add(PBXVariantGroup(graph, uuid));
    PBXFileReference newRef(String uuid) => add(PBXFileReference(graph, uuid));
    PBXResourcesBuildPhase newPhase(String uuid) =>
        add(PBXResourcesBuildPhase(graph, uuid));

    test('buildFiles returns only the PBXBuildFile referrers', () {
      final group = newVariant('1' * 24);
      final buildFile = newPhase('2' * 24).addFileReference(group);
      newGroup('3' * 24).children.add(group);

      expect(group.buildFiles, [buildFile]);
      expect(newGroup('4' * 24).buildFiles, isEmpty);
    });

    test('clear removes every descendant and its build files', () {
      final root = newGroup('1' * 24);
      final sub = newGroup('2' * 24);
      final refA = newRef('3' * 24);
      final refB = newRef('4' * 24);
      root.children
        ..add(sub)
        ..add(refA);
      sub.children.add(refB);
      final phase = newPhase('5' * 24);
      final bfA = phase.addFileReference(refA);
      final bfB = phase.addFileReference(refB);

      root.clear();

      expect(root.children, isEmpty);
      expect(root.toHash()['children'], isEmpty);
      expect(phase.files, isEmpty);
      for (final uuid in [sub.uuid, refA.uuid, refB.uuid, bfA.uuid, bfB.uuid]) {
        expect(graph.objectsByUuid.containsKey(uuid), isFalse, reason: uuid);
      }
      // The group itself stays in the project.
      expect(graph.objectsByUuid.containsKey(root.uuid), isTrue);
    });

    test('removeChildrenRecursively is an alias of clear', () {
      final root = newGroup('1' * 24);
      final ref = newRef('2' * 24);
      root.children.add(ref);
      final bf = newPhase('3' * 24).addFileReference(ref);

      root.removeChildrenRecursively();

      expect(root.children, isEmpty);
      expect(graph.objectsByUuid.containsKey(ref.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(bf.uuid), isFalse);
    });

    test('removeFromProject removes descendants and their build files', () {
      final parent = newGroup('1' * 24);
      final root = newGroup('2' * 24);
      final sub = newGroup('3' * 24);
      final ref = newRef('4' * 24);
      final keptRef = newRef('5' * 24);
      parent.children
        ..add(root)
        ..add(keptRef);
      root.children.add(sub);
      sub.children.add(ref);
      final phase = newPhase('6' * 24);
      phase.addFileReference(ref);
      final keptBuildFile = phase.addFileReference(keptRef);

      root.removeFromProject();

      expect(parent.children.toList(), [keptRef]);
      expect(phase.toHash()['files'], [keptBuildFile.uuid]);
      expect(graph.objectsByUuid.containsKey(root.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(sub.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(ref.uuid), isFalse);
      expect(root.referrers, isEmpty);
    });

    test('removing a variant group leaves no dangling build file', () {
      final parent = newGroup('1' * 24);
      final variant = newVariant('2' * 24);
      final base = newRef('3' * 24);
      parent.children.add(variant);
      variant.children.add(base);
      final phase = newPhase('4' * 24);
      final buildFile = phase.addFileReference(variant);

      variant.removeFromProject();

      expect(parent.children, isEmpty);
      expect(phase.files, isEmpty);
      expect(phase.toHash()['files'], isEmpty);
      expect(graph.objectsByUuid.containsKey(variant.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(base.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(buildFile.uuid), isFalse);
    });

    test('removing a version group removes its children and build files', () {
      final parent = newGroup('1' * 24);
      final version = add(XCVersionGroup(graph, '2' * 24));
      final model = newRef('3' * 24);
      parent.children.add(version);
      version.children.add(model);
      version.currentVersion = model;
      final phase = newPhase('4' * 24);
      phase.addFileReference(version);

      version.removeFromProject();

      expect(phase.files, isEmpty);
      expect(parent.children, isEmpty);
      expect(graph.objectsByUuid.containsKey(version.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(model.uuid), isFalse);
    });
  });

  group('removing variant groups of a pristine Flutter iOS project', () {
    late Directory tmp;
    late XcodeProject project;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('xcodeproj_remove_group_');
      final bundle = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
      File(
        'test/fixtures/flutter_ios_pristine.pbxproj',
      ).copySync('${bundle.path}/project.pbxproj');
      project = await XcodeProject.open(bundle.path);
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    List<PBXVariantGroup> variantGroups() =>
        project.objectsByUuid.values.whereType<PBXVariantGroup>().toList();

    test('the storyboards are variant groups used by the Resources phase', () {
      final groups = variantGroups();
      expect(groups.map((g) => g.displayName).toSet(), {
        'Main.storyboard',
        'LaunchScreen.storyboard',
      });
      for (final group in groups) {
        expect(group.buildFiles, hasLength(1));
      }
    });

    test('leaves no dangling build file or phase entry', () {
      final childUuids = [
        for (final g in variantGroups()) ...g.children.map((c) => c.uuid),
      ];
      expect(childUuids, isNotEmpty);

      for (final group in variantGroups()) {
        group.removeFromProject();
      }

      expect(variantGroups(), isEmpty);
      for (final uuid in childUuids) {
        expect(project.objectsByUuid.containsKey(uuid), isFalse);
      }
      expect(
        project.objectsByUuid.values.whereType<PBXBuildFile>().where(
          (b) => b.fileRef is PBXGroup,
        ),
        isEmpty,
      );
      for (final phase
          in project.objectsByUuid.values.whereType<AbstractBuildPhase>()) {
        for (final uuid in (phase.toHash()['files'] as List).cast<String>()) {
          expect(
            project.objectsByUuid.containsKey(uuid),
            isTrue,
            reason: '${phase.isa} ${phase.uuid} lists missing object $uuid',
          );
        }
      }
    });

    test('saved output matches the Ruby gem output', () async {
      for (final group in variantGroups()) {
        group.removeFromProject();
      }
      await project.save();

      final actual = File('${project.path}/project.pbxproj').readAsStringSync();
      final expected = File(
        'test/fixtures/flutter_ios_removed_variant_groups.expected.pbxproj',
      ).readAsStringSync();
      expect(_withoutComments(actual), _withoutComments(expected));
    });
  });
}
