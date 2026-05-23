// Tests for GroupableHelper — covers group traversal and move semantics.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/groupable_helper.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXGroup'] = (g, u) => PBXGroup(g, u);
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // parent()
  // ---------------------------------------------------------------------------
  group('GroupableHelper.parent', () {
    test(
      'GroupableHelper.parent returns the PBXGroup that contains the object',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final subGroup = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[subGroup.uuid] = subGroup;
        mainGroup.children.add(subGroup);

        final parent = GroupableHelper.parent(subGroup);
        expect(parent, same(mainGroup));
      },
    );

    test(
      'GroupableHelper.parent returns null when object has no parent group',
      () {
        final orphan = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[orphan.uuid] = orphan;

        final parent = GroupableHelper.parent(orphan);
        expect(parent, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // parents()
  // ---------------------------------------------------------------------------
  group('GroupableHelper.parents', () {
    test(
      'GroupableHelper.parents returns ancestors ordered from immediate parent to mainGroup',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final midGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final leafGroup = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[midGroup.uuid] = midGroup;
        graph.objectsByUuid[leafGroup.uuid] = leafGroup;
        mainGroup.children.add(midGroup);
        midGroup.children.add(leafGroup);

        final parents = GroupableHelper.parents(leafGroup);
        // Should be [midGroup, mainGroup] — immediate parent first
        expect(parents.length, equals(2));
        expect(parents[0], same(midGroup));
        expect(parents[1], same(mainGroup));
      },
    );

    test(
      'GroupableHelper.parents returns empty list when object has no parent',
      () {
        final orphan = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[orphan.uuid] = orphan;

        final parents = GroupableHelper.parents(orphan);
        expect(parents, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // hierarchyPath()
  // ---------------------------------------------------------------------------
  group('GroupableHelper.hierarchyPath', () {
    test(
      'GroupableHelper.hierarchyPath returns "/" + slash-joined displayNames from mainGroup down to the object',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final subGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[subGroup.uuid] = subGroup;
        graph.objectsByUuid[fileRef.uuid] = fileRef;

        subGroup.name = 'Sources';
        fileRef.name = 'main.swift';
        mainGroup.children.add(subGroup);
        subGroup.children.add(fileRef);

        final path = GroupableHelper.hierarchyPath(fileRef);
        // Should be '/Sources/main.swift' (main group skipped)
        expect(path, equals('/Sources/main.swift'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // isMainGroup()
  // ---------------------------------------------------------------------------
  group('GroupableHelper.isMainGroup', () {
    test(
      'GroupableHelper.isMainGroup returns true when the object IS the project mainGroup; works without PBXProject by treating top-level group as main',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        // Main group has no parent → isMainGroup returns true
        expect(GroupableHelper.isMainGroup(mainGroup), isTrue);
      },
    );

    test(
      'GroupableHelper.isMainGroup returns false when group has a parent',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final childGroup = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[childGroup.uuid] = childGroup;
        mainGroup.children.add(childGroup);

        expect(GroupableHelper.isMainGroup(childGroup), isFalse);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // move() — self-reference guard
  // ---------------------------------------------------------------------------
  group('GroupableHelper.move self-reference guard', () {
    test(
      'GroupableHelper.move(self, self) throws ArgumentError "Cannot move ... into itself"',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[group.uuid] = group;

        expect(
          () => GroupableHelper.move(group, group),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message.toString(),
              'message',
              contains('Cannot move'),
            ),
          ),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // move() — ancestor cycle guard
  // ---------------------------------------------------------------------------
  group('GroupableHelper.move ancestor-cycle guard', () {
    test(
      'GroupableHelper.move(parentGroup, childOfParent) throws ArgumentError "Cannot move ... into one of its descendants"',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final childGroup = graph.newObject((g, u) => PBXGroup(g, u));
        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[childGroup.uuid] = childGroup;
        mainGroup.children.add(childGroup);

        // Attempt to move mainGroup into childGroup (its descendant)
        expect(
          () => GroupableHelper.move(mainGroup, childGroup),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message.toString(),
              'message',
              contains('Cannot move'),
            ),
          ),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // move() — valid move
  // ---------------------------------------------------------------------------
  group('GroupableHelper.move valid move', () {
    test(
      'GroupableHelper.move removes from current parent.children and adds to newParent.children with correct ref counts',
      () {
        final mainGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final sourceGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final targetGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));

        graph.objectsByUuid[mainGroup.uuid] = mainGroup;
        graph.objectsByUuid[sourceGroup.uuid] = sourceGroup;
        graph.objectsByUuid[targetGroup.uuid] = targetGroup;
        graph.objectsByUuid[fileRef.uuid] = fileRef;

        mainGroup.children.add(sourceGroup);
        mainGroup.children.add(targetGroup);
        sourceGroup.children.add(fileRef);

        expect(sourceGroup.children.length, equals(1));
        expect(targetGroup.children.length, equals(0));

        GroupableHelper.move(fileRef, targetGroup);

        expect(sourceGroup.children.length, equals(0));
        expect(targetGroup.children.length, equals(1));
        expect(targetGroup.children.first, same(fileRef));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // realPath ( — TDD RED)
  // ---------------------------------------------------------------------------
  group('realPath', () {
    late XcodeProject project;
    late PBXFileReference ref;

    setUp(() async {
      registerPhase3Types();
      registerPhase4Types();
      project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
      ref = project.newObject((g, u) => PBXFileReference(g, u));
      project.mainGroup.children.add(ref);
      ref.path = 'main.swift';
    });

    tearDown(() {
      isaRegistry.clear();
    });

    test('SOURCE_ROOT returns projectDir joined with path', () {
      ref.sourceTree = 'SOURCE_ROOT';
      ref.path = 'main.swift';
      final result = GroupableHelper.realPath(ref, project);
      expect(result, equals(p.join(project.projectDir, 'main.swift')));
    });

    test('<absolute> returns path as-is', () {
      ref.sourceTree = '<absolute>';
      ref.path = '/Users/dev/main.swift';
      final result = GroupableHelper.realPath(ref, project);
      expect(result, equals('/Users/dev/main.swift'));
    });

    test(
      '<group> with PBXGroup parent returns parent realPath joined with path',
      () {
        // ref is child of mainGroup (PBXGroup); mainGroup parent is PBXProject
        ref.sourceTree = '<group>';
        ref.path = 'main.swift';
        final result = GroupableHelper.realPath(ref, project);
        // mainGroup has no path set, so its realPath = projectDir
        expect(result, equals(p.join(project.projectDir, 'main.swift')));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // setSourceTree ( — TDD RED)
  // ---------------------------------------------------------------------------
  group('setSourceTree', () {
    late XcodeProject project;
    late PBXFileReference ref;

    setUp(() async {
      registerPhase3Types();
      registerPhase4Types();
      project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
      ref = project.newObject((g, u) => PBXFileReference(g, u));
    });

    tearDown(() {
      isaRegistry.clear();
    });

    test("'project' sets sourceTree = 'SOURCE_ROOT'", () {
      GroupableHelper.setSourceTree(ref, 'project');
      expect(ref.sourceTree, equals('SOURCE_ROOT'));
    });

    test("'group' sets sourceTree = '<group>'", () {
      GroupableHelper.setSourceTree(ref, 'group');
      expect(ref.sourceTree, equals('<group>'));
    });

    test("'absolute' sets sourceTree = '<absolute>'", () {
      GroupableHelper.setSourceTree(ref, 'absolute');
      expect(ref.sourceTree, equals('<absolute>'));
    });
  });
}
