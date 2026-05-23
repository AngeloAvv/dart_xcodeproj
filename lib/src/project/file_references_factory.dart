// configureDefaultsForFileReference]
// Provides static helpers for creating file references with automatic type
// inference (lastKnownFileType from extension) and sourceTree assignment.

import 'package:path/path.dart' as p;

import '../constants/file_types.dart';
import '../object/abstract_object.dart';
import '../pbx/group.dart';
import '../pbx/pbx_file_reference.dart';
import 'xcode_project.dart';

/// Static helpers for creating file references and adding them to groups.
/// Port of [Xcodeproj::Project::Object::FileReferencesFactory]
/// All methods are static — this class is not instantiable.
class FileReferencesFactory {
  FileReferencesFactory._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Creates a new file reference with the given [refPath] and adds it to [group].
  /// The reference type is dispatched by extension:
  /// - `.xcdatamodeld` → [XCVersionGroup]
  /// - `.xcodeproj` → PBXFileReference (simplified — no proxy wiring)
  /// - otherwise → [PBXFileReference]
  /// [lastKnownFileType] is inferred from the extension via [FileTypes.byExtension].
  /// [name] is set to the basename when [refPath] contains a `/`.
  /// Port of.
  static AbstractObject newReference(
    PBXGroup group,
    String refPath,
    String sourceTree,
  ) {
    final ext = p.extension(refPath).toLowerCase();
    late AbstractObject ref;

    if (ext == '.xcdatamodeld') {
      ref = _newXcdatamodeld(group, refPath, sourceTree);
    } else if (ext == '.xcodeproj') {
      ref = _newSubproject(group, refPath, sourceTree);
    } else {
      ref = _newFileReference(group, refPath, sourceTree);
    }

    _configureDefaults(ref, refPath);
    return ref;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Creates a PBXFileReference, adds it to [group.children], and sets
  /// [sourceTree], [path], and [lastKnownFileType].
  /// Port of.
  static PBXFileReference _newFileReference(
    PBXGroup group,
    String refPath,
    String sourceTree,
  ) {
    final project = group.project as XcodeProject;
    final ref = project.newObject((g, u) => PBXFileReference(g, u));

    group.children.add(ref); // ref-counted — fires ref.addReferrer(group)
    ref.sourceTree = sourceTree;

    // Ruby: GroupableHelper.set_path_with_source_tree sets path = Pathname.new(path)
    // For simple path assignment: set path to full refPath; basename is set in
    // _configureDefaults when refPath contains '/'.
    ref.path = refPath;

    // Infer lastKnownFileType from extension
    final rawExt = p.extension(refPath).toLowerCase();
    final extKey = rawExt.startsWith('.') ? rawExt.substring(1) : rawExt;
    final fileType = FileTypes.byExtension[extKey];
    if (fileType != null) ref.lastKnownFileType = fileType;

    return ref;
  }

  /// Creates an [XCVersionGroup] for a Core Data `.xcdatamodeld` bundle,
  /// adds it to [group.children].
  /// Note: child .xcdatamodel files are NOT added here ( simplified port
  /// does not read the filesystem; child files are added externally if needed).
  /// Port of.
  static AbstractObject _newXcdatamodeld(
    PBXGroup group,
    String refPath,
    String sourceTree,
  ) {
    final project = group.project as XcodeProject;
    final versionGroup = project.newObject((g, u) => XCVersionGroup(g, u));

    versionGroup.path = p.basename(refPath);
    versionGroup.sourceTree = sourceTree;
    versionGroup.name = p.basenameWithoutExtension(refPath);
    versionGroup.versionGroupType = 'wrapper.xcdatamodel';

    group.children.add(versionGroup);
    return versionGroup;
  }

  /// Creates a PBXFileReference for a subproject (simplified — no proxy wiring).
  /// A full subproject reference would also create PBXContainerItemProxy and
  /// PBXReferenceProxy objects; that complexity is deferred.
  /// Port of (simplified).
  static AbstractObject _newSubproject(
    PBXGroup group,
    String refPath,
    String sourceTree,
  ) {
    final project = group.project as XcodeProject;
    final ref = project.newObject((g, u) => PBXFileReference(g, u));

    ref.path = refPath;
    ref.sourceTree = sourceTree;
    ref.lastKnownFileType = 'wrapper.pb-project';

    group.children.add(ref);
    return ref;
  }

  /// Configures defaults on [ref] after the type-specific factory ran.
  /// Rules (port of):
  /// 1. If [refPath] contains '/', set name = basename.
  /// 2. If extension is '.framework', set includeInIndex = null.
  /// Port of configure_defaults_for_file_reference (lines 224-232).
  static void _configureDefaults(AbstractObject ref, String refPath) {
    // Set name to basename when path contains a directory separator
    if (refPath.contains('/')) {
      if (ref is PBXFileReference) {
        ref.name = p.basename(refPath);
        // Also update path to be just the basename (Ruby Pathname behavior)
        ref.path = refPath;
      } else if (ref is XCVersionGroup) {
        ref.name = p.basename(refPath);
      }
    }

    // .framework files: Ruby sets include_in_index = nil (omits from plist)
    final ext = p.extension(refPath).toLowerCase();
    if (ext == '.framework') {
      if (ref is PBXFileReference) {
        ref.includeInIndex = null;
      }
    }
  }
}
