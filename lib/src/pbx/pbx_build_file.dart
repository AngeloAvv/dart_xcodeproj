import '../object/abstract_object.dart';

/// Represents a file included in a build phase.
/// Port of [PBXBuildFile]. A [PBXBuildFile] is always a member
/// of a build phase and points to a [PBXFileReference] (or other file-like
/// object) via [fileRef].
/// Key contracts:
/// - [fileRef] and [productRef] are ref-counted (`AbstractObject?` — not typed
/// to a specific subclass so types can be stored without breakage).
/// - [settings] is a plain `Map<String, dynamic>` — NOT ref-counted.
/// - [settings] is serialized only when non-null AND non-empty.
/// - [asciiPlistAnnotation] scans [_referrers] for a parent phase ( stub).
class PBXBuildFile extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXBuildFile';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kSettings = 'settings';
  static const String _kFileRef = 'fileRef';
  static const String _kProductRef = 'productRef';
  static const String _kPlatformFilter = 'platformFilter';
  static const String _kPlatformFilters = 'platformFilters';

  /// Declared attribute order — subclass before superclass.
  /// Matches Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kSettings,
    _kFileRef,
    _kProductRef,
    _kPlatformFilter,
    _kPlatformFilters,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Compiler flags and other per-file build settings.
  /// This is a PLAIN map — NOT an ObjectDictionary. Values are typically
  /// `{'ATTRIBUTES': ['Public']}` (string arrays, not object refs).
  /// Serialized only when non-null AND non-empty.
  Map<String, dynamic>? settings;

  /// The file this build-file entry refers to.
  /// Declared as `AbstractObject?` (not `PBXFileReference?`) so types
  /// (`PBXGroup`, `PBXVariantGroup`, `PBXReferenceProxy`, etc.) can be stored
  /// without a breaking change. Ref-counted via setter.
  AbstractObject? _fileRef;
  AbstractObject? get fileRef => _fileRef;
  set fileRef(AbstractObject? value) {
    if (identical(_fileRef, value)) return;
    markProjectAsDirty();
    _fileRef?.removeReferrer(this);
    _fileRef = value;
    value?.addReferrer(this);
  }

  /// Swift Package product dependency reference (Xcode 11+, optional).
  /// Declared as `AbstractObject?` for forward-compat.
  /// Ref-counted via setter.
  AbstractObject? _productRef;
  AbstractObject? get productRef => _productRef;
  set productRef(AbstractObject? value) {
    if (identical(_productRef, value)) return;
    markProjectAsDirty();
    _productRef?.removeReferrer(this);
    _productRef = value;
    value?.addReferrer(this);
  }

  /// Platform filter string (e.g., 'ios') for conditional build membership (Xcode 12+).
  String? platformFilter;

  /// Multiple platform filters (e.g., ['ios', 'maccatalyst']).
  List<String>? platformFilters;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXBuildFile(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  /// Subclass attributes first, then superclass (always empty for AbstractObject).
  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  /// Inline annotation for the ASCII plist writer.
  /// When the build file has been added to a build phase (referrer present),
  /// returns `' $displayName in ${phase.displayName} '`.
  /// Otherwise returns `' $displayName '`.
  /// scans [_referrers] for any `AbstractObject` as the parent phase.
  /// GroupableHelper wiring is deferred.
  /// Port of.
  @override
  String get asciiPlistAnnotation {
    final phase = referrers.whereType<AbstractObject>().firstOrNull;
    if (phase != null) {
      return ' $displayName in ${phase.displayName} ';
    }
    return ' $displayName ';
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kSettings:
        // Emit only when non-null AND non-empty
        if (settings != null && settings!.isNotEmpty) {
          into[_kSettings] = settings;
        }
      case _kFileRef:
        if (_fileRef != null) into[_kFileRef] = _fileRef!.uuid;
      case _kProductRef:
        if (_productRef != null) into[_kProductRef] = _productRef!.uuid;
      case _kPlatformFilter:
        if (platformFilter != null) into[_kPlatformFilter] = platformFilter;
      case _kPlatformFilters:
        if (platformFilters != null) into[_kPlatformFilters] = platformFilters;
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kSettings:
        // plain map — same as serialize
        if (settings != null && settings!.isNotEmpty) {
          into[_kSettings] = settings;
        }
      case _kFileRef:
        if (_fileRef != null) {
          if (visited.contains(_fileRef!.uuid)) {
            into[_kFileRef] = '<cycle: ${_fileRef!.uuid}>';
          } else {
            into[_kFileRef] = _fileRef!.toTreeHash(visited);
          }
        }
      case _kProductRef:
        if (_productRef != null) {
          if (visited.contains(_productRef!.uuid)) {
            into[_kProductRef] = '<cycle: ${_productRef!.uuid}>';
          } else {
            into[_kProductRef] = _productRef!.toTreeHash(visited);
          }
        }
      case _kPlatformFilter:
        if (platformFilter != null) into[_kPlatformFilter] = platformFilter;
      case _kPlatformFilters:
        if (platformFilters != null) into[_kPlatformFilters] = platformFilters;
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
      case _kSettings:
        if (value is Map) settings = value.cast<String, dynamic>();
      case _kFileRef:
        if (value is String) {
          final ref = objectWithUuid(value, objectsByUuidPlist);
          if (ref != null) fileRef = ref;
        }
      case _kProductRef:
        if (value is String) {
          final ref = objectWithUuid(value, objectsByUuidPlist);
          if (ref != null) productRef = ref;
        }
      case _kPlatformFilter:
        platformFilter = value is String ? value : null;
      case _kPlatformFilters:
        if (value is List) platformFilters = value.cast<String>().toList();
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  /// Called by [removeFromProject] on each referrer that holds a field pointing
  /// to [obj]. Removes ref-count before nulling [_fileRef] or [_productRef].
  @override
  void removeReference(AbstractObject obj) {
    if (identical(_fileRef, obj)) {
      _fileRef!.removeReferrer(this);
      _fileRef = null;
    }
    if (identical(_productRef, obj)) {
      _productRef!.removeReferrer(this);
      _productRef = null;
    }
  }

  /// Called by [removeFromProject] on this object to clear all outgoing
  /// references. Calls [removeReferrer] to properly decrement ref counts.
  @override
  void clearRelationships() {
    if (_fileRef != null) {
      _fileRef!.removeReferrer(this);
      _fileRef = null;
    }
    if (_productRef != null) {
      _productRef!.removeReferrer(this);
      _productRef = null;
    }
  }
}
