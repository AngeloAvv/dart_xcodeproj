// Tests for PBXBuildRule — covers PBX-03 requirements.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_rule.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXBuildRule'] = (g, u) => PBXBuildRule(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // initializeDefaults
  // ---------------------------------------------------------------------------
  group('PBXBuildRule initializeDefaults (PBX-03)', () {
    test('default isEditable is "1"', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.isEditable, equals('1'));
    });

    test('default outputFiles is empty List<String> (not null)', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.outputFiles, isA<List<String>>());
      expect(rule.outputFiles, isEmpty);
    });

    test(
      'default outputFilesCompilerFlags is empty List<String> (not null)',
      () {
        final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
        expect(rule.outputFilesCompilerFlags, isA<List<String>>());
        expect(rule.outputFilesCompilerFlags, isEmpty);
      },
    );

    test('outputFiles is a fresh instance per object (not shared)', () {
      final rule1 = graph.newObject((g, u) => PBXBuildRule(g, u));
      final rule2 = graph.newObject((g, u) => PBXBuildRule(g, u));
      rule1.outputFiles.add('foo.txt');
      expect(rule2.outputFiles, isEmpty);
    });

    test(
      'outputFilesCompilerFlags is a fresh instance per object (not shared)',
      () {
        final rule1 = graph.newObject((g, u) => PBXBuildRule(g, u));
        final rule2 = graph.newObject((g, u) => PBXBuildRule(g, u));
        rule1.outputFilesCompilerFlags.add('-Wall');
        expect(rule2.outputFilesCompilerFlags, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // toHash serialization
  // ---------------------------------------------------------------------------
  group('PBXBuildRule toHash serialization (PBX-03)', () {
    test('toHash includes isEditable always (non-nullable, default "1")', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      final hash = rule.toHash();
      expect(hash.containsKey('isEditable'), isTrue);
      expect(hash['isEditable'], equals('1'));
    });

    test('toHash includes outputFiles always (even when empty)', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      final hash = rule.toHash();
      expect(hash.containsKey('outputFiles'), isTrue);
      expect(hash['outputFiles'], equals(<String>[]));
    });

    test(
      'toHash includes outputFilesCompilerFlags always (even when empty)',
      () {
        final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
        final hash = rule.toHash();
        expect(hash.containsKey('outputFilesCompilerFlags'), isTrue);
        expect(hash['outputFilesCompilerFlags'], equals(<String>[]));
      },
    );

    test('toHash omits inputFiles when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.inputFiles, isNull);
      final hash = rule.toHash();
      expect(hash.containsKey('inputFiles'), isFalse);
    });

    test('toHash includes inputFiles when set to ["input.txt"]', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      rule.inputFiles = ['input.txt'];
      final hash = rule.toHash();
      expect(hash.containsKey('inputFiles'), isTrue);
      expect(hash['inputFiles'], equals(['input.txt']));
    });

    test('toHash omits name when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.name, isNull);
      expect(rule.toHash().containsKey('name'), isFalse);
    });

    test('toHash omits compilerSpec when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('compilerSpec'), isFalse);
    });

    test('toHash omits fileType when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('fileType'), isFalse);
    });

    test('toHash omits filePatterns when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('filePatterns'), isFalse);
    });

    test('toHash omits script when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('script'), isFalse);
    });

    test('toHash omits runOncePerArchitecture when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('runOncePerArchitecture'), isFalse);
    });

    test('toHash omits dependencyFile when null', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.toHash().containsKey('dependencyFile'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // asciiPlistAnnotation
  // ---------------------------------------------------------------------------
  group('PBXBuildRule asciiPlistAnnotation (PBX-03)', () {
    test('returns " PBXBuildRule " (exact string with spaces)', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.asciiPlistAnnotation, equals(' PBXBuildRule '));
    });
  });

  // ---------------------------------------------------------------------------
  // Attribute order
  // ---------------------------------------------------------------------------
  group('PBXBuildRule attribute order (PBX-03)', () {
    test(
      'attributeOrder follows _ownAttributes: name, compilerSpec, dependencyFile, fileType, filePatterns, isEditable, inputFiles, outputFiles, outputFilesCompilerFlags, runOncePerArchitecture, script',
      () {
        final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
        // Set all fields so they all appear in toHash
        rule.name = 'Test';
        rule.compilerSpec = 'com.apple.compilers.proxy.script';
        rule.dependencyFile = r'$(DERIVED_FILES_DIR)/out.d';
        rule.fileType = 'pattern.proxy';
        rule.filePatterns = '*.css';
        rule.isEditable = '1';
        rule.inputFiles = ['in.txt'];
        rule.outputFiles = ['out.txt'];
        rule.outputFilesCompilerFlags = ['-Wall'];
        rule.runOncePerArchitecture = '0';
        rule.script = 'echo hello';

        final hash = rule.toHash();
        final keys = hash.keys.toList();
        // isa is first
        expect(keys.first, equals('isa'));
        // The rest should follow _ownAttributes order
        final expectedOrder = [
          'name',
          'compilerSpec',
          'dependencyFile',
          'fileType',
          'filePatterns',
          'isEditable',
          'inputFiles',
          'outputFiles',
          'outputFilesCompilerFlags',
          'runOncePerArchitecture',
          'script',
        ];
        int lastIdx = -1;
        for (final attr in expectedOrder) {
          final idx = keys.indexOf(attr);
          expect(
            idx,
            greaterThan(lastIdx),
            reason: '$attr should come after previous attribute',
          );
          lastIdx = idx;
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Round-trip
  // ---------------------------------------------------------------------------
  group('PBXBuildRule round-trip (PBX-03)', () {
    test(
      'round-trip: set name, outputFiles, isEditable; serialize and deserialize back',
      () {
        const uuid = 'BBBBBBBBBBBBBBBBBBBBBB01';

        final plist = <String, dynamic>{
          uuid: {
            'isa': 'PBXBuildRule',
            'name': 'Custom Rule',
            'outputFiles': [r'$(SRCROOT)/out.txt'],
            'isEditable': '0',
            'outputFilesCompilerFlags': <String>[],
          },
        };

        final rule = PBXBuildRule(graph, uuid);
        graph.objectsByUuid[uuid] = rule;
        rule.configureWithPlist(plist);

        expect(rule.name, equals('Custom Rule'));
        expect(rule.outputFiles, equals([r'$(SRCROOT)/out.txt']));
        expect(rule.isEditable, equals('0'));

        // Re-serialize and verify round-trip
        final hash = rule.toHash();
        expect(hash['name'], equals('Custom Rule'));
        expect(hash['outputFiles'], equals([r'$(SRCROOT)/out.txt']));
        expect(hash['isEditable'], equals('0'));
      },
    );

    test('round-trip: inputFiles read from plist and serialized back', () {
      const uuid = 'BBBBBBBBBBBBBBBBBBBBBB02';

      final plist = <String, dynamic>{
        uuid: {
          'isa': 'PBXBuildRule',
          'inputFiles': ['src/input.c'],
          'outputFiles': <String>[],
          'outputFilesCompilerFlags': <String>[],
          'isEditable': '1',
        },
      };

      final rule = PBXBuildRule(graph, uuid);
      graph.objectsByUuid[uuid] = rule;
      rule.configureWithPlist(plist);

      expect(rule.inputFiles, equals(['src/input.c']));
      final hash = rule.toHash();
      expect(hash['inputFiles'], equals(['src/input.c']));
    });

    test('round-trip: script and compilerSpec preserved', () {
      const uuid = 'BBBBBBBBBBBBBBBBBBBBBB03';

      final plist = <String, dynamic>{
        uuid: {
          'isa': 'PBXBuildRule',
          'compilerSpec': 'com.apple.compilers.proxy.script',
          'script': 'echo hello',
          'outputFiles': <String>[],
          'outputFilesCompilerFlags': <String>[],
          'isEditable': '1',
        },
      };

      final rule = PBXBuildRule(graph, uuid);
      graph.objectsByUuid[uuid] = rule;
      rule.configureWithPlist(plist);

      expect(rule.compilerSpec, equals('com.apple.compilers.proxy.script'));
      expect(rule.script, equals('echo hello'));

      final hash = rule.toHash();
      expect(hash['compilerSpec'], equals('com.apple.compilers.proxy.script'));
      expect(hash['script'], equals('echo hello'));
    });
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXBuildRule ISA (PBX-03)', () {
    test('isa returns "PBXBuildRule"', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      expect(rule.isa, equals('PBXBuildRule'));
    });

    test('isaStatic returns "PBXBuildRule"', () {
      expect(PBXBuildRule.isaStatic, equals('PBXBuildRule'));
    });

    test('toHash always has isa as first key', () {
      final rule = graph.newObject((g, u) => PBXBuildRule(g, u));
      final keys = rule.toHash().keys.toList();
      expect(keys.first, equals('isa'));
    });
  });
}
