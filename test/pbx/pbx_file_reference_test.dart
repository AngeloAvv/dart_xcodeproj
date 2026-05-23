// Tests for PBXFileReference — covers PBX-01 requirements.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------
  group('PBXFileReference defaults (PBX-01)', () {
    test('sourceTree defaults to SOURCE_ROOT after initializeDefaults', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      expect(ref.sourceTree, equals('SOURCE_ROOT'));
    });

    test('includeInIndex defaults to 1 after initializeDefaults', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      expect(ref.includeInIndex, equals('1'));
    });

    test('nullable attributes are null by default', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      expect(ref.name, isNull);
      expect(ref.path, isNull);
      expect(ref.explicitFileType, isNull);
      expect(ref.lastKnownFileType, isNull);
      expect(ref.fileEncoding, isNull);
      expect(ref.xcLanguageSpecificationIdentifier, isNull);
      expect(ref.plistStructureDefinitionIdentifier, isNull);
      expect(ref.usesTabs, isNull);
      expect(ref.indentWidth, isNull);
      expect(ref.tabWidth, isNull);
      expect(ref.wrapsLines, isNull);
      expect(ref.lineEnding, isNull);
      expect(ref.expectedSignature, isNull);
      expect(ref.comments, isNull);
    });

    test('isa is PBXFileReference', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      expect(ref.isa, equals('PBXFileReference'));
    });

    test('isaStatic is PBXFileReference', () {
      expect(PBXFileReference.isaStatic, equals('PBXFileReference'));
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('PBXFileReference serialization (PBX-01)', () {
    test('toHash includes isa always', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      final hash = ref.toHash();
      expect(hash['isa'], equals('PBXFileReference'));
    });

    test('toHash includes sourceTree always', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      final hash = ref.toHash();
      expect(hash.containsKey('sourceTree'), isTrue);
      expect(hash['sourceTree'], equals('SOURCE_ROOT'));
    });

    test('toHash includes includeInIndex always', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      final hash = ref.toHash();
      expect(hash.containsKey('includeInIndex'), isTrue);
      expect(hash['includeInIndex'], equals('1'));
    });

    test('toHash omits null nullable attributes', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      final hash = ref.toHash();
      expect(hash.containsKey('name'), isFalse);
      expect(hash.containsKey('path'), isFalse);
      expect(hash.containsKey('explicitFileType'), isFalse);
      expect(hash.containsKey('lastKnownFileType'), isFalse);
      expect(hash.containsKey('fileEncoding'), isFalse);
      expect(hash.containsKey('xcLanguageSpecificationIdentifier'), isFalse);
      expect(hash.containsKey('plistStructureDefinitionIdentifier'), isFalse);
      expect(hash.containsKey('usesTabs'), isFalse);
      expect(hash.containsKey('indentWidth'), isFalse);
      expect(hash.containsKey('tabWidth'), isFalse);
      expect(hash.containsKey('wrapsLines'), isFalse);
      expect(hash.containsKey('lineEnding'), isFalse);
      expect(hash.containsKey('expectedSignature'), isFalse);
      expect(hash.containsKey('comments'), isFalse);
    });

    test('toHash emits name when set', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.name = 'AppDelegate.swift';
      final hash = ref.toHash();
      expect(hash['name'], equals('AppDelegate.swift'));
    });

    test('toHash emits path when set', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.path = 'AppDelegate.swift';
      final hash = ref.toHash();
      expect(hash['path'], equals('AppDelegate.swift'));
    });

    test(
      'toHash attribute order: isa first, then name, path, sourceTree, ...',
      () {
        final ref = graph.newObject((g, u) => PBXFileReference(g, u));
        ref.name = 'Foo.swift';
        ref.path = 'Foo.swift';
        final hash = ref.toHash();
        final keys = hash.keys.toList();
        expect(keys.first, equals('isa'));
        // name before path before sourceTree
        final nameIdx = keys.indexOf('name');
        final pathIdx = keys.indexOf('path');
        final sourceTreeIdx = keys.indexOf('sourceTree');
        expect(nameIdx, lessThan(pathIdx));
        expect(pathIdx, lessThan(sourceTreeIdx));
      },
    );

    test('toHash emits includeInIndex even when set to 0', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.includeInIndex = '0';
      final hash = ref.toHash();
      expect(hash.containsKey('includeInIndex'), isTrue);
      expect(hash['includeInIndex'], equals('0'));
    });
  });

  // ---------------------------------------------------------------------------
  // displayName
  // ---------------------------------------------------------------------------
  group('PBXFileReference displayName (PBX-01)', () {
    test('returns name when name is non-null', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.name = 'MyApp';
      ref.path = 'MyApp.app';
      expect(ref.displayName, equals('MyApp'));
    });

    test(
      'returns path when sourceTree is BUILT_PRODUCTS_DIR and path is non-null',
      () {
        final ref = graph.newObject((g, u) => PBXFileReference(g, u));
        ref.sourceTree = 'BUILT_PRODUCTS_DIR';
        ref.path = 'MyApp.app';
        expect(ref.displayName, equals('MyApp.app'));
      },
    );

    test('returns basename of path for regular files', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.path = 'Classes/AppDelegate.swift';
      expect(ref.displayName, equals('AppDelegate.swift'));
    });

    test('falls through to super.displayName when path is null', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      // super.displayName strips PBX prefix → 'FileReference'
      expect(ref.displayName, equals('FileReference'));
    });

    test('name takes priority over BUILT_PRODUCTS_DIR path', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.name = 'Named';
      ref.sourceTree = 'BUILT_PRODUCTS_DIR';
      ref.path = 'full.app';
      expect(ref.displayName, equals('Named'));
    });
  });

  // ---------------------------------------------------------------------------
  // asciiPlistAnnotation
  // ---------------------------------------------------------------------------
  group('PBXFileReference asciiPlistAnnotation (PBX-01)', () {
    test('returns displayName surrounded by spaces', () {
      final ref = graph.newObject((g, u) => PBXFileReference(g, u));
      ref.path = 'AppDelegate.swift';
      // displayName = 'AppDelegate.swift' (basename)
      expect(ref.asciiPlistAnnotation, equals(' AppDelegate.swift '));
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip (deserialization)
  // ---------------------------------------------------------------------------
  group('PBXFileReference deserialization round-trip (PBX-01)', () {
    test('all non-null attributes survive round-trip', () {
      const uuid = 'ABCDEF012345678901234567';
      // Build source plist with all attributes
      final plist = <String, dynamic>{
        uuid: {
          'isa': 'PBXFileReference',
          'name': 'MyFile.swift',
          'path': 'Sources/MyFile.swift',
          'sourceTree': '<group>',
          'explicitFileType': 'sourcecode.swift',
          'lastKnownFileType': 'sourcecode.swift',
          'includeInIndex': '0',
          'fileEncoding': '4',
          'xcLanguageSpecificationIdentifier': 'xcode.lang.swift',
          'plistStructureDefinitionIdentifier': 'com.apple.xcode.plist',
          'usesTabs': '0',
          'indentWidth': '4',
          'tabWidth': '4',
          'wrapsLines': '0',
          'lineEnding': '0',
          'expectedSignature': 'sign123',
          'comments': 'Some comment',
        },
      };

      final ref = PBXFileReference(graph, uuid);
      graph.objectsByUuid[uuid] = ref;
      ref.configureWithPlist(plist);

      expect(ref.name, equals('MyFile.swift'));
      expect(ref.path, equals('Sources/MyFile.swift'));
      expect(ref.sourceTree, equals('<group>'));
      expect(ref.explicitFileType, equals('sourcecode.swift'));
      expect(ref.lastKnownFileType, equals('sourcecode.swift'));
      expect(ref.includeInIndex, equals('0'));
      expect(ref.fileEncoding, equals('4'));
      expect(ref.xcLanguageSpecificationIdentifier, equals('xcode.lang.swift'));
      expect(
        ref.plistStructureDefinitionIdentifier,
        equals('com.apple.xcode.plist'),
      );
      expect(ref.usesTabs, equals('0'));
      expect(ref.indentWidth, equals('4'));
      expect(ref.tabWidth, equals('4'));
      expect(ref.wrapsLines, equals('0'));
      expect(ref.lineEnding, equals('0'));
      expect(ref.expectedSignature, equals('sign123'));
      expect(ref.comments, equals('Some comment'));
    });

    test('toHash output matches original plist data for round-trip', () {
      const uuid = 'ABCDEF012345678901234568';
      final plist = <String, dynamic>{
        uuid: {
          'isa': 'PBXFileReference',
          'name': 'AppDelegate.swift',
          'path': 'AppDelegate.swift',
          'sourceTree': '<group>',
          'lastKnownFileType': 'sourcecode.swift',
          'includeInIndex': '1',
        },
      };

      final ref = PBXFileReference(graph, uuid);
      graph.objectsByUuid[uuid] = ref;
      ref.configureWithPlist(plist);

      final hash = ref.toHash();
      expect(hash['isa'], equals('PBXFileReference'));
      expect(hash['name'], equals('AppDelegate.swift'));
      expect(hash['path'], equals('AppDelegate.swift'));
      expect(hash['sourceTree'], equals('<group>'));
      expect(hash['lastKnownFileType'], equals('sourcecode.swift'));
      expect(hash['includeInIndex'], equals('1'));
    });

    test(
      'serializeAttributeAsTree delegates to serializeAttribute for non-ref type',
      () {
        final ref = graph.newObject((g, u) => PBXFileReference(g, u));
        ref.name = 'Test.swift';
        ref.path = 'Test.swift';
        final treeHash = ref.toTreeHash();
        expect(treeHash['name'], equals('Test.swift'));
        expect(treeHash['path'], equals('Test.swift'));
        expect(treeHash['sourceTree'], equals('SOURCE_ROOT'));
        expect(treeHash['includeInIndex'], equals('1'));
      },
    );
  });
}
