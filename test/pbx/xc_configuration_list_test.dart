// Tests for XCConfigurationList (PBX-06)
// TDD RED phase — all tests expected to fail until implementation exists.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    registerPhase3Types();
  });

  tearDown(() {
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // XCConfigurationList attribute defaults
  // ---------------------------------------------------------------------------

  group('XCConfigurationList attributes', () {
    test(
      'default defaultConfigurationIsVisible is "0" after initializeDefaults()',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        expect(list.defaultConfigurationIsVisible, equals('0'));
      },
    );

    test(
      'default defaultConfigurationName is "Release" after initializeDefaults()',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        expect(list.defaultConfigurationName, equals('Release'));
      },
    );

    test(
      'buildConfigurations is ObjectList<XCBuildConfiguration> — empty after construction',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        expect(
          list.buildConfigurations,
          isA<ObjectList<XCBuildConfiguration>>(),
        );
        expect(list.buildConfigurations, isEmpty);
      },
    );

    test(
      'adding XCBuildConfiguration to buildConfigurations increments its referrer count',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final config = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        final beforeCount = config.referrers.length;
        list.buildConfigurations.add(config);
        expect(config.referrers.length, greaterThan(beforeCount));
      },
    );

    test('toHash() includes defaultConfigurationIsVisible always', () {
      final list = graph.newObject((g, u) => XCConfigurationList(g, u));
      final hash = list.toHash();
      expect(hash, contains('defaultConfigurationIsVisible'));
    });

    test('toHash() includes defaultConfigurationName always', () {
      final list = graph.newObject((g, u) => XCConfigurationList(g, u));
      final hash = list.toHash();
      expect(hash, contains('defaultConfigurationName'));
    });

    test(
      'toHash() includes buildConfigurations as list of UUIDs (empty list when no configs)',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final hash = list.toHash();
        expect(hash, contains('buildConfigurations'));
        expect(hash['buildConfigurations'], isA<List<dynamic>>());
        expect(hash['buildConfigurations'], isEmpty);
      },
    );

    test(
      'toHash() attribute order: defaultConfigurationIsVisible, defaultConfigurationName, buildConfigurations',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final hash = list.toHash();
        final keys = hash.keys.toList();
        // isa is emitted by AbstractObject first; then subclass attrs
        final isVisible = keys.indexOf('defaultConfigurationIsVisible');
        final isName = keys.indexOf('defaultConfigurationName');
        final isBc = keys.indexOf('buildConfigurations');
        expect(isVisible, lessThan(isName));
        expect(isName, lessThan(isBc));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // operator[] lookup
  // ---------------------------------------------------------------------------

  group('XCConfigurationList operator[]', () {
    test('operator[]("Release") returns null when no configs', () {
      final list = graph.newObject((g, u) => XCConfigurationList(g, u));
      expect(list['Release'], isNull);
    });

    test(
      'operator[]("Release") returns the XCBuildConfiguration with name=="Release" when present',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final release = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        list.buildConfigurations.add(release);
        expect(list['Release'], same(release));
      },
    );

    test(
      'operator[]("Debug") returns null when only "Release" config exists',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final release = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        list.buildConfigurations.add(release);
        expect(list['Debug'], isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Round-trip deserialization
  // ---------------------------------------------------------------------------

  group('XCConfigurationList round-trip', () {
    test(
      'add two configurations, serialize, then verify buildConfigurations UUIDs present in hash',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final debug = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        final release = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        list.buildConfigurations.add(debug);
        list.buildConfigurations.add(release);

        final hash = list.toHash();
        expect(hash['buildConfigurations'], isA<List<dynamic>>());
        final uuids = (hash['buildConfigurations'] as List).cast<String>();
        expect(uuids, contains(debug.uuid));
        expect(uuids, contains(release.uuid));
        expect(uuids.length, equals(2));
      },
    );

    test('deserialization restores buildConfigurations from plist UUIDs', () {
      // Build plist-like data with two XCBuildConfiguration entries.
      final configA = XCBuildConfiguration(graph, 'AAAAAAAABBBBBBBBCCCCCCCC');
      configA.name = 'Debug';
      final configB = XCBuildConfiguration(graph, 'DDDDDDDDEEEEEEEEFFFFFFFF');
      configB.name = 'Release';
      graph.objectsByUuid['AAAAAAAABBBBBBBBCCCCCCCC'] = configA;
      graph.objectsByUuid['DDDDDDDDEEEEEEEEFFFFFFFF'] = configB;

      final objectsByUuidPlist = <String, dynamic>{
        'AAAAAAAABBBBBBBBCCCCCCCC': {
          'isa': 'XCBuildConfiguration',
          'name': 'Debug',
          'buildSettings': <String, dynamic>{},
        },
        'DDDDDDDDEEEEEEEEFFFFFFFF': {
          'isa': 'XCBuildConfiguration',
          'name': 'Release',
          'buildSettings': <String, dynamic>{},
        },
        'LISTLISTLISTLISTLISTLIST': {
          'isa': 'XCConfigurationList',
          'defaultConfigurationIsVisible': '0',
          'defaultConfigurationName': 'Release',
          'buildConfigurations': [
            'AAAAAAAABBBBBBBBCCCCCCCC',
            'DDDDDDDDEEEEEEEEFFFFFFFF',
          ],
        },
      };

      final list = XCConfigurationList(graph, 'LISTLISTLISTLISTLISTLIST');
      list.configureWithPlist(objectsByUuidPlist);

      expect(list.buildConfigurations.length, equals(2));
      expect(list['Debug'], isNotNull);
      expect(list['Release'], isNotNull);
      expect(list['Debug']!.name, equals('Debug'));
      expect(list['Release']!.name, equals('Release'));
    });
  });

  // ---------------------------------------------------------------------------
  // getSetting ( — TDD RED)
  // ---------------------------------------------------------------------------

  group('XCConfigurationList.getSetting', () {
    test(
      'getSetting returns Map keyed by config name with correct raw values',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final debug = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        debug.buildSettings['PRODUCT_NAME'] = 'MyApp';
        final release = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        release.name = 'Release';
        release.buildSettings['PRODUCT_NAME'] = 'MyApp';
        list.buildConfigurations.add(debug);
        list.buildConfigurations.add(release);

        final result = list.getSetting('PRODUCT_NAME', false);
        expect(result, isA<Map<String, String?>>());
        expect(result.length, equals(2));
        expect(result['Debug'], equals('MyApp'));
        expect(result['Release'], equals('MyApp'));
      },
    );

    test(
      'getSetting returns null value for a key that does not exist in any config',
      () {
        final list = graph.newObject((g, u) => XCConfigurationList(g, u));
        final debug = graph.newObject((g, u) => XCBuildConfiguration(g, u));
        debug.name = 'Debug';
        list.buildConfigurations.add(debug);

        final result = list.getSetting('NONEXISTENT_KEY', false);
        expect(result['Debug'], isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // ISA registry
  // ---------------------------------------------------------------------------

  group('ISA registry after registerPhase3Types()', () {
    test('isaRegistry["PBXFileReference"] is not null', () {
      expect(isaRegistry['PBXFileReference'], isNotNull);
    });

    test('isaRegistry creates typed PBXFileReference via factory', () {
      final factory = isaRegistry['PBXFileReference']!;
      final obj = factory(graph, 'AAAAAAAABBBBBBBBCCCCCCCC');
      expect(obj.isa, equals('PBXFileReference'));
    });

    test('all 12 ISA keys are present in the registry', () {
      const expected = {
        'PBXFileReference',
        'PBXBuildFile',
        'PBXBuildRule',
        'PBXHeadersBuildPhase',
        'PBXSourcesBuildPhase',
        'PBXFrameworksBuildPhase',
        'PBXResourcesBuildPhase',
        'PBXCopyFilesBuildPhase',
        'PBXShellScriptBuildPhase',
        'PBXRezBuildPhase',
        'XCBuildConfiguration',
        'XCConfigurationList',
      };
      for (final key in expected) {
        expect(
          isaRegistry,
          contains(key),
          reason:
              'isaRegistry should contain "$key" after registerPhase3Types()',
        );
      }
      // Exactly 12 entries (tearDown clears, setUp called registerPhase3Types once)
      expect(isaRegistry.length, equals(12));
    });

    test('isaRegistry does NOT contain "AbstractBuildPhase"', () {
      expect(isaRegistry, isNot(contains('AbstractBuildPhase')));
    });
  });
}
