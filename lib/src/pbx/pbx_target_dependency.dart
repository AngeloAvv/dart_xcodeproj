import '../object/abstract_object.dart';
import 'pbx_container_item_proxy.dart';
import 'pbx_native_target.dart' show AbstractTarget;

/// Represents a dependency between two Xcode targets.
/// Port of [PBXTargetDependency].
/// Key contracts:
/// - [target] is ref-counted (has_one pattern); typed as [AbstractObject?] in
/// — will narrow to `AbstractTarget?` once that class exists.
/// - [targetProxy] is ref-counted (has_one pattern); typed as [PBXContainerItemProxy?].
/// - [toTreeHash] overrides the base to prevent infinite recursion: it does NOT
/// recurse into [target] (targets can be mutually dependent). It DOES recurse
/// into [targetProxy].
/// - [clearRelationships] nulls both [target] and [targetProxy].
/// - [removeReference] clears whichever field matches [obj].
class PBXTargetDependency extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXTargetDependency';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kPlatformFilter = 'platformFilter';
  static const String _kPlatformFilters = 'platformFilters';
  static const String _kTarget = 'target';
  static const String _kTargetProxy = 'targetProxy';

  /// Declared attribute order — subclass before superclass.
  /// Matches Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kName,
    _kPlatformFilter,
    _kPlatformFilters,
    _kTarget,
    _kTargetProxy,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Human-readable name of the dependency (usually the target's name).
  String? name;

  /// Platform filter string (e.g., 'ios', 'maccatalyst').
  String? platformFilter;

  /// Multiple platform filters.
  List<String>? platformFilters;

  /// The target this dependency points to.
  /// Typed narrowed from [AbstractObject?] to [AbstractTarget?] in ,
  /// now that [AbstractTarget] exists. Ref-counted via setter.
  AbstractTarget? _target;
  AbstractTarget? get target => _target;
  set target(AbstractTarget? value) {
    if (identical(_target, value)) return;
    markProjectAsDirty();
    _target?.removeReferrer(this);
    _target = value;
    value?.addReferrer(this);
  }

  /// The container item proxy for this dependency.
  /// Ref-counted via setter.
  PBXContainerItemProxy? _targetProxy;
  PBXContainerItemProxy? get targetProxy => _targetProxy;
  set targetProxy(PBXContainerItemProxy? value) {
    if (identical(_targetProxy, value)) return;
    markProjectAsDirty();
    _targetProxy?.removeReferrer(this);
    _targetProxy = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXTargetDependency(super.project, super.uuid);

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
  String get displayName => name ?? _target?.displayName ?? super.displayName;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kPlatformFilter:
        if (platformFilter != null) into[_kPlatformFilter] = platformFilter;
      case _kPlatformFilters:
        if (platformFilters != null) into[_kPlatformFilters] = platformFilters;
      case _kTarget:
        if (_target != null) into[_kTarget] = _target!.uuid;
      case _kTargetProxy:
        if (_targetProxy != null) into[_kTargetProxy] = _targetProxy!.uuid;
    }
  }

  /// Override [toTreeHash] to prevent infinite recursion on cyclic target dependencies.
  /// Per#to_tree_hash (lines 76-88): include [displayName] + [isa]
  /// + [targetProxy] subtree; DO NOT recurse into [target].
  /// Port of.
  @override
  Map<String, dynamic> toTreeHash([Set<String>? visited]) {
    final v = visited ?? <String>{};
    final hash = <String, dynamic>{'displayName': displayName, 'isa': isa};
    if (_targetProxy != null && !v.contains(_targetProxy!.uuid)) {
      hash['targetProxy'] = _targetProxy!.toTreeHash(v);
    }
    return hash;
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
      case _kPlatformFilter:
        if (value is String) platformFilter = value;
      case _kPlatformFilters:
        if (value is List) platformFilters = value.cast<String>().toList();
      case _kTarget:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is AbstractTarget) target = obj;
        }
      case _kTargetProxy:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is PBXContainerItemProxy) targetProxy = obj;
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_target, obj)) target = null;
    if (identical(_targetProxy, obj)) targetProxy = null;
  }

  @override
  void clearRelationships() {
    target = null;
    targetProxy = null;
  }
}
