// — TDD RED: TestAction + TestableReference tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:dart_xcodeproj/src/scheme/test_action.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_reference.dart';
import 'package:dart_xcodeproj/src/scheme/environment_variables.dart';
import 'package:dart_xcodeproj/src/scheme/command_line_arguments.dart';
import 'package:dart_xcodeproj/src/scheme/execution_action.dart';
import 'package:dart_xcodeproj/src/scheme/macro_expansion.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

void main() {
  // -------------------------------------------------------------------------
  // TestAction defaults
  // -------------------------------------------------------------------------

  group('TestAction defaults (null constructor)', () {
    test('buildConfiguration defaults to Debug', () {
      final a = TestAction();
      expect(a.buildConfiguration, equals('Debug'));
    });

    test('shouldUseLaunchSchemeArgsEnv defaults to true', () {
      final a = TestAction();
      expect(a.shouldUseLaunchSchemeArgsEnv, isTrue);
    });

    test('codeCoverageEnabled defaults to false (not set)', () {
      final a = TestAction();
      // When not set, returns false
      expect(a.codeCoverageEnabled, isFalse);
    });

    test('testables returns empty list', () {
      final a = TestAction();
      expect(a.testables, isEmpty);
    });

    test('preActions returns empty list', () {
      final a = TestAction();
      expect(a.preActions, isEmpty);
    });

    test('postActions returns empty list', () {
      final a = TestAction();
      expect(a.postActions, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // TestAction from Complex.xcscheme
  // -------------------------------------------------------------------------

  group('TestAction from Complex.xcscheme', () {
    late TestAction action;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      action = TestAction(scheme.testActionElement!);
    });

    test('shouldUseLaunchSchemeArgsEnv reads YES as true', () {
      expect(action.shouldUseLaunchSchemeArgsEnv, isTrue);
    });

    test('codeCoverageEnabled reads YES as true', () {
      expect(action.codeCoverageEnabled, isTrue);
    });

    test('testables returns 1 TestableReference', () {
      expect(action.testables.length, equals(1));
    });

    test('preActions returns 1 ExecutionAction', () {
      expect(action.preActions.length, equals(1));
    });

    test('postActions returns 1 ExecutionAction', () {
      expect(action.postActions.length, equals(1));
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
  // TestAction setters
  // -------------------------------------------------------------------------

  group('TestAction setters', () {
    test('shouldUseLaunchSchemeArgsEnv setter writes NO', () {
      final a = TestAction();
      a.shouldUseLaunchSchemeArgsEnv = false;
      expect(
        a.xmlElement.getAttribute('shouldUseLaunchSchemeArgsEnv'),
        equals('NO'),
      );
    });

    test('codeCoverageEnabled setter writes YES', () {
      final a = TestAction();
      a.codeCoverageEnabled = true;
      expect(a.xmlElement.getAttribute('codeCoverageEnabled'), equals('YES'));
    });
  });

  // -------------------------------------------------------------------------
  // TestAction addTestable
  // -------------------------------------------------------------------------

  group('TestAction addTestable', () {
    test('addTestable mutates and appears in subsequent testables call', () {
      final a = TestAction();
      final ref = TestableReference();
      a.addTestable(ref);
      expect(a.testables.length, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // TestAction addMacroExpansion
  // -------------------------------------------------------------------------

  group('TestAction addMacroExpansion', () {
    test('macroExpansions returns empty list by default', () {
      final a = TestAction();
      expect(a.macroExpansions, isEmpty);
    });

    test(
      'addMacroExpansion mutates and appears in subsequent macroExpansions call',
      () {
        final a = TestAction();
        final me = MacroExpansion();
        me.setBuildableReference(BuildableReference());
        a.addMacroExpansion(me);
        expect(a.macroExpansions.length, equals(1));
      },
    );

    test('addMacroExpansion is inserted before the Testables element', () {
      final a = TestAction();
      final ref = TestableReference();
      a.addTestable(ref);

      final me = MacroExpansion();
      me.setBuildableReference(BuildableReference());
      a.addMacroExpansion(me);

      final childTags = a.xmlElement.children
          .whereType<XmlElement>()
          .map((e) => e.name.local)
          .toList();
      expect(
        childTags.indexOf('MacroExpansion') < childTags.indexOf('Testables'),
        isTrue,
      );
    });

    test('addMacroExpansion appends when no Testables element is present', () {
      final a = TestAction(XmlElement(XmlName('TestAction')));
      final me = MacroExpansion();
      me.setBuildableReference(BuildableReference());
      a.addMacroExpansion(me);
      expect(a.macroExpansions.length, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // TestAction addCodeCoverageTarget / codeCoverageTargets
  // -------------------------------------------------------------------------

  group('TestAction codeCoverageTargets', () {
    test('codeCoverageTargets returns empty list by default', () {
      final a = TestAction();
      expect(a.codeCoverageTargets, isEmpty);
    });

    test(
      'addCodeCoverageTarget mutates and flips onlyGenerateCoverageForSpecifiedTargets',
      () {
        final a = TestAction();
        final ref = BuildableReference();
        ref.setReferenceTarget(
          'ABC',
          'Runner.app',
          'Runner',
          'container:Runner.xcodeproj',
        );
        a.addCodeCoverageTarget(ref);
        expect(a.codeCoverageTargets.length, equals(1));
        expect(
          a.xmlElement.getAttribute('onlyGenerateCoverageForSpecifiedTargets'),
          equals('YES'),
        );
      },
    );

    test('codeCoverageTargets setter replaces existing targets', () {
      final a = TestAction();
      final ref1 = BuildableReference()
        ..setReferenceTarget('A', 'A.app', 'A', 'container:A.xcodeproj');
      final ref2 = BuildableReference()
        ..setReferenceTarget('B', 'B.app', 'B', 'container:B.xcodeproj');
      a.addCodeCoverageTarget(ref1);
      a.codeCoverageTargets = [ref2];
      expect(a.codeCoverageTargets.length, equals(1));
      expect(a.codeCoverageTargets.first.blueprintIdentifier, equals('B'));
    });
  });

  // -------------------------------------------------------------------------
  // TestableReference
  // -------------------------------------------------------------------------

  group('TestableReference defaults', () {
    test('skipped defaults to false', () {
      final r = TestableReference();
      expect(r.skipped, isFalse);
    });
  });

  group('TestableReference from Complex.xcscheme', () {
    late TestableReference ref;

    setUpAll(() async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      final action = TestAction(scheme.testActionElement!);
      ref = action.testables.first;
    });

    test('skipped reads NO as false', () {
      expect(ref.skipped, isFalse);
    });

    test('buildableReferences returns 1 item', () {
      expect(ref.buildableReferences.length, equals(1));
    });
  });

  group('TestableReference skipped setter', () {
    test('skipped setter writes YES', () {
      final r = TestableReference();
      r.skipped = true;
      expect(r.xmlElement.getAttribute('skipped'), equals('YES'));
    });
  });

  group('TestableReference parallelizable / execution ordering', () {
    test('parallelizable defaults to false', () {
      final r = TestableReference();
      expect(r.parallelizable, isFalse);
    });

    test('parallelizable setter writes YES', () {
      final r = TestableReference();
      r.parallelizable = true;
      expect(r.xmlElement.getAttribute('parallelizable'), equals('YES'));
    });

    test('testExecutionOrdering defaults to null', () {
      final r = TestableReference();
      expect(r.testExecutionOrdering, isNull);
    });

    test('randomized is true when testExecutionOrdering is random', () {
      final r = TestableReference();
      r.testExecutionOrdering = 'random';
      expect(r.randomized, isTrue);
    });

    test('randomized is false otherwise', () {
      final r = TestableReference();
      expect(r.randomized, isFalse);
    });
  });

  group('TestableReference removeBuildableReference', () {
    test('removes a previously added reference', () {
      final r = TestableReference();
      final ref = BuildableReference();
      ref.setReferenceTarget('ABC', 'A.app', 'A', 'container:A.xcodeproj');
      r.addBuildableReference(ref);
      expect(r.buildableReferences.length, equals(1));
      r.removeBuildableReference(r.buildableReferences.first);
      expect(r.buildableReferences, isEmpty);
    });

    test(
      'removes using the original ref instance passed to addBuildableReference',
      () {
        final r = TestableReference();
        final ref = BuildableReference();
        ref.setReferenceTarget('ABC', 'A.app', 'A', 'container:A.xcodeproj');
        r.addBuildableReference(ref);
        expect(r.buildableReferences.length, equals(1));
        r.removeBuildableReference(ref);
        expect(r.buildableReferences, isEmpty);
      },
    );
  });

  group('TestableReference skippedTests', () {
    test('skippedTests returns empty list by default', () {
      final r = TestableReference();
      expect(r.skippedTests, isEmpty);
    });

    test(
      'addSkippedTest mutates and appears in subsequent skippedTests call',
      () {
        final r = TestableReference();
        final t = Test()..identifier = 'MyTests/testFoo';
        r.addSkippedTest(t);
        expect(r.skippedTests.length, equals(1));
        expect(r.skippedTests.first.identifier, equals('MyTests/testFoo'));
      },
    );
  });

  group('TestableReference selectedTests / useTestSelectionWhitelist', () {
    test('useTestSelectionWhitelist defaults to false', () {
      final r = TestableReference();
      expect(r.useTestSelectionWhitelist, isFalse);
    });

    test('useTestSelectionWhitelist setter writes YES', () {
      final r = TestableReference();
      r.useTestSelectionWhitelist = true;
      expect(
        r.xmlElement.getAttribute('useTestSelectionWhitelist'),
        equals('YES'),
      );
    });

    test('selectedTests returns empty list by default', () {
      final r = TestableReference();
      expect(r.selectedTests, isEmpty);
    });

    test(
      'addSelectedTest mutates and appears in subsequent selectedTests call',
      () {
        final r = TestableReference();
        final t = Test()..identifier = 'MyTests/testBar';
        r.addSelectedTest(t);
        expect(r.selectedTests.length, equals(1));
        expect(r.selectedTests.first.identifier, equals('MyTests/testBar'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // environmentVariables / commandLineArguments mutations
  // -------------------------------------------------------------------------

  group('TestAction environmentVariables mutation', () {
    test('assignVariable adds child to EnvironmentVariables', () {
      final evWrapper = EnvironmentVariables();
      final ev = EnvironmentVariable();
      ev.key = 'FOO';
      ev.value = 'bar';
      evWrapper.assignVariable(ev);
      expect(evWrapper.allVariables.length, equals(1));
    });
  });

  group('TestAction commandLineArguments mutation', () {
    test('assignArgument adds child to CommandLineArguments', () {
      final clWrapper = CommandLineArguments();
      final cl = CommandLineArgument();
      cl.argument = '--foo';
      cl.isEnabled = true;
      clWrapper.assignArgument(cl);
      expect(clWrapper.allArguments.length, equals(1));
    });
  });

  // -------------------------------------------------------------------------
  // pre/post actions
  // -------------------------------------------------------------------------

  group('TestAction preActions and postActions', () {
    test('addPreAction appears in preActions', () {
      final a = TestAction();
      final ea = ExecutionAction(
        null,
        'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction',
      );
      a.addPreAction(ea);
      expect(a.preActions.length, equals(1));
    });

    test('addPostAction appears in postActions', () {
      final a = TestAction();
      final ea = ExecutionAction(
        null,
        'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction',
      );
      a.addPostAction(ea);
      expect(a.postActions.length, equals(1));
    });
  });
}
