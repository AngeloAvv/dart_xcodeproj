// Tests for PBXProject root object — covers PBX-19.

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_dictionary.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_project.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXProject'] = (g, u) => PBXProject(g, u);
    isaRegistry['PBXGroup'] = (g, u) => PBXGroup(g, u);
    isaRegistry['PBXVariantGroup'] = (g, u) => PBXVariantGroup(g, u);
    isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
    isaRegistry['PBXNativeTarget'] = (g, u) => PBXNativeTarget(g, u);
    isaRegistry['XCConfigurationList'] = (g, u) => XCConfigurationList(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  group('PBXProject isa (PBX-19)', () {
    test("PBXProject has isa 'PBXProject'", () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      expect(project.isa, equals('PBXProject'));
    });
  });

  group('PBXProject has_one ref-counted fields (PBX-19)', () {
    test('PBXProject.mainGroup has_one PBXGroup ref counted', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      final group = graph.newObject((g, u) => PBXGroup(g, u));

      project.mainGroup = group;
      expect(group.referrers.contains(project), isTrue);

      project.mainGroup = null;
      expect(group.referrers.contains(project), isFalse);
    });

    test(
      'PBXProject.buildConfigurationList has_one XCConfigurationList ref counted',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        final configList = graph.newObject((g, u) => XCConfigurationList(g, u));

        project.buildConfigurationList = configList;
        expect(configList.referrers.contains(project), isTrue);

        project.buildConfigurationList = null;
        expect(configList.referrers.contains(project), isFalse);
      },
    );
  });

  group('PBXProject ObjectList fields (PBX-19)', () {
    test('PBXProject.targets is late final ObjectList<AbstractTarget>', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      expect(project.targets, isA<ObjectList<AbstractTarget>>());
    });

    test(
      'PBXProject.packageReferences is late final ObjectList<AbstractObject>',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        expect(project.packageReferences, isA<ObjectList<AbstractObject>>());
      },
    );

    test(
      'PBXProject.projectReferences is late final ObjectList<ObjectDictionary>',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        expect(project.projectReferences, isA<ObjectList<ObjectDictionary>>());
      },
    );
  });

  group('PBXProject attribute pitfalls (PBX-19)', () {
    test("PBXProject does NOT have a 'name' attribute in attributeOrder", () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      expect(project.attributeOrder.contains('name'), isFalse);
    });
  });

  group('PBXProject serialization (PBX-19)', () {
    test('PBXProject serializes targets as UUID list (always emitted)', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      final hash = project.toHash();
      expect(hash.containsKey('targets'), isTrue);
      expect(hash['targets'], isA<List<dynamic>>());
      expect(hash['targets'], isEmpty);
    });

    test('PBXProject OMITS projectReferences key from toHash when empty', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      final hash = project.toHash();
      expect(hash.containsKey('projectReferences'), isFalse);
    });

    test('PBXProject OMITS packageReferences key from toHash when empty', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      final hash = project.toHash();
      expect(hash.containsKey('packageReferences'), isFalse);
    });

    test(
      'PBXProject serializes projectReferences as List<Map> when non-empty',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        final fileRef = graph.newObject((g, u) => PBXFileReference(g, u));
        final group = graph.newObject((g, u) => PBXGroup(g, u));

        const projectRefKeys = {
          'ProjectRef': PBXFileReference,
          'ProductGroup': PBXGroup,
        };
        final dict = ObjectDictionary(projectRefKeys, project);
        dict['ProjectRef'] = fileRef;
        dict['ProductGroup'] = group;
        project.projectReferences.add(dict);

        final hash = project.toHash();
        expect(hash.containsKey('projectReferences'), isTrue);
        expect(hash['projectReferences'], isA<List<dynamic>>());
        expect((hash['projectReferences'] as List<dynamic>).length, equals(1));
        final entry = (hash['projectReferences'] as List<dynamic>).first;
        expect(entry, isA<Map<dynamic, dynamic>>());
      },
    );

    test('PBXProject serializes attributes as plain Map<String, dynamic>', () {
      final project = graph.newObject((g, u) => PBXProject(g, u));
      project.attributes = {
        'LastUpgradeCheck': '1430',
        'ORGANIZATIONNAME': 'Example',
      };
      final hash = project.toHash();
      expect(hash.containsKey('attributes'), isTrue);
      expect(hash['attributes'], isA<Map<dynamic, dynamic>>());
    });

    test(
      'PBXProject serializes compatibilityVersion, developmentRegion, hasScannedForEncodings, knownRegions, preferredProjectObjectVersion, projectDirPath, projectRoot, minimizedProjectReferenceProxies when non-null',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        project.compatibilityVersion = 'Xcode 14.0';
        project.developmentRegion = 'en';
        project.hasScannedForEncodings = '0';
        project.knownRegions = ['en', 'Base'];
        project.preferredProjectObjectVersion = '77';
        project.projectDirPath = '';
        project.projectRoot = '';
        project.minimizedProjectReferenceProxies = '0';

        final hash = project.toHash();
        expect(hash['compatibilityVersion'], equals('Xcode 14.0'));
        expect(hash['developmentRegion'], equals('en'));
        expect(hash['hasScannedForEncodings'], equals('0'));
        expect(hash['knownRegions'], equals(['en', 'Base']));
        expect(hash['preferredProjectObjectVersion'], equals('77'));
        expect(hash['projectDirPath'], equals(''));
        expect(hash['projectRoot'], equals(''));
        expect(hash['minimizedProjectReferenceProxies'], equals('0'));
      },
    );
  });

  group('PBXProject clearRelationships (PBX-19)', () {
    test(
      'PBXProject.clearRelationships clears mainGroup, productRefGroup, buildConfigurationList, targets, packageReferences, projectReferences',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        final group = graph.newObject((g, u) => PBXGroup(g, u));
        final configList = graph.newObject((g, u) => XCConfigurationList(g, u));
        final target = graph.newObject((g, u) => PBXNativeTarget(g, u));

        project.mainGroup = group;
        project.buildConfigurationList = configList;
        project.targets.add(target);

        project.clearRelationships();

        expect(project.mainGroup, isNull);
        expect(project.buildConfigurationList, isNull);
        expect(project.targets.isEmpty, isTrue);
        expect(project.packageReferences.isEmpty, isTrue);
        expect(project.projectReferences.isEmpty, isTrue);
      },
    );
  });

  group('PBXProject round-trip (PBX-19)', () {
    test('PBXProject round-trips via toHash -> configureWithPlist', () {
      const projectUuid = 'AABBCCDDEEFF001122334455';
      const mainGroupUuid = 'AABBCCDDEEFF001122334466';
      const configListUuid = 'AABBCCDDEEFF001122334477';

      final mainGroup = PBXGroup(graph, mainGroupUuid);
      graph.objectsByUuid[mainGroupUuid] = mainGroup;

      final configList = XCConfigurationList(graph, configListUuid);
      graph.objectsByUuid[configListUuid] = configList;

      final plist = <String, dynamic>{
        projectUuid: {
          'isa': 'PBXProject',
          'targets': <String>[],
          'attributes': <String, dynamic>{'LastUpgradeCheck': '1430'},
          'buildConfigurationList': configListUuid,
          'compatibilityVersion': 'Xcode 14.0',
          'developmentRegion': 'en',
          'hasScannedForEncodings': '0',
          'knownRegions': ['en', 'Base'],
          'mainGroup': mainGroupUuid,
          'projectDirPath': '',
          'projectRoot': '',
        },
        mainGroupUuid: {
          'isa': 'PBXGroup',
          'children': <String>[],
          'sourceTree': '<group>',
        },
        configListUuid: {
          'isa': 'XCConfigurationList',
          'buildConfigurations': <String>[],
          'defaultConfigurationIsVisible': '0',
        },
      };

      final project = PBXProject(graph, projectUuid);
      graph.objectsByUuid[projectUuid] = project;
      project.configureWithPlist(plist);

      expect(project.mainGroup, isNotNull);
      expect(project.mainGroup!.uuid, equals(mainGroupUuid));
      expect(project.buildConfigurationList, isNotNull);
      expect(project.buildConfigurationList!.uuid, equals(configListUuid));
      expect(project.compatibilityVersion, equals('Xcode 14.0'));
      expect(project.developmentRegion, equals('en'));
      expect(project.knownRegions, equals(['en', 'Base']));
    });
  });

  group('ObjectDictionary accepts subclass values', () {
    test(
      'ObjectDictionary accepts subclass values: store PBXVariantGroup under PBXGroup-typed key without throwing',
      () {
        final project = graph.newObject((g, u) => PBXProject(g, u));
        final variantGroup = graph.newObject((g, u) => PBXVariantGroup(g, u));

        // PBXVariantGroup is a subclass of PBXGroup.
        // Storing under a PBXGroup-typed slot should NOT throw after the patch.
        const keys = {'ProductGroup': PBXGroup};
        final dict = ObjectDictionary(keys, project);

        expect(() => dict['ProductGroup'] = variantGroup, returnsNormally);
        expect(dict['ProductGroup'], same(variantGroup));
      },
    );
  });
}
