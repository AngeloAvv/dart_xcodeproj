import 'package:path/path.dart' as p;

import '../constants/misc.dart';
import '../object/abstract_object.dart';
import '../object/object_list.dart';
import 'pbx_build_file.dart';

// =============================================================================
// AbstractBuildPhase (abstract — NOT registered in isaRegistry)
// =============================================================================

/// Abstract base for all Xcode build phase types.
/// Port of [AbstractBuildPhase]. Carries 5
/// common attributes: [files] (ref-counted ObjectList), [buildActionMask],
/// [runOnlyForDeploymentPostprocessing], [alwaysOutOfDate], [comments].
/// [displayName] strips the `BuildPhase` suffix from the ISA string, so
/// `PBXSourcesBuildPhase` produces `'Sources'`.
/// [files] is a `late final` field — initialized once via field initializer;
/// do NOT reinitialize in [initializeDefaults].
abstract class AbstractBuildPhase extends AbstractObject {
  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kFiles = 'files';
  static const String _kBuildActionMask = 'buildActionMask';
  static const String _kRunOnlyForDeploymentPostprocessing =
      'runOnlyForDeploymentPostprocessing';
  static const String _kAlwaysOutOfDate = 'alwaysOutOfDate';
  static const String _kComments = 'comments';

  /// Declared attribute order — subclass before superclass.
  static const List<String> _ownAttributes = [
    _kFiles,
    _kBuildActionMask,
    _kRunOnlyForDeploymentPostprocessing,
    _kAlwaysOutOfDate,
    _kComments,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Ref-counted collection of build files in this phase.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  /// Do NOT reinitialize in [initializeDefaults].
  /// Port of `has_many :files, PBXBuildFile`.
  late final ObjectList<PBXBuildFile> files = ObjectList<PBXBuildFile>(this);

  /// Bitmask controlling when this phase runs. Default matches Ruby's default.
  String buildActionMask = '2147483647';

  /// Whether this phase runs only during deployment postprocessing. Default '0'.
  String runOnlyForDeploymentPostprocessing = '0';

  /// Optional flag to mark the phase always out-of-date (rarely used).
  String? alwaysOutOfDate;

  /// Optional comment string stored in the plist.
  String? comments;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  AbstractBuildPhase(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  void initializeDefaults() {
    buildActionMask = '2147483647';
    runOnlyForDeploymentPostprocessing = '0';
    // files is a late final — already initialized via field initializer.
  }

  @override
  List<String> get attributeOrder => [
    ..._ownAttributes,
    ...super.attributeOrder,
  ];

  /// Strips the `BuildPhase` suffix from the ISA string.
  /// Port of:
  /// `isa.gsub('BuildPhase', '')`
  @override
  String get displayName =>
      super.displayName.replaceAll(RegExp(r'BuildPhase$'), '');

  /// Returns `' $displayName '` (spaces on both sides) using the stripped name.
  /// Port of.
  @override
  String get asciiPlistAnnotation => ' $displayName ';

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kFiles:
        // Always emit — even when empty (to-many invariant).
        into[_kFiles] = files.uuids;
      case _kBuildActionMask:
        into[_kBuildActionMask] = buildActionMask;
      case _kRunOnlyForDeploymentPostprocessing:
        into[_kRunOnlyForDeploymentPostprocessing] =
            runOnlyForDeploymentPostprocessing;
      case _kAlwaysOutOfDate:
        if (alwaysOutOfDate != null) into[_kAlwaysOutOfDate] = alwaysOutOfDate;
      case _kComments:
        if (comments != null) into[_kComments] = comments;
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kFiles:
        // Expand each file inline; cycle guard uses visited set.
        into[_kFiles] = files
            .map(
              (f) => visited.contains(f.uuid)
                  ? '<cycle: ${f.uuid}>'
                  : f.toTreeHash(visited),
            )
            .toList();
      default:
        serializeAttribute(key, into);
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
      case _kFiles:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj is PBXBuildFile) files.add(obj);
          }
        }
      case _kBuildActionMask:
        if (value is String) buildActionMask = value;
      case _kRunOnlyForDeploymentPostprocessing:
        if (value is String) runOnlyForDeploymentPostprocessing = value;
      case _kAlwaysOutOfDate:
        alwaysOutOfDate = value is String ? value : null;
      case _kComments:
        comments = value is String ? value : null;
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  void clearRelationships() {
    files.clear();
  }

  // ---------------------------------------------------------------------------
  // AbstractBuildPhase mutation helpers
  // ---------------------------------------------------------------------------

  /// Returns the [PBXBuildFile] in [files] whose [fileRef] is identical to [fileRef].
  /// Returns null if not found.
  PBXBuildFile? buildFile(AbstractObject fileRef) {
    for (final bf in files) {
      if (identical(bf.fileRef, fileRef)) return bf;
    }
    return null;
  }

  /// Returns the file references pointed to by all [PBXBuildFile] entries in [files].
  List<AbstractObject?> get filesReferences =>
      files.map((f) => f.fileRef).toList();

  /// Creates a new [PBXBuildFile] referencing [fileRef] and adds it to [files].
  /// If [avoidDuplicates] is true and a [PBXBuildFile] with the same [fileRef]
  /// already exists, returns the existing one without creating a duplicate.
  PBXBuildFile addFileReference(
    AbstractObject fileRef, {
    bool avoidDuplicates = false,
  }) {
    if (avoidDuplicates) {
      final existing = buildFile(fileRef);
      if (existing != null) return existing;
    }
    final bf = project.newObject((g, u) => PBXBuildFile(g, u));
    bf.fileRef = fileRef; // has-one setter → fileRef.addReferrer(bf)
    files.add(bf); // ObjectList.add → bf.addReferrer(this)
    return bf;
  }

  /// Removes the [PBXBuildFile] whose [fileRef] is [fileRef] from [files].
  void removeFileReference(AbstractObject fileRef) {
    final bf = buildFile(fileRef);
    if (bf != null) _removeBuildFile(bf);
  }

  /// Removes [buildFile] from [files], clearing the fileRef reference.
  void _removeBuildFile(PBXBuildFile buildFile) {
    buildFile.fileRef = null; // has-one setter → removeReferrer on old fileRef
    files.remove(
      buildFile,
    ); // ObjectList.remove → buildFile.removeReferrer(this)
  }

  /// Sorts [files] by display name (case-insensitive basename without extension,
  /// then extension, then full path).
  void sort() {
    files.sortInPlace((x, y) {
      final xName = x.displayName.toLowerCase();
      final yName = y.displayName.toLowerCase();
      final String xBase = p.basenameWithoutExtension(xName);
      final String yBase = p.basenameWithoutExtension(yName);
      var result = xBase.compareTo(yBase);
      if (result == 0) {
        result = p.extension(xName).compareTo(p.extension(yName));
        if (result == 0) {
          final xPath =
              (x.fileRef as dynamic)?.path?.toString().toLowerCase() ?? '';
          final yPath =
              (y.fileRef as dynamic)?.path?.toString().toLowerCase() ?? '';
          result = xPath.compareTo(yPath);
        }
      }
      return result;
    });
  }
}

