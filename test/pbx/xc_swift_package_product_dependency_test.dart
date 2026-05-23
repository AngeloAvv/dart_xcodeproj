// Tests for XCSwiftPackageProductDependency — covers PBX-16.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/swift_package_references.dart';
import 'package:dart_xcodeproj/src/pbx/xc_swift_package_product_dependency.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['XCSwiftPackageProductDependency'] = (g, u) =>
        XCSwiftPackageProductDependency(g, u);
    isaRegistry['XCRemoteSwiftPackageReference'] = (g, u) =>
        XCRemoteSwiftPackageReference(g, u);
    isaRegistry['XCLocalSwiftPackageReference'] = (g, u) =>
        XCLocalSwiftPackageReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  group('XCSwiftPackageProductDependency isa (PBX-16)', () {
    test(
      "XCSwiftPackageProductDependency has isa 'XCSwiftPackageProductDependency'",
      () {
        final dep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        expect(dep.isa, equals('XCSwiftPackageProductDependency'));
      },
    );
  });

  group('XCSwiftPackageProductDependency ref-counting (PBX-16)', () {
    test(
      'XCSwiftPackageProductDependency.package setter ref counts XCRemoteSwiftPackageReference',
      () {
        final dep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        final remoteRef = graph.newObject(
          (g, u) => XCRemoteSwiftPackageReference(g, u),
        );

        dep.package = remoteRef;

        expect(remoteRef.referrers.contains(dep), isTrue);
      },
    );

    test(
      'XCSwiftPackageProductDependency.package setter accepts XCLocalSwiftPackageReference',
      () {
        final dep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        final localRef = graph.newObject(
          (g, u) => XCLocalSwiftPackageReference(g, u),
        );

        dep.package = localRef;

        expect(dep.package, same(localRef));
        expect(localRef.referrers.contains(dep), isTrue);
      },
    );

    test('package setter removeReferrer on old value', () {
      final dep = graph.newObject(
        (g, u) => XCSwiftPackageProductDependency(g, u),
      );
      final remoteRef1 = graph.newObject(
        (g, u) => XCRemoteSwiftPackageReference(g, u),
      );
      final remoteRef2 = graph.newObject(
        (g, u) => XCRemoteSwiftPackageReference(g, u),
      );

      dep.package = remoteRef1;
      expect(remoteRef1.referrers.contains(dep), isTrue);

      dep.package = remoteRef2;
      expect(remoteRef1.referrers.contains(dep), isFalse);
      expect(remoteRef2.referrers.contains(dep), isTrue);
    });
  });

  group('XCSwiftPackageProductDependency serialization (PBX-16)', () {
    test(
      'XCSwiftPackageProductDependency serializes package as UUID + productName',
      () {
        final dep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        final remoteRef = graph.newObject(
          (g, u) => XCRemoteSwiftPackageReference(g, u),
        );
        dep.package = remoteRef;
        dep.productName = 'Alamofire';

        final hash = dep.toHash();
        expect(hash['package'], equals(remoteRef.uuid));
        expect(hash['productName'], equals('Alamofire'));
      },
    );

    test('package NOT serialized when null', () {
      final dep = graph.newObject(
        (g, u) => XCSwiftPackageProductDependency(g, u),
      );
      final hash = dep.toHash();
      expect(hash.containsKey('package'), isFalse);
    });
  });

  group('XCSwiftPackageProductDependency clearRelationships (PBX-16)', () {
    test(
      'XCSwiftPackageProductDependency.clearRelationships nulls package',
      () {
        final dep = graph.newObject(
          (g, u) => XCSwiftPackageProductDependency(g, u),
        );
        final remoteRef = graph.newObject(
          (g, u) => XCRemoteSwiftPackageReference(g, u),
        );

        dep.package = remoteRef;
        expect(dep.package, isNotNull);

        dep.clearRelationships();
        expect(dep.package, isNull);
        expect(remoteRef.referrers.contains(dep), isFalse);
      },
    );
  });

  group('XCSwiftPackageProductDependency round-trip (PBX-16)', () {
    test('round-trips via toHash -> configureWithPlist', () {
      const depUuid = 'AABBCCDDEEFF001122334477';
      const pkgUuid = 'AABBCCDDEEFF001122334488';

      final plist = <String, dynamic>{
        depUuid: {
          'isa': 'XCSwiftPackageProductDependency',
          'package': pkgUuid,
          'productName': 'Alamofire',
        },
        pkgUuid: {
          'isa': 'XCRemoteSwiftPackageReference',
          'repositoryURL': 'https://github.com/Alamofire/Alamofire.git',
          'requirement': {
            'kind': 'upToNextMajorVersion',
            'minimumVersion': '5.6.0',
          },
        },
      };

      final pkgRef = XCRemoteSwiftPackageReference(graph, pkgUuid);
      graph.objectsByUuid[pkgUuid] = pkgRef;

      final dep = XCSwiftPackageProductDependency(graph, depUuid);
      graph.objectsByUuid[depUuid] = dep;
      dep.configureWithPlist(plist);

      expect(dep.package, isNotNull);
      expect(dep.package!.uuid, equals(pkgUuid));
      expect(dep.productName, equals('Alamofire'));
    });
  });
}
