/// dart_xcodeproj — 1:1 Dart port of the Ruby xcodeproj gem.
/// Public API for manipulating .xcodeproj, .xcworkspace, .xcscheme, and
/// .xcconfig files. See README.md for quick-start.
library;

// ---- Foundational utilities ----
export 'src/project/uuid_generator.dart';
export 'src/project/case_converter.dart';
export 'src/constants/build_settings.dart';
export 'src/constants/file_types.dart';
export 'src/constants/misc.dart';
export 'src/constants/object_versions.dart';
export 'src/constants/product_types.dart';
export 'src/constants/sdk_versions.dart';

// ---- Abstract base classes ----
export 'src/object/abstract_object.dart';

// ---- Concrete PBX leaf types ----
export 'src/pbx/pbx_file_reference.dart';
export 'src/pbx/pbx_build_file.dart';
export 'src/pbx/pbx_build_rule.dart';
export 'src/pbx/pbx_build_phase.dart';
export 'src/pbx/xc_build_configuration.dart';
export 'src/pbx/xc_configuration_list.dart';

// ---- Concrete PBX composite types ----
export 'src/pbx/group.dart';
export 'src/pbx/groupable_helper.dart';
export 'src/pbx/pbx_container_item_proxy.dart';
export 'src/pbx/pbx_target_dependency.dart';
export 'src/pbx/pbx_reference_proxy.dart';
export 'src/pbx/pbx_native_target.dart';
export 'src/pbx/swift_package_references.dart';
export 'src/pbx/xc_swift_package_product_dependency.dart';
export 'src/pbx/pbx_file_system_synchronized_root_group.dart';
export 'src/pbx/pbx_file_system_synchronized_exception_set.dart';
export 'src/pbx/pbx_project.dart';

// ---- Top-level containers ----
export 'src/project/xcode_project.dart';
export 'src/project/groups_position.dart';
export 'src/project/project_helper.dart';

// ---- Adjacent file formats ----
export 'src/workspace/xc_workspace.dart';
export 'src/workspace/file_reference.dart';
export 'src/workspace/group_reference.dart';
export 'src/workspace/workspace_reference.dart';
export 'src/scheme/xc_scheme.dart';
export 'src/config/xc_config.dart';
export 'src/config/other_linker_flags_parser.dart';

// ---- Differ ----
export 'src/differ/differ.dart';
