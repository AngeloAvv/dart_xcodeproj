// Ruby sources:

import '../object/abstract_object.dart';

// =============================================================================
// XCRemoteSwiftPackageReference
// =============================================================================

/// Represents a remote Swift package reference (SPM).
/// Port of [XCRemoteSwiftPackageReference].
/// The plist key is `'repositoryURL'` — capital URL. This is already
/// camelCase in the Ruby source symbol (`:repositoryURL`). Do NOT run CaseConverter
/// on it. Use the literal string constant [_kRepositoryURL] directly.
class XCRemoteSwiftPackageReference extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'XCRemoteSwiftPackageReference';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  /// 'repositoryURL' is already camelCase with capital URL.
  /// Use the literal string — DO NOT run CaseConverter on this key.
  static const String _kRepositoryURL = 'repositoryURL';
  static const String _kRequirement = 'requirement';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [_kRepositoryURL, _kRequirement];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// The repository URL for the remote package.
  String? repositoryURL;

  /// Version requirement map, e.g., {'kind': 'upToNextMajorVersion', 'minimumVersion': '1.0.0'}.
  /// Port of Ruby Hash attribute.
  Map<String, dynamic>? requirement;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCRemoteSwiftPackageReference(super.project, super.uuid);

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
      case _kRepositoryURL:
        if (repositoryURL != null) into[_kRepositoryURL] = repositoryURL;
      case _kRequirement:
        if (requirement != null) into[_kRequirement] = requirement;
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
      case _kRepositoryURL:
        if (value is String) repositoryURL = value;
      case _kRequirement:
        if (value is Map) requirement = Map<String, dynamic>.from(value);
    }
  }
}

// =============================================================================
// XCLocalSwiftPackageReference
// =============================================================================

/// Represents a local Swift package reference (SPM).
/// Port of [XCLocalSwiftPackageReference].
class XCLocalSwiftPackageReference extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'XCLocalSwiftPackageReference';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kRelativePath = 'relativePath';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [_kRelativePath];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// The relative path to the local package from the project root.
  String? relativePath;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCLocalSwiftPackageReference(super.project, super.uuid);

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
    if (key == _kRelativePath && relativePath != null) {
      into[_kRelativePath] = relativePath;
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
    if (key == _kRelativePath && value is String) relativePath = value;
  }
}
