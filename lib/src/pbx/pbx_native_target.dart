import '../constants/misc.dart';
import '../object/abstract_object.dart';
import '../object/object_list.dart';
import 'pbx_build_phase.dart';
import 'pbx_container_item_proxy.dart';
import 'pbx_target_dependency.dart';
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
  void removeReference(AbstractObject obj) {
    if (identical(_buildConfigurationList, obj)) buildConfigurationList = null;
    if (obj is AbstractBuildPhase) buildPhases.remove(obj);
    if (obj is PBXTargetDependency) dependencies.remove(obj);
  }

  @override
  void clearRelationships() {
    buildConfigurationList = null;
    buildPhases.clear();
    dependencies.clear();
  }

  // ---------------------------------------------------------------------------
  // Resolved build settings
  // ---------------------------------------------------------------------------

  /// Returns a Map of configName → resolved value for [key].
  /// Resolution order: target config → project config. '$(inherited)' in the target
  /// value is replaced with the project-level value. When target value is null,
  /// the project-level value is used directly.
  Map<String, String?> resolvedBuildSetting(
    String key, {
    bool resolveAgainstXcconfig = false,
  }) {
    final targetSettings =
        buildConfigurationList?.getSetting(key, resolveAgainstXcconfig) ?? {};

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
            as Map<String, String?>? ??
        <String, String?>{};

    return targetSettings.map((configName, targetVal) {
      final projVal = projectSettings[configName];
      if (targetVal != null && _includesInherited(targetVal)) {
        return MapEntry(configName, _expandInherited(targetVal, projVal));
      }
      return MapEntry(configName, targetVal ?? projVal);
    });
  }

  /// Returns the single resolved value for [key] if all configurations agree.
  /// Throws [StateError] if configurations produce different non-null values.
  String? commonResolvedBuildSetting(
    String key, {
    bool resolveAgainstXcconfig = false,
  }) {
    final values = resolvedBuildSetting(
      key,
      resolveAgainstXcconfig: resolveAgainstXcconfig,
    ).values.whereType<String>().toSet();
    if (values.length <= 1) return values.isEmpty ? null : values.first;
    throw StateError('Build setting $key has multiple values: $values');
  }

  bool _includesInherited(String value) {
    for (final kw in MiscConstants.inheritedKeywords) {
      if (value.contains(kw)) return true;
    }
    return false;
  }

  String? _expandInherited(String value, String? inherited) {
    if (inherited == null) return value;
    var result = value;
    for (final kw in MiscConstants.inheritedKeywords) {
      result = result.replaceAll(kw, inherited);
    }
    return result;
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
  void removeReference(AbstractObject obj) {
    if (identical(_productReference, obj)) productReference = null;
    packageProductDependencies.remove(obj);
    fileSystemSynchronizedGroups.remove(obj);
    buildRules.remove(obj);
    super.removeReference(obj);
  }

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
