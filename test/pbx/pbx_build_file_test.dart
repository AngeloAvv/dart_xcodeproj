// Tests for PBXBuildFile — covers PBX-02 requirements.

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
    isaRegistry['PBXBuildFile'] = (g, u) => PBXBuildFile(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // fileRef ref-counting
  // ---------------------------------------------------------------------------
  group('PBXBuildFile fileRef ref-counting (PBX-02)', () {
    test('setting fileRef calls addReferrer on new value', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      // Initially not in referrers
      expect(fileRef.referrers.contains(buildFile), isFalse);
      buildFile.fileRef = fileRef;
      expect(fileRef.referrers.contains(buildFile), isTrue);
    });

    test('setting fileRef calls removeReferrer on old value', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef1 = graph.newObject((g, u) => PBXFileReference(g, u));
      final fileRef2 = graph.newObject((g, u) => PBXFileReference(g, u));

      buildFile.fileRef = fileRef1;
      expect(fileRef1.referrers.contains(buildFile), isTrue);

      buildFile.fileRef = fileRef2;
      expect(fileRef1.referrers.contains(buildFile), isFalse);
      expect(fileRef2.referrers.contains(buildFile), isTrue);
    });

    test('identity guard prevents double-counting referrers', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));

      buildFile.fileRef = fileRef;
      final referrerCountBefore = fileRef.referrers.length;

      // Set the same ref again — should be a no-op
      buildFile.fileRef = fileRef;
      expect(fileRef.referrers.length, equals(referrerCountBefore));
    });

    test('setting fileRef to null removes referrer', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));

      buildFile.fileRef = fileRef;
      expect(fileRef.referrers.contains(buildFile), isTrue);

      buildFile.fileRef = null;
      expect(fileRef.referrers.contains(buildFile), isFalse);
    });

    test(
      'fileRef field declared as AbstractObject? (accepts any AbstractObject subtype)',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));

        // This should compile fine since PBXFileReference is-a AbstractObject
        buildFile.fileRef = fileRef;
        expect(buildFile.fileRef, isA<AbstractObject>());
        expect(buildFile.fileRef, same(fileRef));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // productRef ref-counting
  // ---------------------------------------------------------------------------
  group('PBXBuildFile productRef ref-counting (PBX-02)', () {
    test(
      'setting productRef calls addReferrer and removeReferrer correctly',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        final prodRef1 = graph.newObject((g, u) => PBXFileReference(g, u));
        final prodRef2 = graph.newObject((g, u) => PBXFileReference(g, u));

        buildFile.productRef = prodRef1;
        expect(prodRef1.referrers.contains(buildFile), isTrue);

        buildFile.productRef = prodRef2;
        expect(prodRef1.referrers.contains(buildFile), isFalse);
        expect(prodRef2.referrers.contains(buildFile), isTrue);
      },
    );

    test('productRef identity guard prevents double-counting', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final prodRef = graph.newObject((g, u) => PBXFileReference(g, u));

      buildFile.productRef = prodRef;
      final countBefore = prodRef.referrers.length;
      buildFile.productRef = prodRef;
      expect(prodRef.referrers.length, equals(countBefore));
    });
  });

  // ---------------------------------------------------------------------------
  // settings serialization
  // ---------------------------------------------------------------------------
  group('PBXBuildFile settings serialization (PBX-02)', () {
    test('settings serialized when non-null and non-empty', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      buildFile.settings = {
        'ATTRIBUTES': <String>['Public'],
      };
      final hash = buildFile.toHash();
      expect(hash.containsKey('settings'), isTrue);
      expect(
        hash['settings'],
        equals({
          'ATTRIBUTES': <String>['Public'],
        }),
      );
    });

    test('settings NOT serialized when null', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      buildFile.settings = null;
      final hash = buildFile.toHash();
      expect(hash.containsKey('settings'), isFalse);
    });

    test('settings NOT serialized when empty map', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      buildFile.settings = {};
      final hash = buildFile.toHash();
      expect(hash.containsKey('settings'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Attribute order
  // ---------------------------------------------------------------------------
  group('PBXBuildFile attribute order (PBX-02)', () {
    test('toHash attribute order: settings before fileRef', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;
      buildFile.settings = {
        'ATTRIBUTES': <String>['Public'],
      };
      final hash = buildFile.toHash();
      final keys = hash.keys.toList();
      expect(keys.first, equals('isa'));
      final settingsIdx = keys.indexOf('settings');
      final fileRefIdx = keys.indexOf('fileRef');
      expect(settingsIdx, lessThan(fileRefIdx));
    });

    test(
      'toHash attribute order follows _ownAttributes: settings, fileRef, productRef, platformFilter, platformFilters',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        buildFile.fileRef = fileRef;
        buildFile.settings = {
          'ATTRIBUTES': <String>['Public'],
        };
        buildFile.platformFilter = 'ios';
        final hash = buildFile.toHash();
        final keys = hash.keys.toList();
        // fileRef present, settings present, platformFilter present
        final settingsIdx = keys.indexOf('settings');
        final fileRefIdx = keys.indexOf('fileRef');
        final pfIdx = keys.indexOf('platformFilter');
        expect(settingsIdx, lessThan(fileRefIdx));
        expect(fileRefIdx, lessThan(pfIdx));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // fileRef serialization
  // ---------------------------------------------------------------------------
  group('PBXBuildFile fileRef serialization (PBX-02)', () {
    test('fileRef serialized as UUID string', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;
      final hash = buildFile.toHash();
      expect(hash['fileRef'], equals(fileRef.uuid));
    });

    test('fileRef NOT serialized when null', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final hash = buildFile.toHash();
      expect(hash.containsKey('fileRef'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // platformFilter / platformFilters
  // ---------------------------------------------------------------------------
  group('PBXBuildFile platformFilter/platformFilters (PBX-02)', () {
    test('platformFilter serialized only when non-null', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      expect(buildFile.toHash().containsKey('platformFilter'), isFalse);
      buildFile.platformFilter = 'ios';
      expect(buildFile.toHash()['platformFilter'], equals('ios'));
    });

    test('platformFilters serialized only when non-null', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      expect(buildFile.toHash().containsKey('platformFilters'), isFalse);
      buildFile.platformFilters = ['ios', 'maccatalyst'];
      expect(
        buildFile.toHash()['platformFilters'],
        equals(['ios', 'maccatalyst']),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // configureWithPlist — deserialization
  // ---------------------------------------------------------------------------
  group('PBXBuildFile deserialization (PBX-02)', () {
    test(
      'configureWithPlist resolves fileRef UUID to PBXFileReference instance',
      () {
        const fileRefUuid = 'AAAAAAAAAAAAAAAAAAAAAA01';
        const buildFileUuid = 'AAAAAAAAAAAAAAAAAAAAAA02';

        final plist = <String, dynamic>{
          fileRefUuid: {
            'isa': 'PBXFileReference',
            'path': 'AppDelegate.swift',
            'sourceTree': '<group>',
            'includeInIndex': '1',
          },
          buildFileUuid: {
            'isa': 'PBXBuildFile',
            'fileRef': fileRefUuid,
            'settings': {
              'ATTRIBUTES': <String>['Public'],
            },
          },
        };

        final buildFile = PBXBuildFile(graph, buildFileUuid);
        graph.objectsByUuid[buildFileUuid] = buildFile;
        buildFile.configureWithPlist(plist);

        expect(buildFile.fileRef, isNotNull);
        expect(buildFile.fileRef, isA<PBXFileReference>());
        expect(buildFile.fileRef!.uuid, equals(fileRefUuid));
        expect(
          buildFile.settings,
          equals({
            'ATTRIBUTES': <String>['Public'],
          }),
        );
      },
    );

    test('configureWithPlist reads platformFilter and platformFilters', () {
      const buildFileUuid = 'AAAAAAAAAAAAAAAAAAAAAA03';
      final plist = <String, dynamic>{
        buildFileUuid: {
          'isa': 'PBXBuildFile',
          'platformFilter': 'ios',
          'platformFilters': ['ios', 'maccatalyst'],
        },
      };

      final buildFile = PBXBuildFile(graph, buildFileUuid);
      graph.objectsByUuid[buildFileUuid] = buildFile;
      buildFile.configureWithPlist(plist);

      expect(buildFile.platformFilter, equals('ios'));
      expect(buildFile.platformFilters, equals(['ios', 'maccatalyst']));
    });
  });

  // ---------------------------------------------------------------------------
  // clearRelationships and removeReference
  // ---------------------------------------------------------------------------
  group('PBXBuildFile clearRelationships / removeReference (PBX-02)', () {
    test('clearRelationships removes fileRef referrer and nulls _fileRef', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;
      expect(fileRef.referrers.contains(buildFile), isTrue);

      buildFile.clearRelationships();
      expect(buildFile.fileRef, isNull);
      expect(fileRef.referrers.contains(buildFile), isFalse);
    });

    test(
      'clearRelationships removes productRef referrer and nulls _productRef',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        final prodRef = graph.newObject((g, u) => PBXFileReference(g, u));
        buildFile.productRef = prodRef;
        expect(prodRef.referrers.contains(buildFile), isTrue);

        buildFile.clearRelationships();
        expect(buildFile.productRef, isNull);
        expect(prodRef.referrers.contains(buildFile), isFalse);
      },
    );

    test('removeReference nulls fileRef when obj is identical to fileRef', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;

      buildFile.removeReference(fileRef);
      expect(buildFile.fileRef, isNull);
    });

    test(
      'removeReference nulls productRef when obj is identical to productRef',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        final prodRef = graph.newObject((g, u) => PBXFileReference(g, u));
        buildFile.productRef = prodRef;

        buildFile.removeReference(prodRef);
        expect(buildFile.productRef, isNull);
      },
    );

    test('removeReference does not null fileRef for a different object', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      final other = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;

      buildFile.removeReference(other);
      expect(buildFile.fileRef, same(fileRef)); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // asciiPlistAnnotation
  // ---------------------------------------------------------------------------
  group('PBXBuildFile asciiPlistAnnotation (PBX-02)', () {
    test('returns displayName surrounded by spaces when no referrers', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      // displayName strips PBX prefix → 'BuildFile'
      expect(buildFile.asciiPlistAnnotation, equals(' BuildFile '));
    });

    test(
      'returns displayName in phase.displayName with spaces when referrer is AbstractObject',
      () {
        final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
        // Use a PBXFileReference as a mock "phase" referrer to trigger the annotation path
        // In practice, the referrer is a build phase; here we just verify the format
        final phase = graph.newObject((g, u) => PBXFileReference(g, u));
        phase.name = 'Sources';
        buildFile.addReferrer(phase);

        // ' BuildFile in Sources ' — BuildFile from displayName, Sources from phase.displayName
        expect(
          buildFile.asciiPlistAnnotation,
          equals(' BuildFile in Sources '),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // serializeAttributeAsTree (cycle guard)
  // ---------------------------------------------------------------------------
  group('PBXBuildFile serializeAttributeAsTree (PBX-02)', () {
    test('toTreeHash expands fileRef inline', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      fileRef.path = 'Foo.swift';
      buildFile.fileRef = fileRef;

      final tree = buildFile.toTreeHash();
      expect(tree['fileRef'], isA<Map<dynamic, dynamic>>());
      expect((tree['fileRef'] as Map)['isa'], equals('PBXFileReference'));
    });

    test('toTreeHash handles cycle in fileRef', () {
      final buildFile = graph.newObject((g, u) => PBXBuildFile(g, u));
      final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
      buildFile.fileRef = fileRef;

      // Pre-populate visited with fileRef's uuid to simulate a cycle
      final visited = <String>{fileRef.uuid};
      visited.add(buildFile.uuid);
      final tree = buildFile.toTreeHash(visited);
      expect(tree['fileRef'], startsWith('<cycle:'));
    });
  });
}
