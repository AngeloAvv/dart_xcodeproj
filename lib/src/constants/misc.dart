// Port of Xcodeproj::Constants miscellaneous constants
// static const Map/List, not enums
// Ruby uses Symbol keys; Dart uses String keys
class MiscConstants {
  MiscConstants._();

  /// The known ISAs grouped by superclass.
  /// Ruby: KNOWN_ISAS
  static const Map<String, List<String>> knownIsas = {
    'AbstractObject': [
      'PBXBuildFile',
      'AbstractBuildPhase',
      'PBXBuildRule',
      'XCBuildConfiguration',
      'XCConfigurationList',
      'PBXContainerItemProxy',
      'PBXFileReference',
      'PBXGroup',
      'PBXProject',
      'PBXTargetDependency',
      'PBXReferenceProxy',
      'AbstractTarget',
    ],
    'AbstractBuildPhase': [
      'PBXCopyFilesBuildPhase',
      'PBXResourcesBuildPhase',
      'PBXSourcesBuildPhase',
      'PBXFrameworksBuildPhase',
      'PBXHeadersBuildPhase',
      'PBXShellScriptBuildPhase',
    ],
    'AbstractTarget': [
      'PBXNativeTarget',
      'PBXAggregateTarget',
      'PBXLegacyTarget',
    ],
    'PBXGroup': ['XCVersionGroup', 'PBXVariantGroup'],
  };

  /// The corresponding numeric value of each copy build phase destination.
  /// Ruby: COPY_FILES_BUILD_PHASE_DESTINATIONS
  /// Ruby Symbol keys → Dart String keys
  static const Map<String, String> copyFilesBuildPhaseDestinations = {
    'absolute_path': '0',
    'products_directory': '16',
    'wrapper': '1',
    'resources': '7', // default
    'executables': '6',
    'java_resources': '15',
    'frameworks': '10',
    'shared_frameworks': '11',
    'shared_support': '12',
    'plug_ins': '13',
  };

  /// The corresponding numeric value of each proxy type for PBXContainerItemProxy.
  /// Ruby: PROXY_TYPES
  /// Ruby Symbol keys → Dart String keys
  static const Map<String, String> proxyTypes = {
    'native_target': '1',
    'reference': '2',
  };

  /// The extensions which are associated with header files.
  /// Ruby: HEADER_FILES_EXTENSIONS
  static const List<String> headerFilesExtensions = [
    '.h',
    '.hh',
    '.hpp',
    '.ipp',
    '.tpp',
    '.hxx',
    '.def',
    '.inl',
    '.inc',
  ];

  /// The keywords Xcode uses to identify a build setting can inherit values
  /// from a previous precedence level.
  /// Ruby: INHERITED_KEYWORDS
  static const List<String> inheritedKeywords = [
    r'$(inherited)',
    r'${inherited}',
  ];

  /// Possible types for a scheme's 'ExecutionAction' node.
  /// Ruby: EXECUTION_ACTION_TYPE
  /// Ruby Symbol keys → Dart String keys
  static const Map<String, String> executionActionType = {
    'shell_script':
        'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction',
    'send_email':
        'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction',
  };
}
