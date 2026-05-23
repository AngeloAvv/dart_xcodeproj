// buildConfigurations), operator[], ascii_plist_annotation]

import '../object/abstract_object.dart';
import '../object/object_list.dart';
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
  /// When [resolveAgainstXcconfig] is false, looks up [key] in each config's
  /// [XCBuildConfiguration.buildSettings] directly. When true, calls
  /// [XCBuildConfiguration.resolveBuildSetting] (xcconfig support).
  /// [rootTarget] is forwarded to [resolveBuildSetting] when resolving.
  Map<String, String?> getSetting(
    String key,
    bool resolveAgainstXcconfig, [
    dynamic rootTarget,
  ]) {
    final result = <String, String?>{};
    for (final bc in buildConfigurations) {
      result[bc.name ?? ''] = resolveAgainstXcconfig
          ? bc.resolveBuildSetting(key) as String?
          : bc.buildSettings[key] as String?;
    }
    return result;
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

  /// Called by [removeFromProject] on each referrer that holds a field pointing
  /// to [obj]. Removes [obj] from [buildConfigurations] if it is a member.
  @override
  void removeReference(AbstractObject obj) {
    if (obj is XCBuildConfiguration) buildConfigurations.remove(obj);
  }

  @override
  void clearRelationships() {
    buildConfigurations.clear();
  }
}
