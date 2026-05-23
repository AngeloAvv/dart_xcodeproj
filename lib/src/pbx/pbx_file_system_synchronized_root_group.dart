import '../object/abstract_object.dart';
import '../object/object_list.dart';

/// Represents an Xcode 15+ file-system-synchronized root group.
/// Port of [PBXFileSystemSynchronizedRootGroup].
/// [exceptions] is an [ObjectList<AbstractObject>] of exception-set objects.
/// It always serializes (even when empty) unlike the PBXProject omit-when-empty rule.
class PBXFileSystemSynchronizedRootGroup extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXFileSystemSynchronizedRootGroup';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------

  static const String _kPath = 'path';
  static const String _kSourceTree = 'sourceTree';
  static const String _kName = 'name';
  static const String _kExplicitFileType = 'explicitFileType';
  static const String _kExceptions = 'exceptions';
  static const String _kExplicitFolders = 'explicitFolders';
  static const String _kExplicitFolderEntries = 'explicitFolderEntries';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kPath,
    _kSourceTree,
    _kName,
    _kExplicitFileType,
    _kExceptions,
    _kExplicitFolders,
    _kExplicitFolderEntries,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Path to the file-system-synchronized folder.
  String? path;

  /// Source tree anchor. Defaults to `'<group>'`.
  String sourceTree = '<group>';

  /// Optional display name override.
  String? name;

  /// Optional explicit file type override.
  String? explicitFileType;

  /// Optional list of explicitly tracked folder names.
  List<String>? explicitFolders;

  /// Optional list of explicitly tracked folder entry names.
  List<String>? explicitFolderEntries;

  /// Ref-counted list of exception-set objects.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  /// Do NOT reinitialize in [initializeDefaults].
  /// Port of `has_many :exceptions`.
  late final ObjectList<AbstractObject> exceptions = ObjectList<AbstractObject>(
    this,
  );

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXFileSystemSynchronizedRootGroup(super.project, super.uuid);

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
  void initializeDefaults() {
    sourceTree = '<group>';
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kPath:
        if (path != null) into[_kPath] = path;
      case _kSourceTree:
        into[_kSourceTree] = sourceTree;
      case _kName:
        if (name != null) into[_kName] = name;
      case _kExplicitFileType:
        if (explicitFileType != null)
          into[_kExplicitFileType] = explicitFileType;
      case _kExceptions:
        // Always emit — even when empty (differs from PBXProject empty-array omission).
        into[_kExceptions] = exceptions.uuids.toList();
      case _kExplicitFolders:
        if (explicitFolders != null) into[_kExplicitFolders] = explicitFolders;
      case _kExplicitFolderEntries:
        if (explicitFolderEntries != null) {
          into[_kExplicitFolderEntries] = explicitFolderEntries;
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
      case _kPath:
        if (value is String) path = value;
      case _kSourceTree:
        if (value is String) sourceTree = value;
      case _kName:
        if (value is String) name = value;
      case _kExplicitFileType:
        if (value is String) explicitFileType = value;
      case _kExceptions:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj != null) exceptions.add(obj);
          }
        }
      case _kExplicitFolders:
        if (value is List) explicitFolders = value.cast<String>();
      case _kExplicitFolderEntries:
        if (value is List) explicitFolderEntries = value.cast<String>();
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void removeReference(AbstractObject obj) {
    exceptions.remove(obj);
  }

  @override
  void clearRelationships() {
    exceptions.clear();
  }
}
