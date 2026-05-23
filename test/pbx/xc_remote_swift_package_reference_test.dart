// Tests for XCRemoteSwiftPackageReference — covers PBX-14.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/swift_package_references.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['XCRemoteSwiftPackageReference'] = (g, u) =>
        XCRemoteSwiftPackageReference(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  group('XCRemoteSwiftPackageReference isa (PBX-14)', () {
    test(
      "XCRemoteSwiftPackageReference has isa 'XCRemoteSwiftPackageReference'",
      () {
        final ref = graph.newObject(
          (g, u) => XCRemoteSwiftPackageReference(g, u),
        );
        expect(ref.isa, equals('XCRemoteSwiftPackageReference'));
      },
    );
  });

  group(
    "XCRemoteSwiftPackageReference serializes 'repositoryURL' as exact key with capital URL",
    () {
      test(
        "XCRemoteSwiftPackageReference serializes 'repositoryURL' as exact key with capital URL",
        () {
          final ref = graph.newObject(
            (g, u) => XCRemoteSwiftPackageReference(g, u),
          );
          ref.repositoryURL = 'https://github.com/example/repo.git';
          final hash = ref.toHash();
          // Must use 'repositoryURL' — capital URL — not 'repositoryUrl' or 'repository_url'
          expect(hash.containsKey('repositoryURL'), isTrue);
          expect(hash.containsKey('repositoryUrl'), isFalse);
          expect(
            hash['repositoryURL'],
            equals('https://github.com/example/repo.git'),
          );
        },
      );
    },
  );

  group('XCRemoteSwiftPackageReference requirement serialization (PBX-14)', () {
    test(
      'XCRemoteSwiftPackageReference serializes requirement as a Map<String, dynamic>',
      () {
        final ref = graph.newObject(
          (g, u) => XCRemoteSwiftPackageReference(g, u),
        );
        ref.requirement = {
          'kind': 'upToNextMajorVersion',
          'minimumVersion': '1.0.0',
        };
        final hash = ref.toHash();
        expect(hash.containsKey('requirement'), isTrue);
        expect(hash['requirement'], isA<Map<dynamic, dynamic>>());
        expect(hash['requirement']['kind'], equals('upToNextMajorVersion'));
        expect(hash['requirement']['minimumVersion'], equals('1.0.0'));
      },
    );

    test('requirement NOT serialized when null', () {
      final ref = graph.newObject(
        (g, u) => XCRemoteSwiftPackageReference(g, u),
      );
      final hash = ref.toHash();
      expect(hash.containsKey('requirement'), isFalse);
    });
  });

  group('XCRemoteSwiftPackageReference round-trip (PBX-14)', () {
    test(
      'XCRemoteSwiftPackageReference round-trips via toHash -> configureWithPlist',
      () {
        const uuid = 'AABBCCDDEEFF001122334455';
        final plist = <String, dynamic>{
          uuid: {
            'isa': 'XCRemoteSwiftPackageReference',
            'repositoryURL': 'https://github.com/Alamofire/Alamofire.git',
            'requirement': {
              'kind': 'upToNextMajorVersion',
              'minimumVersion': '5.6.0',
            },
          },
        };

        final ref = XCRemoteSwiftPackageReference(graph, uuid);
        graph.objectsByUuid[uuid] = ref;
        ref.configureWithPlist(plist);

        expect(
          ref.repositoryURL,
          equals('https://github.com/Alamofire/Alamofire.git'),
        );
        expect(ref.requirement, isNotNull);
        expect(ref.requirement!['kind'], equals('upToNextMajorVersion'));
        expect(ref.requirement!['minimumVersion'], equals('5.6.0'));

        final hash = ref.toHash();
        expect(
          hash['repositoryURL'],
          equals('https://github.com/Alamofire/Alamofire.git'),
        );
        expect(hash['requirement'], isA<Map<dynamic, dynamic>>());
      },
    );
  });
}