// =============================================================================
// Empty concrete subclasses (no additional attributes)
// =============================================================================

/// Headers build phase — contains public/private/project header files.
/// Port of `PBXHeadersBuildPhase`.
class PBXHeadersBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXHeadersBuildPhase';

  PBXHeadersBuildPhase(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

/// Sources build phase — contains compiled source files.
/// Port of `PBXSourcesBuildPhase`.
class PBXSourcesBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXSourcesBuildPhase';

  PBXSourcesBuildPhase(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

/// Frameworks build phase — links frameworks and libraries.
/// Port of `PBXFrameworksBuildPhase`.
class PBXFrameworksBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXFrameworksBuildPhase';

  PBXFrameworksBuildPhase(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

/// Resources build phase — copies resource files into the bundle.
/// Port of `PBXResourcesBuildPhase`.
class PBXResourcesBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXResourcesBuildPhase';

  PBXResourcesBuildPhase(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

/// Rez build phase — compiles Carbon resources (legacy).
/// Port of `PBXRezBuildPhase`.
class PBXRezBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXRezBuildPhase';

  PBXRezBuildPhase(super.project, super.uuid);

  @override
  String get isa => isaStatic;
}

// =============================================================================
// PBXCopyFilesBuildPhase (3 additional attributes)
// =============================================================================

/// Copy files build phase — copies arbitrary files into the product bundle.
/// Port of `PBXCopyFilesBuildPhase`.
/// Adds [name], [dstPath], and [dstSubfolderSpec] on top of AbstractBuildPhase.
/// [dstSubfolderSpec] defaults to `'7'` (resources destination) per Ruby's
/// `Constants::COPY_FILES_BUILD_PHASE_DESTINATIONS[:resources]`.
class PBXCopyFilesBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXCopyFilesBuildPhase';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kDstPath = 'dstPath';
  static const String _kDstSubfolderSpec = 'dstSubfolderSpec';

  /// Own attributes appear BEFORE AbstractBuildPhase attributes in merged order.
  static const List<String> _ownAttributes = [
    _kName,
    _kDstPath,
    _kDstSubfolderSpec,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Optional display name for this copy phase.
  String? name;

  /// Destination path within the product bundle. Default is empty string.
  String dstPath = '';

  /// Numeric destination folder specifier. Default `'7'` = resources folder.
  /// Ruby: `Constants::COPY_FILES_BUILD_PHASE_DESTINATIONS[:resources]` = `'7'`.
  String dstSubfolderSpec = '7';

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXCopyFilesBuildPhase(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  void initializeDefaults() {
    super
        .initializeDefaults(); // sets buildActionMask, runOnlyForDeploymentPostprocessing
    dstPath = '';
    dstSubfolderSpec =
        MiscConstants.copyFilesBuildPhaseDestinations['resources']!; // '7'
  }

  /// Subclass attributes first (name, dstPath, dstSubfolderSpec),
  /// then AbstractBuildPhase attributes (files, buildActionMask, ...).
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
      case _kName:
        if (name != null) into[_kName] = name;
      case _kDstPath:
        into[_kDstPath] = dstPath;
      case _kDstSubfolderSpec:
        into[_kDstSubfolderSpec] = dstSubfolderSpec;
      default:
        super.serializeAttribute(key, into);
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kName:
      case _kDstPath:
      case _kDstSubfolderSpec:
        // No object refs in own attrs — plain serialize.
        serializeAttribute(key, into);
      default:
        super.serializeAttributeAsTree(key, into, visited);
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
      case _kName:
        name = value is String ? value : null;
      case _kDstPath:
        if (value is String) dstPath = value;
      case _kDstSubfolderSpec:
        if (value is String) dstSubfolderSpec = value;
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }
}

// =============================================================================
// PBXShellScriptBuildPhase (9 additional attributes)
// =============================================================================

/// Shell script build phase — runs an arbitrary shell script during build.
/// Port of `PBXShellScriptBuildPhase`.
/// Adds 9 attributes on top of AbstractBuildPhase. Notably:
/// - [inputPaths], [outputPaths], [inputFileListPaths], [outputFileListPaths]
/// are plain `List<String>` (NOT ObjectList — they hold path strings,
/// not object references).
/// - [shellPath] and [shellScript] are non-nullable with defaults.
class PBXShellScriptBuildPhase extends AbstractBuildPhase {
  static const String isaStatic = 'PBXShellScriptBuildPhase';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kName = 'name';
  static const String _kInputPaths = 'inputPaths';
  static const String _kInputFileListPaths = 'inputFileListPaths';
  static const String _kOutputPaths = 'outputPaths';
  static const String _kOutputFileListPaths = 'outputFileListPaths';
  static const String _kShellPath = 'shellPath';
  static const String _kShellScript = 'shellScript';
  static const String _kShowEnvVarsInLog = 'showEnvVarsInLog';
  static const String _kDependencyFile = 'dependencyFile';

  /// Own attributes appear BEFORE AbstractBuildPhase attributes.
  static const List<String> _ownAttributes = [
    _kName,
    _kInputPaths,
    _kInputFileListPaths,
    _kOutputPaths,
    _kOutputFileListPaths,
    _kShellPath,
    _kShellScript,
    _kShowEnvVarsInLog,
    _kDependencyFile,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Optional display name for this script phase.
  String? name;

  /// Input file paths for the script (plain strings — NOT ObjectList).
  /// Port of `attribute :input_paths, Array`.
  /// Nullable so that plist-loaded objects that lack this key don't emit it
  /// on save (byte-identical round-trip requirement). initializeDefaults() sets
  /// this to [] for programmatically created objects.
  List<String>? inputPaths;

  /// Input file list paths (.xcfilelist references) — plain `List<String>`.
  /// Port of `attribute :input_file_list_paths, Array`.
  /// Nullable for byte-identical round-trip — same pattern as inputPaths.
  List<String>? inputFileListPaths;

  /// Output file paths for the script (plain strings — NOT ObjectList).
  /// Port of `attribute :output_paths, Array`.
  /// Nullable for byte-identical round-trip — same pattern as inputPaths.
  List<String>? outputPaths;

  /// Output file list paths (.xcfilelist references) — plain `List<String>`.
  /// Port of `attribute :output_file_list_paths, Array`.
  /// Nullable for byte-identical round-trip — same pattern as inputPaths.
  List<String>? outputFileListPaths;

  /// Path to the shell interpreter. Default `/bin/sh`.
  String shellPath = '/bin/sh';

  /// The shell script body. Default matches Ruby's placeholder.
  String shellScript = '# Type a script...\n';

  /// Whether to show environment variables in the build log (optional).
  String? showEnvVarsInLog;

  /// Optional path to the dependency file (`.d` file for make-style deps).
  String? dependencyFile;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXShellScriptBuildPhase(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  @override
  void initializeDefaults() {
    super
        .initializeDefaults(); // sets buildActionMask, runOnlyForDeploymentPostprocessing
    // Create fresh list instances per object (never share defaults).
    // These are set to [] (not null) for NEW objects; null means absent in plist.
    inputPaths = [];
    inputFileListPaths = [];
    outputPaths = [];
    outputFileListPaths = [];
    shellPath = '/bin/sh';
    shellScript = '# Type a script...\n';
  }

  /// Subclass attributes first, then AbstractBuildPhase attributes.
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
      case _kName:
        if (name != null) into[_kName] = name;
      case _kInputPaths:
        // Emit only when non-null (byte-identical round-trip: omit if not in original plist)
        if (inputPaths != null) into[_kInputPaths] = inputPaths;
      case _kInputFileListPaths:
        if (inputFileListPaths != null)
          into[_kInputFileListPaths] = inputFileListPaths;
      case _kOutputPaths:
        if (outputPaths != null) into[_kOutputPaths] = outputPaths;
      case _kOutputFileListPaths:
        if (outputFileListPaths != null)
          into[_kOutputFileListPaths] = outputFileListPaths;
      case _kShellPath:
        into[_kShellPath] = shellPath;
      case _kShellScript:
        into[_kShellScript] = shellScript;
      case _kShowEnvVarsInLog:
        if (showEnvVarsInLog != null)
          into[_kShowEnvVarsInLog] = showEnvVarsInLog;
      case _kDependencyFile:
        if (dependencyFile != null) into[_kDependencyFile] = dependencyFile;
      default:
        super.serializeAttribute(key, into);
    }
  }

  @override
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {
    switch (key) {
      case _kName:
      case _kInputPaths:
      case _kInputFileListPaths:
      case _kOutputPaths:
      case _kOutputFileListPaths:
      case _kShellPath:
      case _kShellScript:
      case _kShowEnvVarsInLog:
      case _kDependencyFile:
        // All own attrs are plain values — no object refs.
        serializeAttribute(key, into);
      default:
        super.serializeAttributeAsTree(key, into, visited);
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
      case _kName:
        name = value is String ? value : null;
      case _kInputPaths:
        // Set to the list from plist (may be empty — key was present in original)
        if (value is List) inputPaths = value.cast<String>().toList();
      case _kInputFileListPaths:
        if (value is List) inputFileListPaths = value.cast<String>().toList();
      case _kOutputPaths:
        if (value is List) outputPaths = value.cast<String>().toList();
      case _kOutputFileListPaths:
        if (value is List) outputFileListPaths = value.cast<String>().toList();
      case _kShellPath:
        if (value is String) shellPath = value;
      case _kShellScript:
        if (value is String) shellScript = value;
      case _kShowEnvVarsInLog:
        showEnvVarsInLog = value is String ? value : null;
      case _kDependencyFile:
        dependencyFile = value is String ? value : null;
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }
}
