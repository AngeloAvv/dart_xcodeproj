// — TDD RED: LaunchAction tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:dart_xcodeproj/src/scheme/launch_action.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_product_runnable.dart';
import 'package:dart_xcodeproj/src/scheme/environment_variables.dart';
import 'package:dart_xcodeproj/src/scheme/command_line_arguments.dart';
import 'package:dart_xcodeproj/src/scheme/location_scenario_reference.dart';
import 'package:dart_xcodeproj/src/scheme/macro_expansion.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // LaunchAction defaults
  // -------------------------------------------------------------------------

  group('LaunchAction defaults (null constructor)', () {
    test('buildConfiguration defaults to Debug', () {
      final a = LaunchAction();
      expect(a.buildConfiguration, equals('Debug'));
    });

    test('allowLocationSimulation defaults to true', () {
      final a = LaunchAction();
      expect(a.allowLocationSimulation, isTrue);
    });

    test('useCustomWorkingDirectory defaults to false', () {
      final a = LaunchAction();
      expect(a.useCustomWorkingDirectory, isFalse);
    });

    test('debugDocumentVersioning defaults to true', () {
      final a = LaunchAction();
      expect(a.debugDocumentVersioning, isTrue);
    });

    test('launchStyle defaults to 0', () {
      final a = LaunchAction();
      expect(a.launchStyle, equals('0'));
    });

    test('macroExpansions returns empty list', () {
      final a = LaunchAction();
      expect(a.macroExpansions, isEmpty);
    });

    test('preActions returns empty list', () {
      final a = LaunchAction();
      expect(a.preActions, isEmpty);
    });

    test('postActions returns empty list', () {
      final a = LaunchAction();
      expect(a.postActions, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // LaunchAction from Complex.xcscheme
  // -------------------------------------------------------------------------

  group('LaunchAction from Complex.xcscheme', () {
    late LaunchAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = LaunchAction(scheme.launchActionElement!);
    });

    test('buildConfiguration reads Debug', () {
      expect(action.buildConfiguration, equals('Debug'));
    });

    test('allowLocationSimulation reads YES as true', () {
      expect(action.allowLocationSimulation, isTrue);
    });

    test(
      'buildableProductRunnable returns typed wrapper when child exists',
      () {
        final bpr = action.buildableProductRunnable;
        expect(bpr, isNotNull);
        expect(bpr, isA<BuildableProductRunnable>());
      },
    );

    test('buildableProductRunnable.runnableDebuggingMode is 0', () {
      final bpr = action.buildableProductRunnable!;
      expect(bpr.runnableDebuggingMode, equals('0'));
    });

    test('locationScenarioReference returns typed wrapper', () {
      final lsr = action.locationScenarioReference;
      expect(lsr, isNotNull);
      expect(lsr, isA<LocationScenarioReference>());
    });

    test('locationScenarioReference.identifier is set', () {
      final lsr = action.locationScenarioReference!;
      expect(lsr.identifier, equals('com.apple.maps.sim.GoldenGateBridge'));
    });

    test('locationScenarioReference.referenceType is 1', () {
      final lsr = action.locationScenarioReference!;
      expect(lsr.referenceType, equals('1'));
    });

    test('macroExpansions returns 1 MacroExpansion', () {
      expect(action.macroExpansions.length, equals(1));
    });

    test('macroExpansions[0] has buildableReference', () {
      final me = action.macroExpansions.first;
      expect(me, isA<MacroExpansion>());
      final br = me.buildableReference;
      expect(br, isNotNull);
    });

    test('environmentVariables returns EnvironmentVariables wrapper', () {
      final ev = action.environmentVariables;
      expect(ev, isNotNull);
      expect(ev, isA<EnvironmentVariables>());
    });

    test('commandLineArguments returns CommandLineArguments wrapper', () {
      final ca = action.commandLineArguments;
      expect(ca, isNotNull);
      expect(ca, isA<CommandLineArguments>());
    });
  });

  // -------------------------------------------------------------------------
  // LaunchAction setters
  // -------------------------------------------------------------------------

  group('LaunchAction setters', () {
    test('allowLocationSimulation setter writes NO', () {
      final a = LaunchAction();
      a.allowLocationSimulation = false;
      expect(
        a.xmlElement.getAttribute('allowLocationSimulation'),
        equals('NO'),
      );
    });

    test('useCustomWorkingDirectory setter writes YES', () {
      final a = LaunchAction();
      a.useCustomWorkingDirectory = true;
      expect(
        a.xmlElement.getAttribute('useCustomWorkingDirectory'),
        equals('YES'),
      );
    });

    test('debugDocumentVersioning setter writes NO', () {
      final a = LaunchAction();
      a.debugDocumentVersioning = false;
      expect(
        a.xmlElement.getAttribute('debugDocumentVersioning'),
        equals('NO'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // LaunchAction buildableProductRunnable is null when no child
  // -------------------------------------------------------------------------

  group('LaunchAction buildableProductRunnable null when absent', () {
    test('returns null if no BuildableProductRunnable child', () {
      final a = LaunchAction();
      expect(a.buildableProductRunnable, isNull);
    });
  });
}
