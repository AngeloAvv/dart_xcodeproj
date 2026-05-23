import '../object/abstract_object.dart';
import 'pbx_build_phase.dart' show AbstractBuildPhase;
import 'pbx_native_target.dart' show AbstractTarget;

// =============================================================================
// PBXFileSystemSynchronizedBuildFileExceptionSet
// =============================================================================

/// Exception set for file-system-synchronized groups — specifies which files
/// have non-default build file settings for a particular target.
/// Port of [PBXFileSystemSynchronizedBuildFileExceptionSet]
class PBXFileSystemSynchronizedBuildFileExceptionSet extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic =
      'PBXFileSystemSynchronizedBuildFileExceptionSet';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kTarget = 'target';
  static const String _kMembershipExceptions = 'membershipExceptions';
  static const String _kPublicHeaders = 'publicHeaders';
  static const String _kPrivateHeaders = 'privateHeaders';
  static const String _kAttributesByRelativePath = 'attributesByRelativePath';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kTarget,
    _kMembershipExceptions,
    _kPublicHeaders,
    _kPrivateHeaders,
    _kAttributesByRelativePath,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Excluded/exception file paths relative to the synchronized group.
  List<String>? membershipExceptions;

  /// Public header paths.
  List<String>? publicHeaders;

  /// Private header paths.
  List<String>? privateHeaders;

  /// Build attributes indexed by relative path.
  Map<String, dynamic>? attributesByRelativePath;

  /// Has-one relationship to the target this exception applies to.
  AbstractTarget? _target;

  AbstractTarget? get target => _target;

  set target(AbstractTarget? value) {
    if (identical(_target, value)) return;
    markProjectAsDirty();
    _target?.removeReferrer(this);
    _target = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXFileSystemSynchronizedBuildFileExceptionSet(super.project, super.uuid);

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
      case _kTarget:
        if (_target != null) into[_kTarget] = _target!.uuid;
      case _kMembershipExceptions:
        if (membershipExceptions != null) {
          into[_kMembershipExceptions] = membershipExceptions;
        }
      case _kPublicHeaders:
        if (publicHeaders != null) into[_kPublicHeaders] = publicHeaders;
      case _kPrivateHeaders:
        if (privateHeaders != null) into[_kPrivateHeaders] = privateHeaders;
      case _kAttributesByRelativePath:
        if (attributesByRelativePath != null) {
          into[_kAttributesByRelativePath] = attributesByRelativePath;
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
      case _kTarget:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is AbstractTarget) target = obj;
        }
      case _kMembershipExceptions:
        if (value is List) membershipExceptions = value.cast<String>();
      case _kPublicHeaders:
        if (value is List) publicHeaders = value.cast<String>();
      case _kPrivateHeaders:
        if (value is List) privateHeaders = value.cast<String>();
      case _kAttributesByRelativePath:
        if (value is Map) {
          attributesByRelativePath = Map<String, dynamic>.from(value);
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_target, obj)) target = null;
  }

  @override
  void clearRelationships() {
    target = null;
  }
}

// =============================================================================
// PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
// =============================================================================

/// Exception set specifying which files are excluded from a specific build phase
/// within a file-system-synchronized group.
/// Port of [PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet]
class PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
    extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic =
      'PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kBuildPhase = 'buildPhase';
  static const String _kMembershipExceptions = 'membershipExceptions';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kBuildPhase,
    _kMembershipExceptions,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Excluded/exception file paths relative to the synchronized group.
  List<String>? membershipExceptions;

  /// Has-one relationship to the build phase this exception applies to.
  AbstractBuildPhase? _buildPhase;

  AbstractBuildPhase? get buildPhase => _buildPhase;

  set buildPhase(AbstractBuildPhase? value) {
    if (identical(_buildPhase, value)) return;
    markProjectAsDirty();
    _buildPhase?.removeReferrer(this);
    _buildPhase = value;
    value?.addReferrer(this);
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet(
    super.project,
    super.uuid,
  );

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
      case _kBuildPhase:
        if (_buildPhase != null) into[_kBuildPhase] = _buildPhase!.uuid;
      case _kMembershipExceptions:
        if (membershipExceptions != null) {
          into[_kMembershipExceptions] = membershipExceptions;
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
      case _kBuildPhase:
        if (value is String) {
          final obj = objectWithUuid(value, objectsByUuidPlist);
          if (obj is AbstractBuildPhase) buildPhase = obj;
        }
      case _kMembershipExceptions:
        if (value is List) membershipExceptions = value.cast<String>();
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    if (identical(_buildPhase, obj)) buildPhase = null;
  }

  @override
  void clearRelationships() {
    buildPhase = null;
  }
}
