import '../object/abstract_object.dart';

/// Represents a container item proxy used for cross-project target references.
/// Port of [PBXContainerItemProxy].
/// All four attributes are `:simple` strings — [containerPortal] is a UUID string,
/// NOT a has_one ref-counted relationship.
/// Key contracts:
/// - [containerPortal] is a plain String UUID (no ref counting).
/// - [remoteGlobalIDString] uses exact plist key `remoteGlobalIDString` (capital ID)
/// CaseConverter exception ( / from ).
/// - No [clearRelationships] or [removeReference] override needed — all fields are Strings.
class PBXContainerItemProxy extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXContainerItemProxy';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kContainerPortal = 'containerPortal';
  static const String _kProxyType = 'proxyType';

  /// Exact plist key — CaseConverter exception: capital 'ID' (not 'Id').
  /// Port of: `attribute :remoteGlobalIDString`.
  static const String _kRemoteGlobalIDString = 'remoteGlobalIDString';
  static const String _kRemoteInfo = 'remoteInfo';

  /// Declared attribute order — subclass before superclass.
  /// Matches Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kContainerPortal,
    _kProxyType,
    _kRemoteGlobalIDString,
    _kRemoteInfo,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields — all plain Strings (no ref counting)
  // ---------------------------------------------------------------------------

  /// UUID of the project that contains the referenced object.
  /// Plain String UUID — NOT a has_one. Cross-project references use UUID strings
  /// to avoid ref-count cycles with possibly-external objects.
  String? containerPortal;

  /// Proxy type: '1' = native_target, '2' = reference.
  String? proxyType;

  /// UUID of the referenced object in the remote container.
  /// Note: plist key is `remoteGlobalIDString` (capital ID) — CaseConverter exception.
  String? remoteGlobalIDString;

  /// Human-readable name of the referenced target.
  String? remoteInfo;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXContainerItemProxy(super.project, super.uuid);

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
      case _kContainerPortal:
        if (containerPortal != null) into[_kContainerPortal] = containerPortal;
      case _kProxyType:
        if (proxyType != null) into[_kProxyType] = proxyType;
      case _kRemoteGlobalIDString:
        if (remoteGlobalIDString != null) {
          into[_kRemoteGlobalIDString] = remoteGlobalIDString;
        }
      case _kRemoteInfo:
        if (remoteInfo != null) into[_kRemoteInfo] = remoteInfo;
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
      case _kContainerPortal:
        if (value is String) containerPortal = value;
      case _kProxyType:
        if (value is String) proxyType = value;
      case _kRemoteGlobalIDString:
        if (value is String) remoteGlobalIDString = value;
      case _kRemoteInfo:
        if (value is String) remoteInfo = value;
    }
  }

  // NO clearRelationships override needed — all fields are plain Strings.
  // NO removeReference override needed.
}
