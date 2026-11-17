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

      group('sdk, platformName and deploymentTarget', () {
        // Values read by Ruby's `sdk`, `platform_name` and `deployment_target`
        // on the Runner target (xcodeproj 1.28.1).
        const expected = {
          'ios': ('iphoneos', 'ios', '13.0'),
          'macos': ('macosx', 'osx', '10.15'),
        };

        test('are read from the resolved settings of the target', () {
          expect(runner.sdk, equals(expected[name]!.$1));
          expect(runner.platformName, equals(expected[name]!.$2));
          expect(runner.deploymentTarget, equals(expected[name]!.$3));
        });

        test('are null for a target and a project without SDKROOT', () {
          for (final config in project.buildConfigurations) {
            config.buildSettings.remove('SDKROOT');
          }
          final bare = project.newObject((g, u) => PBXNativeTarget(g, u))
            ..buildConfigurationList = project.newObject(
              (g, u) => XCConfigurationList(g, u),
            );

          expect(bare.sdk, isNull);
          expect(bare.platformName, isNull);
          expect(bare.deploymentTarget, isNull);
        });

        test('recognise every platform by its SDK', () {
          const platforms = {
            'iphoneos17.0': 'ios',
            'macosx14.0': 'osx',
            'appletvos': 'tvos',
            'xros': 'visionos',
            'watchos': 'watchos',
            // Like Ruby, which looks for `iphoneos`, not `iphonesimulator`.
            'iphonesimulator': null,
            'driverkit': null,
          };
          for (final entry in platforms.entries) {
            runner.buildConfigurationList!.setSetting('SDKROOT', entry.key);

            expect(runner.platformName, equals(entry.value), reason: entry.key);
          }
        });

        test('deploymentTarget follows the platform of the SDK', () {
          runner.buildConfigurationList!
            ..setSetting('SDKROOT', 'watchos')
            ..setSetting('WATCHOS_DEPLOYMENT_TARGET', '9.0');

          expect(runner.deploymentTarget, equals('9.0'));
        });

        test('count a configuration only the project has, like Ruby', () {
          // Ruby merges the project settings into the target ones, so the
          // `Profile` of the project (SDKROOT iphoneos) is part of the result
          // for a target that has only Debug and Release.
          final tv = project.newObject((g, u) => PBXNativeTarget(g, u))
            ..buildConfigurationList = project.newObject(
              (g, u) => XCConfigurationList(g, u),
            );
          for (final configName in ['Debug', 'Release']) {
            tv.buildConfigurationList!.buildConfigurations.add(
              project.newObject((g, u) => XCBuildConfiguration(g, u))
                ..name = configName
                ..buildSettings = {'SDKROOT': 'appletvos'},
            );
          }

          expect(
            tv.resolvedBuildSetting('SDKROOT'),
            equals({
              'Debug': 'appletvos',
              'Release': 'appletvos',
              'Profile': name == 'ios' ? 'iphoneos' : 'macosx',
            }),
          );
          expect(() => tv.sdk, throwsStateError);
        });

        test('throw a StateError when the configurations disagree', () {
          runner.buildConfigurationList!['Debug']!.buildSettings['SDKROOT'] =
              'watchos';

          expect(() => runner.sdk, throwsStateError);
        });
      });

      group('addBuildConfiguration', () {
        // Settings of `add_build_configuration` on the Runner target
        // (xcodeproj 1.28.1). `CLANG_ENABLE_OBJC_WEAK` is `NO` because Ruby
        // compares the deployment target as a string: '13.0' < '5'.
        const debugSettings = {
          'ios': {
            'SDKROOT': 'iphoneos',
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
            'LD_RUNPATH_SEARCH_PATHS':
                r'$(inherited) @executable_path/Frameworks',
            'TARGETED_DEVICE_FAMILY': '1,2',
            'IPHONEOS_DEPLOYMENT_TARGET': '13.0',
            'CLANG_ENABLE_OBJC_WEAK': 'NO',
          },
          'macos': {
            'SDKROOT': 'macosx',
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME': 'AccentColor',
            'COMBINE_HIDPI_IMAGES': 'YES',
            'LD_RUNPATH_SEARCH_PATHS':
                r'$(inherited) @executable_path/../Frameworks',
            'MACOSX_DEPLOYMENT_TARGET': '10.15',
            'CLANG_ENABLE_OBJC_WEAK': 'NO',
          },
        };

        test('creates a debug configuration with the defaults of Ruby', () {
          final config = runner.addBuildConfiguration(
            'Debug-dev',
            BuildConfigType.debug,
          );

          expect(config.name, equals('Debug-dev'));
          expect(config.buildSettings, equals(debugSettings[name]));
        });

        test(
          'creates a release configuration with VALIDATE_PRODUCT on iOS',
          () {
            final config = runner.addBuildConfiguration(
              'Release-dev',
              BuildConfigType.release,
            );

            expect(
              config.buildSettings,
              equals({
                ...debugSettings[name]!,
                if (name == 'ios') 'VALIDATE_PRODUCT': 'YES',
              }),
            );
          },
        );

        test('appends the configuration to the list of the target', () {
          final names = [for (final c in runner.buildConfigurations) c.name];

          final config = runner.addBuildConfiguration(
            'Debug-dev',
            BuildConfigType.debug,
          );

          expect(runner.buildConfigurations.last, same(config));
          expect([
            for (final c in runner.buildConfigurations) c.name,
          ], equals([...names, 'Debug-dev']));
          expect(project.objectsByUuid[config.uuid], same(config));
          expect(runner.buildConfigurationList!['Debug-dev'], same(config));
        });

        test('does not touch the configurations of the project', () {
          final names = [for (final c in project.buildConfigurations) c.name];

          runner.addBuildConfiguration('Debug-dev', BuildConfigType.debug);

          expect([
            for (final c in project.buildConfigurations) c.name,
          ], equals(names));
        });

        test('is idempotent: an existing name returns that configuration', () {
          final existing = runner.buildConfigurationList!['Release']!;
          final settings = Map<String, dynamic>.of(existing.buildSettings);
          final count = runner.buildConfigurations.length;

          final config = runner.addBuildConfiguration(
            'Release',
            BuildConfigType.debug,
          );

          expect(config, same(existing));
          expect(config.buildSettings, equals(settings));
          expect(runner.buildConfigurations.length, equals(count));
        });

        test('adding the same new name twice adds one configuration', () {
          final first = runner.addBuildConfiguration(
            'Debug-dev',
            BuildConfigType.debug,
          );
          final count = runner.buildConfigurations.length;

          final second = runner.addBuildConfiguration(
            'Debug-dev',
            BuildConfigType.release,
          );

          expect(second, same(first));
          expect(runner.buildConfigurations.length, equals(count));
        });

        test('the settings are not shared between configurations', () {
          final a = runner.addBuildConfiguration('A', BuildConfigType.debug);
          final b = runner.addBuildConfiguration('B', BuildConfigType.debug);

          a.buildSettings['SDKROOT'] = 'changed';

          expect(b.buildSettings['SDKROOT'], isNot('changed'));
        });

        test('throws a StateError without a configuration list', () {
          final bare = project.newObject((g, u) => PBXNativeTarget(g, u));

          expect(
            () => bare.addBuildConfiguration('X', BuildConfigType.debug),
            throwsStateError,
          );
        });
      });

      group('buildSettings(name)', () {
        test(
          'the list returns the live settings of the named configuration',
          () {
            final list = runner.buildConfigurationList!;

            final settings = list.buildSettings('Debug');

            expect(settings, same(list['Debug']!.buildSettings));
            settings!['FOO'] = 'bar';
            expect(list['Debug']!.buildSettings['FOO'], equals('bar'));
            expect(list['Release']!.buildSettings.containsKey('FOO'), isFalse);
          },
        );

        test('the list returns null for an unknown name', () {
          expect(runner.buildConfigurationList!.buildSettings('Nope'), isNull);
        });

        test('the target returns the settings of the named configuration', () {
          for (final configName in ['Debug', 'Release', 'Profile']) {
            expect(
              runner.buildSettings(configName),
              same(runner.buildConfigurationList![configName]?.buildSettings),
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
