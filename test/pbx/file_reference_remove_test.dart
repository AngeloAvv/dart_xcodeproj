// Regression tests for PBXFileReference.buildFiles / removeFromProject
// (issue #8): removing a file reference also removes its build files.

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
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
  group('PBXFileReference.removeFromProject (issue #8)', () {
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

    PBXFileReference newRef(String uuid) {
      final ref = PBXFileReference(graph, uuid);
      graph.objectsByUuid[ref.uuid] = ref;
      return ref;
    }

    PBXSourcesBuildPhase newPhase(String uuid) {
      final phase = PBXSourcesBuildPhase(graph, uuid);
      graph.objectsByUuid[phase.uuid] = phase;
      return phase;
    }

    test('buildFiles returns only the PBXBuildFile referrers', () {
      final ref = newRef('1' * 24);
      final a = newPhase('2' * 24).addFileReference(ref);
      final b = newPhase('3' * 24).addFileReference(ref);

      expect(ref.buildFiles, unorderedEquals([a, b]));
      expect(newRef('4' * 24).buildFiles, isEmpty);
    });

    test('removes every build file pointing to the reference', () {
      final ref = newRef('1' * 24);
      final phaseA = newPhase('2' * 24);
      final phaseB = newPhase('3' * 24);
      final a = phaseA.addFileReference(ref);
      final b = phaseB.addFileReference(ref);

      ref.removeFromProject();

      expect(phaseA.files, isEmpty);
      expect(phaseB.files, isEmpty);
      expect(phaseA.toHash()['files'], isEmpty);
      expect(phaseB.toHash()['files'], isEmpty);
      expect(ref.referrers, isEmpty);
      expect(graph.objectsByUuid.containsKey(ref.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(a.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(b.uuid), isFalse);
    });

    test('keeps the build files of other references', () {
      final removed = newRef('1' * 24);
      final kept = newRef('2' * 24);
      final phase = newPhase('3' * 24);
      phase.addFileReference(removed);
      final keptBuildFile = phase.addFileReference(kept);

      removed.removeFromProject();

      expect(phase.toHash()['files'], [keptBuildFile.uuid]);
      expect(keptBuildFile.fileRef, same(kept));
    });
  });

  group('removing file references of a pristine Flutter iOS project', () {
    late Directory tmp;
    late XcodeProject project;

    const removedNames = {
      'AppFrameworkInfo.plist', // Resources phase
      'Assets.xcassets', // Resources phase
      'AppDelegate.swift', // Sources phase
      'GeneratedPluginRegistrant.m', // Sources phase
    };

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('xcodeproj_remove_ref_');
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

    List<PBXFileReference> targets() => project.files
        .where((f) => removedNames.contains(f.displayName))
        .toList();

    test('leaves no build file without fileRef/productRef', () {
      expect(targets(), hasLength(removedNames.length));

      for (final ref in targets()) {
        ref.removeFromProject();
      }

      final buildFiles = project.objectsByUuid.values
          .whereType<PBXBuildFile>()
          .toList();
      expect(buildFiles, isNotEmpty);
      expect(
        buildFiles.where((b) => b.fileRef == null && b.productRef == null),
        isEmpty,
      );
    });

    test('leaves no phase entry pointing to a missing object', () {
      for (final ref in targets()) {
        ref.removeFromProject();
      }

      final phases = project.objectsByUuid.values
          .whereType<AbstractBuildPhase>()
          .toList();
      expect(phases, isNotEmpty);
      for (final phase in phases) {
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
      for (final ref in targets()) {
        ref.removeFromProject();
      }
      await project.save();

      final actual = File('${project.path}/project.pbxproj').readAsStringSync();
      final expected = File(
        'test/fixtures/flutter_ios_removed_refs.expected.pbxproj',
      ).readAsStringSync();
      expect(_withoutComments(actual), _withoutComments(expected));
      expect(actual, isNot(contains('isa = PBXBuildFile; }')));
    });
  });
}
