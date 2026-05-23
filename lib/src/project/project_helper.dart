// newLegacyTarget, configurationList, commonBuildSettings]
// Provides static helpers for creating targets and configuration lists.
// Provides helpers for adding targets without needing to know the internal PBX graph structure.

import '../constants/build_settings.dart';
import '../constants/file_types.dart';
import '../constants/product_types.dart';
import '../object/isa_registry.dart';
import '../pbx/group.dart';
import '../pbx/pbx_build_phase.dart';
import '../pbx/pbx_file_reference.dart';
import '../pbx/pbx_native_target.dart';
import '../pbx/xc_build_configuration.dart';
import '../pbx/xc_configuration_list.dart';
import 'xcode_project.dart';

/// Static helper methods for creating Xcode targets and configuration lists.
/// Port of [Xcodeproj::Project::ProjectHelper].
/// All methods are static — this class is not instantiable.
class ProjectHelper {
  ProjectHelper._();

  // ---------------------------------------------------------------------------
  // Target creation
  // ---------------------------------------------------------------------------

  /// Creates a new native target and adds it to [project].
  /// The target is configured for [platform] with common build settings.
  /// A product file reference is added to [productGroup]. Build phases
  /// appropriate for [type] are added.
  /// [type] — 'application', 'framework', 'static_library', etc.
  /// [name] — display name for the target.
  /// [platform] — 'ios', 'osx', 'tvos', 'visionos', 'watchos'.
  /// [deploymentTarget]— optional deployment target version string.
  /// [productGroup] — PBXGroup to add the product file reference to.
  /// [language] — 'swift', 'objc', or null.
  /// [productBasename] — base name of the product (without extension).
  /// Port of.
  static PBXNativeTarget newTarget(
    XcodeProject project,
    String type,
    String name,
    String platform,
    String? deploymentTarget,
    PBXGroup productGroup,
    String? language,
    String productBasename,
  ) {
    final target = project.newObject((g, u) => PBXNativeTarget(g, u));
    project.rootObject.targets.add(target);
    target.name = name;
    target.productName = productBasename;
    target.productType = ProductTypes.productTypeUti[type];

    target.buildConfigurationList = configurationList(
      project,
      platform,
      deploymentTarget,
      type,
      language,
    );

    // Product reference file
    final ext = ProductTypes.productUtiExtensions[type] ?? '';
    final prefix = type == 'static_library' ? 'lib' : '';
    final filename = ext.isEmpty
        ? '$prefix$productBasename'
        : '$prefix$productBasename.$ext';

    final productRef = project.newObject((g, u) => PBXFileReference(g, u));
    productRef.path = filename;
    productRef.sourceTree = 'BUILT_PRODUCTS_DIR';
    productRef.includeInIndex = '0';

    // Set explicitFileType if known
    if (ext.isNotEmpty) {
      final fileType = FileTypes.byExtension[ext];
      if (fileType != null) productRef.explicitFileType = fileType;
    }

    productGroup.children.add(productRef);
    target.productReference = productRef;

    // Add build phases appropriate for this target type
    for (final isa in _buildPhasesForType(type)) {
      final factory = isaRegistry[isa];
      if (factory != null) {
        final phase = project.newObject((g, u) => factory(g, u));
        if (phase is AbstractBuildPhase) {
          target.buildPhases.add(phase);
        }
      }
    }

    return target;
  }

  /// Creates a new resources bundle target and adds it to [project].
  /// Port of.
  static PBXNativeTarget newResourcesBundle(
    XcodeProject project,
    String name,
    String platform,
    String? deploymentTarget,
    PBXGroup productGroup,
  ) => newTarget(
    project,
    'bundle',
    name,
    platform,
    deploymentTarget,
    productGroup,
    null,
    name,
  );

  /// Creates a new aggregate target and adds it to [project].
  /// Aggregate targets have no product; they are used to group build phases
  /// (e.g., run scripts) without producing an artifact.
  /// Port of.
  static PBXAggregateTarget newAggregateTarget(
    XcodeProject project,
    String name,
    String platform,
    String? deploymentTarget,
  ) {
    final target = project.newObject((g, u) => PBXAggregateTarget(g, u));
    project.rootObject.targets.add(target);
    target.name = name;
    target.productName = name;
    target.buildConfigurationList = configurationList(
      project,
      platform,
      deploymentTarget,
      'aggregate',
      null,
    );
    return target;
  }

  /// Creates a new legacy (external build tool) target and adds it to [project].
  /// Port of.
  static PBXLegacyTarget newLegacyTarget(
    XcodeProject project,
    String name,
    String buildToolPath,
    String platform,
    String? deploymentTarget,
  ) {
    final target = project.newObject((g, u) => PBXLegacyTarget(g, u));
    project.rootObject.targets.add(target);
    target.name = name;
    target.productName = name;
    target.buildToolPath = buildToolPath;
    target.passBuildSettingsInEnvironment = '1';
    target.buildConfigurationList = configurationList(
      project,
      platform,
      deploymentTarget,
      'legacy',
      null,
    );
    return target;
  }

