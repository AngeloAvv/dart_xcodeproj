import 'package:path/path.dart' as p;

import '../object/abstract_object.dart';
import 'pbx_build_file.dart';
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
/// - [removeFromProject] also removes the proxy's [buildFiles], and with them
///   the [remoteRef] once nothing else refers to it.
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
  List<String> get referenceAttributes => const [_kRemoteRef];

  @override
  String get displayName => name ?? path ?? super.displayName;

  /// ` $name ` or ` basename(path) `, so a proxy for `Sub/Foo.framework` is
  /// annotated `Foo.framework`; blank (`'  '`) when it has neither, as Ruby.
  /// Port of `PBXReferenceProxy#ascii_plist_annotation`.
  @override
  String get asciiPlistAnnotation =>
      ' ${name ?? (path != null ? p.basename(path!) : '')} ';

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
  List<ToOneAttribute> get toOneAttributes => [
    ToOneAttribute(
      get: () => remoteRef,
      set: (v) => remoteRef = v as PBXContainerItemProxy?,
    ),
  ];

  /// The build files associated with this reference proxy.
  /// Port of `build_files` (`referrers.grep(PBXBuildFile)`).
  List<PBXBuildFile> get buildFiles =>
      referrers.whereType<PBXBuildFile>().toList();

  /// In addition to removing the reference proxy, removes every item related
  /// to it: its [buildFiles] (which also drops them from their build phases)
  /// and, through the usual reference counting, its [remoteRef] when this
  /// proxy was its last referrer.
  /// Port of `remove_from_project`.
  @override
  void removeFromProject() {
    // Iterate over a snapshot: removing a build file mutates the referrers.
    for (final buildFile in buildFiles) {
      buildFile.removeFromProject();
    }
    super.removeFromProject();
  }

  @override
  void clearRelationships() {
    remoteRef = null;
  }
}
