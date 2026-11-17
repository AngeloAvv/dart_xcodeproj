// The build settings helpers of XCConfigurationList and AbstractTarget must
// write exactly what Ruby's xcodeproj writes.
//
// Each scenario below is the Dart twin of the one of the same name in
// test/fixtures/build_settings/generate.rb: it runs on a pristine `flutter
// create` project, then `predictabilizeUuids` (the new objects get random UUIDs
// otherwise) and `save`, and the result is compared with the file the Ruby
// script wrote. See test/fixtures/build_settings/README.md.

import 'dart:io';

import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/xc_build_configuration.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

const _annotations = 'test/fixtures/annotations';
const _expectedDir = 'test/fixtures/build_settings';

const _application = 'com.apple.product-type.application';
const _framework = 'com.apple.product-type.framework';

PBXNativeTarget _runner(XcodeProject project) => project.targets
    .whereType<PBXNativeTarget>()
    .firstWhere((t) => t.name == 'Runner');

/// Twin of `target_with` in generate.rb: a native target of [productType]
/// whose Debug, Release and Profile configurations start with a copy of
/// [settings].
PBXNativeTarget _targetWith(
  XcodeProject project,
  String name,
  String productType, [
  Map<String, dynamic> settings = const {},
]) {
  final target = project.newObject((g, u) => PBXNativeTarget(g, u));
  project.targets.add(target);
  target.name = name;
  target.productName = name;
  target.productType = productType;
  final list = project.newObject((g, u) => XCConfigurationList(g, u));
  target.buildConfigurationList = list;
  for (final configName in ['Debug', 'Release', 'Profile']) {
    final config = project.newObject((g, u) => XCBuildConfiguration(g, u));
    config.name = configName;
    config.buildSettings = Map<String, dynamic>.of(settings);
    list.buildConfigurations.add(config);
  }
  return target;
}

