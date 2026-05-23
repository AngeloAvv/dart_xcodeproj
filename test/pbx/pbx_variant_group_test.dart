// Tests for PBXVariantGroup — covers PBX-08.

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
    isaRegistry['PBXVariantGroup'] = (g, u) => PBXVariantGroup(g, u);
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXVariantGroup ISA (PBX-08)', () {
    test('PBXVariantGroup has isa "PBXVariantGroup"', () {
      final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));
      expect(variantGroup.isa, equals('PBXVariantGroup'));
      expect(PBXVariantGroup.isaStatic, equals('PBXVariantGroup'));
    });
  });

  // ---------------------------------------------------------------------------
  // Inherited behavior
  // ---------------------------------------------------------------------------
  group('PBXVariantGroup inherits PBXGroup behavior (PBX-08)', () {
    test(
      'PBXVariantGroup inherits children/name/path/sourceTree behavior from PBXGroup',
      () {
        final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));
        // Inherited from PBXGroup
        expect(variantGroup.sourceTree, equals('<group>'));
        expect(variantGroup.name, isNull);
        expect(variantGroup.path, isNull);
        expect(variantGroup.children, isEmpty);
      },
    );

    test('PBXVariantGroup sourceTree defaults to "<group>"', () {
      final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));
      expect(variantGroup.sourceTree, equals('<group>'));
    });

    test('PBXVariantGroup is a subclass of PBXGroup', () {
      final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));
      expect(variantGroup, isA<PBXGroup>());
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip
  // ---------------------------------------------------------------------------
  group('PBXVariantGroup round-trip (PBX-08)', () {
    test(
      'PBXVariantGroup round-trips through toHash → configureWithPlist with same children',
      () {
        const groupUuid = 'BBBBBBBBBBBBBBBBBBBBBBB1';
        const childUuid = 'BBBBBBBBBBBBBBBBBBBBBBB2';

        final plist = <String, dynamic>{
          groupUuid: {
            'isa': 'PBXVariantGroup',
            'children': [childUuid],
            'name': 'InfoPlist.strings',
            'sourceTree': '<group>',
          },
          childUuid: {
            'isa': 'PBXFileReference',
            'path': 'en.lproj/InfoPlist.strings',
            'sourceTree': '<group>',
            'includeInIndex': '1',
          },
        };

        final variantGroup = PBXVariantGroup(graph, groupUuid);
        graph.objectsByUuid[groupUuid] = variantGroup;
        variantGroup.configureWithPlist(plist);

        // Verify deserialization
        expect(variantGroup.name, equals('InfoPlist.strings'));
        expect(variantGroup.children.length, equals(1));
        expect(variantGroup.children.first, isA<PBXFileReference>());

        // Verify round-trip serialization
        final hash = variantGroup.toHash();
        expect(hash['isa'], equals('PBXVariantGroup'));
        expect(hash['name'], equals('InfoPlist.strings'));
        expect((hash['children'] as List).first, equals(childUuid));
      },
    );
  });
}
