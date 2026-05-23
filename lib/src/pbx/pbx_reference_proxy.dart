import '../object/abstract_object.dart';
import 'pbx_container_item_proxy.dart';

/// Represents a proxy for a file reference in a sub-project.
/// Port of [PBXReferenceProxy]. Used for cross-project
/// file references, where a file in an external project is referenced via
/// a [PBXContainerItemProxy].
/// Key contracts:
/// - [path], [fileType], [sourceTree], [name] are plain String attributes (no ref counting).
/// - [remoteRef] is ref-counted (has_one pattern → [PBXContainerItemProxy]).
/// - [clearRelationships] nulls [remoteRef].
/// - [removeReference] clears [remoteRef] if it matches [obj].
class PBXReferenceProxy extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXReferenceProxy';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kPath = 'path';
  static const String _kFileType = 'fileType';
  static const String _kSourceTree = 'sourceTree';
  static const String _kRemoteRef = 'remoteRef';
  static const String _kName = 'name';

  /// Declared attribute order — subclass before superclass.
  /// Matches Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kPath,
    _kFileType,
    _kSourceTree,
    _kRemoteRef,
    _kName,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Relative path to the referenced file.
  String? path;

  /// UTI-style file type (e.g., `wrapper.framework`, `archive.ar`).
  String? fileType;

  /// Source tree anchor (e.g., `BUILT_PRODUCTS_DIR`, `<group>`).
  String? sourceTree;

  /// Human-readable name (optional, used when path is not descriptive enough).
  String? name;

  /// The container item proxy pointing to the external project reference.
  /// Ref-counted via setter.
  PBXContainerItemProxy? _remoteRef;
  PBXContainerItemProxy? get remoteRef => _remoteRef;
  set remoteRef(PBXContainerItemProxy? value) {
    if (identical(_remoteRef, value)) return;
    markProjectAsDirty();
    _remoteRef?.removeReferrer(this);
    _remoteRef = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXReferenceProxy(super.project, super.uuid);

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
  String get displayName => name ?? path ?? super.displayName;

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kPath:
        if (path != null) into[_kPath] = path;
      case _kFileType:
        if (fileType != null) into[_kFileType] = fileType;
      case _kSourceTree:
        if (sourceTree != null) into[_kSourceTree] = sourceTree;
      case _kRemoteRef:
        if (_remoteRef != null) into[_kRemoteRef] = _remoteRef!.uuid;
      case _kName:
        if (name != null) into[_kName] = name;
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
      case _kPath:
        if (value is String) path = value;
      case _kFileType:
        if (value is String) fileType = value;
      case _kSourceTree:
        if (value is String) sourceTree = value;
      case _kRemoteRef:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is PBXContainerItemProxy) remoteRef = obj;
        }
      case _kName:
        if (value is String) name = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_remoteRef, obj)) remoteRef = null;
  }

  @override
  void clearRelationships() {
    remoteRef = null;
  }
}
