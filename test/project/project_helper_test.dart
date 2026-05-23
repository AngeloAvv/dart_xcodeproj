// Tests for ProjectHelper — (TDD RED)
// Covers: newTarget, newAggregateTarget, newResourcesBundle, newLegacyTarget,
// configurationList, commonBuildSettings.

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/project/project_helper.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  late XcodeProject project;

  setUp(() async {
    registerPhase3Types();
    registerPhase4Types();
    project = await XcodeProject.create('/tmp/TestProject.xcodeproj');
  });

  tearDown(() {
    isaRegistry.clear();
  });

  group('ProjectHelper', () {
    group('newTarget', () {
      test('adds a PBXNativeTarget to project.rootObject.targets', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(project.rootObject.targets.contains(target), isTrue);
      });

      test('target has correct name and productName', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(target.name, equals('MyApp'));
        expect(target.productName, equals('MyApp'));
      });

      test('target has correct productType for application', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(
          target.productType,
          equals('com.apple.product-type.application'),
        );
      });

      test('target has a non-null buildConfigurationList', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(target.buildConfigurationList, isNotNull);
      });

      test('target buildConfigurationList has Debug and Release configs', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        final cl = target.buildConfigurationList!;
        final names = cl.buildConfigurations.map((c) => c.name).toList();
        expect(names, containsAll(['Release', 'Debug']));
      });

      test('target has at least 2 build phases for application type', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(target.buildPhases.length, greaterThanOrEqualTo(2));
      });

      test('target is a PBXNativeTarget', () {
        final target = ProjectHelper.newTarget(
          project,
          'application',
          'MyApp',
          'ios',
          null,
          project.productsGroup,
          null,
          'MyApp',
        );
        expect(target, isA<PBXNativeTarget>());
      });
    });

    group('newAggregateTarget', () {
      test('adds a PBXAggregateTarget to project.rootObject.targets', () {
        final target = ProjectHelper.newAggregateTarget(
          project,
          'MyAggregateTarget',
          'ios',
          null,
        );
        expect(project.rootObject.targets.contains(target), isTrue);
        expect(target, isA<PBXAggregateTarget>());
      });

      test('aggregate target has correct name', () {
        final target = ProjectHelper.newAggregateTarget(
          project,
          'MyAggregateTarget',
          'ios',
          null,
        );
        expect(target.name, equals('MyAggregateTarget'));
      });
    });

    group('newResourcesBundle', () {
      test('returns PBXNativeTarget with bundle productType', () {
        final target = ProjectHelper.newResourcesBundle(
          project,
          'MyBundle',
          'ios',
          null,
          project.productsGroup,
        );
        expect(target, isA<PBXNativeTarget>());
        expect(target.productType, equals('com.apple.product-type.bundle'));
      });
    });

    group('commonBuildSettings', () {
      test('returns a non-empty Map for debug,ios,application', () {
        final settings = ProjectHelper.commonBuildSettings(
          'debug',
          'ios',
          'application',
          null,
        );
        expect(settings, isNotEmpty);
      });

      test('contains SDKROOT=iphoneos for ios platform', () {
        final settings = ProjectHelper.commonBuildSettings(
          'debug',
          'ios',
          'application',
          null,
        );
        expect(settings['SDKROOT'], equals('iphoneos'));
      });

      test('returns non-empty Map for release,ios,application', () {
        final settings = ProjectHelper.commonBuildSettings(
          'release',
          'ios',
          'application',
          null,
        );
        expect(settings, isNotEmpty);
      });
    });

    group('configurationList', () {
      test(
        'creates an XCConfigurationList and returns it as XCConfigurationList',
        () {
          // configurationList() registers via buildConfigurations.add() ref-counting
          // when wired to a target; calling standalone returns a valid XCConfigurationList
          final target = ProjectHelper.newTarget(
            project,
            'application',
            'MyApp',
            'ios',
            null,
            project.productsGroup,
            null,
            'MyApp',
          );
          final cl = target.buildConfigurationList!;
          expect(cl, isA<XCConfigurationList>());
          expect(project.objectsByUuid.containsValue(cl), isTrue);
        },
      );

      test(
        'has defaultConfigurationName = Release and defaultConfigurationIsVisible = 0',
        () {
          final cl = ProjectHelper.configurationList(
            project,
            'ios',
            null,
            'application',
            null,
          );
          expect(cl.defaultConfigurationName, equals('Release'));
          expect(cl.defaultConfigurationIsVisible, equals('0'));
        },
      );

      test('buildConfigurations contains at least Debug and Release', () {
        final cl = ProjectHelper.configurationList(
          project,
          'ios',
          null,
          'application',
          null,
        );
        final names = cl.buildConfigurations.map((c) => c.name).toList();
        expect(names, containsAll(['Release', 'Debug']));
      });
    });
  });
}
