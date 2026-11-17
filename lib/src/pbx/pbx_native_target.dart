import '../constants/misc.dart';
import '../constants/product_types.dart';
import '../object/abstract_object.dart';
import '../object/object_graph.dart';
import '../object/object_list.dart';
import '../project/project_helper.dart';
import '../project/xcode_project.dart';
import 'pbx_build_file.dart';
import 'pbx_build_phase.dart';
import 'pbx_container_item_proxy.dart';
import 'pbx_file_reference.dart';
import 'pbx_target_dependency.dart';
import 'xc_build_configuration.dart';
import 'xc_configuration_list.dart';
import 'xc_swift_package_product_dependency.dart';

// NOTE: DO NOT import pbx_project.dart — sibling. Runtime ISA scan used instead.

// =============================================================================
// AbstractTarget (abstract — base class for all Xcode targets)
// =============================================================================

/// Abstract base for all Xcode target types.
/// Port of [AbstractTarget]. Carries common
/// attributes: [buildConfigurationList] (has_one XCConfigurationList),
/// [buildPhases] (`ObjectList<AbstractBuildPhase>`), [dependencies]
/// (`ObjectList<PBXTargetDependency>`), [name], [productName].
/// Subclasses: [PBXNativeTarget], [PBXAggregateTarget], [PBXLegacyTarget].
abstract class AbstractTarget extends AbstractObject {
  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kBuildConfigurationList = 'buildConfigurationList';
  static const String _kBuildPhases = 'buildPhases';
  static const String _kDependencies = 'dependencies';
  static const String _kProductName = 'productName';

  /// Declared attribute order — subclass before superclass.
  /// Matches Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kName,
    _kBuildConfigurationList,
    _kBuildPhases,
    _kDependencies,
    _kProductName,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Target display name.
  String? name;

  /// Product name (may differ from target name for some product types).
  String? productName;

  /// Ref-counted build phases for this target.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  /// Do NOT reinitialize in [initializeDefaults].
  /// Port of `has_many :build_phases, AbstractBuildPhase`.
  late final ObjectList<AbstractBuildPhase> buildPhases =
      ObjectList<AbstractBuildPhase>(this);

  /// Ref-counted target dependencies.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  /// Do NOT reinitialize in [initializeDefaults].
  /// Port of `has_many :dependencies, PBXTargetDependency`.
  late final ObjectList<PBXTargetDependency> dependencies =
      ObjectList<PBXTargetDependency>(this);

  /// Has-one relationship to the configuration list.
  /// Port of `has_one :build_configuration_list, XCConfigurationList`
  ///. Ref-counted via setter.
  XCConfigurationList? _buildConfigurationList;

  XCConfigurationList? get buildConfigurationList => _buildConfigurationList;

