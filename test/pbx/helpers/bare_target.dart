import 'package:dart_xcodeproj/src/pbx/pbx_native_target.dart';
import 'package:dart_xcodeproj/src/pbx/xc_configuration_list.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';

/// Adds a native target without any build phase to [project], so that every
/// helper that creates a phase on demand has to. Mirrors `bare_target` in
/// test/fixtures/build_phases/generate.rb.
PBXNativeTarget bareTarget(XcodeProject project) {
  final target = project.newObject((g, u) => PBXNativeTarget(g, u));
  project.targets.add(target);
  target.name = 'Bare';
  target.productName = 'Bare';
  target.productType = 'com.apple.product-type.library.static';
  target.buildConfigurationList = project.newObject(
    (g, u) => XCConfigurationList(g, u),
  );
  return target;
}
