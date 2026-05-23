// — TDD RED: ProfileAction, AnalyzeAction, ArchiveAction tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:dart_xcodeproj/src/scheme/profile_action.dart';
import 'package:dart_xcodeproj/src/scheme/analyze_action.dart';
import 'package:dart_xcodeproj/src/scheme/archive_action.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_product_runnable.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // ProfileAction
  // -------------------------------------------------------------------------

  group('ProfileAction defaults (null constructor)', () {
    test('buildConfiguration defaults to Release', () {
      final a = ProfileAction();
      expect(a.buildConfiguration, equals('Release'));
    });

    test('shouldUseLaunchSchemeArgsEnv defaults to true', () {
      final a = ProfileAction();
      expect(a.shouldUseLaunchSchemeArgsEnv, isTrue);
    });

    test('buildableProductRunnable returns null when absent', () {
      final a = ProfileAction();
      expect(a.buildableProductRunnable, isNull);
    });
  });

  group('ProfileAction from Complex.xcscheme', () {
    late ProfileAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = ProfileAction(scheme.profileActionElement!);
    });

    test('shouldUseLaunchSchemeArgsEnv reads YES as true', () {
      expect(action.shouldUseLaunchSchemeArgsEnv, isTrue);
    });

    test('buildConfiguration reads Release', () {
      expect(action.buildConfiguration, equals('Release'));
    });

    test('buildableProductRunnable returns typed wrapper', () {
      final bpr = action.buildableProductRunnable;
      expect(bpr, isNotNull);
      expect(bpr, isA<BuildableProductRunnable>());
    });
  });

  group('ProfileAction setters', () {
    test('shouldUseLaunchSchemeArgsEnv setter writes NO', () {
      final a = ProfileAction();
      a.shouldUseLaunchSchemeArgsEnv = false;
      expect(
        a.xmlElement.getAttribute('shouldUseLaunchSchemeArgsEnv'),
        equals('NO'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // AnalyzeAction
  // -------------------------------------------------------------------------

  group('AnalyzeAction defaults (null constructor)', () {
    test('buildConfiguration defaults to Debug', () {
      final a = AnalyzeAction();
      expect(a.buildConfiguration, equals('Debug'));
    });
  });

  group('AnalyzeAction from Complex.xcscheme', () {
    late AnalyzeAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = AnalyzeAction(scheme.analyzeActionElement!);
    });

    test('buildConfiguration reads Debug', () {
      expect(action.buildConfiguration, equals('Debug'));
    });

    test('buildConfiguration setter writes value', () {
      action.buildConfiguration = 'Release';
      expect(action.buildConfiguration, equals('Release'));
      action.buildConfiguration = 'Debug';
    });
  });

  // -------------------------------------------------------------------------
  // ArchiveAction
  // -------------------------------------------------------------------------

  group('ArchiveAction defaults (null constructor)', () {
    test('buildConfiguration defaults to Release', () {
      final a = ArchiveAction();
      expect(a.buildConfiguration, equals('Release'));
    });

    test('revealArchiveInOrganizer defaults to true', () {
      final a = ArchiveAction();
      expect(a.revealArchiveInOrganizer, isTrue);
    });

    test('customArchiveName is null when not set', () {
      final a = ArchiveAction();
      expect(a.customArchiveName, isNull);
    });
  });

  group('ArchiveAction from Complex.xcscheme', () {
    late ArchiveAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = ArchiveAction(scheme.archiveActionElement!);
    });

    test('revealArchiveInOrganizer reads YES as true', () {
      expect(action.revealArchiveInOrganizer, isTrue);
    });

    test('customArchiveName reads the string value', () {
      expect(action.customArchiveName, equals('MyArchive'));
    });

    test('buildConfiguration reads Release', () {
      expect(action.buildConfiguration, equals('Release'));
    });
  });

  group('ArchiveAction setters', () {
    test('revealArchiveInOrganizer setter writes NO', () {
      final a = ArchiveAction();
      a.revealArchiveInOrganizer = false;
      expect(
        a.xmlElement.getAttribute('revealArchiveInOrganizer'),
        equals('NO'),
      );
    });

    test('customArchiveName setter writes string', () {
      final a = ArchiveAction();
      a.customArchiveName = 'MyApp';
      expect(a.customArchiveName, equals('MyApp'));
    });

    test('customArchiveName setter with null removes attribute', () {
      final a = ArchiveAction();
      a.customArchiveName = 'MyApp';
      a.customArchiveName = null;
      expect(a.customArchiveName, isNull);
    });
  });
}
