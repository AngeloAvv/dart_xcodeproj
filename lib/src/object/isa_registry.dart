// Dart has no Class.forName / Object.const_get equivalent. This map is the
// substitute. adds leaf types; adds composite types. Never
// auto-register via static initialisers — keep entries explicit.

import 'dart:developer' as developer;

import 'abstract_object.dart';
import 'object_graph.dart';
import '../pbx/pbx_build_file.dart';
import '../pbx/pbx_build_phase.dart';
import '../pbx/pbx_build_rule.dart';
import '../pbx/pbx_file_reference.dart';
import '../pbx/xc_build_configuration.dart';
import '../pbx/xc_configuration_list.dart';
import '../pbx/group.dart';
import '../pbx/pbx_container_item_proxy.dart';
import '../pbx/pbx_target_dependency.dart';
import '../pbx/pbx_reference_proxy.dart';
import '../pbx/pbx_native_target.dart';
import '../pbx/swift_package_references.dart';
import '../pbx/xc_swift_package_product_dependency.dart';
import '../pbx/pbx_file_system_synchronized_root_group.dart';
import '../pbx/pbx_file_system_synchronized_exception_set.dart';
import '../pbx/pbx_project.dart';

/// Factory signature for creating an [AbstractObject] from a plist entry.
typedef ObjectFactory = AbstractObject Function(ObjectGraph graph, String uuid);

/// Central ISA-to-factory registry.
/// Mutable so /4 can register concrete types at startup.
/// ships this empty.
final Map<String, ObjectFactory> isaRegistry = <String, ObjectFactory>{};

/// Create-and-configure an object from its plist representation, dispatching
/// via [isaRegistry].
/// Implements the register-then-configure pattern:
/// 1. Resolve the factory by ISA string.
/// 2. Create the object via the factory.
/// 3. Register in `graph.objectsByUuid[uuid]` BEFORE calling configureWithPlist.
/// 4. Call configureWithPlist on the object.
/// Returns null and emits a warning (never throws) if:
/// - the plist entry for [uuid] is missing or malformed
/// - the entry has no 'isa' key
/// - the ISA string is not in [isaRegistry]
/// Port of (warning behaviour).
AbstractObject? objectFromPlist(
  String uuid,
  Map<String, dynamic> objectsByUuidPlist,
  ObjectGraph graph,
) {
  final raw = objectsByUuidPlist[uuid];
  if (raw is! Map) {
    developer.log(
      "[dart_xcodeproj] No plist entry for UUID $uuid — skipping.",
      name: 'dart_xcodeproj',
    );
    return null;
  }

  final isa = raw['isa'];
  if (isa is! String) {
    developer.log(
      "[dart_xcodeproj] UUID $uuid has no 'isa' key — skipping.",
      name: 'dart_xcodeproj',
    );
    return null;
  }

  final factory = isaRegistry[isa];
  if (factory == null) {
    developer.log(
      "[dart_xcodeproj] Unknown ISA '$isa' for UUID $uuid — skipping.",
      name: 'dart_xcodeproj',
    );
    return null;
  }

  // register BEFORE configuring so cyclic refs terminate.
  final obj = factory(graph, uuid);
  graph.objectsByUuid[uuid] = obj;
  obj.configureWithPlist(objectsByUuidPlist);
  return obj;
}

/// Register all concrete ISA types into [isaRegistry].
/// Call this once at startup (before loading any project) or in test setUp.
/// will call [registerPhase4Types] similarly.
/// [AbstractBuildPhase] is NOT registered — it is abstract.
void registerPhase3Types() {
  isaRegistry['PBXFileReference'] = (g, u) => PBXFileReference(g, u);
  isaRegistry['PBXBuildFile'] = (g, u) => PBXBuildFile(g, u);
  isaRegistry['PBXBuildRule'] = (g, u) => PBXBuildRule(g, u);
  isaRegistry['PBXHeadersBuildPhase'] = (g, u) => PBXHeadersBuildPhase(g, u);
  isaRegistry['PBXSourcesBuildPhase'] = (g, u) => PBXSourcesBuildPhase(g, u);
  isaRegistry['PBXFrameworksBuildPhase'] = (g, u) =>
      PBXFrameworksBuildPhase(g, u);
  isaRegistry['PBXResourcesBuildPhase'] = (g, u) =>
      PBXResourcesBuildPhase(g, u);
  isaRegistry['PBXCopyFilesBuildPhase'] = (g, u) =>
      PBXCopyFilesBuildPhase(g, u);
  isaRegistry['PBXShellScriptBuildPhase'] = (g, u) =>
      PBXShellScriptBuildPhase(g, u);
  isaRegistry['PBXRezBuildPhase'] = (g, u) => PBXRezBuildPhase(g, u);
  isaRegistry['XCBuildConfiguration'] = (g, u) => XCBuildConfiguration(g, u);
  isaRegistry['XCConfigurationList'] = (g, u) => XCConfigurationList(g, u);
}

/// Register all composite PBX ISA types in the global [isaRegistry].
/// Must be called once at startup (typically alongside [registerPhase3Types]).
/// Registers exactly 16 concrete ISA types — AbstractTarget is abstract and
/// not registered.
void registerPhase4Types() {
  // Groups (3)
  isaRegistry['PBXGroup'] = (g, u) => PBXGroup(g, u);
  isaRegistry['PBXVariantGroup'] = (g, u) => PBXVariantGroup(g, u);
  isaRegistry['XCVersionGroup'] = (g, u) => XCVersionGroup(g, u);

  // Proxy/dependency infrastructure (3)
  isaRegistry['PBXContainerItemProxy'] = (g, u) => PBXContainerItemProxy(g, u);
  isaRegistry['PBXTargetDependency'] = (g, u) => PBXTargetDependency(g, u);
  isaRegistry['PBXReferenceProxy'] = (g, u) => PBXReferenceProxy(g, u);

  // Concrete targets (3)
  isaRegistry['PBXAggregateTarget'] = (g, u) => PBXAggregateTarget(g, u);
  isaRegistry['PBXNativeTarget'] = (g, u) => PBXNativeTarget(g, u);
  isaRegistry['PBXLegacyTarget'] = (g, u) => PBXLegacyTarget(g, u);

  // Swift packages (3)
  isaRegistry['XCRemoteSwiftPackageReference'] = (g, u) =>
      XCRemoteSwiftPackageReference(g, u);
  isaRegistry['XCLocalSwiftPackageReference'] = (g, u) =>
      XCLocalSwiftPackageReference(g, u);
  isaRegistry['XCSwiftPackageProductDependency'] = (g, u) =>
      XCSwiftPackageProductDependency(g, u);

  // FileSystem-sync types — Xcode 15+ (3)
  isaRegistry['PBXFileSystemSynchronizedRootGroup'] = (g, u) =>
      PBXFileSystemSynchronizedRootGroup(g, u);
  isaRegistry['PBXFileSystemSynchronizedBuildFileExceptionSet'] = (g, u) =>
      PBXFileSystemSynchronizedBuildFileExceptionSet(g, u);
  isaRegistry['PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet'] =
      (g, u) =>
          PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(g, u);

  // Root object (1)
  isaRegistry['PBXProject'] = (g, u) => PBXProject(g, u);
}
