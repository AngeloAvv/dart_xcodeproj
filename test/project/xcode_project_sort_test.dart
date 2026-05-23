// Tests for XcodeProject.sort(), toHash(), toTreeHash(), prettyPrint()
// and PBXGroup.sort() with GroupsPosition enum.
// TDD RED phase — these tests MUST FAIL before implementation.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/project/groups_position.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  group('XcodeProject.sort', () {
    late XcodeProject project;

    setUp(() async {
      registerPhase3Types();
      registerPhase4Types();
      project = await XcodeProject.create('/tmp/SortTest.xcodeproj');
    });

    tearDown(() {
      isaRegistry.clear();
    });

    // -------------------------------------------------------------------------
    // Helpers: add a named file ref or named group to a group
    // -------------------------------------------------------------------------

    PBXFileReference addFile(PBXGroup parent, String name) {
      final ref = project.newObject((g, u) => PBXFileReference(g, u));
      ref.name = name;
      ref.path = name;
      ref.sourceTree = '<group>';
      parent.children.add(ref);
      return ref;
    }

    PBXGroup addGroup(PBXGroup parent, String name) {
      final grp = project.newObject((g, u) => PBXGroup(g, u));
      grp.name = name;
      parent.children.add(grp);
      return grp;
    }

    // -------------------------------------------------------------------------
    // GroupsPosition.above: groups come before files
    // -------------------------------------------------------------------------

    test(
      'sort(groupsPosition: GroupsPosition.above): groups before files in mainGroup',
      () {
        // Arrange: add files first so they're ahead of groups in insertion order
        addFile(project.mainGroup, 'bravo.swift');
        addGroup(project.mainGroup, 'Alpha');
        addFile(project.mainGroup, 'charlie.swift');
        addGroup(project.mainGroup, 'Zulu');

        // Act
        project.sort(groupsPosition: GroupsPosition.above);

        // Assert: all PBXGroup children appear before all PBXFileReference children
        final children = project.mainGroup.children.toList();
        // All groups (non-PBXFileReference) should be before all PBXFileReferences
        final groups = children.whereType<PBXGroup>().toList();
        final files = children.whereType<PBXFileReference>().toList();
        if (groups.isNotEmpty && files.isNotEmpty) {
          final lastGroupIdx = children.indexOf(groups.last);
          final firstFileIdx = children.indexOf(files.first);
          expect(
            lastGroupIdx,
            lessThan(firstFileIdx),
            reason:
                'All groups should appear before all files with GroupsPosition.above',
          );
        }
      },
    );

    test(
      'sort(groupsPosition: GroupsPosition.below): files before groups in mainGroup',
      () {
        // Arrange
        addGroup(project.mainGroup, 'Alpha');
        addFile(project.mainGroup, 'bravo.swift');
        addGroup(project.mainGroup, 'Zulu');
        addFile(project.mainGroup, 'charlie.swift');

        // Act
        project.sort(groupsPosition: GroupsPosition.below);

        // Assert: all PBXFileReference children appear before all PBXGroup children
        final children = project.mainGroup.children.toList();
        final groups = children.whereType<PBXGroup>().toList();
        final files = children.whereType<PBXFileReference>().toList();
        if (groups.isNotEmpty && files.isNotEmpty) {
          final lastFileIdx = children.indexOf(files.last);
          final firstGroupIdx = children.indexOf(groups.first);
          expect(
            lastFileIdx,
            lessThan(firstGroupIdx),
            reason:
                'All files should appear before all groups with GroupsPosition.below',
          );
        }
      },
    );

    test('sort() with no argument sorts by name only (interleaved)', () {
      // Arrange: add in non-alphabetical order
      addFile(project.mainGroup, 'Zulu.swift');
      addGroup(project.mainGroup, 'Alpha');
      addFile(project.mainGroup, 'bravo.swift');
      addGroup(project.mainGroup, 'middle');

      // Act: null groupsPosition
      project.sort();

      // Assert: sorted alphabetically by display name (case-insensitive), interleaved
      final children = project.mainGroup.children.toList();
      // The order should be: Alpha, bravo, middle, ..., Zulu
      // (case-insensitive: alpha < bravo < middle < zulu)
      // Also includes Products and Frameworks groups from create()
      // Check that among the children we added, the relative order is alphabetical
      final alpha = children.indexWhere(
        (c) => c is PBXGroup && c.name == 'Alpha',
      );
      final bravo = children.indexWhere(
        (c) => c is PBXFileReference && c.name == 'bravo.swift',
      );
      final mid = children.indexWhere(
        (c) => c is PBXGroup && c.name == 'middle',
      );
      final zulu = children.indexWhere(
        (c) => c is PBXFileReference && c.name == 'Zulu.swift',
      );
      expect(alpha, lessThan(bravo));
      expect(bravo, lessThan(mid));
      expect(mid, lessThan(zulu));
    });

    test('sort() is recursive — children of children are also sorted', () {
      // Arrange: create a subgroup with unsorted children
      final subGroup = addGroup(project.mainGroup, 'SubGroup');
      addFile(subGroup, 'zeta.swift');
      addFile(subGroup, 'alpha.swift');

      // Act
      project.sort();

      // Assert: subGroup children are sorted
      final subChildren = subGroup.children.toList();
      expect(subChildren.length, greaterThanOrEqualTo(2));
      // alpha < zeta
      final alphaIdx = subChildren.indexWhere(
        (c) => c is PBXFileReference && c.name == 'alpha.swift',
      );
      final zetaIdx = subChildren.indexWhere(
        (c) => c is PBXFileReference && c.name == 'zeta.swift',
      );
      expect(
        alphaIdx,
        lessThan(zetaIdx),
        reason: 'Recursive sort should sort children of subgroups',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // toHash / toTreeHash / prettyPrint
  // ---------------------------------------------------------------------------

  group('XcodeProject representations', () {
    late XcodeProject project;

    setUp(() async {
      registerPhase3Types();
      registerPhase4Types();
      project = await XcodeProject.create('/tmp/RepTest.xcodeproj');
    });

    tearDown(() {
      isaRegistry.clear();
    });

    // toHash
    test(
      "project.toHash() has keys: 'objects', 'archiveVersion', 'objectVersion', 'classes', 'rootObject'",
      () {
        final hash = project.toHash();
        expect(hash.containsKey('objects'), isTrue);
        expect(hash.containsKey('archiveVersion'), isTrue);
        expect(hash.containsKey('objectVersion'), isTrue);
        expect(hash.containsKey('classes'), isTrue);
        expect(hash.containsKey('rootObject'), isTrue);
      },
    );

    test("project.toHash()['rootObject'] is a String (UUID)", () {
      final hash = project.toHash();
      expect(hash['rootObject'], isA<String>());
    });

    test("project.toHash()['objects'] is a Map with one entry per object", () {
      final hash = project.toHash();
      final objs = hash['objects'] as Map;
      expect(objs.length, equals(project.objectsByUuid.length));
    });

    // toTreeHash
    test("project.toTreeHash()['rootObject'] is a Map (expanded tree)", () {
      final tree = project.toTreeHash();
      expect(tree['rootObject'], isA<Map<dynamic, dynamic>>());
    });

    test(
      "project.toTreeHash()['objects'] is empty (objects omitted in tree)",
      () {
        final tree = project.toTreeHash();
        final objs = tree['objects'] as Map;
        expect(objs, isEmpty);
      },
    );

    // prettyPrint
    test(
      "project.prettyPrint() keys are 'File References', 'Targets', 'Build Configurations'",
      () {
        final pp = project.prettyPrint();
        expect(pp.containsKey('File References'), isTrue);
        expect(pp.containsKey('Targets'), isTrue);
        expect(pp.containsKey('Build Configurations'), isTrue);
      },
    );

    test("project.prettyPrint()['Targets'] is a List", () {
      final pp = project.prettyPrint();
      expect(pp['Targets'], isA<List<dynamic>>());
    });

    test("project.prettyPrint()['Build Configurations'] is a List", () {
      final pp = project.prettyPrint();
      expect(pp['Build Configurations'], isA<List<dynamic>>());
    });
  });

  // ---------------------------------------------------------------------------
  // GroupsPosition enum
  // ---------------------------------------------------------------------------

  group('GroupsPosition enum', () {
    test('GroupsPosition.above and GroupsPosition.below exist', () {
      expect(GroupsPosition.above, isNotNull);
      expect(GroupsPosition.below, isNotNull);
    });
  });
}
