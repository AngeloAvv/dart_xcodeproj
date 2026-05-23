// — unit + round-trip tests for XCScheme (SCH-01..SCH-03).
// TDD RED phase: these tests are written BEFORE the implementation.

import 'dart:io';

import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('xc_scheme_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  // -------------------------------------------------------------------------
  // SCH-01 — create()
  // -------------------------------------------------------------------------

  group('SCH-01 create()', () {
    test('returns XCScheme with non-null document', () {
      final scheme = XCScheme.create();
      expect(scheme.document, isNotNull);
    });

    test('path is null for a newly created scheme', () {
      final scheme = XCScheme.create();
      expect(scheme.path, isNull);
    });

    test('root element name is Scheme', () {
      final scheme = XCScheme.create();
      expect(scheme.document.rootElement.name.local, equals('Scheme'));
    });

    test('root element has LastUpgradeVersion attribute', () {
      final scheme = XCScheme.create();
      final attr = scheme.document.rootElement.getAttribute(
        'LastUpgradeVersion',
      );
      expect(attr, isNotNull);
      expect(attr, isNotEmpty);
    });

    test('root element has version attribute = 1.3', () {
      final scheme = XCScheme.create();
      final attr = scheme.document.rootElement.getAttribute('version');
      expect(attr, equals('1.3'));
    });

    test('buildActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.buildActionElement, isNotNull);
    });

    test('buildActionElement has parallelizeBuildables = YES', () {
      final scheme = XCScheme.create();
      expect(
        scheme.buildActionElement!.getAttribute('parallelizeBuildables'),
        equals('YES'),
      );
    });

    test('buildActionElement has buildImplicitDependencies = YES', () {
      final scheme = XCScheme.create();
      expect(
        scheme.buildActionElement!.getAttribute('buildImplicitDependencies'),
        equals('YES'),
      );
    });

    test('testActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.testActionElement, isNotNull);
    });

    test('testActionElement has buildConfiguration = Debug', () {
      final scheme = XCScheme.create();
      expect(
        scheme.testActionElement!.getAttribute('buildConfiguration'),
        equals('Debug'),
      );
    });

    test('testActionElement has shouldUseLaunchSchemeArgsEnv = YES', () {
      final scheme = XCScheme.create();
      expect(
        scheme.testActionElement!.getAttribute('shouldUseLaunchSchemeArgsEnv'),
        equals('YES'),
      );
    });

    test('launchActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.launchActionElement, isNotNull);
    });

    test('launchActionElement has buildConfiguration = Debug', () {
      final scheme = XCScheme.create();
      expect(
        scheme.launchActionElement!.getAttribute('buildConfiguration'),
        equals('Debug'),
      );
    });

    test('launchActionElement has launchStyle = 0', () {
      final scheme = XCScheme.create();
      expect(
        scheme.launchActionElement!.getAttribute('launchStyle'),
        equals('0'),
      );
    });

    test('launchActionElement has useCustomWorkingDirectory = NO', () {
      final scheme = XCScheme.create();
      expect(
        scheme.launchActionElement!.getAttribute('useCustomWorkingDirectory'),
        equals('NO'),
      );
    });

    test('profileActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.profileActionElement, isNotNull);
    });

    test('profileActionElement has buildConfiguration = Release', () {
      final scheme = XCScheme.create();
      expect(
        scheme.profileActionElement!.getAttribute('buildConfiguration'),
        equals('Release'),
      );
    });

    test('analyzeActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.analyzeActionElement, isNotNull);
    });

    test('analyzeActionElement has buildConfiguration = Debug', () {
      final scheme = XCScheme.create();
      expect(
        scheme.analyzeActionElement!.getAttribute('buildConfiguration'),
        equals('Debug'),
      );
    });

    test('archiveActionElement is non-null', () {
      final scheme = XCScheme.create();
      expect(scheme.archiveActionElement, isNotNull);
    });

    test('archiveActionElement has buildConfiguration = Release', () {
      final scheme = XCScheme.create();
      expect(
        scheme.archiveActionElement!.getAttribute('buildConfiguration'),
        equals('Release'),
      );
    });

    test('archiveActionElement has revealArchiveInOrganizer = YES', () {
      final scheme = XCScheme.create();
      expect(
        scheme.archiveActionElement!.getAttribute('revealArchiveInOrganizer'),
        equals('YES'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // SCH-02 — open()
  // -------------------------------------------------------------------------

  group('SCH-02 open()', () {
    const fixturePath = 'test/fixtures/scheme/Demo.xcscheme';

    test('open returns XCScheme with non-null document', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.document, isNotNull);
    });

    test('open sets path on the scheme', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.path, isNotNull);
    });

    test('buildActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.buildActionElement, isNotNull);
    });

    test('testActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.testActionElement, isNotNull);
    });

    test('launchActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.launchActionElement, isNotNull);
    });

    test('profileActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.profileActionElement, isNotNull);
    });

    test('analyzeActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.analyzeActionElement, isNotNull);
    });

    test('archiveActionElement is parsed', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.archiveActionElement, isNotNull);
    });

    test('launchActionElement allowLocationSimulation == YES', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(
        scheme.launchActionElement!.getAttribute('allowLocationSimulation'),
        equals('YES'),
      );
    });

    test('all 6 action elements are non-null (comprehensive check)', () async {
      final scheme = await XCScheme.open(fixturePath);
      expect(scheme.buildActionElement, isNotNull);
      expect(scheme.testActionElement, isNotNull);
      expect(scheme.launchActionElement, isNotNull);
      expect(scheme.profileActionElement, isNotNull);
      expect(scheme.analyzeActionElement, isNotNull);
      expect(scheme.archiveActionElement, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // SCH-03 — saveAs() / save() round-trip
  // -------------------------------------------------------------------------

  group('SCH-03 saveAs() / save()', () {
    const fixturePath = 'test/fixtures/scheme/Demo.xcscheme';

    test('saveAs round-trip: bytes equal original fixture', () async {
      final destPath = p.join(tmp.path, 'Demo.xcscheme');
      final scheme = await XCScheme.open(fixturePath);
      await scheme.saveAs(destPath);

      final orig = File(fixturePath).readAsBytesSync();
      final saved = File(destPath).readAsBytesSync();
      expect(saved, equals(orig), reason: 'SCH-03 byte-identical round-trip');
    });

    test(
      'save() on scheme opened from disk produces byte-identical output',
      () async {
        final destPath = p.join(tmp.path, 'Demo.xcscheme');
        // Copy fixture so save() has a valid path
        await File(fixturePath).copy(destPath);
        final scheme = await XCScheme.open(destPath);
        await scheme.save();

        final orig = File(fixturePath).readAsBytesSync();
        final saved = File(destPath).readAsBytesSync();
        expect(saved, equals(orig), reason: 'save() byte-identical round-trip');
      },
    );

    test('save() on a null-path scheme throws StateError', () {
      final scheme = XCScheme.create();
      expect(() => scheme.save(), throwsA(isA<StateError>()));
    });

    test(
      'create() + saveAs() produces file starting with double-quoted XML declaration',
      () async {
        final destPath = p.join(tmp.path, 'New.xcscheme');
        final scheme = XCScheme.create();
        await scheme.saveAs(destPath);
        final content = await File(destPath).readAsString();
        expect(content, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
      },
    );

    test('saveAs updates path on the scheme', () async {
      final destPath = p.join(tmp.path, 'New.xcscheme');
      final scheme = XCScheme.create();
      expect(scheme.path, isNull);
      await scheme.saveAs(destPath);
      expect(scheme.path, isNotNull);
    });

    test('toXmlString() contains double-quoted XML declaration', () {
      final scheme = XCScheme.create();
      final xml = scheme.toXmlString();
      expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    });
  });
}
