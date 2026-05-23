// Tests for PBXGroup — covers PBX-07.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXGroup'] = (g, u) => PBXGroup(g, u);
    isaRegistry['PBXVariantGroup'] = (g, u) => PBXVariantGroup(g, u);
    isaRegistry['XCVersionGroup'] = (g, u) => XCVersionGroup(g, u);
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXGroup ISA (PBX-07)', () {
    test('PBXGroup has isa "PBXGroup"', () {
      final group = graph.newObject((g, u) => PBXGroup(g, u));
      expect(group.isa, equals('PBXGroup'));
      expect(PBXGroup.isaStatic, equals('PBXGroup'));
    });
  });

  // ---------------------------------------------------------------------------
  // children ObjectList
  // ---------------------------------------------------------------------------
  group('PBXGroup children ObjectList (PBX-07)', () {
    test(
      'PBXGroup children is an ObjectList<AbstractObject> initialized empty',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        expect(group.children, isA<ObjectList>());
        expect(group.children, isEmpty);
      },
    );

    test(
      'PBXGroup ref counting on children: add a file ref via children.add, expect file.referrers contains group',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[fileRef.uuid] = fileRef;
        group.children.add(fileRef);
        expect(fileRef.referrers.contains(group), isTrue);
      },
    );

    test(
      'PBXGroup children are two separate instances per object (no sharing)',
      () {
        final group1 = graph.newObject((g, u) => PBXGroup(g, u));
        final group2 = graph.newObject((g, u) => PBXGroup(g, u));
        expect(group1.children, isNot(same(group2.children)));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('PBXGroup toHash serialization (PBX-07)', () {
    test(
      'PBXGroup serializes children as List of UUIDs: add a PBXFileReference child, call toHash, expect children is List<String> with 1 entry',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[fileRef.uuid] = fileRef;
        group.children.add(fileRef);
        final hash = group.toHash();
        expect(hash['children'], isA<List<dynamic>>());
        expect((hash['children'] as List).length, equals(1));
        expect((hash['children'] as List).first, equals(fileRef.uuid));
      },
    );

    test(
      'PBXGroup children always emits even when empty: new group, toHash, expect "children" key present with []',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final hash = group.toHash();
        expect(hash.containsKey('children'), isTrue);
        expect(hash['children'], equals(<String>[]));
      },
    );

    test('PBXGroup serializes name only when non-null', () {
      final group = graph.newObject((g, u) => PBXGroup(g, u));
      expect(group.toHash().containsKey('name'), isFalse);

      group.name = 'MyGroup';
      expect(group.toHash()['name'], equals('MyGroup'));
    });

    test('PBXGroup serializes path only when non-null', () {
      final group = graph.newObject((g, u) => PBXGroup(g, u));
      expect(group.toHash().containsKey('path'), isFalse);

      group.path = 'MyFolder';
      expect(group.toHash()['path'], equals('MyFolder'));
    });

    test(
      'PBXGroup sourceTree defaults to "<group>": initializeDefaults, expect sourceTree == "<group>"',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        expect(group.sourceTree, equals('<group>'));
        expect(group.toHash()['sourceTree'], equals('<group>'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // typed getters: groups / files / versionGroups
  // ---------------------------------------------------------------------------
  group('PBXGroup typed getters (PBX-07)', () {
    test(
      'PBXGroup.groups returns only runtimeType == PBXGroup (excludes PBXVariantGroup)',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final subGroup = graph.newObject((g, u) => PBXGroup(g, u));
        final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));
        graph.objectsByUuid[subGroup.uuid] = subGroup;
        graph.objectsByUuid[variantGroup.uuid] = variantGroup;
        group.children.add(subGroup);
        group.children.add(variantGroup);

        final groups = group.groups.toList();
        expect(groups, contains(subGroup));
        expect(groups, isNot(contains(variantGroup)));
        expect(groups.length, equals(1));
      },
    );

    test('PBXGroup.files returns whereType<PBXFileReference>()', () {
      final group = graph.newObject((g, u) => PBXGroup(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      final subGroup = graph.newObject((g, u) => PBXGroup(g, u));
      graph.objectsByUuid[fileRef.uuid] = fileRef;
      graph.objectsByUuid[subGroup.uuid] = subGroup;
      group.children.add(fileRef);
      group.children.add(subGroup);

      final files = group.files.toList();
      expect(files, contains(fileRef));
      expect(files, isNot(contains(subGroup)));
      expect(files.length, equals(1));
    });
  });

  // ---------------------------------------------------------------------------
  // displayName
  // ---------------------------------------------------------------------------
  group('PBXGroup displayName (PBX-07)', () {
    test(
      'PBXGroup.displayName returns name when set, else basename(path), else super.displayName',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        // No name, no path → super.displayName (isa or uuid)
        final defaultName = group.displayName;
        expect(defaultName, isNotEmpty);

        // Set path → basename
        group.path = 'some/folder/MyFolder';
        expect(group.displayName, equals('MyFolder'));

        // Set name → name takes priority
        group.name = 'OverrideName';
        expect(group.displayName, equals('OverrideName'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // attributeOrder
  // ---------------------------------------------------------------------------
  group('PBXGroup attributeOrder (PBX-07)', () {
    test(
      'PBXGroup attributeOrder is _ownAttributes ++ super.attributeOrder',
      () {
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final order = group.attributeOrder;
        expect(order.contains('children'), isTrue);
        expect(order.contains('sourceTree'), isTrue);
        // children should appear before isa key
        final childrenIdx = order.indexOf('children');
        expect(childrenIdx, greaterThan(-1));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------
  group('PBXGroup configureWithPlist deserialization (PBX-07)', () {
    test(
      'PBXGroup configureWithPlist reads children: configure with {"isa":"PBXGroup","children":["UUID1"]} where objectsByUuidPlist has UUID1 → group.children has the resolved object',
      () {
        const groupUuid = 'AAAAAAAAAAAAAAAAAAAAAAA1';
        const childUuid = 'AAAAAAAAAAAAAAAAAAAAAAA2';
        final plist = <String, dynamic>{
          groupUuid: {
            'isa': 'PBXGroup',
            'children': [childUuid],
            'sourceTree': '<group>',
          },
          childUuid: {
            'isa': 'PBXFileReference',
            'sourceTree': 'SOURCE_ROOT',
            'includeInIndex': '1',
          },
        };
        final group = PBXGroup(graph, groupUuid);
        graph.objectsByUuid[groupUuid] = group;
        group.configureWithPlist(plist);

        expect(group.children.length, equals(1));
        expect(group.children.first, isA<PBXFileReference>());
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearRelationships
  // ---------------------------------------------------------------------------
  group('PBXGroup clearRelationships (PBX-07)', () {
    test('PBXGroup clearRelationships clears children', () {
      final group = graph.newObject((g, u) => PBXGroup(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      graph.objectsByUuid[fileRef.uuid] = fileRef;
      group.children.add(fileRef);
      expect(group.children, isNotEmpty);

      group.clearRelationships();
      expect(group.children, isEmpty);
    });
  });
}
