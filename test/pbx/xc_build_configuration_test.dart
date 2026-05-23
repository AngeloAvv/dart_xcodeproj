// Tests for XCBuildConfiguration (PBX-05)
// TDD RED phase — all tests expected to fail until implementation exists.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['XCBuildConfiguration'] = (g, u) => XCBuildConfiguration(g, u);
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
  });

  tearDown(() {
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // Attribute defaults
  // ---------------------------------------------------------------------------

  group('XCBuildConfiguration attributes', () {
    test('default buildSettings is empty map after initializeDefaults()', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      expect(config.buildSettings, isEmpty);
      expect(config.buildSettings, isA<Map<String, dynamic>>());
    });

    test(
      'toHash() always includes buildSettings key even when map is empty',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        final hash = config.toHash();
        expect(hash, containsPair('buildSettings', isEmpty));
      },
    );

    test('toHash() buildSettings contents preserved', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'SWIFT_VERSION': '5.0'};
      final hash = config.toHash();
      expect(hash['buildSettings']['SWIFT_VERSION'], equals('5.0'));
    });

    test('toHash() attribute order — name before buildSettings', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.name = 'Debug';
      final hash = config.toHash();
      final keys = hash.keys.toList();
      // isa is first (AbstractObject), then subclass attrs: name, buildSettings, ...
      final nameIdx = keys.indexOf('name');
      final settingsIdx = keys.indexOf('buildSettings');
      expect(nameIdx, lessThan(settingsIdx));
    });

    test(
      'baseConfigurationReference setter ref-counts — addReferrer on set',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        fileRef.addReferrer(graph); // seed so it's in objectsByUuid

        config.baseConfigurationReference = fileRef;

        expect(fileRef.referrers, contains(config));
      },
    );

    test(
      'baseConfigurationReference setter ref-counts — removeReferrer on change',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        final fileRef1 = graph.newObject((g, u) => PBXFileReference(g, u));
        final fileRef2 = graph.newObject((g, u) => PBXFileReference(g, u));
        fileRef1.addReferrer(graph);
        fileRef2.addReferrer(graph);

        config.baseConfigurationReference = fileRef1;
        expect(fileRef1.referrers, contains(config));

        config.baseConfigurationReference = fileRef2;
        expect(fileRef1.referrers, isNot(contains(config)));
        expect(fileRef2.referrers, contains(config));
      },
    );

    test('round-trip — set name + buildSettings, serialize, deserialize', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.name = 'Release';
      config.buildSettings = {
        'SWIFT_VERSION': '5.0',
        'PRODUCT_NAME': r'$(TARGET_NAME)',
      };

      final hash = config.toHash();

      // Build a minimal objectsByUuidPlist for round-trip
      final plist = {config.uuid: hash};

      final config2 = XCBuildConfiguration(graph, config.uuid);
      config2.configureWithPlist(plist);

      expect(config2.name, equals('Release'));
      expect(config2.buildSettings['SWIFT_VERSION'], equals('5.0'));
      expect(config2.buildSettings['PRODUCT_NAME'], equals(r'$(TARGET_NAME)'));
    });

    test('round-trip from raw plist — ARRAY_SETTINGS value as space-separated String '
        'deserializes correctly and re-serializes as List', () {
      // Simulate the raw plist format that Xcode writes:
      // ARRAY_SETTINGS keys are stored as space-separated strings, not arrays.
      final uuid = 'AABBCCDD112233440000DEAD';
      final rawPlist = {
        uuid: {
          'isa': 'XCBuildConfiguration',
          'name': 'Debug',
          'buildSettings': {
            // As written by Xcode: space-separated string for an ARRAY_SETTINGS key.
            'OTHER_LDFLAGS': r'$(inherited) -ObjC',
            // Non-array key: plain string.
            'SWIFT_VERSION': '5.0',
          },
        },
      };

      final config = XCBuildConfiguration(graph, uuid);
      config.configureWithPlist(rawPlist);

      // After deserialization, raw String is preserved in-memory (normalization is write-time only).
      expect(config.buildSettings['OTHER_LDFLAGS'], isA<String>());
      expect(
        config.buildSettings['OTHER_LDFLAGS'],
        equals(r'$(inherited) -ObjC'),
      );
      expect(config.buildSettings['SWIFT_VERSION'], equals('5.0'));

      // On re-serialization (toHash), the ARRAY_SETTINGS String is split into a List.
      final hash = config.toHash();
      expect(hash['buildSettings']['OTHER_LDFLAGS'], isA<List<dynamic>>());
      expect(
        hash['buildSettings']['OTHER_LDFLAGS'],
        equals([r'$(inherited)', '-ObjC']),
      );
      // Non-array key is left as String.
      expect(hash['buildSettings']['SWIFT_VERSION'], isA<String>());
    });
  });

  // ---------------------------------------------------------------------------
  // resolveBuildSetting
  // ---------------------------------------------------------------------------

  group('resolveBuildSetting', () {
    test('returns value for simple key', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'SWIFT_VERSION': '5.0'};
      expect(config.resolveBuildSetting('SWIFT_VERSION'), equals('5.0'));
    });

    test('returns product name', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'PRODUCT_NAME': 'MyApp'};
      expect(config.resolveBuildSetting('PRODUCT_NAME'), equals('MyApp'));
    });

    test('returns null for absent key', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {};
      expect(config.resolveBuildSetting('FOO'), isNull);
    });

    test('resolves \${VAR} variable substitution', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'A': r'${B}', 'B': 'hello'};
      expect(config.resolveBuildSetting('A'), equals('hello'));
    });

    test('resolves \$(VAR) variable substitution', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'A': r'$(B)', 'B': 'world'};
      expect(config.resolveBuildSetting('A'), equals('world'));
    });

    test('handles \$(inherited) with inherited value', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      // CONFIGURATION default from defaults map
      config.name = 'Debug';
      config.buildSettings = {'FOO': r'$(inherited) extra'};
      // No project-level setting; inherited chain is just 'FOO' → null, so
      // the result should still be the resolved string (inherited → '')
      final result = config.resolveBuildSetting('FOO');
      // When inherited = '' (no project setting), $(inherited) → ''. Result: ' extra' (trimmed or with space).
      expect(result, isNotNull);
      expect(result, contains('extra'));
    });

    test('mutual recursion guard — A=\$(A) does not stack overflow', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'A': r'$(A)'};
      // Must not throw; sentinel-converted value is null or empty string
      expect(() => config.resolveBuildSetting('A'), returnsNormally);
      final result = config.resolveBuildSetting('A');
      expect(
        result == null || result == '',
        isTrue,
        reason:
            'Expected null or empty string for self-referencing key, got: $result',
      );
    });

    test(
      'mutual recursion cross-key — A=\$(B) B=\$(A) does not stack overflow',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.buildSettings = {'A': r'$(B)', 'B': r'$(A)'};
        expect(() => config.resolveBuildSetting('A'), returnsNormally);
        // Result is sentinel or null
      },
    );

    test('returns null for absent list value', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {};
      expect(config.resolveBuildSetting('MISSING'), isNull);
    });

    test(
      'CONFIGURATION default resolves to name when absent from buildSettings',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.name = 'Debug';
        config.buildSettings = {};
        // CONFIGURATION is injected as default
        expect(config.resolveBuildSetting('CONFIGURATION'), equals('Debug'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // normalizeArraySettings (via toHash())
  // ---------------------------------------------------------------------------

  group('normalizeArraySettings', () {
    test(
      'toHash() normalizes OTHER_LDFLAGS — space-separated string → List with 2 items',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.buildSettings = {'OTHER_LDFLAGS': r'$(inherited) -ObjC'};
        final hash = config.toHash();
        expect(
          hash['buildSettings']['OTHER_LDFLAGS'],
          equals([r'$(inherited)', '-ObjC']),
        );
      },
    );

    test(
      'toHash() does NOT split single-token ARRAY_SETTINGS — stays as String',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.buildSettings = {'OTHER_LDFLAGS': '-ObjC'};
        final hash = config.toHash();
        expect(hash['buildSettings']['OTHER_LDFLAGS'], isA<String>());
        expect(hash['buildSettings']['OTHER_LDFLAGS'], equals('-ObjC'));
      },
    );

    test('toHash() collapses Array to String for non-ARRAY_SETTINGS key', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {
        'PRODUCT_NAME': ['Foo', 'Bar'],
      };
      final hash = config.toHash();
      expect(hash['buildSettings']['PRODUCT_NAME'], equals('Foo Bar'));
    });

    test(
      'toHash() normalizes FRAMEWORK_SEARCH_PATHS — returns List with 2 items',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.buildSettings = {
          'FRAMEWORK_SEARCH_PATHS': r'$(inherited) path/to/frameworks',
        };
        final hash = config.toHash();
        final val = hash['buildSettings']['FRAMEWORK_SEARCH_PATHS'];
        expect(val, isA<List<dynamic>>());
        expect((val as List).length, equals(2));
      },
    );

    test(
      'toHash() strips [sdk=...] condition suffix before ARRAY_SETTINGS lookup',
      () {
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        config.buildSettings = {
          'OTHER_LDFLAGS[sdk=iphonesimulator*]': r'$(inherited) -framework Foo',
        };
        final hash = config.toHash();
        final val =
            hash['buildSettings']['OTHER_LDFLAGS[sdk=iphonesimulator*]'];
        expect(val, isA<List<dynamic>>());
      },
    );

    test('buildSettings in-memory model is NOT mutated by toHash()', () {
      final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
      config.buildSettings = {'OTHER_LDFLAGS': r'$(inherited) -ObjC'};
      config.toHash(); // trigger normalization
      // Original buildSettings must still have the String value
      expect(config.buildSettings['OTHER_LDFLAGS'], isA<String>());
      expect(
        config.buildSettings['OTHER_LDFLAGS'],
        equals(r'$(inherited) -ObjC'),
      );
    });
  });
}
