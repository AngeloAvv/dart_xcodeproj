// Regression test for XCConfigurationList.getSetting on array-valued build
// settings, using the real Flutter Runner fixture (test/fixtures/runner.pbxproj).

import 'dart:io';

import 'package:dart_xcodeproj/src/object/isa_registry.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

void main() {
  group('XCConfigurationList.getSetting on the Flutter Runner fixture', () {
    late Directory tmp;
    late PBXNativeTarget runner;

    setUp(() async {
      registerPhase3Types();
      registerPhase4Types();

      tmp = Directory.systemTemp.createTempSync('xcodeproj_get_setting_');
      final xcodeproj = Directory('${tmp.path}/Runner.xcodeproj')..createSync();
      File(
        'test/fixtures/runner.pbxproj',
      ).copySync('${xcodeproj.path}/project.pbxproj');

      final project = await XcodeProject.open(xcodeproj.path);
      runner = project.targets.whereType<PBXNativeTarget>().firstWhere(
        (t) => t.name == 'Runner',
      );
    });

    tearDown(() {
      isaRegistry.clear();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('returns LD_RUNPATH_SEARCH_PATHS arrays unchanged', () {
      final result = runner.buildConfigurationList!.getSetting(
        'LD_RUNPATH_SEARCH_PATHS',
        false,
      );

      expect(result.keys, containsAll(['Debug', 'Release', 'Profile']));
      for (final value in result.values) {
        expect(value, isA<List<dynamic>>());
        expect(value, equals([r'$(inherited)', '@executable_path/Frameworks']));
      }
    });

    test('returns scalar settings as strings', () {
      final result = runner.buildConfigurationList!.getSetting(
        'PRODUCT_BUNDLE_IDENTIFIER',
        false,
      );

      expect(result['Debug'], isA<String>());
    });

    test('resolvedBuildSetting does not throw on array settings', () {
      final result = runner.resolvedBuildSetting('LD_RUNPATH_SEARCH_PATHS');

      expect(result['Debug'], isA<List<dynamic>>());
    });
  });
}
