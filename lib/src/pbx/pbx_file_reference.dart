import 'package:path/path.dart' as p;

import '../object/abstract_object.dart';
import '../object/object_graph.dart';

/// Represents a file on disk referenced by the Xcode project.
/// Port of [PBXFileReference]. Every file in the project
/// (source, header, resource, product, xcconfig) is represented by a
/// PBXFileReference. Holds 16 optional/required attributes describing the
/// file's path, type, and editor settings.
/// Key contract:
/// - [sourceTree] and [includeInIndex] are non-nullable with defaults.
/// - [includeInIndex] is ALWAYS serialized (even when value equals default '1').
/// - [displayName] follows: name ?? (BUILT_PRODUCTS_DIR ? path : basename(path)).
class PBXFileReference extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXFileReference';

  // ---------------------------------------------------------------------------
  // Attribute key constants — each maps 1:1 to a plist key string.
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kPath = 'path';
  static const String _kSourceTree = 'sourceTree';
  static const String _kExplicitFileType = 'explicitFileType';
  static const String _kLastKnownFileType = 'lastKnownFileType';
  static const String _kIncludeInIndex = 'includeInIndex';
  static const String _kFileEncoding = 'fileEncoding';
  static const String _kXcLanguageSpecificationIdentifier =
      'xcLanguageSpecificationIdentifier';
  static const String _kPlistStructureDefinitionIdentifier =
      'plistStructureDefinitionIdentifier';
  static const String _kUsesTabs = 'usesTabs';
  static const String _kIndentWidth = 'indentWidth';
  static const String _kTabWidth = 'tabWidth';
  static const String _kWrapsLines = 'wrapsLines';
  static const String _kLineEnding = 'lineEnding';
  static const String _kExpectedSignature = 'expectedSignature';
  static const String _kComments = 'comments';

  /// Declared attribute order for this class (subclass attributes before super).
  /// Matches the Ruby attribute declaration order.
  static const List<String> _ownAttributes = [
    _kName,
    _kPath,
    _kSourceTree,
    _kExplicitFileType,
    _kLastKnownFileType,
    _kIncludeInIndex,
    _kFileEncoding,
    _kXcLanguageSpecificationIdentifier,
    _kPlistStructureDefinitionIdentifier,
    _kUsesTabs,
    _kIndentWidth,
    _kTabWidth,
    _kWrapsLines,
    _kLineEnding,
    _kExpectedSignature,
    _kComments,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Optional display name shown in the Xcode navigator.
  String? name;

  /// Path to the file, relative to [sourceTree].
  String? path;

  /// The anchor for [path] resolution (e.g., `SOURCE_ROOT`, `<group>`, `BUILT_PRODUCTS_DIR`).
  /// Non-nullable; default is 'SOURCE_ROOT'. Always serialized.
  String sourceTree = 'SOURCE_ROOT';

  /// Explicit file type override (e.g., 'sourcecode.swift').
  String? explicitFileType;

  /// File type inferred by Xcode (e.g., 'sourcecode.swift').
  String? lastKnownFileType;

  /// Whether to include in the project's file index.
  /// Default is '1' (set in initializeDefaults for programmatically created objects).
  /// When null (e.g., for .framework product refs, or plist-loaded objects where
  /// includeInIndex was absent), omitted from the plist output.
  /// IMPORTANT: Must be null here (not '1') so that plist-loaded objects that lack
  /// includeInIndex in the original file do not emit it on save (byte-identical
  /// round-trip requirement).
  String? includeInIndex;

  /// Text encoding of the file (e.g., '4' for UTF-8).
  String? fileEncoding;

  /// Xcode language spec identifier for syntax highlighting.
  String? xcLanguageSpecificationIdentifier;

  /// Plist structure definition identifier.
  String? plistStructureDefinitionIdentifier;

  /// Whether the file uses tabs for indentation ('0' or '1').
  String? usesTabs;

  /// Editor indent width in spaces.
  String? indentWidth;

  /// Editor tab width in spaces.
  String? tabWidth;

  /// Whether the editor wraps lines ('0' or '1').
  String? wrapsLines;

  /// Line ending style (e.g., '0' for LF).
  String? lineEnding;

  /// Expected code signature for the file.
  String? expectedSignature;

  /// Arbitrary comments stored in the plist.
  String? comments;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXFileReference(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  /// Set non-nullable defaults. Called by [ObjectGraph.newObject].
  /// Port of initialization (implicit defaults on attribute macros).
  @override
  void initializeDefaults() {
    sourceTree = 'SOURCE_ROOT';
    includeInIndex = '1';
  }

  /// Subclass attributes first, then superclass (always empty for AbstractObject).
  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  /// Display name for the Xcode navigator and plist annotations.
  /// Priority:
  /// 1. [name] if non-null.
  /// 2. [path] when [sourceTree] is 'BUILT_PRODUCTS_DIR' (product references).
  /// 3. [p.basename(path)] for regular source/resource files.
  /// 4. super.displayName (ISA with prefix stripped) when [path] is null.
  /// Port of.
  @override
  String get displayName {
    if (name != null) return name!;
    if (sourceTree == 'BUILT_PRODUCTS_DIR' && path != null) return path!;
    if (path != null) return p.basename(path!);
    return super.displayName;
  }

  /// Serialize one attribute key into [into].
  /// Non-nullable attributes ([sourceTree], [includeInIndex]) are always emitted.
  /// Nullable attributes are only emitted when non-null.
  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kPath:
        if (path != null) into[_kPath] = path;
      case _kSourceTree:
        into[_kSourceTree] = sourceTree; // always present (non-nullable)
      case _kExplicitFileType:
        if (explicitFileType != null)
          into[_kExplicitFileType] = explicitFileType;
      case _kLastKnownFileType:
        if (lastKnownFileType != null)
          into[_kLastKnownFileType] = lastKnownFileType;
      case _kIncludeInIndex:
        // Emit when non-null. Ruby sets include_in_index = nil for .framework
        // product refs which causes the attribute to be omitted.
        if (includeInIndex != null) into[_kIncludeInIndex] = includeInIndex;
      case _kFileEncoding:
        if (fileEncoding != null) into[_kFileEncoding] = fileEncoding;
      case _kXcLanguageSpecificationIdentifier:
        if (xcLanguageSpecificationIdentifier != null) {
          into[_kXcLanguageSpecificationIdentifier] =
              xcLanguageSpecificationIdentifier;
        }
      case _kPlistStructureDefinitionIdentifier:
        if (plistStructureDefinitionIdentifier != null) {
          into[_kPlistStructureDefinitionIdentifier] =
              plistStructureDefinitionIdentifier;
        }
      case _kUsesTabs:
        if (usesTabs != null) into[_kUsesTabs] = usesTabs;
      case _kIndentWidth:
        if (indentWidth != null) into[_kIndentWidth] = indentWidth;
      case _kTabWidth:
        if (tabWidth != null) into[_kTabWidth] = tabWidth;
      case _kWrapsLines:
        if (wrapsLines != null) into[_kWrapsLines] = wrapsLines;
      case _kLineEnding:
        if (lineEnding != null) into[_kLineEnding] = lineEnding;
      case _kExpectedSignature:
        if (expectedSignature != null)
          into[_kExpectedSignature] = expectedSignature;
      case _kComments:
        if (comments != null) into[_kComments] = comments;
    }
  }

  /// PBXFileReference has no object references — delegate to [serializeAttribute].
  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    serializeAttribute(key, into);
  }

  /// Read one attribute from the plist during deserialization.
  /// Type-guards non-nullable fields; casts nullable fields directly.
  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kName:
        name = value is String ? value : null;
      case _kPath:
        path = value is String ? value : null;
      case _kSourceTree:
        if (value is String) sourceTree = value;
      case _kExplicitFileType:
        explicitFileType = value is String ? value : null;
      case _kLastKnownFileType:
        lastKnownFileType = value is String ? value : null;
      case _kIncludeInIndex:
        includeInIndex = value is String ? value : null;
      case _kFileEncoding:
        fileEncoding = value is String ? value : null;
      case _kXcLanguageSpecificationIdentifier:
        xcLanguageSpecificationIdentifier = value is String ? value : null;
      case _kPlistStructureDefinitionIdentifier:
        plistStructureDefinitionIdentifier = value is String ? value : null;
      case _kUsesTabs:
        usesTabs = value is String ? value : null;
      case _kIndentWidth:
        indentWidth = value is String ? value : null;
      case _kTabWidth:
        tabWidth = value is String ? value : null;
      case _kWrapsLines:
        wrapsLines = value is String ? value : null;
      case _kLineEnding:
        lineEnding = value is String ? value : null;
      case _kExpectedSignature:
        expectedSignature = value is String ? value : null;
      case _kComments:
        comments = value is String ? value : null;
    }
  }
}