  set buildConfigurationList(XCConfigurationList? value) {
    if (identical(_buildConfigurationList, value)) return;
    markProjectAsDirty();
    _buildConfigurationList?.removeReferrer(this);
    _buildConfigurationList = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  AbstractTarget(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  @override
  List<String> get referenceAttributes => const [
    _kBuildConfigurationList,
    _kBuildPhases,
    _kDependencies,
  ];

  @override
  void initializeDefaults() {
    // buildPhases and dependencies are late final — do NOT reinitialize here.
  }

  @override
  String get displayName => name ?? super.displayName;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kProductName:
        if (productName != null) into[_kProductName] = productName;
      case _kBuildConfigurationList:
        if (_buildConfigurationList != null) {
          into[_kBuildConfigurationList] = _buildConfigurationList!.uuid;
        }
      case _kBuildPhases:
        // ALWAYS emit — even when empty (to-many invariant for build phases).
        into[_kBuildPhases] = buildPhases.uuids;
      case _kDependencies:
        // ALWAYS emit — even when empty (to-many invariant for dependencies).
        into[_kDependencies] = dependencies.uuids;
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kBuildPhases:
        into[_kBuildPhases] = buildPhases
            .map(
              (p) => visited.contains(p.uuid)
                  ? '<cycle: ${p.uuid}>'
                  : p.toTreeHash(visited),
            )
            .toList();
      case _kDependencies:
        into[_kDependencies] = dependencies
            .map(
              (d) => visited.contains(d.uuid)
                  ? '<cycle: ${d.uuid}>'
                  : d.toTreeHash(visited),
            )
            .toList();
      case _kBuildConfigurationList:
        if (_buildConfigurationList != null) {
          into[_kBuildConfigurationList] =
              visited.contains(_buildConfigurationList!.uuid)
              ? '<cycle: ${_buildConfigurationList!.uuid}>'
              : _buildConfigurationList!.toTreeHash(visited);
        }
      default:
        serializeAttribute(key, into);
    }
  }

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kName:
        if (value is String) name = value;
      case _kProductName:
        if (value is String) productName = value;
      case _kBuildConfigurationList:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is XCConfigurationList) buildConfigurationList = obj;
        }
      case _kBuildPhases:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj is AbstractBuildPhase) buildPhases.add(obj);
          }
        }
      case _kDependencies:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj is PBXTargetDependency) dependencies.add(obj);
          }
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  List<ToOneAttribute> get toOneAttributes => [
    ...super.toOneAttributes,
    ToOneAttribute(
      get: () => buildConfigurationList,
      set: (v) => buildConfigurationList = v as XCConfigurationList?,
    ),
  ];

  @override
  List<ObjectList<Object>> get toManyAttributes => [
    ...super.toManyAttributes,
    buildPhases,
    dependencies,
  ];

  @override
  List<String> get toManyAttributeKeys => [
    ...super.toManyAttributeKeys,
    _kBuildPhases,
    _kDependencies,
  ];

  @override
  void clearRelationships() {
    buildConfigurationList = null;
    buildPhases.clear();
    dependencies.clear();
  }

  // ---------------------------------------------------------------------------
  // Build configuration and build phase helpers
  // ---------------------------------------------------------------------------

  /// The build configurations of the target (commonly `Debug` and `Release`),
  /// those of its [buildConfigurationList].
  /// Throws a [StateError] when the target has no configuration list (Ruby
  /// raises a `NoMethodError`).
  /// Port of `AbstractTarget#build_configurations`.
  ObjectList<XCBuildConfiguration> get buildConfigurations {
    final list = buildConfigurationList;
    if (list == null) {
      throw StateError('Target "$displayName" has no build configuration list');
    }
    return list.buildConfigurations;
  }

  /// The SDK the target uses: its `SDKROOT` setting, resolved against the
  /// project's, or `null` when it has none.
  /// Throws a [StateError] when the configurations disagree
  /// (see [commonResolvedBuildSetting]).
  /// Port of `AbstractTarget#sdk`.
  String? get sdk => commonResolvedBuildSetting('SDKROOT') as String?;

  /// The name of the platform of the target, one of `ios`, `osx`, `tvos`,
  /// `visionos` and `watchos` (the symbols of Ruby as strings), or `null`
  /// when the [sdk] is unknown or missing. Like Ruby it looks for the
  /// substrings `iphoneos`, `macosx`, `appletvos`, `xros` and `watchos` in
  /// that order, so `iphonesimulator` has no platform.
  /// Port of `AbstractTarget#platform_name`.
  String? get platformName {
    final sdk = this.sdk;
    if (sdk == null) return null;
    if (sdk.contains('iphoneos')) return 'ios';
    if (sdk.contains('macosx')) return 'osx';
    if (sdk.contains('appletvos')) return 'tvos';
    if (sdk.contains('xros')) return 'visionos';
    if (sdk.contains('watchos')) return 'watchos';
    return null;
  }

  /// The name of the build setting that holds the deployment target of each
  /// platform of [platformName].
  /// Port of `AbstractTarget::DEPLOYMENT_TARGET_SETTING_BY_PLATFORM_NAME`.
  static const Map<String, String> deploymentTargetSettingByPlatformName = {
    'ios': 'IPHONEOS_DEPLOYMENT_TARGET',
    'osx': 'MACOSX_DEPLOYMENT_TARGET',
    'tvos': 'TVOS_DEPLOYMENT_TARGET',
    'visionos': 'XROS_DEPLOYMENT_TARGET',
    'watchos': 'WATCHOS_DEPLOYMENT_TARGET',
  };

  /// The deployment target of the target according to its [platformName], or
  /// `null` when it has no platform or no deployment target.
  /// Throws a [StateError] when the configurations disagree.
  /// Port of `AbstractTarget#deployment_target`.
  String? get deploymentTarget {
    final setting = deploymentTargetSettingByPlatformName[platformName];
    if (setting == null) return null;
    return commonResolvedBuildSetting(setting) as String?;
  }

  /// The build settings of the configuration named [buildConfigurationName],
  /// or `null` when the target has no such configuration. The map is the live
  /// [XCBuildConfiguration.buildSettings] of the configuration, not a copy, so
  /// changing a key changes only that key of that configuration.
  /// Throws a [StateError] when the target has no configuration list (Ruby
  /// raises a `NoMethodError`).
  /// Port of `AbstractTarget#build_settings`.
  Map<String, dynamic>? buildSettings(String buildConfigurationName) {
    final list = buildConfigurationList;
    if (list == null) {
      throw StateError('Target "$displayName" has no build configuration list');
    }
    return list.buildSettings(buildConfigurationName);
  }

  /// Adds a build configuration named [name] to the target and fills it with
  /// the default build settings of a [type] configuration for the target's
  /// [platformName], [deploymentTarget] and, for a [PBXNativeTarget], product
  /// type (an application when it has none). Objective-C is the language, as
  /// in Ruby.
  /// When the target already has a configuration called [name] nothing is
  /// added and that configuration is returned untouched, whatever its [type].
  /// The new configuration is appended to [buildConfigurations] and takes
  /// nothing from the configurations of the project.
  /// Throws a [StateError] when the target has no configuration list, or when
  /// its configurations disagree about the SDK or the deployment target (Ruby
  /// raises a `NoMethodError` and a `RuntimeError`); nothing is created then.
  /// Port of `AbstractTarget#add_build_configuration`.
  XCBuildConfiguration addBuildConfiguration(
    String name,
    BuildConfigType type,
  ) {
    final list = buildConfigurationList;
    if (list == null) {
      throw StateError('Target "$displayName" has no build configuration list');
    }
    final existing = list[name];
    if (existing != null) return existing;

    final self = this;
    final productTypeUti = self is PBXNativeTarget ? self.productType : null;
    final settings = ProjectHelper.commonBuildSettings(
      type.name,
      platformName,
      _productTypeKey(productTypeUti),
      'objc',
      deploymentTarget: deploymentTarget,
    );
    final configuration = project.newObject(
      (g, u) => XCBuildConfiguration(g, u),
    )..name = name;
    configuration.buildSettings = settings;
    list.buildConfigurations.add(configuration);
    return configuration;
  }

  /// The name Ruby gives to the product type [uti]: the first entry of
  /// [ProductTypes.productTypeUti] with that UTI, [uti] itself when there is
  /// none and `application` when it is `null`.
  static String _productTypeKey(String? uti) {
    if (uti == null) return 'application';
    for (final entry in ProductTypes.productTypeUti.entries) {
      if (entry.value == uti) return entry.key;
    }
    return uti;
  }

  /// The shell script build phases of the target, in the order of
  /// [buildPhases].
  /// Port of `AbstractTarget#shell_script_build_phases`.
  List<PBXShellScriptBuildPhase> get shellScriptBuildPhases =>
      buildPhases.whereType<PBXShellScriptBuildPhase>().toList();

  /// The copy files build phases of the target, in the order of
  /// [buildPhases].
  /// Port of `AbstractTarget#copy_files_build_phases`.
  List<PBXCopyFilesBuildPhase> get copyFilesBuildPhases =>
      buildPhases.whereType<PBXCopyFilesBuildPhase>().toList();

  /// Appends a new copy files build phase named [name] (optional) to
  /// [buildPhases] and returns it. It copies to the resources folder until
  /// [PBXCopyFilesBuildPhase.dstSubfolderSpec] says otherwise.
  /// Unlike [PBXNativeTarget.sourceBuildPhase] and its siblings, a target can
  /// have many of these: a new phase is created every time.
  /// Port of `AbstractTarget#new_copy_files_build_phase`.
  PBXCopyFilesBuildPhase newCopyFilesBuildPhase([String? name]) {
    final phase = project.newObject((g, u) => PBXCopyFilesBuildPhase(g, u))
      ..name = name;
    buildPhases.add(phase);
    return phase;
  }

  /// Appends a new shell script build phase named [name] (optional) to
  /// [buildPhases] and returns it, with the default `/bin/sh` and
  /// placeholder script: set [PBXShellScriptBuildPhase.shellScript]
  /// to make it do something. A new phase is created every time.
  /// Port of `AbstractTarget#new_shell_script_build_phase`.
  PBXShellScriptBuildPhase newShellScriptBuildPhase([String? name]) {
    final phase = project.newObject((g, u) => PBXShellScriptBuildPhase(g, u))
      ..name = name;
    buildPhases.add(phase);
    return phase;
  }

  // ---------------------------------------------------------------------------
  // Resolved build settings
  // ---------------------------------------------------------------------------

  /// Returns a Map of configName → resolved value for [key].
  /// Values are a [String] for scalar settings, a `List<dynamic>` for array
  /// settings, or `null` when the key is not set.
  /// Resolution order: target config → project config. '$(inherited)' in the target
  /// value is replaced with the project-level value (spliced in for arrays).
  /// When target value is null, the project-level value is used directly.
  Map<String, dynamic> resolvedBuildSetting(
    String key, {
    bool resolveAgainstXcconfig = false,
  }) {
    final targetSettings =
        buildConfigurationList?.getSetting(key, resolveAgainstXcconfig) ??
        <String, dynamic>{};

    // Find PBXProject via ISA scan — avoids circular import of pbx_project.dart.
    // Established pattern (see addDependency in PBXNativeTarget).
    AbstractObject? pbxProjectObj;
    for (final o in project.objectsByUuid.values) {
      if (o.isa == 'PBXProject') {
        pbxProjectObj = o;
        break;
      }
    }
    final projectSettings =
        (pbxProjectObj as dynamic)?.buildConfigurationList?.getSetting(
              key,
              resolveAgainstXcconfig,
            )
            as Map<String, dynamic>? ??
        <String, dynamic>{};

    // Like Ruby's `Hash#merge`: the configurations only the project has are
    // part of the result too, with the project value, after the target ones.
    return {
      ...targetSettings.map((configName, targetVal) {
        final projVal = projectSettings[configName];
        if (targetVal != null &&
            projVal != null &&
            _includesInherited(targetVal)) {
          return MapEntry(configName, _expandInherited(targetVal, projVal));
        }
        return MapEntry(configName, targetVal ?? projVal);
      }),
      for (final entry in projectSettings.entries)
        if (!targetSettings.containsKey(entry.key)) entry.key: entry.value,
    };
  }

  /// Returns the single resolved value for [key] if all configurations agree.
  /// The value is a [String] or a `List<dynamic>` depending on the setting.
  /// Throws [StateError] if configurations produce different non-null values.
  dynamic commonResolvedBuildSetting(
    String key, {
    bool resolveAgainstXcconfig = false,
  }) {
    final values = <dynamic>[];
    for (final value in resolvedBuildSetting(
      key,
      resolveAgainstXcconfig: resolveAgainstXcconfig,
    ).values) {
      if (value != null && !values.any((v) => _deepEquals(v, value))) {
        values.add(value);
      }
    }
    if (values.length <= 1) return values.isEmpty ? null : values.first;
    throw StateError('Build setting $key has multiple values: $values');
  }

  /// Whether [value] (a [String] or a `List<dynamic>`) contains an
  /// `$(inherited)` keyword: as a substring for strings, as an element for lists.
  bool _includesInherited(dynamic value) {
    if (value is List) {
      return value.any(MiscConstants.inheritedKeywords.contains);
    }
    if (value is String) {
      for (final kw in MiscConstants.inheritedKeywords) {
        if (value.contains(kw)) return true;
      }
    }
    return false;
  }

  /// Replaces `$(inherited)` in [value] with [inherited]. Strings are
  /// substituted textually; for lists each inherited element is replaced by
  /// [inherited] (spliced in when it is itself a list).
  dynamic _expandInherited(dynamic value, dynamic inherited) {
    if (value is List) {
      return [
        for (final item in value)
          if (MiscConstants.inheritedKeywords.contains(item))
            ...(inherited is List ? inherited : [inherited])
          else
            item,
      ];
    }
    final replacement = inherited is List ? inherited.join(' ') : '$inherited';
    // Single pass over the original string (like Ruby's `gsub(Regexp.union(..))`)
    // so keywords inside [replacement] are not expanded a second time.
    return (value as String).replaceAllMapped(
      _inheritedPattern,
      (_) => replacement,
    );
  }

  static final RegExp _inheritedPattern = RegExp(
    MiscConstants.inheritedKeywords.map(RegExp.escape).join('|'),
  );

  bool _deepEquals(dynamic a, dynamic b) {
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}

