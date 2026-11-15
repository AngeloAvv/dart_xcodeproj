// Regression tests for the generic AbstractObject.removeReference mechanism.
//
// None of these tests rely on `assert`: every check is an explicit `expect`,
// so the behaviour is identical with asserts enabled and disabled
// (`dart test --enable-asserts` vs. `dart run` / `dart compile`).

import 'dart:convert';

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_dictionary.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_phase.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

/// Minimal concrete object declaring one attribute of each kind, to exercise
/// the generic [AbstractObject.removeReference] in isolation.
class _Holder extends AbstractObject {
  _Holder(super.project, super.uuid);

  AbstractObject? _single;
  AbstractObject? get single => _single;
  set single(AbstractObject? value) {
    if (identical(_single, value)) return;
    _single?.removeReferrer(this);
    _single = value;
    value?.addReferrer(this);
  }

  late final ObjectList<AbstractObject> many = ObjectList<AbstractObject>(this);

  late final ObjectList<ObjectDictionary> dictionaries =
      ObjectList<ObjectDictionary>(this);

  @override
  String get isa => 'PBXHolder';

  @override
  List<ToOneAttribute> get toOneAttributes => [
    ToOneAttribute(get: () => single, set: (v) => single = v),
  ];

  @override
  List<ObjectList<Object>> get toManyAttributes => [many];

  @override
  List<ObjectList<ObjectDictionary>> get referencesByKeysAttributes => [
    dictionaries,
  ];
}

/// Candidate plist values for an attribute: a to-one UUID, a to-many list of
/// UUIDs and a list of reference dictionaries (`projectReferences`).
List<Object> _valueForms(String uuid) => [
  uuid,
  [uuid],
  [
    {'ProductGroup': uuid, 'ProjectRef': uuid},
  ],
];

