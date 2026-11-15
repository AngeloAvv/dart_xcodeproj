// Tests for PBXReferenceProxy — covers PBX-12.

import 'dart:io';

import 'package:dart_xcodeproj/dart_xcodeproj.dart';
import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../object/helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() {
    graph = MockObjectGraph();
    isaRegistry['PBXContainerItemProxy'] = (g, u) =>
        PBXContainerItemProxy(g, u);
    isaRegistry['PBXReferenceProxy'] = (g, u) => PBXReferenceProxy(g, u);
  });

  tearDown(() {
    graph.reset();
    isaRegistry.clear();
  });

  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy isa (PBX-12)', () {
    test("PBXReferenceProxy has isa 'PBXReferenceProxy'", () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      expect(refProxy.isa, equals('PBXReferenceProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // remoteRef ref-counting
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy remoteRef ref-counting (PBX-12)', () {
    test(
      'PBXReferenceProxy.remoteRef setter ref counts PBXContainerItemProxy',
      () {
        final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final containerProxy = graph.newObject(
          (g, u) => PBXContainerItemProxy(g, u),
        );

        expect(containerProxy.referrers.contains(refProxy), isFalse);
        refProxy.remoteRef = containerProxy;
        expect(containerProxy.referrers.contains(refProxy), isTrue);
      },
    );

    test('remoteRef setter decrements old ref when reassigned', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final proxy1 = graph.newObject((g, u) => PBXContainerItemProxy(g, u));
      final proxy2 = graph.newObject((g, u) => PBXContainerItemProxy(g, u));

      refProxy.remoteRef = proxy1;
      expect(proxy1.referrers.contains(refProxy), isTrue);

      refProxy.remoteRef = proxy2;
      expect(proxy1.referrers.contains(refProxy), isFalse);
      expect(proxy2.referrers.contains(refProxy), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy serialization (PBX-12)', () {
    test('PBXReferenceProxy serializes path when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.path = 'Framework.framework';
      final hash = refProxy.toHash();
      expect(hash.containsKey('path'), isTrue);
      expect(hash['path'], equals('Framework.framework'));
    });

    test('PBXReferenceProxy serializes fileType when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.fileType = 'wrapper.framework';
      final hash = refProxy.toHash();
      expect(hash.containsKey('fileType'), isTrue);
      expect(hash['fileType'], equals('wrapper.framework'));
    });

    test('PBXReferenceProxy serializes sourceTree when non-null', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.sourceTree = 'BUILT_PRODUCTS_DIR';
      final hash = refProxy.toHash();
      expect(hash.containsKey('sourceTree'), isTrue);
      expect(hash['sourceTree'], equals('BUILT_PRODUCTS_DIR'));
    });

    test(
      'PBXReferenceProxy serializes remoteRef as UUID string when non-null',
      () {
        final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final containerProxy = graph.newObject(
          (g, u) => PBXContainerItemProxy(g, u),
        );
        refProxy.remoteRef = containerProxy;
        final hash = refProxy.toHash();
        expect(hash.containsKey('remoteRef'), isTrue);
        expect(hash['remoteRef'], equals(containerProxy.uuid));
      },
    );

    test('PBXReferenceProxy omits null attributes', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final hash = refProxy.toHash();
      expect(hash.containsKey('path'), isFalse);
      expect(hash.containsKey('fileType'), isFalse);
      expect(hash.containsKey('sourceTree'), isFalse);
      expect(hash.containsKey('remoteRef'), isFalse);
      expect(hash['isa'], equals('PBXReferenceProxy'));
    });
  });

  // ---------------------------------------------------------------------------
  // Round-trip via configureWithPlist
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy round-trip (PBX-12)', () {
    test(
      'PBXReferenceProxy round-trips through toHash → configureWithPlist',
      () {
        const containerProxyUuid = 'CCCCCCCCCCCCCCCCCCCCCC01';
        const refProxyUuid = 'DDDDDDDDDDDDDDDDDDDDDD01';

        final plist = <String, dynamic>{
          containerProxyUuid: {
            'isa': 'PBXContainerItemProxy',
            'containerPortal': 'EEEEEEEEEEEEEEEEEEEEEE01',
            'proxyType': '2',
            'remoteGlobalIDString': 'FFFFFFFFFFFFFFFFFFFF0001',
            'remoteInfo': 'RemoteLib',
          },
          refProxyUuid: {
            'isa': 'PBXReferenceProxy',
            'path': 'libRemote.a',
            'fileType': 'archive.ar',
            'sourceTree': 'BUILT_PRODUCTS_DIR',
            'remoteRef': containerProxyUuid,
          },
        };

        final refProxy = PBXReferenceProxy(graph, refProxyUuid);
        graph.objectsByUuid[refProxyUuid] = refProxy;
        refProxy.configureWithPlist(plist);

        expect(refProxy.path, equals('libRemote.a'));
        expect(refProxy.fileType, equals('archive.ar'));
        expect(refProxy.sourceTree, equals('BUILT_PRODUCTS_DIR'));
        expect(refProxy.remoteRef, isNotNull);
        expect(refProxy.remoteRef, isA<PBXContainerItemProxy>());
        expect(refProxy.remoteRef!.uuid, equals(containerProxyUuid));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // clearRelationships
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy clearRelationships (PBX-12)', () {
    test('PBXReferenceProxy.clearRelationships nulls remoteRef', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final containerProxy = graph.newObject(
        (g, u) => PBXContainerItemProxy(g, u),
      );
      refProxy.remoteRef = containerProxy;
      expect(containerProxy.referrers.contains(refProxy), isTrue);

      refProxy.clearRelationships();
      expect(refProxy.remoteRef, isNull);
      expect(containerProxy.referrers.contains(refProxy), isFalse);
    });

    test('PBXReferenceProxy.removeReference nulls remoteRef when matching', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final containerProxy = graph.newObject(
        (g, u) => PBXContainerItemProxy(g, u),
      );
      refProxy.remoteRef = containerProxy;

      refProxy.removeReference(containerProxy);
      expect(refProxy.remoteRef, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // buildFiles / removeFromProject (issue #10)
  // ---------------------------------------------------------------------------
  group('PBXReferenceProxy buildFiles and removeFromProject', () {
    test('buildFiles returns only the PBXBuildFile referrers', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final bf1 = graph.newObject((g, u) => PBXBuildFile(g, u));
      final bf2 = graph.newObject((g, u) => PBXBuildFile(g, u));
      final other = graph.newObject((g, u) => PBXBuildFile(g, u));
      bf1.fileRef = refProxy;
      bf2.fileRef = refProxy;
      other.fileRef = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      refProxy.addReferrer(PBXContainerItemProxy(graph, 'X'));

      expect(refProxy.buildFiles, unorderedEquals([bf1, bf2]));
    });

    test('removeFromProject removes build files and the remoteRef', () {
      final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
      final containerProxy = graph.newObject(
        (g, u) => PBXContainerItemProxy(g, u),
      );
      final bf = graph.newObject((g, u) => PBXBuildFile(g, u));
      refProxy.remoteRef = containerProxy;
      bf.fileRef = refProxy;

      refProxy.removeFromProject();

      expect(graph.objectsByUuid.containsKey(refProxy.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(bf.uuid), isFalse);
      expect(graph.objectsByUuid.containsKey(containerProxy.uuid), isFalse);
      expect(refProxy.referrers, isEmpty);
      expect(containerProxy.referrers, isEmpty);
      expect(bf.fileRef, isNull);
    });

    test(
      'remoteRef still referenced elsewhere is kept (refcount, as Ruby)',
      () {
        final refProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final otherProxy = graph.newObject((g, u) => PBXReferenceProxy(g, u));
        final containerProxy = graph.newObject(
          (g, u) => PBXContainerItemProxy(g, u),
        );
        refProxy.remoteRef = containerProxy;
        otherProxy.remoteRef = containerProxy;

        refProxy.removeFromProject();

        expect(graph.objectsByUuid[containerProxy.uuid], same(containerProxy));
        expect(containerProxy.referrers, equals({otherProxy}));
      },
    );
  });

  group(
    'PBXReferenceProxy removeFromProject on a sub-project (Ruby parity)',
    () {
      late Directory tmp;

      setUp(() => tmp = Directory.systemTemp.createTempSync('xcodeproj_rp_'));
      tearDown(() => tmp.deleteSync(recursive: true));

      Future<XcodeProject> open(String fixture) async {
        final bundle = Directory(p.join(tmp.path, 'App.xcodeproj'))
          ..createSync();
        File(
          p.join('test', 'fixtures', fixture),
        ).copySync(p.join(bundle.path, 'project.pbxproj'));
        return XcodeProject.open(bundle.path);
      }

      /// Every 24-hex UUID referenced as a value (not as an object key) must be
      /// the key of an object entry.
      void expectNoDanglingUuids(String pbxproj) {
        final defined = RegExp(
          r'^\t\t([0-9A-F]{24}) ',
          multiLine: true,
        ).allMatches(pbxproj).map((m) => m.group(1)).toSet();
        final used = RegExp(
          r'(?<![0-9A-F])[0-9A-F]{24}(?![0-9A-F])',
        ).allMatches(pbxproj).map((m) => m.group(0)).toSet();
        // remoteGlobalIDString points into the *sub-project*, not this one.
        final remote = RegExp(
          r'remoteGlobalIDString = ([0-9A-F]{24})',
        ).allMatches(pbxproj).map((m) => m.group(1)).toSet();
        final rootObject = RegExp(
          r'rootObject = ([0-9A-F]{24})',
        ).firstMatch(pbxproj)!.group(1);
        expect(
          used.difference(defined).difference(remote),
          isEmpty,
          reason: 'UUIDs referenced but not defined (root: $rootObject)',
        );
      }

      test('the dangling-UUID helper flags undefined tab-indented entries', () {
        const defined = 'AAAAAAAAAAAAAAAAAAAAAAAA';
        const undefinedUuid = 'BBBBBBBBBBBBBBBBBBBBBBBB';
        String pbxproj(String entry) =>
            '''
\t\t$defined /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tfiles = (
\t\t\t\t$entry /* a.m in Sources */,
\t\t\t);
\t\t};
\t\trootObject = $defined;
''';

        expectNoDanglingUuids(pbxproj(defined));
        expect(
          () => expectNoDanglingUuids(pbxproj(undefinedUuid)),
          throwsA(isA<TestFailure>()),
        );
      });

      test('buildFiles lists the build files of the proxy', () async {
        final project = await open('subproject.pbxproj');
        final proxy = project.objectsByUuid.values
            .whereType<PBXReferenceProxy>()
            .single;
        expect(proxy.buildFiles, hasLength(2));
      });

      test(
        'removal then save matches Ruby and leaves no dangling UUIDs',
        () async {
          final project = await open('subproject.pbxproj');
          final proxy = project.objectsByUuid.values
              .whereType<PBXReferenceProxy>()
              .single;
          final containerProxy = proxy.remoteRef!;
          final buildFiles = proxy.buildFiles;

          proxy.removeFromProject();
          await project.save();

          final saved = File(
            p.join(project.path, 'project.pbxproj'),
          ).readAsStringSync();
          // Generated by the Ruby xcodeproj 1.27.0 gem:
          //   proxy.remove_from_project; project.save
          expect(
            saved,
            File(
              'test/fixtures/subproject_proxy_removed.pbxproj',
            ).readAsStringSync(),
          );
          expectNoDanglingUuids(saved);
          for (final obj in [proxy, containerProxy, ...buildFiles]) {
            expect(project.objectsByUuid.containsKey(obj.uuid), isFalse);
            expect(saved.contains(obj.uuid), isFalse);
          }
          for (final phase
              in project.targets.first.buildPhases
                  .whereType<AbstractBuildPhase>()) {
            expect(phase.files.any((f) => f.fileRef == proxy), isFalse);
          }
        },
      );
    },
  );
}