/// scenario name -> its steps, twin of `SCENARIOS` in generate.rb.
final Map<String, void Function(XcodeProject)> _scenarios = {
  'set_setting': (project) {
    final list = _runner(project).buildConfigurationList!;
    list.setSetting('PRODUCT_BUNDLE_IDENTIFIER', 'com.example.changed');
    list.setSetting('DEVELOPMENT_TEAM', 'ABCDE12345');
    list.setSetting('DEVELOPMENT_TEAM', 'ZZZZZZZZZZ');
    list.setSetting('OTHER_LDFLAGS', '-ObjC -lc++');
    list.setSetting('HEADER_SEARCH_PATHS', [
      r'$(inherited)',
      r'$(SRCROOT)/Pods/Headers',
    ]);
    list.setSetting('OTHER_CFLAGS', r'$(inherited) -DFOO');
    list.setSetting(
      'HEADER_SEARCH_PATHS[sdk=iphoneos*]',
      r'$(inherited) "$(SRCROOT)/Device"',
    );
    list.setSetting('LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]', ['a', 'b']);
    list.setSetting(
      'LD_RUNPATH_SEARCH_PATHS',
      r'$(inherited) @executable_path/Frameworks',
    );
    final projectList = project.buildConfigurationList;
    projectList.setSetting('SWIFT_VERSION', '5.0');
    projectList.setSetting(
      'FRAMEWORK_SEARCH_PATHS',
      r'$(inherited) $(PROJECT_DIR)/Flutter',
    );
    _targetWith(project, 'Bare', _application, {
      'SDKROOT': 'iphoneos',
    }).buildConfigurationList!.setSetting('ONLY_BARE', 'YES');
    final empty = _targetWith(project, 'Empty', _application);
    empty.buildConfigurationList!.buildConfigurations.clear();
    empty.buildConfigurationList!.setSetting('NOTHING', 'HAPPENS');
  },
  'build_settings': (project) {
    final target = _runner(project);
    target.buildSettings('Debug')!['FOO'] = 'debug-only';
    target.buildSettings('Release')!['OTHER_LDFLAGS'] = ['-a', '-b'];
    target.buildSettings('Profile')!['BAR'] = r'$(inherited) profile';
    target.buildSettings('Profile')!.remove('CODE_SIGN_STYLE');
    target.buildSettings('Debug')!['LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'] =
        r'$(inherited) lib';
    target.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    target.buildSettings('Debug-dev')!['GCC_PREPROCESSOR_DEFINITIONS'] = [
      r'$(inherited)',
      'DEV=1',
    ];
    if (target.buildSettings('Nope') != null) {
      throw StateError('unknown name must be null');
    }
  },
  'add_build_configuration': (project) {
    final target = _runner(project);
    target.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    target.addBuildConfiguration('Release-dev', BuildConfigType.release);
    target.addBuildConfiguration('Release', BuildConfigType.debug);
    target.addBuildConfiguration('Debug-dev', BuildConfigType.release);
    target.addBuildConfiguration('Profile-dev', BuildConfigType.release);

    for (final config in project.buildConfigurationList.buildConfigurations) {
      config.buildSettings.remove('SDKROOT');
    }
    final noPlatform = _targetWith(project, 'NoPlatform', _framework);
    noPlatform.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    noPlatform.addBuildConfiguration('Release-dev', BuildConfigType.release);

    final tv = _targetWith(project, 'Tv', _application, {
      'SDKROOT': 'appletvos',
      'TVOS_DEPLOYMENT_TARGET': '12.0',
    });
    tv.buildConfigurationList!.setSetting('SDKROOT', 'appletvos');
    project.buildConfigurationList.setSetting('SDKROOT', 'appletvos');
    tv.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    tv.addBuildConfiguration('Release-dev', BuildConfigType.release);

    final watch = _targetWith(
      project,
      'Watch',
      'com.apple.product-type.application.watchapp2',
      {'SDKROOT': 'watchos', 'WATCHOS_DEPLOYMENT_TARGET': '7.0'},
    );
    project.buildConfigurationList.setSetting('SDKROOT', 'watchos');
    watch.addBuildConfiguration('Release-dev', BuildConfigType.release);

    final vision = _targetWith(
      project,
      'Vision',
      'com.apple.product-type.bundle.unit-test',
      {'SDKROOT': 'xros', 'XROS_DEPLOYMENT_TARGET': '1.0'},
    );
    project.buildConfigurationList.setSetting('SDKROOT', 'xros');
    vision.addBuildConfiguration('Debug-dev', BuildConfigType.debug);

    final mac = _targetWith(
      project,
      'Mac',
      'com.apple.product-type.library.static',
      {'SDKROOT': 'macosx', 'MACOSX_DEPLOYMENT_TARGET': '10.6'},
    );
    project.buildConfigurationList.setSetting('SDKROOT', 'macosx');
    mac.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    mac.addBuildConfiguration('Release-dev', BuildConfigType.release);

    final macNew = _targetWith(
      project,
      'MacNew',
      'com.apple.product-type.framework',
      {'SDKROOT': 'macosx', 'MACOSX_DEPLOYMENT_TARGET': '14.0'},
    );
    macNew.addBuildConfiguration('Release-dev', BuildConfigType.release);

    final iosOld = _targetWith(
      project,
      'IosOld',
      'com.apple.product-type.app-extension',
      {'SDKROOT': 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET': '4.3'},
    );
    project.buildConfigurationList.setSetting('SDKROOT', 'iphoneos');
    iosOld.addBuildConfiguration('Debug-dev', BuildConfigType.debug);

    final unknown = _targetWith(
      project,
      'Unknown',
      'com.example.product-type.custom',
      {'SDKROOT': 'iphoneos'},
    );
    unknown.addBuildConfiguration('Debug-dev', BuildConfigType.debug);
    unknown.addBuildConfiguration('Release', BuildConfigType.release);
  },
  'project_add_build_configuration': (project) {
    project.addBuildConfiguration('Staging', BuildConfigType.release);
    project.addBuildConfiguration('Staging-debug', BuildConfigType.debug);
    project.addBuildConfiguration('Release', BuildConfigType.debug);
    project.addBuildConfiguration('Staging', BuildConfigType.debug);
  },
};

/// Opens the pristine project [name] from a `Runner.xcodeproj` bundle in a
/// temporary directory, as generate.rb does.
Future<XcodeProject> _open(String name) async {
  final tmp = Directory.systemTemp.createTempSync('build_settings_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final bundle = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
  File(
    '$_annotations/$name.xcodeproj/project.pbxproj',
  ).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(bundle.path);
}

void main() {
  for (final name in ['ios', 'macos']) {
    for (final entry in _scenarios.entries) {
      test(
        '${entry.key} on the $name project writes the same file as Ruby',
        () async {
          final project = await _open(name);

          entry.value(project);
          project.predictabilizeUuids();
          await project.save();

          expect(
            File('${project.path}/project.pbxproj').readAsStringSync(),
            equals(
              File(
                '$_expectedDir/$name.${entry.key}.pbxproj',
              ).readAsStringSync(),
            ),
          );
        },
      );
    }
  }
}
