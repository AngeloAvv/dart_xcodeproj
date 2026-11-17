// buildConfigurations), operator[], ascii_plist_annotation]

import '../object/abstract_object.dart';
import '../object/object_list.dart';
import 'pbx_native_target.dart';
import 'pbx_project.dart';
import 'xc_build_configuration.dart';

/// Maintains a collection of related build configurations for a project or target.
/// Port of [XCConfigurationList]. Holds 3 attributes:
/// - [defaultConfigurationIsVisible] — usually `'0'`
/// - [defaultConfigurationName] — usually `'Release'`
/// - [buildConfigurations] — ref-counted [ObjectList] of [XCBuildConfiguration]
/// [operator[]] provides lookup by configuration name (returns null when not found).
class XCConfigurationList extends AbstractObject {
  // ---------------------------------------------------------------------------
  // ISA
  // ---------------------------------------------------------------------------

  static const String isaStatic = 'XCConfigurationList';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kDefaultConfigurationIsVisible =
      'defaultConfigurationIsVisible';
  static const String _kDefaultConfigurationName = 'defaultConfigurationName';
  static const String _kBuildConfigurations = 'buildConfigurations';

  /// Own attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kDefaultConfigurationIsVisible,
    _kDefaultConfigurationName,
    _kBuildConfigurations,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Whether the default configuration is visible. Usually `'0'`.
  /// Port of `attribute :default_configuration_is_visible, String, '0'`
  String defaultConfigurationIsVisible = '0';

  /// The name of the default configuration. Usually `'Release'`.
  /// Port of `attribute :default_configuration_name, String, 'Release'`
  String defaultConfigurationName = 'Release';

  /// Ref-counted collection of build configurations.
  /// Port of `has_many :build_configurations, XCBuildConfiguration`
  ///. Uses `late final` so the field
  /// initializer runs exactly once per instance.
  late final ObjectList<XCBuildConfiguration> buildConfigurations =
      ObjectList<XCBuildConfiguration>(this);

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCConfigurationList(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  void initializeDefaults() {
    defaultConfigurationIsVisible = '0';
    defaultConfigurationName = 'Release';
    // buildConfigurations is late final — already initialized via field initializer.
  }

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  @override
  List<String> get referenceAttributes => const [_kBuildConfigurations];

  /// The project or target that owns this list, or `null` if none does.
  /// Port of `XCConfigurationList#target`.
  AbstractObject? get target => referrers
      .whereType<AbstractObject>()
      .where((r) => r is PBXProject || r is AbstractTarget)
      .firstOrNull;

  /// `' Build configuration list for <isa> "<name>" '`, naming the owning
  /// project or target; `<deleted target>` if there is none.
  /// Port of `XCConfigurationList#ascii_plist_annotation`.
  @override
  String get asciiPlistAnnotation {
    final owner = target;
    final name = switch (owner) {
      PBXProject() => owner.name,
      AbstractTarget() => owner.displayName,
      _ => null,
    };
    if (owner == null) {
      return ' Build configuration list for <deleted target> ';
    }
    return ' Build configuration list for ${owner.isa} "$name" ';
  }

  // ---------------------------------------------------------------------------
  // Lookup helper
  // ---------------------------------------------------------------------------

  /// Returns the [XCBuildConfiguration] with the given [configName], or null.
  /// Port of:
  /// `def [](name) build_configurations.find { |bc| bc.name == name }`
  /// Uses explicit loop — no package:collection dependency (per architecture constraints).
  XCBuildConfiguration? operator [](String configName) {
    for (final bc in buildConfigurations) {
      if (bc.name == configName) return bc;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Build setting lookup
  // ---------------------------------------------------------------------------

  /// Returns a Map of configName → raw (or resolved) buildSettings value for [key].
  /// Each value is returned unchanged: a [String] for scalar settings, a
  /// `List<dynamic>` for array settings (e.g. `LD_RUNPATH_SEARCH_PATHS`,
  /// `OTHER_LDFLAGS`), or `null` when the key is not set.
  /// When [resolveAgainstXcconfig] is false, looks up [key] in each config's
  /// [XCBuildConfiguration.buildSettings] directly. When true, calls
  /// [XCBuildConfiguration.resolveBuildSetting] (xcconfig support).
  /// [rootTarget] is forwarded to [resolveBuildSetting] when resolving.
  /// Port of `#get_setting`.
  Map<String, dynamic> getSetting(
    String key,
    bool resolveAgainstXcconfig, [
    dynamic rootTarget,
  ]) {
    final result = <String, dynamic>{};
    for (final bc in buildConfigurations) {
      result[bc.name ?? ''] = resolveAgainstXcconfig
          ? bc.resolveBuildSetting(key)
          : bc.buildSettings[key];
    }
    return result;
  }

  /// Sets the build setting [key] to [value] in every configuration of the
  /// list and leaves their other settings untouched. [value] is a [String] for
  /// scalar settings or a `List<dynamic>` for array settings; the very same
  /// instance is stored in each configuration, like Ruby does.
  /// Port of `#set_setting`.
  void setSetting(String key, dynamic value) {
    for (final bc in buildConfigurations) {
      bc.buildSettings[key] = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kDefaultConfigurationIsVisible:
        into[_kDefaultConfigurationIsVisible] = defaultConfigurationIsVisible;
      case _kDefaultConfigurationName:
        into[_kDefaultConfigurationName] = defaultConfigurationName;
      case _kBuildConfigurations:
        // Always emit — even when empty (to-many invariant).
        into[_kBuildConfigurations] = buildConfigurations.uuids;
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kBuildConfigurations:
        // Expand each config inline; cycle guard uses visited set.
        into[_kBuildConfigurations] = buildConfigurations
            .map(
              (bc) => visited.contains(bc.uuid)
                  ? '<cycle: ${bc.uuid}>'
                  : bc.toTreeHash(visited),
            )
            .toList();
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
      case _kDefaultConfigurationIsVisible:
        if (value is String) defaultConfigurationIsVisible = value;
      case _kDefaultConfigurationName:
        if (value is String) defaultConfigurationName = value;
      case _kBuildConfigurations:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj is XCBuildConfiguration) buildConfigurations.add(obj);
          }
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  List<ObjectList<Object>> get toManyAttributes => [buildConfigurations];

  @override
  List<String> get toManyAttributeKeys => const [_kBuildConfigurations];

  @override
  void clearRelationships() {
    buildConfigurations.clear();
  }
}
