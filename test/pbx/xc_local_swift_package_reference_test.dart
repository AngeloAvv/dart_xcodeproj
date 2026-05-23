// Tests for XCLocalSwiftPackageReference — covers PBX-15.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/swift_package_references.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['XCLocalSwiftPackageReference'] = (g, u) =>
        XCLocalSwiftPackageReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  group('XCLocalSwiftPackageReference isa (PBX-15)', () {
    test(
      "XCLocalSwiftPackageReference has isa 'XCLocalSwiftPackageReference'",
      () {
        final ref = graph.newObject(
          (g, u) => XCLocalSwiftPackageReference(g, u),
        );
        expect(ref.isa, equals('XCLocalSwiftPackageReference'));
      },
    );
  });

  group('XCLocalSwiftPackageReference relativePath serialization (PBX-15)', () {
    test(
      'XCLocalSwiftPackageReference serializes relativePath when non-null',
      () {
        final ref = graph.newObject(
          (g, u) => XCLocalSwiftPackageReference(g, u),
        );
        ref.relativePath = '../LocalPackage';
        final hash = ref.toHash();
        expect(hash.containsKey('relativePath'), isTrue);
        expect(hash['relativePath'], equals('../LocalPackage'));
      },
    );

    test('relativePath NOT serialized when null', () {
      final ref = graph.newObject((g, u) => XCLocalSwiftPackageReference(g, u));
      final hash = ref.toHash();
      expect(hash.containsKey('relativePath'), isFalse);
    });
  });

  group('XCLocalSwiftPackageReference round-trip (PBX-15)', () {
    test(
      'XCLocalSwiftPackageReference round-trips via toHash -> configureWithPlist',
      () {
        const uuid = 'AABBCCDDEEFF001122334466';
        final plist = <String, dynamic>{
          uuid: {
            'isa': 'XCLocalSwiftPackageReference',
            'relativePath': '../MyLocalPackage',
          },
        };

        final ref = XCLocalSwiftPackageReference(graph, uuid);
        graph.objectsByUuid[uuid] = ref;
        ref.configureWithPlist(plist);

        expect(ref.relativePath, equals('../MyLocalPackage'));

        final hash = ref.toHash();
        expect(hash['relativePath'], equals('../MyLocalPackage'));
      },
    );
  });
}