// =============================================================================
// PBXNativeTarget extends AbstractTarget
// =============================================================================

/// A native Xcode build target.
/// Port of [PBXNativeTarget]. Adds:
/// - [productType], [productInstallPath], [productReference] (has_one),
/// - [packageProductDependencies], [fileSystemSynchronizedGroups], [buildRules] (ObjectLists)
/// - [addDependency] helper — creates PBXContainerItemProxy + PBXTargetDependency (SC-2)
/// - [addBuildPhase] helper — appends a build phase to [buildPhases]
/// Empty-array omission: [packageProductDependencies] and [fileSystemSynchronizedGroups]
/// are OMITTED from the plist when empty.
class PBXNativeTarget extends AbstractTarget {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXNativeTarget';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kProductType = 'productType';
  static const String _kProductReference = 'productReference';
  static const String _kProductInstallPath = 'productInstallPath';
  static const String _kPackageProductDependencies =
      'packageProductDependencies';
  static const String _kFileSystemSynchronizedGroups =
      'fileSystemSynchronizedGroups';
  static const String _kBuildRules = 'buildRules';

  /// Declared attribute order — subclass before superclass (AbstractTarget attrs follow).
  static const List<String> _ownAttributes = [
    _kProductType,
    _kProductReference,
    _kProductInstallPath,
    _kPackageProductDependencies,
    _kFileSystemSynchronizedGroups,
    _kBuildRules,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Product type identifier (e.g., 'com.apple.product-type.application').
  String? productType;

  /// Optional installation path for the product.
  String? productInstallPath;

  /// Has-one relationship to the product file reference.
  /// Typed as [AbstractObject?] to avoid forcing forward-ref ordering
  /// (same approach as PBXBuildFile.fileRef — decision).
  AbstractObject? _productReference;

  AbstractObject? get productReference => _productReference;

  set productReference(AbstractObject? value) {
    if (identical(_productReference, value)) return;
    markProjectAsDirty();
    _productReference?.removeReferrer(this);
    _productReference = value;
    value?.addReferrer(this);
  }

  /// Swift package product dependencies.
  /// Narrowed to [ObjectList<XCSwiftPackageProductDependency>] (-04).
  /// OMITTED when empty.
  /// Port of `has_many :package_product_dependencies, XCSwiftPackageProductDependency`
  late final ObjectList<XCSwiftPackageProductDependency>
  packageProductDependencies = ObjectList<XCSwiftPackageProductDependency>(
    this,
  );

  /// File system synchronized groups (Xcode 15+). OMITTED when empty.
  /// Port of `has_many :file_system_synchronized_groups, PBXFileSystemSynchronizedRootGroup`
  late final ObjectList<AbstractObject> fileSystemSynchronizedGroups =
      ObjectList<AbstractObject>(this);

  /// Build rules for this target.
  /// Port of `has_many :build_rules, PBXBuildRule`.
  late final ObjectList<AbstractObject> buildRules = ObjectList<AbstractObject>(
    this,
  );

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXNativeTarget(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  @override
  List<String> get referenceAttributes => [
    _kProductReference,
    _kPackageProductDependencies,
    _kFileSystemSynchronizedGroups,
    _kBuildRules,
    ...super.referenceAttributes,
  ];

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kProductType:
        if (productType != null) into[_kProductType] = productType;
      case _kProductReference:
        if (_productReference != null)
          into[_kProductReference] = _productReference!.uuid;
      case _kProductInstallPath:
        if (productInstallPath != null)
          into[_kProductInstallPath] = productInstallPath;
      case _kPackageProductDependencies:
        // OMIT when empty
        final uuids = packageProductDependencies.uuids;
        if (uuids.isNotEmpty) into[_kPackageProductDependencies] = uuids;
      case _kFileSystemSynchronizedGroups:
        // OMIT when empty
        final uuids = fileSystemSynchronizedGroups.uuids;
        if (uuids.isNotEmpty) into[_kFileSystemSynchronizedGroups] = uuids;
      case _kBuildRules:
        // Always emit build rules (even empty)
        into[_kBuildRules] = buildRules.uuids;
      default:
        super.serializeAttribute(key, into);
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kProductType:
      case _kProductReference:
      case _kProductInstallPath:
        serializeAttribute(key, into);
      case _kPackageProductDependencies:
        final list = packageProductDependencies
            .map(
              (d) => visited.contains(d.uuid)
                  ? '<cycle: ${d.uuid}>'
                  : d.toTreeHash(visited),
            )
            .toList();
        if (list.isNotEmpty) into[_kPackageProductDependencies] = list;
      case _kFileSystemSynchronizedGroups:
        final list = fileSystemSynchronizedGroups
            .map(
              (g) => visited.contains(g.uuid)
                  ? '<cycle: ${g.uuid}>'
                  : g.toTreeHash(visited),
            )
            .toList();
        if (list.isNotEmpty) into[_kFileSystemSynchronizedGroups] = list;
      case _kBuildRules:
        into[_kBuildRules] = buildRules
            .map(
              (r) => visited.contains(r.uuid)
                  ? '<cycle: ${r.uuid}>'
                  : r.toTreeHash(visited),
            )
            .toList();
      default:
        super.serializeAttributeAsTree(key, into, visited);
    }
  }

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kProductType:
        if (value is String) productType = value;
      case _kProductReference:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj != null) productReference = obj;
        }
      case _kProductInstallPath:
        if (value is String) productInstallPath = value;
      case _kPackageProductDependencies:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            // narrowed to XCSwiftPackageProductDependency (-04)
            if (obj is XCSwiftPackageProductDependency) {
              packageProductDependencies.add(obj);
            }
          }
        }
      case _kFileSystemSynchronizedGroups:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj != null) fileSystemSynchronizedGroups.add(obj);
          }
        }
      case _kBuildRules:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj != null) buildRules.add(obj);
          }
        }
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  List<ToOneAttribute> get toOneAttributes => [
    ...super.toOneAttributes,
    ToOneAttribute(
      get: () => productReference,
      set: (v) => productReference = v,
    ),
  ];

  @override
  List<ObjectList<Object>> get toManyAttributes => [
    buildRules,
    packageProductDependencies,
    buildPhases,
    fileSystemSynchronizedGroups,
    dependencies,
  ];

  // In the order Ruby's PBXNativeTarget declares them (and so follows them):
  // its own build_phases come before those of AbstractTarget.
  @override
  List<String> get toManyAttributeKeys => const [
    _kBuildRules,
    _kPackageProductDependencies,
    AbstractTarget._kBuildPhases,
    _kFileSystemSynchronizedGroups,
    AbstractTarget._kDependencies,
  ];

  @override
  void clearRelationships() {
    productReference = null;
    packageProductDependencies.clear();
    fileSystemSynchronizedGroups.clear();
    buildRules.clear();
    super.clearRelationships();
  }

  // ---------------------------------------------------------------------------
  // Target dependency helpers
  // ---------------------------------------------------------------------------

  /// Appends [phase] to the [buildPhases] ObjectList.
  /// Port of helper pattern.
  /// Reference counting is handled automatically by [ObjectList.add].
  void addBuildPhase(AbstractBuildPhase phase) {
    buildPhases.add(phase);
  }

  /// Creates a [PBXTargetDependency] and [PBXContainerItemProxy] for [target],
  /// and appends the dependency to [dependencies].
  /// Idempotent — calling twice with the same target is a no-op.
  /// Port of#add_dependency (lines 242-264).
  /// Referrer counts after this call:
  /// - [target] gains 1 referrer (the new [PBXTargetDependency])
  /// - The new [PBXContainerItemProxy] gains 1 referrer (the new dependency)
  /// - The new [PBXTargetDependency] gains 1 referrer (this target, via [dependencies])
  /// containerPortal is set to the UUID of the PBXProject root object, located
  /// via a runtime ISA scan over [project.objectsByUuid] (rootObject is ).
  /// Security: — idempotency guard prevents duplicate dependencies.
  void addDependency(AbstractTarget target) {
    if (dependencyForTarget(target) != null) return; // idempotency guard
    // Locate PBXProject root via runtime ISA scan.
    // rootObject is deferred; use ISA scan here.
    // bounded by project's object count; no info leaks.
    AbstractObject? pbxProject;
    for (final o in project.objectsByUuid.values) {
      if (o.isa == 'PBXProject') {
        pbxProject = o;
        break;
      }
    }

    final containerProxy = project.newObject<PBXContainerItemProxy>(
      (g, u) => PBXContainerItemProxy(g, u),
    );
    containerProxy.containerPortal = pbxProject?.uuid;
    containerProxy.proxyType =
        '1'; // PROXY_TYPES[:native_target] — Ruby Constants gem
    containerProxy.remoteGlobalIDString = target.uuid;
    containerProxy.remoteInfo = target.name;

    final dependency = project.newObject<PBXTargetDependency>(
      (g, u) => PBXTargetDependency(g, u),
    );
    dependency.name = target.name;
    dependency.target = target; // triggers target.addReferrer(dependency)
    dependency.targetProxy =
        containerProxy; // triggers containerProxy.addReferrer(dependency)

    dependencies.add(dependency); // triggers dependency.addReferrer(this)
  }

  /// Returns the existing [PBXTargetDependency] for [target], or null if none exists.
  /// Used by [addDependency] for idempotency checking.
  PBXTargetDependency? dependencyForTarget(AbstractTarget target) {
    for (final dep in dependencies) {
      if (dep.target is AbstractTarget &&
          (dep.target as AbstractTarget).uuid == target.uuid) {
        return dep;
      }
      if (dep.targetProxy?.remoteGlobalIDString == target.uuid) return dep;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build phase helpers
  // ---------------------------------------------------------------------------

  /// Finds or creates the sources build phase of the target.
  ///
  /// A target should have only one sources build phase: the first one is
  /// returned, and when there is none a new [PBXSourcesBuildPhase] is appended
  /// to [buildPhases].
  /// Port of `PBXNativeTarget#source_build_phase`.
  PBXSourcesBuildPhase get sourceBuildPhase =>
      _findOrCreateBuildPhase((g, u) => PBXSourcesBuildPhase(g, u));

  /// Finds or creates the frameworks build phase of the target.
  ///
  /// A target should have only one frameworks build phase: the first one is
  /// returned, and when there is none a new [PBXFrameworksBuildPhase] is
  /// appended to [buildPhases].
  /// Port of `PBXNativeTarget#frameworks_build_phase`.
  PBXFrameworksBuildPhase get frameworksBuildPhase =>
      _findOrCreateBuildPhase((g, u) => PBXFrameworksBuildPhase(g, u));

  /// Finds or creates the resources build phase of the target.
  ///
  /// A target should have only one resources build phase: the first one is
  /// returned, and when there is none a new [PBXResourcesBuildPhase] is
  /// appended to [buildPhases].
  /// Port of `PBXNativeTarget#resources_build_phase`.
  PBXResourcesBuildPhase get resourcesBuildPhase =>
      _findOrCreateBuildPhase((g, u) => PBXResourcesBuildPhase(g, u));

  /// Finds or creates the headers build phase of the target.
  ///
  /// A target should have only one headers build phase: the first one is
  /// returned, and when there is none a new [PBXHeadersBuildPhase] is appended
  /// to [buildPhases].
  /// Port of `PBXNativeTarget#headers_build_phase`.
  PBXHeadersBuildPhase get headersBuildPhase =>
      _findOrCreateBuildPhase((g, u) => PBXHeadersBuildPhase(g, u));

  /// Adds [fileReferences] to the target and returns the build file of each,
  /// in the same order.
  ///
  /// A file whose extension is one of [MiscConstants.headerFilesExtensions]
  /// (compared in lower case, so `.HPP` is a header) goes to the
  /// [headersBuildPhase], any other to the [sourceBuildPhase]; the phase is
  /// created when the target has none, but only when there is a file to add.
  /// A file that already has a build file in its phase is not added again: the
  /// existing build file is returned (so a reference given twice yields the
  /// same build file twice).
  ///
  /// A non-empty [compilerFlags] is stored as the `COMPILER_FLAGS` setting of
  /// the build file of each source file (headers have none), appended after a
  /// space to the flags the build file already has, even when they are the
  /// same, the other settings being kept. [onBuildFile] is called with the
  /// build file of each reference, a new or an existing one.
  ///
  /// Only [PBXFileReference]s are taken, as the Ruby docs say, though Ruby
  /// would also take any object with a `path`, such as a group.
  ///
  /// Throws an [ArgumentError], before changing anything, when a reference has
  /// no `path` (Ruby raises a `TypeError` midway).
  /// Port of `PBXNativeTarget#add_file_references`. [compilerFlags] is the
  /// second argument there, and [onBuildFile] its block.
  List<PBXBuildFile> addFileReferences(
    Iterable<PBXFileReference> fileReferences, {
    String? compilerFlags,
    void Function(PBXBuildFile buildFile)? onBuildFile,
  }) {
    final files = fileReferences.toList();
    for (final file in files) {
      if (file.path == null) {
        throw ArgumentError.value(
          file,
          'fileReferences',
          'a file reference without a path cannot be added to a build phase',
        );
      }
    }

    final buildFiles = <PBXBuildFile>[];
    for (final file in files) {
      final isHeader = MiscConstants.headerFilesExtensions.contains(
        _extname(file.path!).toLowerCase(),
      );
      final phase = isHeader ? headersBuildPhase : sourceBuildPhase;
      final buildFile = phase.addFileReference(file, avoidDuplicates: true);

      if (compilerFlags != null && compilerFlags.isNotEmpty && !isHeader) {
        final settings = buildFile.settings ??= <String, dynamic>{};
        final old = settings['COMPILER_FLAGS'];
        settings['COMPILER_FLAGS'] = old == null
            ? compilerFlags
            : '$old $compilerFlags';
      }

      onBuildFile?.call(buildFile);
      buildFiles.add(buildFile);
    }
    return buildFiles;
  }

  /// Adds [resourceFileReferences] to the [resourcesBuildPhase] of the target.
  ///
  /// A reference that already has a build file in the phase is skipped (also
  /// when it appears twice in the list). The phase is created only when there
  /// is a reference to add it to: an empty list leaves [buildPhases] alone.
  /// Port of `PBXNativeTarget#add_resources`.
  void addResources(Iterable<AbstractObject> resourceFileReferences) {
    for (final file in resourceFileReferences) {
      resourcesBuildPhase.addFileReference(file, avoidDuplicates: true);
    }
  }

  /// Finds the first build phase whose class is exactly [T], or creates one
  /// and appends it to [buildPhases].
  /// Port of `PBXNativeTarget#find_or_create_build_phase_by_class`. Ruby also
  /// memoizes the phase in an instance variable, which goes stale when the
  /// phase is removed from the target: this looks [buildPhases] up every time.
  T _findOrCreateBuildPhase<T extends AbstractBuildPhase>(
    T Function(ObjectGraph, String) factory,
  ) {
    for (final phase in buildPhases) {
      if (phase.runtimeType == T) return phase as T;
    }
    final phase = project.newObject(factory);
    buildPhases.add(phase);
    return phase;
  }
}

// =============================================================================
// PBXAggregateTarget extends AbstractTarget
// =============================================================================

/// An aggregate (non-product-generating) Xcode target.
/// Port of [PBXAggregateTarget].
/// No additional attributes beyond [AbstractTarget].
class PBXAggregateTarget extends AbstractTarget {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXAggregateTarget';

  PBXAggregateTarget(super.project, super.uuid);

  @override
  String get isa => isaStatic;
  // No additional attributes — confirms.
}

// =============================================================================
// PBXLegacyTarget extends AbstractTarget
// =============================================================================

/// A legacy (external build tool) Xcode target.
/// Port of [PBXLegacyTarget]. Adds
/// [buildArgumentsString], [buildToolPath], [buildWorkingDirectory],
/// [passBuildSettingsInEnvironment] on top of [AbstractTarget].
class PBXLegacyTarget extends AbstractTarget {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXLegacyTarget';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kBuildArgumentsString = 'buildArgumentsString';
  static const String _kBuildToolPath = 'buildToolPath';
  static const String _kBuildWorkingDirectory = 'buildWorkingDirectory';
  static const String _kPassBuildSettingsInEnvironment =
      'passBuildSettingsInEnvironment';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kBuildArgumentsString,
    _kBuildToolPath,
    _kBuildWorkingDirectory,
    _kPassBuildSettingsInEnvironment,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Arguments string for the external build tool.
  String? buildArgumentsString;

  /// Path to the external build tool binary.
  String? buildToolPath;

  /// Working directory for the build tool.
  String? buildWorkingDirectory;

  /// Whether to pass build settings in environment ('0' or '1').
  String? passBuildSettingsInEnvironment;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXLegacyTarget(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kBuildArgumentsString:
        if (buildArgumentsString != null) {
          into[_kBuildArgumentsString] = buildArgumentsString;
        }
      case _kBuildToolPath:
        if (buildToolPath != null) into[_kBuildToolPath] = buildToolPath;
      case _kBuildWorkingDirectory:
        if (buildWorkingDirectory != null) {
          into[_kBuildWorkingDirectory] = buildWorkingDirectory;
        }
      case _kPassBuildSettingsInEnvironment:
        if (passBuildSettingsInEnvironment != null) {
          into[_kPassBuildSettingsInEnvironment] =
              passBuildSettingsInEnvironment;
        }
      default:
        super.serializeAttribute(key, into);
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kBuildArgumentsString:
      case _kBuildToolPath:
      case _kBuildWorkingDirectory:
      case _kPassBuildSettingsInEnvironment:
        serializeAttribute(key, into);
      default:
        super.serializeAttributeAsTree(key, into, visited);
    }
  }

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kBuildArgumentsString:
        if (value is String) buildArgumentsString = value;
      case _kBuildToolPath:
        if (value is String) buildToolPath = value;
      case _kBuildWorkingDirectory:
        if (value is String) buildWorkingDirectory = value;
      case _kPassBuildSettingsInEnvironment:
        if (value is String) passBuildSettingsInEnvironment = value;
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }
}

/// The extension of [path], with its leading dot, like Ruby's `File.extname`:
/// a leading dot of the basename does not start an extension (`.h` has none),
/// a trailing one is one (`foo.` gives `.`). `package:path`'s `extension`
/// would take `.h` as an extension.
String _extname(String path) {
  final trimmed = path.replaceFirst(RegExp(r'/+$'), '');
  final base = trimmed.substring(trimmed.lastIndexOf('/') + 1);
  final name = base.replaceFirst(RegExp(r'^\.+'), '');
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot);
}
