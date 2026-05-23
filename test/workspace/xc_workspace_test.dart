// — unit + round-trip tests for XCWorkspace (WORK-01..WORK-05).
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:io';

import 'package:dart_xcodeproj/src/workspace/file_reference.dart';
import 'package:dart_xcodeproj/src/workspace/group_reference.dart';
import 'package:dart_xcodeproj/src/workspace/xc_workspace.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helper: recursive directory copy
// ---------------------------------------------------------------------------

Future<void> _copyDir(Directory src, Directory dest) async {
  await dest.create(recursive: true);
  await for (final entry in src.list()) {
    final name = p.basename(entry.path);
    if (entry is File) {
      await entry.copy(p.join(dest.path, name));
    } else if (entry is Directory) {
      await _copyDir(entry, Directory(p.join(dest.path, name)));
    }
  }
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('xc_workspace_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // -------------------------------------------------------------------------
  // WORK-01 — create()
  // -------------------------------------------------------------------------

  group('WORK-01 create()', () {
    test(
      'returns XCWorkspace with empty fileReferences and groupReferences',
      () {
        final ws = XCWorkspace.create(p.join(tmp.path, 'New.xcworkspace'));
        expect(ws.fileReferences, isEmpty);
        expect(ws.groupReferences, isEmpty);
      },
    );

    test('schemes is an empty map', () {
      final ws = XCWorkspace.create(p.join(tmp.path, 'New.xcworkspace'));
      expect(ws.schemes, isA<Map<String, String>>());
      expect(ws.schemes, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // WORK-02 — open()
  // -------------------------------------------------------------------------

  group('WORK-02 open()', () {
    const fixtureRoot = 'test/fixtures/workspace/Sample.xcworkspace';

    test('rootReferences has length 2', () async {
      final ws = await XCWorkspace.open(fixtureRoot);
      expect(ws.rootReferences, hasLength(2));
    });

    test(
      'rootReferences[0] is WorkspaceFileReference type=group path=App.xcodeproj',
      () async {
        final ws = await XCWorkspace.open(fixtureRoot);
        final ref = ws.rootReferences[0];
        expect(ref, isA<WorkspaceFileReference>());
        final fr = ref as WorkspaceFileReference;
        expect(fr.type, equals('group'));
        expect(fr.path, equals('App.xcodeproj'));
      },
    );

    test(
      'rootReferences[1] is WorkspaceGroupReference type=container name=Subprojects',
      () async {
        final ws = await XCWorkspace.open(fixtureRoot);
        final ref = ws.rootReferences[1];
        expect(ref, isA<WorkspaceGroupReference>());
        final gr = ref as WorkspaceGroupReference;
        expect(gr.type, equals('container'));
        expect(gr.name, equals('Subprojects'));
        expect(gr.children, hasLength(1));
      },
    );

    test(
      'children[0] is WorkspaceFileReference path=Subprojects/Lib.xcodeproj',
      () async {
        final ws = await XCWorkspace.open(fixtureRoot);
        final gr = ws.rootReferences[1] as WorkspaceGroupReference;
        final child = gr.children[0];
        expect(child, isA<WorkspaceFileReference>());
        final fr = child as WorkspaceFileReference;
        expect(fr.type, equals('group'));
        expect(fr.path, equals('Subprojects/Lib.xcodeproj'));
      },
    );

    test('fileReferences yields exactly 1 element (top-level only)', () async {
      final ws = await XCWorkspace.open(fixtureRoot);
      expect(ws.fileReferences.toList(), hasLength(1));
    });

    test('groupReferences yields exactly 1 element', () async {
      final ws = await XCWorkspace.open(fixtureRoot);
      expect(ws.groupReferences.toList(), hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // WORK-03 — save() byte-identical round-trip
  // -------------------------------------------------------------------------

  group('WORK-03 save()', () {
    test(
      'produces byte-identical round-trip on Sample.xcworkspace fixture',
      () async {
        const fixtureRoot = 'test/fixtures/workspace/Sample.xcworkspace';
        final destWs = p.join(tmp.path, 'Sample.xcworkspace');
        await _copyDir(Directory(fixtureRoot), Directory(destWs));

        final ws = await XCWorkspace.open(destWs);
        await ws.save();

        final orig = File(
          p.join(fixtureRoot, 'contents.xcworkspacedata'),
        ).readAsBytesSync();
        final saved = File(
          p.join(destWs, 'contents.xcworkspacedata'),
        ).readAsBytesSync();
        expect(
          saved,
          equals(orig),
          reason: 'WORK-03 byte-identical round-trip',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // WORK-04 — reference type parsing and absolutePath
  // -------------------------------------------------------------------------

  group('WORK-04 reference types', () {
    // fromLocation parsing
    test(
      'fromLocation group:App.xcodeproj → type=group path=App.xcodeproj',
      () {
        final ref = WorkspaceFileReference.fromLocation('group:App.xcodeproj');
        expect(ref.type, equals('group'));
        expect(ref.path, equals('App.xcodeproj'));
      },
    );

    test('fromLocation container:foo → type=container', () {
      final ref = WorkspaceFileReference.fromLocation('container:foo');
      expect(ref.type, equals('container'));
      expect(ref.path, equals('foo'));
    });

    test('fromLocation absolute:/tmp/x → type=absolute path=/tmp/x', () {
      final ref = WorkspaceFileReference.fromLocation('absolute:/tmp/x');
      expect(ref.type, equals('absolute'));
      expect(ref.path, equals('/tmp/x'));
    });

    test('fromLocation self: → type=self path=empty', () {
      final ref = WorkspaceFileReference.fromLocation('self:');
      expect(ref.type, equals('self'));
      expect(ref.path, equals(''));
    });

    test('location getter returns type:path', () {
      final ref = WorkspaceFileReference(type: 'group', path: 'X.proj');
      expect(ref.location, equals('group:X.proj'));
    });

    // absolutePath cases
    test('absolutePath group resolves relative to workspaceDir', () {
      final ref = WorkspaceFileReference(type: 'group', path: 'App.xcodeproj');
      final abs = ref.absolutePath('/tmp/workspace');
      expect(
        abs,
        equals(p.normalize(p.absolute('/tmp/workspace', 'App.xcodeproj'))),
      );
    });

    test('absolutePath container resolves relative to workspaceDir', () {
      final ref = WorkspaceFileReference(
        type: 'container',
        path: 'Subprojects',
      );
      final abs = ref.absolutePath('/tmp/workspace');
      expect(
        abs,
        equals(p.normalize(p.absolute('/tmp/workspace', 'Subprojects'))),
      );
    });

    test('absolutePath self resolves relative to workspaceDir', () {
      final ref = WorkspaceFileReference(type: 'self', path: '');
      final abs = ref.absolutePath('/tmp/workspace');
      expect(abs, equals(p.normalize(p.absolute('/tmp/workspace', ''))));
    });

    test('absolutePath absolute ignores workspaceDir', () {
      final ref = WorkspaceFileReference(type: 'absolute', path: '/etc/file');
      final abs = ref.absolutePath('/tmp/workspace');
      expect(abs, equals(p.normalize(p.absolute('/etc/file'))));
    });

    test('absolutePath developer throws UnsupportedError', () {
      final ref = WorkspaceFileReference(type: 'developer', path: 'sdk/path');
      expect(() => ref.absolutePath('/tmp'), throwsA(isA<UnsupportedError>()));
    });

    // GroupReference defaults
    test('WorkspaceGroupReference default type is container', () {
      final gr = WorkspaceGroupReference(name: 'MyGroup');
      expect(gr.type, equals('container'));
    });

    test('WorkspaceGroupReference constructor with explicit type', () {
      final gr = WorkspaceGroupReference(
        name: 'G',
        type: 'group',
        path: 'Libs',
      );
      expect(gr.type, equals('group'));
      expect(gr.path, equals('Libs'));
    });
  });

  // -------------------------------------------------------------------------
  // WORK-05 — schemes scan
  // -------------------------------------------------------------------------

  group('WORK-05 schemes', () {
    test('returns Map<String, String>', () async {
      const fixtureRoot = 'test/fixtures/workspace/Sample.xcworkspace';
      final ws = await XCWorkspace.open(fixtureRoot);
      expect(ws.schemes, isA<Map<String, String>>());
    });

    test("contains entry 'Demo' mapped to workspace path", () async {
      const fixtureRoot = 'test/fixtures/workspace/Sample.xcworkspace';
      final ws = await XCWorkspace.open(fixtureRoot);
      expect(
        ws.schemes,
        containsPair('Demo', p.normalize(p.absolute(fixtureRoot))),
      );
    });

    test(
      'does not contain project-internal schemes (fixture has none)',
      () async {
        const fixtureRoot = 'test/fixtures/workspace/Sample.xcworkspace';
        final ws = await XCWorkspace.open(fixtureRoot);
        // Only Demo.xcscheme is in xcshareddata; fixture FileRefs have no real
        // .xcodeproj paths on disk → schemes length is exactly 1
        expect(ws.schemes.length, equals(1));
      },
    );
  });
}
