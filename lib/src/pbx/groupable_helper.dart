import 'package:path/path.dart' as p;

import '../object/abstract_object.dart';
import '../project/xcode_project.dart';
import 'group.dart';

/// Static helper class for traversing the PBX group hierarchy.
/// Port of [GroupableHelper]. All methods are static.
/// Provides parent lookup, ancestry traversal, hierarchy path generation,
/// main-group detection, and move semantics with cycle guards.
/// Deferred methods:
/// - `realPath` — requires [XcodeProject.path] for source tree resolution.
/// - `setSourceTree` / `setPathWithSourceTree` — file-level path helpers.
class GroupableHelper {
  GroupableHelper._();

  // ---------------------------------------------------------------------------
  // parent()
  // ---------------------------------------------------------------------------

  /// Returns the [PBXGroup] whose [children] list contains [object], or null
  /// if no group contains [object].
  /// Dart adaptation of `parent` (lines 12-28). Ruby raises
  /// on missing/multiple parents; Dart returns null to avoid hard dependencies
  /// on error semantics during construction.
  static PBXGroup? parent(AbstractObject object) {
    for (final candidate in object.project.objectsByUuid.values) {
      if (candidate is PBXGroup &&
          candidate.children.any((c) => identical(c, object))) {
        return candidate;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // parents()
  // ---------------------------------------------------------------------------

  /// Returns all ancestors of [object] ordered from immediate parent to the
  /// topmost group (typically main group).
  /// Dart adaptation of `parents` (lines 35-42). Ruby
  /// builds the list recursively from topmost down; Dart iterates upward and
  /// returns `[immediateParent, ..., topmostGroup]`.
  /// Returns an empty list if [object] has no parent.
  static List<PBXGroup> parents(AbstractObject object) {
    final result = <PBXGroup>[];
    final seen = <String>{};
    var current = parent(object);
    while (current != null) {
      if (seen.contains(current.uuid))
        break; // cycle guard — prevents infinite loop
      seen.add(current.uuid);
      result.add(current);
      current = parent(current);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // hierarchyPath()
  // ---------------------------------------------------------------------------

  /// Returns a slash-joined path of [displayName]s from the level below the
  /// topmost group down to (and including) [object].
  /// lines 49-55). The topmost group (main group) is omitted from the path.
  /// Returns `'/$displayName'` when [object] is a direct child of the topmost
  /// group. The topmost group's name is always omitted from the result.
  static String hierarchyPath(AbstractObject object) {
    // parents() returns [immediateParent, ..., topmostGroup]
    // Reverse to get [topmostGroup, ..., immediateParent]
    final chain = parents(object).reversed.toList();
    final names = <String>[];
    // Skip chain[0] (topmost/main group) — Ruby omits it from the path.
    for (var i = 1; i < chain.length; i++) {
      names.add(chain[i].displayName);
    }
    names.add(object.displayName);
    return '/${names.join('/')}';
  }

  // ---------------------------------------------------------------------------
  // isMainGroup()
  // ---------------------------------------------------------------------------

  /// Returns true when [object] is the topmost (main) group of its project.
  /// Dart adaptation of `main_group?` (lines 62-64).
  /// When PBXProject exists in [objectsByUuid], prefer its `mainGroup` linkage.
  /// Fallback: no group contains [object] → it is the main group.
  /// Uses [AbstractObject.isa] for PBXProject detection — stable across Dart
  /// tree-shaking and release-mode minification. `runtimeType.toString()` must
  /// NOT be used here (see in).
  static bool isMainGroup(AbstractObject object) {
    if (object is! PBXGroup) return false;

    // Try to find a PBXProject and compare mainGroup linkage.
    for (final candidate in object.project.objectsByUuid.values) {
      // isa is a hand-coded getter — stable across tree-shaking.
      if (candidate.isa == 'PBXProject') {
        final dyn = candidate as dynamic;
        final mg = dyn.mainGroup as AbstractObject?;
        if (mg != null) return identical(mg, object);
      }
    }

    // Fallback: if no group contains [object], it is the main group.
    return parent(object) == null;
  }

  // ---------------------------------------------------------------------------
  // move()
  // ---------------------------------------------------------------------------

  /// Moves [object] out of its current parent and into [newParent].
  /// Throws [ArgumentError] on:
  /// - Self-reference: `object === newParent`
  /// - Ancestor cycle: [newParent] is a descendant of [object]
  /// Port of `move` (lines 76-91) adapted for Dart null
  /// safety (Dart callers cannot pass null via typed parameters).
  /// Reference counting is handled automatically by [ObjectList.remove] and
  /// [ObjectList.add].
  static void move(AbstractObject object, PBXGroup newParent) {
    if (identical(object, newParent)) {
      throw ArgumentError('Cannot move ${object.displayName} into itself');
    }
    if (parents(newParent).any((ancestor) => identical(ancestor, object))) {
      throw ArgumentError(
        'Cannot move ${object.displayName} into one of its descendants',
      );
    }

    final currentParent = parent(object);
    currentParent?.children.remove(object);
    newParent.children.add(object);
  }

  // ---------------------------------------------------------------------------
  // Source tree helpers
  // ---------------------------------------------------------------------------

  /// Source trees symbol → plist value map.
  static const Map<String, String> sourceTreesByKey = {
    'absolute': '<absolute>',
    'group': '<group>',
    'project': 'SOURCE_ROOT',
    'builtProducts': 'BUILT_PRODUCTS_DIR',
    'developerDir': 'DEVELOPER_DIR',
    'sdkRoot': 'SDKROOT',
  };

  /// Sets [object.sourceTree] to the plist value for [key].
  /// E.g., 'project' → 'SOURCE_ROOT', 'group' → `<group>`.
  static void setSourceTree(AbstractObject object, String key) {
    final value = sourceTreesByKey[key] ?? key;
    (object as dynamic).sourceTree = value;
  }

  /// Resolves [object]'s source tree to an absolute filesystem path base.
  /// Returns null for `<absolute>` (path is already absolute) and unknown trees.
  static String? _sourceTreeRealPath(
    AbstractObject object,
    XcodeProject project,
  ) {
    final sourceTree = (object as dynamic).sourceTree as String? ?? '';
    switch (sourceTree) {
      case '<group>':
        // If the object's parent is PBXProject (i.e., object is mainGroup),
        // use projectDir + rootObject.projectDirPath.
        // Otherwise, recurse to parent's realPath.
        final par = parent(object);
        if (par == null) {
          // isMainGroup case: parent is PBXProject
          final dirPath =
              (project.rootObject as dynamic).projectDirPath as String? ?? '';
          return dirPath.isEmpty
              ? project.projectDir
              : p.join(project.projectDir, dirPath);
        }
        return realPath(par, project);
      case 'SOURCE_ROOT':
        return project.projectDir;
      case '<absolute>':
        return null;
      case 'BUILT_PRODUCTS_DIR':
        return r'${BUILT_PRODUCTS_DIR}';
      case 'DEVELOPER_DIR':
        return r'${DEVELOPER_DIR}';
      case 'SDKROOT':
        return r'${SDKROOT}';
      default:
        return null;
    }
  }

  /// Resolves [object]'s path to an absolute filesystem path using [project]
  /// as the SOURCE_ROOT anchor.
  static String? realPath(AbstractObject object, XcodeProject project) {
    final base = _sourceTreeRealPath(object, project);
    final objectPath = (object as dynamic).path as String? ?? '';
    if (base != null) {
      return objectPath.isEmpty ? base : p.join(base, objectPath);
    }
    return objectPath.isEmpty ? null : objectPath;
  }

  /// Sets [object.path] in a sourceTree-aware way.
  static void setPathWithSourceTree(
    AbstractObject object,
    String path,
    String sourceTreeKey,
  ) {
    final sourceTreeValue = sourceTreesByKey[sourceTreeKey] ?? sourceTreeKey;
    (object as dynamic).sourceTree = sourceTreeValue;

    if (sourceTreeValue == '<absolute>') {
      // assert path is absolute for <absolute> source tree.
      assert(
        p.isAbsolute(path),
        'setPathWithSourceTree: path must be absolute for <absolute> sourceTree',
      );
      (object as dynamic).path = path;
      return;
    }

    // For <group> and SOURCE_ROOT: set path as-is.
    // Relative path computation requires a project reference which may not be
    // available at this call site.
    (object as dynamic).path = path;
  }
}
