// Tests for the typed action getters/setters of XCScheme (issue #23).
//
// The expectations in test/fixtures/scheme/typed_actions come from Ruby's
// xcodeproj (see generate.rb there), never from Dart.

import 'dart:convert';
import 'dart:io';

import 'package:dart_xcodeproj/src/scheme/abstract_scheme_action.dart';
import 'package:dart_xcodeproj/src/scheme/analyze_action.dart';
import 'package:dart_xcodeproj/src/scheme/archive_action.dart';
import 'package:dart_xcodeproj/src/scheme/build_action.dart';
import 'package:dart_xcodeproj/src/scheme/execution_action.dart';
import 'package:dart_xcodeproj/src/scheme/launch_action.dart';
import 'package:dart_xcodeproj/src/scheme/profile_action.dart';
import 'package:dart_xcodeproj/src/scheme/test_action.dart';
import 'package:dart_xcodeproj/src/scheme/xc_scheme.dart';
import 'package:test/test.dart';

const _dir = 'test/fixtures/scheme/typed_actions';

/// The schemes of the Ruby expectations, by name, and where they live.
const _fixtures = {
  'ios_Runner': 'test/fixtures/scheme/flutter/ios_Runner.xcscheme',
  'macos_Runner': 'test/fixtures/scheme/flutter/macos_Runner.xcscheme',
  'missing_actions': '$_dir/missing_actions.xcscheme',
  'repeated_actions': '$_dir/repeated_actions.xcscheme',
  'pre_post_actions': '$_dir/pre_post_actions.xcscheme',
};

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('xc_scheme_typed_actions_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> saved(XCScheme scheme) async {
    final out = '${tmp.path}/out.xcscheme';
    await scheme.saveAs(out);
    return File(out).readAsString();
  }

  group('a scheme that lacks actions', () {
    test('reading the getters does not add elements, like Ruby', () async {
      final scheme = await XCScheme.open('$_dir/missing_actions.xcscheme');

      scheme.buildAction;
      scheme.testAction;
      scheme.launchAction;
      scheme.profileAction;
      scheme.analyzeAction;
      scheme.archiveAction;

      expect(scheme.testActionElement, isNull);
      expect(scheme.profileActionElement, isNull);
      expect(scheme.analyzeActionElement, isNull);
      expect(scheme.archiveActionElement, isNull);
      expect(
        await saved(scheme),
        equals(
          await File(
            '$_dir/missing_actions.read_only.ruby_saved.xcscheme',
          ).readAsString(),
        ),
      );
    });

    test('returns a default action, the same one on every call', () async {
      final scheme = await XCScheme.open('$_dir/missing_actions.xcscheme');

      expect(scheme.testAction.buildConfiguration, 'Debug');
      expect(scheme.profileAction.buildConfiguration, 'Release');
      expect(scheme.analyzeAction.buildConfiguration, 'Debug');
      expect(scheme.archiveAction.buildConfiguration, 'Release');

      scheme.archiveAction.buildConfiguration = 'Release-dev';

      expect(scheme.archiveAction.buildConfiguration, 'Release-dev');
      expect(identical(scheme.archiveAction, scheme.archiveAction), isTrue);
    });

    test('edits to the default action are not saved until assigned', () async {
      final scheme = await XCScheme.open('$_dir/missing_actions.xcscheme');
      scheme.archiveAction.buildConfiguration = 'Release-dev';
      expect(scheme.archiveActionElement, isNull);
      expect(await saved(scheme), isNot(contains('ArchiveAction')));

      scheme.archiveAction = scheme.archiveAction;

      expect(scheme.archiveActionElement, isNotNull);
      expect(
        scheme.archiveActionElement!.getAttribute('buildConfiguration'),
        'Release-dev',
      );
      expect(await saved(scheme), contains('ArchiveAction'));
    });
  });

  group('Ruby parity', () {
    late Map<String, dynamic> expected;

    setUpAll(() async {
      expected =
          jsonDecode(await File('$_dir/expected.json').readAsString())
              as Map<String, dynamic>;
    });

    Map<String, AbstractSchemeAction> actionsOf(XCScheme scheme) => {
      'build': scheme.buildAction,
      'test': scheme.testAction,
      'launch': scheme.launchAction,
      'profile': scheme.profileAction,
      'analyze': scheme.analyzeAction,
      'archive': scheme.archiveAction,
    };

    // Ruby's pre_actions/post_actions are nil when there is no container,
    // Dart's are empty lists.
    List<String?>? typesOf(List<ExecutionAction> actions) =>
        actions.isEmpty ? null : [for (final a in actions) a.actionType];

    for (final entry in _fixtures.entries) {
      test('${entry.key}: every action matches what Ruby returns', () async {
        final scheme = await XCScheme.open(entry.value);
        final ruby = expected[entry.key] as Map<String, dynamic>;
        final dart = actionsOf(scheme);

        for (final key in dart.keys) {
          final action = dart[key]!;
          final want = ruby[key] as Map<String, dynamic>;
          final reason = '${entry.key} $key';

          if (key != 'build') {
            expect(
              action.buildConfiguration,
              want['buildConfiguration'],
              reason: reason,
            );
          }
          expect(
            typesOf(action.preActions),
            (want['preActionTypes'] as List?)?.cast<String>(),
            reason: reason,
          );
          expect(
            typesOf(action.postActions),
            (want['postActionTypes'] as List?)?.cast<String>(),
            reason: reason,
          );

          // Ruby raises on a missing boolean attribute and Dart answers
          // false: only compare what Ruby could read.
          void expectFlag(String name, bool actual) {
            if (want[name] == 'raises') return;
            expect(actual, want[name], reason: '$reason $name');
          }

          switch (action) {
            case BuildAction():
              expectFlag('parallelizeBuildables', action.parallelizeBuildables);
              expectFlag(
                'buildImplicitDependencies',
                action.buildImplicitDependencies,
              );
              // Ruby's entries is nil without a BuildActionEntries container.
              expect(
                action.entries.isEmpty ? null : action.entries.length,
                want['entriesCount'],
                reason: reason,
              );
            case TestAction():
              expectFlag(
                'shouldUseLaunchSchemeArgsEnv',
                action.shouldUseLaunchSchemeArgsEnv,
              );
              expectFlag('codeCoverageEnabled', action.codeCoverageEnabled);
              expect(
                action.testables.length,
                want['testablesCount'] ?? 0,
                reason: reason,
              );
            case LaunchAction():
              expectFlag(
                'allowLocationSimulation',
                action.allowLocationSimulation,
              );
            case ProfileAction():
              expectFlag(
                'shouldUseLaunchSchemeArgsEnv',
                action.shouldUseLaunchSchemeArgsEnv,
              );
            case ArchiveAction():
              expectFlag(
                'revealArchiveInOrganizer',
                action.revealArchiveInOrganizer,
              );
              expect(
                action.customArchiveName,
                want['customArchiveName'],
                reason: reason,
              );
            default:
              break;
          }
        }
      });

      test(
        '${entry.key}: the actions are in the document like in Ruby',
        () async {
          final scheme = await XCScheme.open(entry.value);
          final ruby = expected[entry.key] as Map<String, dynamic>;
          final before = {
            'build': scheme.buildActionElement != null,
            'test': scheme.testActionElement != null,
            'launch': scheme.launchActionElement != null,
            'profile': scheme.profileActionElement != null,
            'analyze': scheme.analyzeActionElement != null,
            'archive': scheme.archiveActionElement != null,
          };

          actionsOf(scheme);

          final after = {
            'build': scheme.buildActionElement != null,
            'test': scheme.testActionElement != null,
            'launch': scheme.launchActionElement != null,
            'profile': scheme.profileActionElement != null,
            'analyze': scheme.analyzeActionElement != null,
            'archive': scheme.archiveActionElement != null,
          };
          for (final key in before.keys) {
            final want = ruby[key] as Map<String, dynamic>;
            expect(before[key], want['inDocumentBefore'], reason: key);
            expect(after[key], want['inDocumentAfter'], reason: key);
          }
        },
      );
    }
  });

  group('editing buildConfiguration', () {
    for (final entry in _fixtures.entries) {
      test('${entry.key}: launchAction matches what Ruby saves', () async {
        final scheme = await XCScheme.open(entry.value);

        scheme.launchAction.buildConfiguration = 'Debug-dev';

        expect(
          await saved(scheme),
          equals(
            await File(
              '$_dir/${entry.key}.build_configuration.ruby_saved.xcscheme',
            ).readAsString(),
          ),
        );
      });
    }

    final setters = <String, void Function(XCScheme, String)>{
      'TestAction': (s, v) => s.testAction.buildConfiguration = v,
      'LaunchAction': (s, v) => s.launchAction.buildConfiguration = v,
      'ProfileAction': (s, v) => s.profileAction.buildConfiguration = v,
      'AnalyzeAction': (s, v) => s.analyzeAction.buildConfiguration = v,
      'ArchiveAction': (s, v) => s.archiveAction.buildConfiguration = v,
    };

    /// [xml] with the `buildConfiguration` of its `<[tag]` set to [value] and
    /// nothing else changed.
    String withBuildConfiguration(String xml, String tag, String value) {
      final start = xml.indexOf('<$tag\n');
      final attribute = RegExp(
        r'buildConfiguration = "[^"]*"',
      ).firstMatch(xml.substring(start))!;
      return xml.replaceRange(
        start + attribute.start,
        start + attribute.end,
        'buildConfiguration = "$value"',
      );
    }

    for (final fixture in [
      'test/fixtures/scheme/flutter/ios_Runner.xcscheme',
      'test/fixtures/scheme/flutter/macos_Runner.xcscheme',
      '$_dir/pre_post_actions.xcscheme',
    ]) {
      for (final entry in setters.entries) {
        test('$fixture: ${entry.key} changes only its attribute', () async {
          final original = await File(fixture).readAsString();
          final scheme = await XCScheme.open(fixture);

          entry.value(scheme, 'Custom-dev');

          expect(
            await saved(scheme),
            equals(withBuildConfiguration(original, entry.key, 'Custom-dev')),
          );
        });
      }
    }

    test('removes the attribute when set to null', () async {
      final scheme = await XCScheme.open(_fixtures['ios_Runner']!);

      scheme.launchAction.buildConfiguration = null;

      expect(
        scheme.launchActionElement!.getAttribute('buildConfiguration'),
        isNull,
      );
      expect(scheme.testAction.buildConfiguration, 'Debug');
    });
  });

  group('assigning an action', () {
    for (final entry in _fixtures.entries) {
      test('${entry.key}: launchAction = matches what Ruby saves', () async {
        final scheme = await XCScheme.open(entry.value);
        final launch = LaunchAction()..buildConfiguration = 'Custom';

        scheme.launchAction = launch;

        expect(
          await saved(scheme),
          equals(
            await File(
              '$_dir/${entry.key}.replaced_launch.ruby_saved.xcscheme',
            ).readAsString(),
          ),
        );
        // The new element is the last child of <Scheme>. The getter finds the
        // first LaunchAction, which is the new one unless the scheme repeats
        // the element (Ruby's getter caches the assigned object instead).
        expect(
          scheme.document.rootElement.childElements.last.getAttribute(
            'buildConfiguration',
          ),
          'Custom',
        );
      });

      test('${entry.key}: analyzeAction = matches what Ruby saves', () async {
        final scheme = await XCScheme.open(entry.value);
        final analyze = AnalyzeAction()..buildConfiguration = 'Custom';

        scheme.analyzeAction = analyze;

        expect(
          await saved(scheme),
          equals(
            await File(
              '$_dir/${entry.key}.replaced_analyze.ruby_saved.xcscheme',
            ).readAsString(),
          ),
        );
      });
    }

    test('every action can be assigned', () async {
      final scheme = XCScheme.create();

      scheme.buildAction = BuildAction();
      scheme.testAction = TestAction()..buildConfiguration = 'T';
      scheme.launchAction = LaunchAction()..buildConfiguration = 'L';
      scheme.profileAction = ProfileAction()..buildConfiguration = 'P';
      scheme.analyzeAction = AnalyzeAction()..buildConfiguration = 'A';
      scheme.archiveAction = ArchiveAction()..buildConfiguration = 'R';

      expect(
        scheme.document.rootElement.childElements.map((e) => e.name.local),
        [
          'BuildAction',
          'TestAction',
          'LaunchAction',
          'ProfileAction',
          'AnalyzeAction',
          'ArchiveAction',
        ],
      );
      expect(scheme.testAction.buildConfiguration, 'T');
      expect(scheme.launchAction.buildConfiguration, 'L');
      expect(scheme.profileAction.buildConfiguration, 'P');
      expect(scheme.analyzeAction.buildConfiguration, 'A');
      expect(scheme.archiveAction.buildConfiguration, 'R');
    });

    test('an action of another scheme is copied, not moved', () async {
      final other = await XCScheme.open(_fixtures['pre_post_actions']!);
      final scheme = await XCScheme.open(_fixtures['missing_actions']!);

      scheme.profileAction = other.profileAction;

      expect(other.profileActionElement, isNotNull);
      expect(scheme.profileAction.buildConfiguration, 'Profile-dev');
      expect(scheme.profileAction.preActions, hasLength(1));
      expect(
        identical(scheme.profileActionElement, other.profileActionElement),
        isFalse,
      );
    });
  });
}
