// Tests for XCVersionGroup — covers PBX-09.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXGroup'] = (g, u) => PBXGroup(g, u);
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
  group('XCVersionGroup ISA (PBX-09)', () {
    test('XCVersionGroup has isa "XCVersionGroup"', () {
      final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
      expect(vg.isa, equals('XCVersionGroup'));
      expect(XCVersionGroup.isaStatic, equals('XCVersionGroup'));
    });
  });

  // ---------------------------------------------------------------------------
  // currentVersion ref counting
  // ---------------------------------------------------------------------------
  group('XCVersionGroup.currentVersion ref counting (PBX-09)', () {
    test(
      'XCVersionGroup.currentVersion setter increments referrer count on PBXFileReference',
      () {
        final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[fileRef.uuid] = fileRef;

        vg.currentVersion = fileRef;
        expect(fileRef.referrers.contains(vg), isTrue);
      },
    );

    test(
      'XCVersionGroup.currentVersion setter decrements old referrer when reassigned to null',
      () {
        final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[fileRef.uuid] = fileRef;

        vg.currentVersion = fileRef;
        expect(fileRef.referrers.contains(vg), isTrue);

        vg.currentVersion = null;
        expect(fileRef.referrers.contains(vg), isFalse);
      },
    );

    test('XCVersionGroup.currentVersion no-op when assigned same value', () {
      final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      graph.objectsByUuid[fileRef.uuid] = fileRef;

      vg.currentVersion = fileRef;
      final referrersBefore = fileRef.referrers.length;
      vg.currentVersion = fileRef; // same reference
      expect(fileRef.referrers.length, equals(referrersBefore));
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('XCVersionGroup serialization (PBX-09)', () {
    test(
      'XCVersionGroup serializes versionGroupType when non-null and currentVersion as UUID when non-null',
      () {
        final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        graph.objectsByUuid[fileRef.uuid] = fileRef;

        vg.currentVersion = fileRef;
        vg.versionGroupType = 'wrapper.xcdatamodel';
        final hash = vg.toHash();
        expect(hash['currentVersion'], equals(fileRef.uuid));
        expect(hash['versionGroupType'], equals('wrapper.xcdatamodel'));
      },
    );

    test('XCVersionGroup omits versionGroupType when null', () {
      final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
      final hash = vg.toHash();
      expect(hash.containsKey('versionGroupType'), isFalse);
    });

    test('XCVersionGroup omits currentVersion when null', () {
      final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
      final hash = vg.toHash();
      expect(hash.containsKey('currentVersion'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Attribute order
  // ---------------------------------------------------------------------------
  group('XCVersionGroup attributeOrder (PBX-09)', () {
    test(
      'XCVersionGroup attributeOrder: currentVersion+versionGroupType come BEFORE PBXGroup\'s children/name/etc.',
      () {
        final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
        vg.currentVersion = graph.newObject((g, u) => PBXFileReference(g, u));
        vg.versionGroupType = 'wrapper.xcdatamodel';
        final hash = vg.toHash();
        final keys = hash.keys.toList();
        final currentVersionIdx = keys.indexOf('currentVersion');
        final childrenIdx = keys.indexOf('children');
        expect(currentVersionIdx, greaterThan(-1));
        expect(childrenIdx, greaterThan(-1));
        expect(currentVersionIdx, lessThan(childrenIdx));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------
  group('XCVersionGroup readAttribute deserialization (PBX-09)', () {
    test(
      'XCVersionGroup readAttribute resolves currentVersion from objectsByUuidPlist',
      () {
        const vgUuid = 'CCCCCCCCCCCCCCCCCCCCCCC1';
        const fileUuid = 'CCCCCCCCCCCCCCCCCCCCCCC2';
        final plist = <String, dynamic>{
          vgUuid: {
            'isa': 'XCVersionGroup',
            'currentVersion': fileUuid,
            'children': [fileUuid],
            'sourceTree': '<group>',
          },
          fileUuid: {
            'isa': 'PBXFileReference',
            'sourceTree': '<group>',
            'includeInIndex': '1',
          },
        };

        final vg = XCVersionGroup(graph, vgUuid);
        graph.objectsByUuid[vgUuid] = vg;
        vg.configureWithPlist(plist);

        expect(vg.currentVersion, isNotNull);
        expect(vg.currentVersion, isA<PBXFileReference>());
        expect(vg.currentVersion!.uuid, equals(fileUuid));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearRelationships
  // ---------------------------------------------------------------------------
  group('XCVersionGroup clearRelationships (PBX-09)', () {
    test('XCVersionGroup clearRelationships nulls currentVersion', () {
      final vg = graph.newObject((g, u) => XCVersionGroup(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      graph.objectsByUuid[fileRef.uuid] = fileRef;

      vg.currentVersion = fileRef;
      expect(vg.currentVersion, isNotNull);

      vg.clearRelationships();
      expect(vg.currentVersion, isNull);
    });
  });
}
