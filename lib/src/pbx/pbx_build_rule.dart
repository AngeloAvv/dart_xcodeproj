import '../object/abstract_object.dart';

/// Represents a custom build rule of an Xcode target.
///
/// Port of [PBXBuildRule] (build_rule.rb lines 1-109). All attributes are
/// simple String or plain `List<String>` — no ObjectList / reference counting.
/// `isEditable` is non-nullable with default `'1'`.
/// `outputFiles` and `outputFilesCompilerFlags` are always serialized (even empty).
/// `inputFiles` is nullable and emitted only when non-null.
class PBXBuildRule extends AbstractObject {
  /// ISA constant used by [isaRegistry] factory registration.
  static const String isaStatic = 'PBXBuildRule';

  // ---------------------------------------------------------------------------
  // Attribute key constants — in _ownAttributes declaration order
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kCompilerSpec = 'compilerSpec';
  static const String _kDependencyFile = 'dependencyFile';
  static const String _kFileType = 'fileType';
  static const String _kFilePatterns = 'filePatterns';
  static const String _kIsEditable = 'isEditable';
  static const String _kInputFiles = 'inputFiles';
  static const String _kOutputFiles = 'outputFiles';
  static const String _kOutputFilesCompilerFlags = 'outputFilesCompilerFlags';
  static const String _kRunOncePerArchitecture = 'runOncePerArchitecture';
  static const String _kScript = 'script';

  static const List<String> _ownAttributes = [
    _kName,
    _kCompilerSpec,
    _kDependencyFile,
    _kFileType,
    _kFilePatterns,
    _kIsEditable,
    _kInputFiles,
    _kOutputFiles,
    _kOutputFilesCompilerFlags,
    _kRunOncePerArchitecture,
    _kScript,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// The name of the rule (optional).
  String? name;

  /// The compiler specification identifier (optional).
  ///
  /// Example: `com.apple.compilers.proxy.script`
  String? compilerSpec;

  /// The discovered dependency file path (optional).
  ///
  /// Example: `$(DERIVED_FILES_DIR)/$(INPUT_FILE_NAME).d`
  String? dependencyFile;

  /// The file type that this rule processes (optional).
  ///
  /// Example: `pattern.proxy`
  String? fileType;

  /// The file pattern glob for files processed by this rule (optional).
  ///
  /// Example: `*.css`
  String? filePatterns;

  /// Whether the rule is editable. Non-nullable; default `'1'`.
  String isEditable = '1';

  /// Input file paths (optional — emitted only when non-null).
  List<String>? inputFiles;

  /// Output file paths. Non-nullable; always emitted (even when empty).
  List<String> outputFiles = [];

  /// Compiler flags for each output file. Non-nullable; always emitted (even when empty).
  List<String> outputFilesCompilerFlags = [];

  /// Whether the rule runs once per architecture (optional).
  ///
  /// Example: `'0'`
  String? runOncePerArchitecture;

  /// The shell script content (optional).
  ///
  /// Present when [compilerSpec] is `com.apple.compilers.proxy.script`.
  String? script;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  PBXBuildRule(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  /// Hardcoded annotation — port of build_rule.rb `ascii_plist_annotation`.
  @override
  String get asciiPlistAnnotation => ' PBXBuildRule ';

  @override
  void initializeDefaults() {
    isEditable = '1';
    outputFiles = []; // fresh list per instance
    outputFilesCompilerFlags = []; // fresh list per instance
  }

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kName:
        if (name != null) into[_kName] = name;
      case _kCompilerSpec:
        if (compilerSpec != null) into[_kCompilerSpec] = compilerSpec;
      case _kDependencyFile:
        if (dependencyFile != null) into[_kDependencyFile] = dependencyFile;
      case _kFileType:
        if (fileType != null) into[_kFileType] = fileType;
      case _kFilePatterns:
        if (filePatterns != null) into[_kFilePatterns] = filePatterns;
      case _kIsEditable:
        into[_kIsEditable] = isEditable; // always emit (non-nullable)
      case _kInputFiles:
        if (inputFiles != null)
          into[_kInputFiles] = inputFiles; // omit when null
      case _kOutputFiles:
        into[_kOutputFiles] = outputFiles; // always emit (even empty)
      case _kOutputFilesCompilerFlags:
        into[_kOutputFilesCompilerFlags] =
            outputFilesCompilerFlags; // always emit
      case _kRunOncePerArchitecture:
        if (runOncePerArchitecture != null) {
          into[_kRunOncePerArchitecture] = runOncePerArchitecture;
        }
      case _kScript:
        if (script != null) into[_kScript] = script;
    }
  }

  /// PBXBuildRule has no object references — delegate directly to [serializeAttribute].
  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    serializeAttribute(key, into);
  }

  @override
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    switch (key) {
      case _kName:
        name = value is String ? value : null;
      case _kCompilerSpec:
        compilerSpec = value is String ? value : null;
      case _kDependencyFile:
        dependencyFile = value is String ? value : null;
      case _kFileType:
        fileType = value is String ? value : null;
      case _kFilePatterns:
        filePatterns = value is String ? value : null;
      case _kIsEditable:
        if (value is String) isEditable = value;
      case _kInputFiles:
        if (value is List) inputFiles = value.cast<String>().toList();
      case _kOutputFiles:
        if (value is List) outputFiles = value.cast<String>().toList();
      case _kOutputFilesCompilerFlags:
        if (value is List) {
          outputFilesCompilerFlags = value.cast<String>().toList();
        }
      case _kRunOncePerArchitecture:
        runOncePerArchitecture = value is String ? value : null;
      case _kScript:
        script = value is String ? value : null;
    }
  }
}