void main() {
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

  group('AbstractObject.removeReference (generic)', () {
    test('clears to-one attributes pointing to the object', () {
      final holder = _Holder(graph, 'A' * 24);
      final child = PBXFileReference(graph, 'B' * 24);
      holder.single = child;

      child.removeFromProject();

      expect(holder.single, isNull);
      expect(child.referrers, isEmpty);
      expect(graph.objectsByUuid.containsKey(child.uuid), isFalse);
    });

    test('keeps to-one attributes pointing to other objects', () {
      final holder = _Holder(graph, 'A' * 24);
      final kept = PBXFileReference(graph, 'B' * 24);
      final removed = PBXFileReference(graph, 'C' * 24);
      holder.single = kept;
      holder.many.add(removed);

      removed.removeFromProject();

      expect(holder.single, same(kept));
      expect(holder.many, isEmpty);
    });

    test('removes the object from to-many attributes', () {
      final holder = _Holder(graph, 'A' * 24);
      final first = PBXFileReference(graph, 'B' * 24);
      final second = PBXFileReference(graph, 'C' * 24);
      holder.many.addAll([first, second]);

      first.removeFromProject();

      expect(holder.many.toList(), [second]);
      expect(holder.toHash().toString(), isNot(contains(first.uuid)));
    });

    test('removes every occurrence of a repeated object', () {
      final holder = _Holder(graph, 'A' * 24);
      final repeated = PBXFileReference(graph, 'B' * 24);
      final other = PBXFileReference(graph, 'C' * 24);
      holder.many.addAll([repeated, other, repeated]);

      repeated.removeFromProject();

      expect(holder.many.toList(), [other]);
      expect(holder.toHash().toString(), isNot(contains(repeated.uuid)));
      expect(repeated.referrers, isEmpty);
    });

    test('removes the object from references-by-keys dictionaries', () {
      final holder = _Holder(graph, 'A' * 24);
      final group = PBXFileReference(graph, 'B' * 24);
      final dictionary = ObjectDictionary({
        'ProjectRef': PBXFileReference,
      }, holder);
      dictionary['ProjectRef'] = group;
      holder.dictionaries.add(dictionary);

      holder.removeReference(group);

      expect(dictionary['ProjectRef'], isNull);
    });
  });

  group('PBXBuildFile.removeFromProject (issue #11)', () {
    test('drops the build file UUID from the owning build phase', () {
      final phase = PBXSourcesBuildPhase(graph, '1' * 24);
      graph.objectsByUuid[phase.uuid] = phase;
      final fileRef = PBXFileReference(graph, '2' * 24);
      graph.objectsByUuid[fileRef.uuid] = fileRef;
      final buildFile = phase.addFileReference(fileRef);

      buildFile.removeFromProject();

      expect(phase.files, isEmpty);
      expect(phase.toHash()['files'], isEmpty);
      expect(buildFile.referrers, isEmpty);
      expect(graph.objectsByUuid.containsKey(buildFile.uuid), isFalse);
    });

    test('drops a build file listed twice in the same phase', () {
      final phase = PBXSourcesBuildPhase(graph, '1' * 24);
      graph.objectsByUuid[phase.uuid] = phase;
      final buildFile = phase.addFileReference(
        PBXFileReference(graph, '2' * 24),
      );
      phase.files.add(buildFile);
      expect(phase.toHash()['files'], [buildFile.uuid, buildFile.uuid]);

      buildFile.removeFromProject();

      expect(phase.files, isEmpty);
      expect(phase.toHash()['files'], isEmpty);
      expect(buildFile.referrers, isEmpty);
    });

    test('keeps the remaining build files in the phase', () {
      final phase = PBXSourcesBuildPhase(graph, '1' * 24);
      graph.objectsByUuid[phase.uuid] = phase;
      final a = phase.addFileReference(PBXFileReference(graph, '2' * 24));
      final b = phase.addFileReference(PBXFileReference(graph, '3' * 24));

      a.removeFromProject();

      expect(phase.toHash()['files'], [b.uuid]);
    });

    test('removing a phase drops it from the target build phases', () {
      final target = PBXNativeTarget(graph, '4' * 24);
      graph.objectsByUuid[target.uuid] = target;
      final phase = PBXFrameworksBuildPhase(graph, '5' * 24);
      target.buildPhases.add(phase);

      phase.removeFromProject();

      expect(target.toHash()['buildPhases'], isEmpty);
    });
  });

  group('no dangling UUIDs after removing a referenced child', () {
    // Black-box enumeration: for every registered class (the owner), every
    // attribute key it declares, and every registered class (the child), load
    // the child into the owner through `readAttribute`. Whenever that creates
    // a reference (observed through the child's referrers), remove the child
    // from the project and require that the owner no longer serializes the
    // child's UUID. No knowledge of the attribute declarations is used, so a
    // class that forgets to drop a reference makes this test fail.
    test('for every object class, attribute and referenced child class', () {
      final covered = <String>{};
      final failures = <String>[];

      for (final ownerIsa in isaRegistry.keys.toList()) {
        final probe = isaRegistry[ownerIsa]!(MockObjectGraph(), '0' * 24);
        for (final key in probe.attributeOrder) {
          for (final childIsa in isaRegistry.keys.toList()) {
            for (final form in _valueForms('F' * 24)) {
              final g = MockObjectGraph();
              final owner = isaRegistry[ownerIsa]!(g, 'E' * 24);
              g.objectsByUuid[owner.uuid] = owner;
              final plist = <String, dynamic>{
                owner.uuid: {'isa': ownerIsa},
                'F' * 24: {'isa': childIsa},
              };
              try {
                owner.readAttribute(key, form, plist);
              } catch (_) {
                continue; // the value form does not fit this attribute
              }
              final child = g.objectsByUuid['F' * 24];
              if (child == null || !child.referrers.contains(owner)) continue;

              covered.add('$ownerIsa.$key');
              final where = '$ownerIsa.$key -> $childIsa';

              child.removeFromProject();

              if (jsonEncode(owner.toHash()).contains(child.uuid)) {
                failures.add('$where: dangling UUID in toHash()');
              }
              if (child.referrers.isNotEmpty) {
                failures.add('$where: child still has referrers');
              }
              if (g.objectsByUuid.containsKey(child.uuid)) {
                failures.add('$where: child still registered in the graph');
              }
            }
          }
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
      // Sanity: the enumeration really reached the relevant attributes.
      expect(
        covered,
        containsAll(<String>[
          'PBXSourcesBuildPhase.files',
          'PBXFrameworksBuildPhase.files',
          'PBXResourcesBuildPhase.files',
          'PBXCopyFilesBuildPhase.files',
          'PBXShellScriptBuildPhase.files',
          'PBXHeadersBuildPhase.files',
          'PBXRezBuildPhase.files',
          'PBXBuildFile.fileRef',
          'PBXGroup.children',
          'PBXNativeTarget.buildPhases',
          'PBXNativeTarget.dependencies',
          'PBXProject.targets',
          'PBXProject.mainGroup',
          'PBXProject.projectReferences',
          'XCConfigurationList.buildConfigurations',
        ]),
      );
    });
  });

  test('build file removal is serialized without dangling UUIDs', () {
    final project = PBXProject(graph, '9' * 24);
    graph.objectsByUuid[project.uuid] = project;
    final target = PBXNativeTarget(graph, '8' * 24);
    project.targets.add(target);
    final phase = PBXSourcesBuildPhase(graph, '7' * 24);
    target.buildPhases.add(phase);
    final buildFile = phase.addFileReference(PBXFileReference(graph, '6' * 24));
    final removed = buildFile.uuid;

    buildFile.removeFromProject();

    final serialized = jsonEncode([
      for (final o in graph.objectsByUuid.values) o.toHash(),
    ]);
    expect(serialized, isNot(contains(removed)));
    expect(graph.objectsByUuid.containsKey(removed), isFalse);
    expect(graph.objectsByUuid.values.whereType<PBXBuildFile>(), isEmpty);
  });
}
