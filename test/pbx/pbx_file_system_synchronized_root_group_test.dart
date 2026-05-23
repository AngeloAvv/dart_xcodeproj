// Tests for PBXFileSystemSynchronizedRootGroup — covers PBX-17.

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/object/object_list.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_system_synchronized_root_group.dart';
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXFileSystemSynchronizedRootGroup'] = (g, u) =>
        PBXFileSystemSynchronizedRootGroup(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  group('PBXFileSystemSynchronizedRootGroup isa (PBX-17)', () {
    test(
      "PBXFileSystemSynchronizedRootGroup has isa 'PBXFileSystemSynchronizedRootGroup'",
      () {
        final group = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
        );
        expect(group.isa, equals('PBXFileSystemSynchronizedRootGroup'));
      },
    );
  });

  group(
    'PBXFileSystemSynchronizedRootGroup.exceptions is ObjectList<AbstractObject>',
    () {
      test(
        'PBXFileSystemSynchronizedRootGroup.exceptions is ObjectList<AbstractObject>',
        () {
          final group = graph.newObject(
            (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
          );
          expect(group.exceptions, isA<ObjectList<AbstractObject>>());
        },
      );

      test('exceptions ObjectList starts empty', () {
        final group = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
        );
        expect(group.exceptions.isEmpty, isTrue);
      });
    },
  );

  group('PBXFileSystemSynchronizedRootGroup serialization (PBX-17)', () {
    test('serializes path when non-null', () {
      final group = graph.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      group.path = 'Sources';
      final hash = group.toHash();
      expect(hash['path'], equals('Sources'));
    });

    test('serializes sourceTree (always present, defaults to <group>)', () {
      final group = graph.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      final hash = group.toHash();
      expect(hash.containsKey('sourceTree'), isTrue);
      expect(hash['sourceTree'], equals('<group>'));
    });

    test('serializes name when non-null', () {
      final group = graph.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      group.name = 'MySyncGroup';
      final hash = group.toHash();
      expect(hash['name'], equals('MySyncGroup'));
    });

    test('does NOT serialize name when null', () {
      final group = graph.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      final hash = group.toHash();
      expect(hash.containsKey('name'), isFalse);
    });

    test('serializes explicitFileType when non-null', () {
      final group = graph.newObject(
        (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
      );
      group.explicitFileType = 'folder';
      final hash = group.toHash();
      expect(hash['explicitFileType'], equals('folder'));
    });

    test(
      'PBXFileSystemSynchronizedRootGroup serializes exceptions as UUID list (always emitted)',
      () {
        final group = graph.newObject(
          (g, u) => PBXFileSystemSynchronizedRootGroup(g, u),
        );
        // Exceptions always emitted, even when empty
        final hash = group.toHash();
        expect(hash.containsKey('exceptions'), isTrue);
        expect(hash['exceptions'], isA<List<dynamic>>());
        expect(hash['exceptions'], isEmpty);
      },
    );
  });

  group('PBXFileSystemSynchronizedRootGroup round-trip (PBX-17)', () {
    test(
      'PBXFileSystemSynchronizedRootGroup round-trips via toHash -> configureWithPlist',
      () {
        const uuid = 'AABBCCDDEEFF001122334499';
        final plist = <String, dynamic>{
          uuid: {
            'isa': 'PBXFileSystemSynchronizedRootGroup',
            'path': 'Sources',
            'sourceTree': '<group>',
            'name': 'SourcesSync',
            'exceptions': <String>[],
          },
        };

        final group = PBXFileSystemSynchronizedRootGroup(graph, uuid);
        graph.objectsByUuid[uuid] = group;
        group.configureWithPlist(plist);

        expect(group.path, equals('Sources'));
        expect(group.sourceTree, equals('<group>'));
        expect(group.name, equals('SourcesSync'));
        expect(group.exceptions.isEmpty, isTrue);

        final hash = group.toHash();
        expect(hash['path'], equals('Sources'));
        expect(hash['sourceTree'], equals('<group>'));
      },
    );
  });
}
