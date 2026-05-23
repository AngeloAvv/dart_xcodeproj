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
export 'src/scheme/abstract_scheme_action.dart';
export 'src/scheme/analyze_action.dart';
export 'src/scheme/archive_action.dart';
export 'src/scheme/build_action.dart';
export 'src/scheme/buildable_product_runnable.dart';
export 'src/scheme/buildable_reference.dart';
export 'src/scheme/command_line_arguments.dart';
export 'src/scheme/environment_variables.dart';
export 'src/scheme/execution_action.dart';
export 'src/scheme/launch_action.dart';
export 'src/scheme/location_scenario_reference.dart';
export 'src/scheme/macro_expansion.dart';
export 'src/scheme/profile_action.dart';
export 'src/scheme/remote_runnable.dart';
export 'src/scheme/send_email_action_content.dart';
export 'src/scheme/shell_script_action_content.dart';
export 'src/scheme/test_action.dart';
export 'src/config/xc_config.dart';
export 'src/config/other_linker_flags_parser.dart';

// ---- Differ ----
export 'src/differ/differ.dart';
