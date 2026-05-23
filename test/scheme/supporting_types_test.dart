// — TDD RED: Supporting types tests.
// Tests are written BEFORE the implementation. All tests should fail (RED).

import 'package:xml/xml.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_reference.dart';
import 'package:dart_xcodeproj/src/scheme/buildable_product_runnable.dart';
import 'package:dart_xcodeproj/src/scheme/remote_runnable.dart';
import 'package:dart_xcodeproj/src/scheme/execution_action.dart';
import 'package:dart_xcodeproj/src/scheme/command_line_arguments.dart';
import 'package:dart_xcodeproj/src/scheme/environment_variables.dart';
import 'package:dart_xcodeproj/src/scheme/location_scenario_reference.dart';
import 'package:dart_xcodeproj/src/scheme/macro_expansion.dart';
import 'package:dart_xcodeproj/src/scheme/send_email_action_content.dart';
import 'package:dart_xcodeproj/src/scheme/shell_script_action_content.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

void main() {
  // -------------------------------------------------------------------------
  // BuildableReference — correct attribute order
  // -------------------------------------------------------------------------

  group('BuildableReference defaults', () {
    test('creates with BuildableIdentifier = primary', () {
      final r = BuildableReference();
      expect(r.buildableIdentifier, equals('primary'));
    });
  });

  group('BuildableReference.setReferenceTarget', () {
    test(
      'attribute order is BuildableIdentifier, BlueprintIdentifier, BuildableName, BlueprintName, ReferencedContainer',
      () {
        final r = BuildableReference();
        r.setReferenceTarget(
          'AABB001122334455',
          'App.app',
          'App',
          'container:App.xcodeproj',
        );
        final attrNames = r.xmlElement.attributes
            .map((a) => a.name.local)
            .toList();
        expect(
          attrNames,
          equals([
            'BuildableIdentifier',
            'BlueprintIdentifier',
            'BuildableName',
            'BlueprintName',
            'ReferencedContainer',
          ]),
        );
      },
    );

    test('sets correct values', () {
      final r = BuildableReference();
      r.setReferenceTarget(
        'AABB001122334455',
        'MyApp.app',
        'MyApp',
        'container:MyApp.xcodeproj',
      );
      expect(r.blueprintIdentifier, equals('AABB001122334455'));
      expect(r.buildableName, equals('MyApp.app'));
      expect(r.blueprintName, equals('MyApp'));
      expect(r.referencedContainer, equals('container:MyApp.xcodeproj'));
    });
  });

  group('BuildableReference individual setters', () {
    test('buildableIdentifier setter works', () {
      final r = BuildableReference();
      r.buildableIdentifier = 'secondary';
      expect(r.buildableIdentifier, equals('secondary'));
    });

    test('blueprintName setter works', () {
      final r = BuildableReference();
      r.blueprintName = 'MyTarget';
      expect(r.blueprintName, equals('MyTarget'));
    });
  });

  // -------------------------------------------------------------------------
  // EnvironmentVariable
  // -------------------------------------------------------------------------

  group('EnvironmentVariable', () {
    test('isEnabled defaults to true (YES default when attr absent)', () {
      final ev = EnvironmentVariable();
      // No isEnabled attr set yet — should default to true per Ruby
      // (default in constructor is YES)
      ev.key = 'KEY';
      ev.value = 'val';
      expect(ev.isEnabled, isTrue);
    });

    test('key setter works', () {
      final ev = EnvironmentVariable();
      ev.key = 'MY_VAR';
      expect(ev.key, equals('MY_VAR'));
    });

    test('value setter works', () {
      final ev = EnvironmentVariable();
      ev.value = 'hello';
      expect(ev.value, equals('hello'));
    });

    test('isEnabled setter writes NO', () {
      final ev = EnvironmentVariable();
      ev.isEnabled = false;
      expect(ev.xmlElement.getAttribute('isEnabled'), equals('NO'));
    });
  });

  // -------------------------------------------------------------------------
  // EnvironmentVariables
  // -------------------------------------------------------------------------

  group('EnvironmentVariables', () {
    test('allVariables returns empty list initially', () {
      final evs = EnvironmentVariables();
      expect(evs.allVariables, isEmpty);
    });

    test('assignVariable adds variable', () {
      final evs = EnvironmentVariables();
      final ev = EnvironmentVariable()
        ..key = 'FOO'
        ..value = 'bar';
      evs.assignVariable(ev);
      expect(evs.allVariables.length, equals(1));
    });

    test('operator [] returns variable by key', () {
      final evs = EnvironmentVariables();
      final ev = EnvironmentVariable()
        ..key = 'MY_KEY'
        ..value = '42';
      evs.assignVariable(ev);
      final found = evs['MY_KEY'];
      expect(found, isNotNull);
      expect(found!.value, equals('42'));
    });

    test('operator [] returns null for missing key', () {
      final evs = EnvironmentVariables();
      expect(evs['MISSING'], isNull);
    });

    test('removeVariable removes by key', () {
      final evs = EnvironmentVariables();
      final ev = EnvironmentVariable()
        ..key = 'X'
        ..value = '1';
      evs.assignVariable(ev);
      evs.removeVariable('X');
      expect(evs.allVariables, isEmpty);
    });

    test('from Complex.xcscheme LaunchAction has MY_KEY variable', () async {
      final scheme = await XCScheme.open(
        'test/fixtures/scheme/Complex.xcscheme',
      );
      // LaunchAction has EnvironmentVariables with MY_KEY
      // We access it through the raw element for now
      final launchEl = scheme.launchActionElement!;
      final evEl = launchEl.findElements('EnvironmentVariables').firstOrNull;
      expect(evEl, isNotNull);
      final evs = EnvironmentVariables(evEl);
      final found = evs['MY_KEY'];
      expect(found, isNotNull);
      expect(found!.value, equals('my_value'));
    });
  });

  // -------------------------------------------------------------------------
  // CommandLineArgument
  // -------------------------------------------------------------------------

  group('CommandLineArgument', () {
    test('argument setter works', () {
      final cl = CommandLineArgument();
      cl.argument = '--verbose';
      expect(cl.argument, equals('--verbose'));
    });

    test('isEnabled setter writes YES', () {
      final cl = CommandLineArgument();
      cl.isEnabled = true;
      expect(cl.xmlElement.getAttribute('isEnabled'), equals('YES'));
    });
  });

  // -------------------------------------------------------------------------
  // CommandLineArguments
  // -------------------------------------------------------------------------

  group('CommandLineArguments', () {
    test('allArguments returns empty list initially', () {
      final ca = CommandLineArguments();
      expect(ca.allArguments, isEmpty);
    });

    test('assignArgument adds argument', () {
      final ca = CommandLineArguments();
      final cl = CommandLineArgument()
        ..argument = '--foo'
        ..isEnabled = true;
      ca.assignArgument(cl);
      expect(ca.allArguments.length, equals(1));
    });

    test('allArguments returns List<CommandLineArgument>', () {
      final ca = CommandLineArguments();
      final cl = CommandLineArgument()..argument = '--bar';
      ca.assignArgument(cl);
      expect(ca.allArguments, isA<List<CommandLineArgument>>());
    });
  });

  // -------------------------------------------------------------------------
  // ExecutionAction
  // -------------------------------------------------------------------------

  group('ExecutionAction with ShellScriptActionContent', () {
    test(
      'shellScriptActionContent returns ShellScriptActionContent when action type is shell script',
      () {
        const shellType =
            'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction';
        final ea = ExecutionAction(null, shellType);
        final content = ShellScriptActionContent();
        content.title = 'My Script';
        content.scriptText = 'echo hello';
        ea.setActionContent(content);
        expect(ea.shellScriptActionContent, isNotNull);
        expect(ea.shellScriptActionContent, isA<ShellScriptActionContent>());
      },
    );

    test(
      'from Complex.xcscheme TestAction preActions[0] has shell script content',
      () async {
        final scheme = await XCScheme.open(
          'test/fixtures/scheme/Complex.xcscheme',
        );
        final testEl = scheme.testActionElement!;
        final preActionsEl = testEl.findElements('PreActions').firstOrNull;
        expect(preActionsEl, isNotNull);
        final execEl = preActionsEl!
            .findElements('ExecutionAction')
            .firstOrNull;
        expect(execEl, isNotNull);
        final ea = ExecutionAction(execEl);
        expect(ea.shellScriptActionContent, isNotNull);
      },
    );
  });

  group('ExecutionAction with SendEmailActionContent', () {
    test(
      'sendEmailActionContent returns SendEmailActionContent when action type is send email',
      () {
        const emailType =
            'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction';
        final ea = ExecutionAction(null, emailType);
        final content = SendEmailActionContent();
        content.subject = 'Test Results';
        ea.setActionContent(content);
        expect(ea.sendEmailActionContent, isNotNull);
        expect(ea.sendEmailActionContent, isA<SendEmailActionContent>());
      },
    );

    test(
      'from Complex.xcscheme TestAction postActions[0] has send email content',
      () async {
        final scheme = await XCScheme.open(
          'test/fixtures/scheme/Complex.xcscheme',
        );
        final testEl = scheme.testActionElement!;
        final postActionsEl = testEl.findElements('PostActions').firstOrNull;
        expect(postActionsEl, isNotNull);
        final execEl = postActionsEl!
            .findElements('ExecutionAction')
            .firstOrNull;
        expect(execEl, isNotNull);
        final ea = ExecutionAction(execEl);
        expect(ea.sendEmailActionContent, isNotNull);
      },
    );
  });

  // -------------------------------------------------------------------------
  // ShellScriptActionContent
  // -------------------------------------------------------------------------

  group('ShellScriptActionContent', () {
    test('title defaults to Run Script', () {
      final s = ShellScriptActionContent();
      expect(s.title, equals('Run Script'));
    });

    test('title setter works', () {
      final s = ShellScriptActionContent();
      s.title = 'My Script';
      expect(s.title, equals('My Script'));
    });

    test('scriptText setter works', () {
      final s = ShellScriptActionContent();
      s.scriptText = 'echo hello';
      expect(s.scriptText, equals('echo hello'));
    });

    test('shellToInvoke setter works', () {
      final s = ShellScriptActionContent();
      s.shellToInvoke = '/bin/bash';
      expect(s.shellToInvoke, equals('/bin/bash'));
    });

    test(
      'from Complex.xcscheme TestAction pre-action has correct script',
      () async {
        final scheme = await XCScheme.open(
          'test/fixtures/scheme/Complex.xcscheme',
        );
        final testEl = scheme.testActionElement!;
        final execEl = testEl
            .findElements('PreActions')
            .first
            .findElements('ExecutionAction')
            .first;
        final ea = ExecutionAction(execEl);
        final content = ea.shellScriptActionContent!;
        expect(content.title, equals('Pre-Test Script'));
        expect(content.scriptText, equals('echo pre-test'));
        expect(content.shellToInvoke, equals('/bin/sh'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // SendEmailActionContent
  // -------------------------------------------------------------------------

  group('SendEmailActionContent', () {
    test('title defaults to Send Email', () {
      final s = SendEmailActionContent();
      expect(s.title, equals('Send Email'));
    });

    test('attachLogToEmail defaults to false (NO)', () {
      final s = SendEmailActionContent();
      expect(s.attachLogToEmail, isFalse);
    });

    test('subject setter works', () {
      final s = SendEmailActionContent();
      s.subject = 'Test Subject';
      expect(s.subject, equals('Test Subject'));
    });

    test('emailRecipient setter works', () {
      final s = SendEmailActionContent();
      s.emailRecipient = 'user@example.com';
      expect(s.emailRecipient, equals('user@example.com'));
    });

    test('emailBody setter works', () {
      final s = SendEmailActionContent();
      s.emailBody = 'Hello World';
      expect(s.emailBody, equals('Hello World'));
    });

    test('attachLogToEmail setter writes YES', () {
      final s = SendEmailActionContent();
      s.attachLogToEmail = true;
      expect(s.xmlElement.getAttribute('attachLogToEmail'), equals('YES'));
    });

    test(
      'from Complex.xcscheme TestAction post-action has correct email content',
      () async {
        final scheme = await XCScheme.open(
          'test/fixtures/scheme/Complex.xcscheme',
        );
        final testEl = scheme.testActionElement!;
        final execEl = testEl
            .findElements('PostActions')
            .first
            .findElements('ExecutionAction')
            .first;
        final ea = ExecutionAction(execEl);
        final content = ea.sendEmailActionContent!;
        expect(content.emailRecipient, equals('test@example.com'));
        expect(content.emailBody, equals('Tests done'));
      },
    );
  });

  // -------------------------------------------------------------------------
  // LocationScenarioReference
  // -------------------------------------------------------------------------

  group('LocationScenarioReference', () {
    test('defaults identifier to empty string', () {
      final r = LocationScenarioReference();
      expect(r.identifier, equals(''));
    });

    test('defaults referenceType to 0', () {
      final r = LocationScenarioReference();
      expect(r.referenceType, equals('0'));
    });

    test('identifier setter works', () {
      final r = LocationScenarioReference();
      r.identifier = 'com.apple.maps.sim.City';
      expect(r.identifier, equals('com.apple.maps.sim.City'));
    });

    test('referenceType setter works', () {
      final r = LocationScenarioReference();
      r.referenceType = '1';
      expect(r.referenceType, equals('1'));
    });
  });

  // -------------------------------------------------------------------------
  // MacroExpansion
  // -------------------------------------------------------------------------

  group('MacroExpansion', () {
    test('buildableReference getter returns BuildableReference', () {
      final me = MacroExpansion();
      // Create a BuildableReference child manually
      final br = BuildableReference();
      br.setReferenceTarget(
        'AABB',
        'App.app',
        'App',
        'container:App.xcodeproj',
      );
      me.setBuildableReference(br);
      final got = me.buildableReference;
      expect(got, isNotNull);
      expect(got!.blueprintName, equals('App'));
    });
  });

  // -------------------------------------------------------------------------
  // RemoteRunnable
  // -------------------------------------------------------------------------

  group('RemoteRunnable', () {
    test('bundleIdentifier setter works', () {
      final r = RemoteRunnable();
      r.bundleIdentifier = 'com.apple.Carousel';
      expect(r.bundleIdentifier, equals('com.apple.Carousel'));
    });

    test('remotePath setter works', () {
      final r = RemoteRunnable();
      r.remotePath = '/some/path';
      expect(r.remotePath, equals('/some/path'));
    });

    test('runnableDebuggingMode can be read and written', () {
      final r = RemoteRunnable();
      r.runnableDebuggingMode = '2';
      expect(r.runnableDebuggingMode, equals('2'));
    });
  });

  // -------------------------------------------------------------------------
  // BuildableProductRunnable
  // -------------------------------------------------------------------------

  group('BuildableProductRunnable', () {
    test('runnableDebuggingMode is null when not set', () {
      final r = BuildableProductRunnable();
      expect(r.runnableDebuggingMode, isNull);
    });

    test('runnableDebuggingMode setter works', () {
      final r = BuildableProductRunnable();
      r.runnableDebuggingMode = '0';
      expect(r.runnableDebuggingMode, equals('0'));
    });

    test('buildableReference returns null when no child', () {
      final r = BuildableProductRunnable();
      expect(r.buildableReference, isNull);
    });

    test('buildableReference setter sets child', () {
      final r = BuildableProductRunnable();
      final br = BuildableReference();
      r.buildableReference = br;
      expect(r.buildableReference, isNotNull);
    });
  });
}
