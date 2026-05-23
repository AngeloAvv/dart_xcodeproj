// — TDD RED: BuildAction + BuildActionEntry tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:dart_xcodeproj/src/scheme/build_action.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_reference.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // BuildAction
  // -------------------------------------------------------------------------

  group('BuildAction defaults (null constructor)', () {
    test('parallelizeBuildables defaults to true', () {
      final a = BuildAction();
      expect(a.parallelizeBuildables, isTrue);
    });

    test('buildImplicitDependencies defaults to true', () {
      final a = BuildAction();
      expect(a.buildImplicitDependencies, isTrue);
    });

    test('entries returns empty list when no BuildActionEntries child', () {
      final a = BuildAction();
      expect(a.entries, isEmpty);
    });
  });

  group('BuildAction from existing XmlElement (Complex.xcscheme)', () {
    late BuildAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = BuildAction(scheme.buildActionElement!);
    });

    test('parallelizeBuildables reads YES as true', () {
      expect(action.parallelizeBuildables, isTrue);
    });

    test('buildImplicitDependencies reads YES as true', () {
      expect(action.buildImplicitDependencies, isTrue);
    });

    test('entries returns 1 BuildActionEntry', () {
      expect(action.entries.length, equals(1));
    });
  });

  group('BuildAction setters', () {
    test('parallelizeBuildables setter mutates xmlElement attribute', () {
      final a = BuildAction();
      a.parallelizeBuildables = false;
      expect(a.xmlElement.getAttribute('parallelizeBuildables'), equals('NO'));
    });

    test('buildImplicitDependencies setter mutates xmlElement attribute', () {
      final a = BuildAction();
      a.buildImplicitDependencies = false;
      expect(
        a.xmlElement.getAttribute('buildImplicitDependencies'),
        equals('NO'),
      );
    });
  });

  group('BuildAction addEntry', () {
    test('addEntry mutates and appears in subsequent entries call', () {
      final a = BuildAction();
      final entry = BuildActionEntry();
      a.addEntry(entry);
      expect(a.entries.length, equals(1));
    });

    test('addEntry twice gives 2 entries', () {
      final a = BuildAction();
      a.addEntry(BuildActionEntry());
      a.addEntry(BuildActionEntry());
      expect(a.entries.length, equals(2));
    });
  });

  // -------------------------------------------------------------------------
  // BuildActionEntry
  // -------------------------------------------------------------------------

  group('BuildActionEntry defaults', () {
    test('buildForTesting defaults to false', () {
      final e = BuildActionEntry();
      expect(e.buildForTesting, isFalse);
    });

    test('buildForRunning defaults to false', () {
      final e = BuildActionEntry();
      expect(e.buildForRunning, isFalse);
    });

    test('buildForProfiling defaults to false', () {
      final e = BuildActionEntry();
      expect(e.buildForProfiling, isFalse);
    });

    test('buildForArchiving defaults to false', () {
      final e = BuildActionEntry();
      expect(e.buildForArchiving, isFalse);
    });

    test('buildForAnalyzing defaults to true', () {
      final e = BuildActionEntry();
      expect(e.buildForAnalyzing, isTrue);
    });
  });

  group('BuildActionEntry from Complex.xcscheme', () {
    late BuildActionEntry entry;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      final action = BuildAction(scheme.buildActionElement!);
      entry = action.entries.first;
    });

    test('buildForTesting is YES', () {
      expect(entry.buildForTesting, isTrue);
    });

    test('buildForRunning is YES', () {
      expect(entry.buildForRunning, isTrue);
    });

    test('buildableReferences returns 1 reference', () {
      expect(entry.buildableReferences.length, equals(1));
    });

    test('buildableReferences[0] has BlueprintName = App', () {
      final ref = entry.buildableReferences.first;
      expect(ref.blueprintName, equals('App'));
    });
  });

  group('BuildActionEntry buildableReference (setter)', () {
    test('buildableReference setter triggers attribute order', () {
      final entry = BuildActionEntry();
      final ref = BuildableReference();
      ref.setReferenceTarget(
        'AABB001122334455',
        'App.app',
        'App',
        'container:App.xcodeproj',
      );
      entry.addBuildableReference(ref);
      // Verify attribute order on the BuildableReference xmlElement
      final attrs = ref.xmlElement.attributes.map((a) => a.name.local).toList();
      expect(
        attrs,
        equals([
          'BuildableIdentifier',
          'BlueprintIdentifier',
          'BuildableName',
          'BlueprintName',
          'ReferencedContainer',
        ]),
      );
    });
  });
}
