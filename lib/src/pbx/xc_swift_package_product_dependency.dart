import '../object/abstract_object.dart';

/// Represents a Swift package product dependency on a native target.
/// Port of [XCSwiftPackageProductDependency].
/// [package] is typed [AbstractObject?] because it accepts either
/// [XCRemoteSwiftPackageReference] or [XCLocalSwiftPackageReference] (same
/// pattern as PBXBuildFile.fileRef — decision).
class XCSwiftPackageProductDependency extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'XCSwiftPackageProductDependency';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kPackage = 'package';
  static const String _kProductName = 'productName';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [_kPackage, _kProductName];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Has-one relationship to the package reference (remote or local).
  /// Typed as [AbstractObject?] to accept both [XCRemoteSwiftPackageReference]
  /// and [XCLocalSwiftPackageReference] without forward-reference ordering issues.
  AbstractObject? _package;

  AbstractObject? get package => _package;

  set package(AbstractObject? value) {
    if (identical(_package, value)) return;
    markProjectAsDirty();
    _package?.removeReferrer(this);
    _package = value;
    value?.addReferrer(this);
  }

  /// The product name as defined by the Swift package manifest.
  String? productName;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCSwiftPackageProductDependency(super.project, super.uuid);

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
      case _kPackage:
        if (_package != null) into[_kPackage] = _package!.uuid;
      case _kProductName:
        if (productName != null) into[_kProductName] = productName;
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
      case _kPackage:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj != null) package = obj;
        }
      case _kProductName:
        if (value is String) productName = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_package, obj)) package = null;
  }

  @override
  void clearRelationships() {
    package = null;
  }
}
