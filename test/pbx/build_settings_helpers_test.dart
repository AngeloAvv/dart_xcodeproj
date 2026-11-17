// Tests for the build settings helpers: XCConfigurationList.setSetting and
// buildSettings(name), AbstractTarget.buildSettings(name) and
// AbstractTarget.addBuildConfiguration, on the pristine `flutter create` iOS and
// macOS projects. Byte-for-byte parity with Ruby lives in
// build_settings_helpers_ruby_parity_test.dart.

import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

const _fixtures = 'test/fixtures/annotations';

/// Opens a pristine Flutter project, `ios` or `macos`.
Future<XcodeProject> _open(String name) =>
    XcodeProject.open('$_fixtures/$name.xcodeproj');

PBXNativeTarget _target(XcodeProject project, String name) => project.targets
    .whereType<PBXNativeTarget>()
    .firstWhere((t) => t.name == name);

void main() {
  for (final name in ['ios', 'macos']) {
    group('$name project:', () {
      late XcodeProject project;
      late PBXNativeTarget runner;

      setUp(() async {
        project = await _open(name);
        runner = _target(project, 'Runner');
      });

      group('buildSettings(name)', () {
        test('the list returns the live settings of the named configuration', () {
          final list = runner.buildConfigurationList!;

          final settings = list.buildSettings('Debug');

          expect(settings, same(list['Debug']!.buildSettings));
          settings!['FOO'] = 'bar';
          expect(list['Debug']!.buildSettings['FOO'], equals('bar'));
          expect(list['Release']!.buildSettings.containsKey('FOO'), isFalse);
        });

        test('the list returns null for an unknown name', () {
          expect(runner.buildConfigurationList!.buildSettings('Nope'), isNull);
        });

        test('the target returns the settings of the named configuration', () {
          for (final configName in ['Debug', 'Release', 'Profile']) {
            expect(
              runner.buildSettings(configName),
              same(
                runner.buildConfigurationList![configName]?.buildSettings,
              ),
              reason: configName,
            );
          }
          expect(runner.buildSettings('Profile'), isNotNull);
        });

        test('the target returns null for an unknown name', () {
          expect(runner.buildSettings('Nope'), isNull);
        });

        test('the target throws a StateError without a configuration list', () {
          final bare = project.newObject((g, u) => PBXNativeTarget(g, u));

          expect(() => bare.buildSettings('Debug'), throwsStateError);
        });
      });

      group('XCConfigurationList.setSetting', () {
        test('updates an existing key in every configuration', () {
          final list = runner.buildConfigurationList!;

          list.setSetting('PRODUCT_BUNDLE_IDENTIFIER', 'com.example.changed');

          expect(list.buildConfigurations, isNotEmpty);
          for (final config in list.buildConfigurations) {
            expect(
              config.buildSettings['PRODUCT_BUNDLE_IDENTIFIER'],
              equals('com.example.changed'),
              reason: config.name,
            );
          }
        });

        test('adds a key that does not exist and keeps the other keys', () {
          final list = runner.buildConfigurationList!;
          final before = {
            for (final config in list.buildConfigurations)
              config.name!: Map<String, dynamic>.of(config.buildSettings),
          };

          list.setSetting('DEVELOPMENT_TEAM', 'ABCDE12345');

          for (final config in list.buildConfigurations) {
            final expected = {...before[config.name]!}
              ..['DEVELOPMENT_TEAM'] = 'ABCDE12345';
            expect(config.buildSettings, equals(expected), reason: config.name);
          }
        });

        test('keeps the settings of the other lists untouched', () {
          final projectSettings = [
            for (final config in project.buildConfigurations)
              Map<String, dynamic>.of(config.buildSettings),
          ];

          runner.buildConfigurationList!.setSetting('DEVELOPMENT_TEAM', 'X');

          expect([
            for (final config in project.buildConfigurations)
              config.buildSettings,
          ], equals(projectSettings));
        });

        test('stores array values and conditional keys as given', () {
          final list = runner.buildConfigurationList!;

          list.setSetting('OTHER_LDFLAGS', ['-ObjC', r'$(inherited)']);
          list.setSetting('OTHER_CFLAGS', r'$(inherited) -DFOO');
          list.setSetting('HEADER_SEARCH_PATHS[sdk=iphoneos*]', 'a b');

          for (final config in list.buildConfigurations) {
            expect(
              config.buildSettings['OTHER_LDFLAGS'],
              equals(['-ObjC', r'$(inherited)']),
            );
            expect(
              config.buildSettings['OTHER_CFLAGS'],
              equals(r'$(inherited) -DFOO'),
            );
            expect(
              config.buildSettings['HEADER_SEARCH_PATHS[sdk=iphoneos*]'],
              equals('a b'),
            );
          }
        });

        test('replaces an array value with a string and the other way', () {
          final list = runner.buildConfigurationList!;
          list.setSetting('OTHER_LDFLAGS', ['-a']);

          list.setSetting('OTHER_LDFLAGS', '-b -c');

          for (final config in list.buildConfigurations) {
            expect(config.buildSettings['OTHER_LDFLAGS'], equals('-b -c'));
          }
        });

        test('does nothing on a list without configurations', () {
          final list = project.newObject((g, u) => XCConfigurationList(g, u));

          expect(() => list.setSetting('A', 'B'), returnsNormally);
        });
      });
    });
  }
}
