import '../object/abstract_object.dart';
import '../object/object_dictionary.dart';
import '../object/object_list.dart';
import '../project/groups_position.dart';
import 'group.dart';
import 'pbx_file_reference.dart';
import 'pbx_native_target.dart';
import 'xc_configuration_list.dart';

/// The root object of every Xcode project file.
/// Port of [PBXProject]. This is the object referenced by
/// `rootObject` in the `.pbxproj` header. All other PBX objects are reachable
/// from here via [mainGroup], [targets], [packageReferences], etc.
/// 'name' is NOT a serialized attribute. In Ruby, `PBXProject#name`
/// returns `project.path.basename('.xcodeproj').to_s` — computed from the project
/// file path. This computation belongs to 's [XcodeProject] container.
/// The [name] key MUST NOT appear in [_ownAttributes] or in any toHash output.
/// [projectReferences] and [packageReferences] are OMITTED from the
/// serialized plist when empty, unlike most other to-many attributes which
/// always emit an empty list. This matches Ruby.
class PBXProject extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXProject';

  // ---------------------------------------------------------------------------
  // Attribute key constants — Ruby declaration order
  // ---------------------------------------------------------------------------

  static const String _kTargets = 'targets';
  static const String _kAttributes = 'attributes';
  static const String _kBuildConfigurationList = 'buildConfigurationList';
  static const String _kCompatibilityVersion = 'compatibilityVersion';
  static const String _kDevelopmentRegion = 'developmentRegion';
  static const String _kHasScannedForEncodings = 'hasScannedForEncodings';
  static const String _kKnownRegions = 'knownRegions';
  static const String _kMainGroup = 'mainGroup';
  static const String _kMinimizedProjectReferenceProxies =
      'minimizedProjectReferenceProxies';
  static const String _kPreferredProjectObjectVersion =
      'preferredProjectObjectVersion';
  static const String _kProductRefGroup = 'productRefGroup';
  static const String _kProjectDirPath = 'projectDirPath';
  static const String _kProjectRoot = 'projectRoot';
  static const String _kPackageReferences = 'packageReferences';
  static const String _kProjectReferences = 'projectReferences';

  // NOTE: 'name' is NOT in _ownAttributes.
  // NOTE: Key order follows Ruby declaration order.
  static const List<String> _ownAttributes = [
    _kTargets,
    _kAttributes,
    _kBuildConfigurationList,
    _kCompatibilityVersion,
    _kDevelopmentRegion,
    _kHasScannedForEncodings,
    _kKnownRegions,
    _kMainGroup,
    _kMinimizedProjectReferenceProxies,
    _kPreferredProjectObjectVersion,
    _kProductRefGroup,
    _kProjectDirPath,
    _kProjectRoot,
    _kPackageReferences,
    _kProjectReferences,
  ];

  /// Key schema for [projectReferences] entries.
  /// Ruby uses `has_many_references_by_keys :project_references,
  /// project_ref: PBXFileReference, product_group: PBXGroup`.
  /// Keys are the camelCase plist key names.
  static const Map<String, Type> _projectRefKeys = {
    'ProjectRef': PBXFileReference,
    'ProductGroup': PBXGroup,
  };

  // ---------------------------------------------------------------------------
  // Simple attributes
  // ---------------------------------------------------------------------------

  /// Project-level attributes map (e.g., LastUpgradeCheck, TargetAttributes).
  /// Always serialized — Ruby always emits this Map.
  Map<String, dynamic> attributes = {};

  /// Compatibility version string (e.g., 'Xcode 14.0').
  String? compatibilityVersion;

  /// Default development region (e.g., 'en').
  String? developmentRegion;

  /// Whether the project has been scanned for encodings ('0' or '1').
  String? hasScannedForEncodings;

  /// Known localizations (e.g., ['en', 'Base']).
  /// Always serialized — Ruby always emits this Array.
  List<String> knownRegions = [];

  /// Whether to minimize reference proxies ('0' or '1').
  String? minimizedProjectReferenceProxies;

  /// Preferred project object version string.
  String? preferredProjectObjectVersion;

  /// Project directory path (usually empty string).
  String? projectDirPath;

  /// Project root path (usually empty string).
  String? projectRoot;

  // ---------------------------------------------------------------------------
  // has_one fields
  // ---------------------------------------------------------------------------

  XCConfigurationList? _buildConfigurationList;

  XCConfigurationList? get buildConfigurationList => _buildConfigurationList;

  set buildConfigurationList(XCConfigurationList? value) {
    if (identical(_buildConfigurationList, value)) return;
    markProjectAsDirty();
    _buildConfigurationList?.removeReferrer(this);
    _buildConfigurationList = value;
    value?.addReferrer(this);
  }

  PBXGroup? _mainGroup;

  PBXGroup? get mainGroup => _mainGroup;

  set mainGroup(PBXGroup? value) {
    if (identical(_mainGroup, value)) return;
    markProjectAsDirty();
    _mainGroup?.removeReferrer(this);
    _mainGroup = value;
    value?.addReferrer(this);
  }

  PBXGroup? _productRefGroup;

  PBXGroup? get productRefGroup => _productRefGroup;

  set productRefGroup(PBXGroup? value) {
    if (identical(_productRefGroup, value)) return;
    markProjectAsDirty();
    _productRefGroup?.removeReferrer(this);
    _productRefGroup = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // ObjectList fields
  // ---------------------------------------------------------------------------

  /// Ref-counted list of build targets.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  late final ObjectList<AbstractTarget> targets = ObjectList<AbstractTarget>(
    this,
  );

  /// Ref-counted list of package references (remote or local Swift packages).
  /// OMIT from plist when empty.
  late final ObjectList<AbstractObject> packageReferences =
      ObjectList<AbstractObject>(this);

  /// Ref-counted list of sub-project references.
  /// Each entry is an [ObjectDictionary] with keys:
  /// - `'ProjectRef'` → [PBXFileReference]
  /// - `'ProductGroup'` → [PBXGroup]
  /// OMIT from plist when empty.
  late final ObjectList<ObjectDictionary> projectReferences =
      ObjectList<ObjectDictionary>(this);

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXProject(super.project, super.uuid);

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
  String get displayName => 'Project object';

  // Do NOT add a 'name' getter that participates in serialization.
  // XcodeProject computes name from the project file path.

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kTargets:
        // Always emit — even when empty. ObjectList.uuids already returns a copy.
        into[_kTargets] = targets.uuids;
      case _kAttributes:
        // Always emit — Ruby always emits the attributes Map.
        into[_kAttributes] = attributes;
      case _kBuildConfigurationList:
        if (_buildConfigurationList != null) {
          into[_kBuildConfigurationList] = _buildConfigurationList!.uuid;
        }
      case _kCompatibilityVersion:
        if (compatibilityVersion != null) {
          into[_kCompatibilityVersion] = compatibilityVersion;
        }
      case _kDevelopmentRegion:
        if (developmentRegion != null)
          into[_kDevelopmentRegion] = developmentRegion;
      case _kHasScannedForEncodings:
        if (hasScannedForEncodings != null) {
          into[_kHasScannedForEncodings] = hasScannedForEncodings;
        }
      case _kKnownRegions:
        // Always emit — Ruby always emits this Array.
        into[_kKnownRegions] = knownRegions;
      case _kMainGroup:
        if (_mainGroup != null) into[_kMainGroup] = _mainGroup!.uuid;
      case _kMinimizedProjectReferenceProxies:
        if (minimizedProjectReferenceProxies != null) {
          into[_kMinimizedProjectReferenceProxies] =
              minimizedProjectReferenceProxies;
        }
      case _kPreferredProjectObjectVersion:
        if (preferredProjectObjectVersion != null) {
          into[_kPreferredProjectObjectVersion] = preferredProjectObjectVersion;
        }
      case _kProductRefGroup:
        if (_productRefGroup != null)
          into[_kProductRefGroup] = _productRefGroup!.uuid;
      case _kProjectDirPath:
        if (projectDirPath != null) into[_kProjectDirPath] = projectDirPath;
      case _kProjectRoot:
        if (projectRoot != null) into[_kProjectRoot] = projectRoot;
      case _kPackageReferences:
        // OMIT when empty.
        // ObjectList.uuids already returns a copy — no .toList() needed.
        final uuids = packageReferences.uuids;
        if (uuids.isNotEmpty) into[_kPackageReferences] = uuids;
      case _kProjectReferences:
        // OMIT when empty; emit as List<Map> when non-empty
        if (projectReferences.isNotEmpty) {
          into[_kProjectReferences] = projectReferences
              .map((d) => d.toHash())
              .toList();
        }
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
      case _kTargets:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj is AbstractTarget) targets.add(obj);
          }
        }
      case _kAttributes:
        if (value is Map) attributes = Map<String, dynamic>.from(value);
      case _kBuildConfigurationList:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is XCConfigurationList) buildConfigurationList = obj;
        }
      case _kCompatibilityVersion:
        if (value is String) compatibilityVersion = value;
      case _kDevelopmentRegion:
        if (value is String) developmentRegion = value;
      case _kHasScannedForEncodings:
        if (value is String) hasScannedForEncodings = value;
      case _kKnownRegions:
        if (value is List) knownRegions = value.cast<String>().toList();
      case _kMainGroup:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is PBXGroup) mainGroup = obj;
        }
      case _kMinimizedProjectReferenceProxies:
        if (value is String) minimizedProjectReferenceProxies = value;
      case _kPreferredProjectObjectVersion:
        if (value is String) preferredProjectObjectVersion = value;
      case _kProductRefGroup:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is PBXGroup) productRefGroup = obj;
        }
      case _kProjectDirPath:
        if (value is String) projectDirPath = value;
      case _kProjectRoot:
        if (value is String) projectRoot = value;
      case _kPackageReferences:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj != null) packageReferences.add(obj);
          }
        }
      case _kProjectReferences:
        if (value is List) {
          for (final entry in value) {
            if (entry is Map) {
              final dict = ObjectDictionary(_projectRefKeys, this);
              for (final mapEntry in entry.entries) {
                final k = mapEntry.key as String;
                final v = mapEntry.value;
                // Skip keys not in the schema — matches Ruby's lenient behavior
                // for unknown keys added by newer Xcode versions (CR-04).
                if (!_projectRefKeys.containsKey(k)) continue;
                if (v is String) {
                  final obj = objectWithUuid(v, objectsByUuidPlist);
                  if (obj != null) dict[k] = obj;
                }
              }
              projectReferences.add(dict);
            }
          }
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_mainGroup, obj)) mainGroup = null;
    if (identical(_productRefGroup, obj)) productRefGroup = null;
    if (identical(_buildConfigurationList, obj)) buildConfigurationList = null;
    if (obj is AbstractTarget) targets.remove(obj);
    // super.removeReference is intentionally omitted — AbstractObject.removeReference
    // is a no-op base implementation. Subclasses of PBXProject (none currently)
    // should call super explicitly if added.
    packageReferences.remove(obj);
    // Propagate to every ObjectDictionary entry in projectReferences so that
    // stale UUID references are cleaned when an object is removed from the project.
    for (final dict in projectReferences) {
      dict.removeReference(obj);
    }
  }

  // ---------------------------------------------------------------------------
  // : sort cascade
  // ---------------------------------------------------------------------------

  /// Recursively sorts the project hierarchy starting from [mainGroup].
  /// Delegates to [PBXGroup.sortRecursively] for the main group tree.
  /// Targets are intentionally not sorted — build phase order matters for builds.
  /// Port of Ruby `root_object.sort_recursively` which calls
  /// `main_group.sort_recursively`.
  void sortRecursively({GroupsPosition? groupsPosition}) {
    mainGroup?.sortRecursively(groupsPosition: groupsPosition);
  }

  @override
  void clearRelationships() {
    mainGroup = null;
    productRefGroup = null;
    buildConfigurationList = null;
    targets.clear();
    packageReferences.clear();
    projectReferences.clear();
  }
}
