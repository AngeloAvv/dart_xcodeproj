// — TDD RED: TestAction + TestableReference tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:dart_xcodeproj/src/scheme/test_action.dart';
import 'package:dart_xcodeproj/src/scheme/environment_variables.dart';
import 'package:dart_xcodeproj/src/scheme/command_line_arguments.dart';
import 'package:dart_xcodeproj/src/scheme/execution_action.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

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