  // ---------------------------------------------------------------------------
  // Configuration list creation
  // ---------------------------------------------------------------------------

  /// Creates a new [XCConfigurationList] with Release and Debug configurations,
  /// populated with common build settings for [platform] and [productType].
  /// Additional project-level configurations (beyond Debug and Release) are
  /// copied from [project.buildConfigurations] with empty build settings.
  /// Port of.
  static XCConfigurationList configurationList(
    XcodeProject project,
    String platform,
    String? deploymentTarget,
    String productType,
    String? language,
  ) {
    final list = project.newObject((g, u) => XCConfigurationList(g, u));
    list.defaultConfigurationIsVisible = '0';
    list.defaultConfigurationName = 'Release';

    // Ruby order: release first, then debug
    for (final type in ['release', 'debug']) {
      final config = project.newObject((g, u) => XCBuildConfiguration(g, u));
      config.name = type == 'release' ? 'Release' : 'Debug';
      final settings = commonBuildSettings(
        type,
        platform,
        productType,
        language,
      );
      if (deploymentTarget != null) {
        final dtKey = _deploymentTargetKey(platform);
        if (dtKey != null) settings[dtKey] = deploymentTarget;
      }
      config.buildSettings = settings;
      list.buildConfigurations.add(config);
    }

    // Copy any extra project-level configurations (not Debug or Release)
    for (final bc in project.buildConfigurations) {
      final bcName = bc.name ?? '';
      if (bcName != 'Debug' && bcName != 'Release' && bcName.isNotEmpty) {
        final extra = project.newObject((g, u) => XCBuildConfiguration(g, u));
        extra.name = bcName;
        extra.buildSettings = {};
        list.buildConfigurations.add(extra);
      }
    }

    return list;
  }

  // ---------------------------------------------------------------------------
  // Common build settings
  // ---------------------------------------------------------------------------

  /// Returns the common build settings map for a given configuration type,
  /// platform, product type and language combination.
  /// Follows the key-combination algorithm from RESEARCH Pattern 4 /
  /// positional key order is [type, platform, productType, language], and all
  /// length-1 to length-N combinations are generated in index order.
  /// Port of.
  static Map<String, dynamic> commonBuildSettings(
    String type,
    String platform,
    String productType,
    String? language,
  ) {
    final result = Map<String, dynamic>.from(
      BuildSettings.commonBuildSettings['all'] ?? {},
    );

    // Keys in positional order: [type, platform, productType, language].compact
    final keys = <String>[
      type,
      platform,
      productType,
      if (language != null) language,
    ];

    // Generate all length-1 to length-N combinations in input-array index order.
    // Matches Ruby: keys.combination(n).to_a
    for (var len = 1; len <= keys.length; len++) {
      for (final combo in _combinations(keys, len)) {
        final comboKey = combo.join(',');
        final settings = BuildSettings.commonBuildSettings[comboKey];
        if (settings != null) {
          result.addAll(Map<String, dynamic>.from(settings));
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the ISA strings of build phases to add for a given target [type].
  /// Port of.
  static List<String> _buildPhasesForType(String type) {
    switch (type) {
      case 'static_library':
      case 'dynamic_library':
        return [
          'PBXHeadersBuildPhase',
          'PBXSourcesBuildPhase',
          'PBXFrameworksBuildPhase',
        ];
      case 'framework':
        return [
          'PBXHeadersBuildPhase',
          'PBXSourcesBuildPhase',
          'PBXFrameworksBuildPhase',
          'PBXResourcesBuildPhase',
        ];
      case 'command_line_tool':
        return ['PBXSourcesBuildPhase', 'PBXFrameworksBuildPhase'];
      default:
        return [
          'PBXSourcesBuildPhase',
          'PBXFrameworksBuildPhase',
          'PBXResourcesBuildPhase',
        ];
    }
  }

  /// Maps [platform] string to the Xcode build setting key for deployment target.
  static String? _deploymentTargetKey(String platform) {
    switch (platform) {
      case 'ios':
        return 'IPHONEOS_DEPLOYMENT_TARGET';
      case 'osx':
        return 'MACOSX_DEPLOYMENT_TARGET';
      case 'tvos':
        return 'TVOS_DEPLOYMENT_TARGET';
      case 'watchos':
        return 'WATCHOS_DEPLOYMENT_TARGET';
      case 'visionos':
        return 'XROS_DEPLOYMENT_TARGET';
      default:
        return null;
    }
  }

  /// Generates all combinations of length [r] from [list], preserving
  /// input-array index order (matches Ruby Array#combination semantics).
  static List<List<String>> _combinations(List<String> list, int r) {
    if (r == 0) return [[]];
    if (list.isEmpty) return [];
    final result = <List<String>>[];
    for (var i = 0; i <= list.length - r; i++) {
      for (final rest in _combinations(list.sublist(i + 1), r - 1)) {
        result.add([list[i], ...rest]);
      }
    }
    return result;
  }
}
