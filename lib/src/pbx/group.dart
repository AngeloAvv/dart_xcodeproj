import 'package:path/path.dart' as p;

import '../object/abstract_object.dart';
import '../object/object_list.dart';
import '../project/groups_position.dart';
import 'pbx_build_file.dart';
import 'pbx_file_reference.dart';
import 'pbx_project.dart';

// =============================================================================
// PBXGroup
// =============================================================================

/// Represents an Xcode group that can contain other groups and file references.
/// Port of [PBXGroup]. Groups are the primary way
/// Xcode organizes files in the project navigator. [children] is a ref-counted
/// [ObjectList] accepting any [AbstractObject] child type.
/// Key contracts:
/// - [children] always serializes (even when empty).
/// - [sourceTree] is non-nullable with default `'<group>'`.
/// - [groups] returns only exact-class [PBXGroup] (excludes [PBXVariantGroup]).
/// - [displayName] follows: [name] ?? basename([path]) ?? super.displayName.
class PBXGroup extends AbstractObject {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXGroup';

  // ---------------------------------------------------------------------------
  // Attribute key constants — plist key order matches Ruby declaration order.
  // ---------------------------------------------------------------------------
  static const String _kChildren = 'children';
  static const String _kSourceTree = 'sourceTree';
  static const String _kPath = 'path';
  static const String _kName = 'name';
  static const String _kUsesTabs = 'usesTabs';
  static const String _kIndentWidth = 'indentWidth';
  static const String _kTabWidth = 'tabWidth';
  static const String _kWrapsLines = 'wrapsLines';
  static const String _kComments = 'comments';

  /// Declared attribute order — Ruby declaration order.
  static const List<String> _ownAttributes = [
    _kChildren,
    _kSourceTree,
    _kPath,
    _kName,
    _kUsesTabs,
    _kIndentWidth,
    _kTabWidth,
    _kWrapsLines,
    _kComments,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// Ref-counted mixed-type collection of group children.
  /// Uses `late final` so the field initializer runs exactly once per instance.
  /// Do NOT reinitialize in [initializeDefaults].
  /// Port of `has_many :children, [PBXGroup, PBXFileReference, ...]`.
  late final ObjectList<AbstractObject> children = ObjectList<AbstractObject>(
    this,
  );

  /// The anchor for path resolution. Default `<group>`. Always serialized.
  /// Port of `attribute :source_tree, String, '<group>'`.
  String sourceTree = '<group>';

  /// Path to a folder in the file system. Optional.
  /// Port of `attribute :path, String`.
  String? path;

  /// Display name shown in Xcode navigator. Optional.
  /// Port of `attribute :name, String`.
  String? name;

  /// Whether Xcode uses tabs. Optional.
  String? usesTabs;

  /// Editor indent width in spaces. Optional.
  String? indentWidth;

  /// Editor tab width in spaces. Optional.
  String? tabWidth;

  /// Whether Xcode wraps lines. Optional.
  String? wrapsLines;

  /// Comments stored in the plist. Optional.
  String? comments;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXGroup(super.project, super.uuid);

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

  /// Set non-nullable defaults. [children] is late final — do NOT touch here.
  /// Port of implicit Ruby attribute default `<group>` for source_tree.
  @override
  void initializeDefaults() {
    sourceTree = '<group>';
  }

  /// Display name for Xcode navigator and plist annotations.
  /// Priority: [name] → basename([path]) → super.displayName.
  /// Port of.
  @override
  String get displayName {
    if (name != null) return name!;
    if (path != null) return p.basename(path!);
    return super.displayName;
  }

  /// Whether this group is the project's main group.
  /// Port of `self.equal?(project.main_group)`.
  bool get isMainGroup => referrers.any(
    (referrer) => referrer is PBXProject && identical(referrer.mainGroup, this),
  );

  /// `null` for the main group, which Xcode writes without a comment;
  /// otherwise ` $name ` or ` basename(path) `. A group with neither gets
  /// the blank annotation `'  '`, as in Ruby (`" #{display_name} "` with a
  /// `nil` display name).
  /// Port of `PBXGroup#ascii_plist_annotation`.
  @override
  String? get asciiPlistAnnotation {
    if (isMainGroup) return null;
    return ' ${name ?? (path != null ? p.basename(path!) : '')} ';
  }

  @override
  List<String> get referenceAttributes => const [_kChildren];

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kChildren:
        // Always emit — even when empty (to-many invariant).
        into[_kChildren] = children.uuids;
      case _kSourceTree:
        into[_kSourceTree] = sourceTree;
      case _kPath:
        if (path != null) into[_kPath] = path;
      case _kName:
        if (name != null) into[_kName] = name;
      case _kUsesTabs:
        if (usesTabs != null) into[_kUsesTabs] = usesTabs;
      case _kIndentWidth:
        if (indentWidth != null) into[_kIndentWidth] = indentWidth;
      case _kTabWidth:
        if (tabWidth != null) into[_kTabWidth] = tabWidth;
      case _kWrapsLines:
        if (wrapsLines != null) into[_kWrapsLines] = wrapsLines;
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
      case _kChildren:
        // Expand each child inline; cycle guard uses visited set.
        into[_kChildren] = children
            .map(
              (c) => visited.contains(c.uuid)
                  ? '<cycle: ${c.uuid}>'
                  : c.toTreeHash(visited),
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
      case _kChildren:
        if (value is List) {
          for (final uuid in value.cast<String>()) {
            final obj = objectWithUuid(uuid, objectsByUuidPlist);
            if (obj != null) children.add(obj);
          }
        }
      case _kSourceTree:
        if (value is String) sourceTree = value;
      case _kPath:
        if (value is String) path = value;
      case _kName:
        if (value is String) name = value;
      case _kUsesTabs:
        if (value is String) usesTabs = value;
      case _kIndentWidth:
        if (value is String) indentWidth = value;
      case _kTabWidth:
        if (value is String) tabWidth = value;
      case _kWrapsLines:
        if (value is String) wrapsLines = value;
      case _kComments:
        if (value is String) comments = value;
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  List<ObjectList<Object>> get toManyAttributes => [children];

  @override
  List<String> get toManyAttributeKeys => const [_kChildren];

  @override
  void clearRelationships() {
    children.clear();
  }

  /// The build files associated with this group (e.g. the Resources phase
  /// entry of a variant group such as `LaunchScreen.storyboard`).
  /// Port of `build_files` (`referrers.grep(PBXBuildFile)`).
  List<PBXBuildFile> get buildFiles =>
      referrers.whereType<PBXBuildFile>().toList();

  /// Removes the children (files and groups, recursively) under this group,
  /// together with their build files.
  /// Port of `clear`.
  void clear() {
    // Iterate over a snapshot: removing a child mutates [children].
    for (final child in children.toList()) {
      child.removeFromProject();
    }
  }

  /// Alias of [clear].
  /// Port of `remove_children_recursively`.
  void removeChildrenRecursively() => clear();

  /// Removes this group from the project together with all of its descendants
  /// and every [PBXBuildFile] that points to it or to them, so build phases
  /// never keep dangling entries. [PBXVariantGroup] and [XCVersionGroup]
  /// inherit this behaviour.
  /// Port of `remove_from_project`
  /// (`build_files.each(&:remove_from_project); super`), extended to [clear]
  /// the group first so the build files of descendants are removed as well.
  @override
  void removeFromProject() {
    clear();
    for (final buildFile in buildFiles) {
      buildFile.removeFromProject();
    }
    super.removeFromProject();
  }

  // ---------------------------------------------------------------------------
  // : sort helpers
  // ---------------------------------------------------------------------------

  /// Sorts the direct children of this group.
  /// Comparison priority (matching Ruby):
  /// 1. If [groupsPosition] is [GroupsPosition.above], all [PBXGroup] children
  /// appear before non-group children. If [GroupsPosition.below], the reverse.
  /// 2. Within the same partition (or when [groupsPosition] is null), children
  /// are sorted by:
  /// a. basenameWithoutExtension of displayName (case-insensitive)
  /// b. extension of displayName (case-insensitive)
  /// c. path (case-insensitive)
  /// Port of.
  void sort({GroupsPosition? groupsPosition}) {
    children.sortInPlace((a, b) {
      final aIsGroup = a is PBXGroup;
      final bIsGroup = b is PBXGroup;
      if (groupsPosition == GroupsPosition.above) {
        if (aIsGroup && !bIsGroup) return -1;
        if (!aIsGroup && bIsGroup) return 1;
      } else if (groupsPosition == GroupsPosition.below) {
        if (aIsGroup && !bIsGroup) return 1;
        if (!aIsGroup && bIsGroup) return -1;
      }
      // Name comparison by basename-without-extension, then extension, then path.
      // Use dynamic to access name/path on any AbstractObject subtype.
      final aDyn = a as dynamic;
      final bDyn = b as dynamic;
      final aDisplayName = ((aDyn.name ?? aDyn.path ?? '') as String? ?? '')
          .toLowerCase();
      final bDisplayName = ((bDyn.name ?? bDyn.path ?? '') as String? ?? '')
          .toLowerCase();
      var result = p
          .basenameWithoutExtension(aDisplayName)
          .compareTo(p.basenameWithoutExtension(bDisplayName));
      if (result == 0) {
        result = p.extension(aDisplayName).compareTo(p.extension(bDisplayName));
        if (result == 0) {
          final aPath = ((aDyn.path ?? '') as String? ?? '').toLowerCase();
          final bPath = ((bDyn.path ?? '') as String? ?? '').toLowerCase();
          result = aPath.compareTo(bPath);
        }
      }
      return result;
    });
  }

  /// Recursively sorts this group and all child groups.
  /// Port of Ruby AbstractObject#sort_recursively
  /// for [PBXGroup]: sorts own children, then recurses into child groups.
  void sortRecursively({GroupsPosition? groupsPosition}) {
    sort(groupsPosition: groupsPosition);
    for (final child in children.toList()) {
      if (child is PBXGroup) {
        child.sortRecursively(groupsPosition: groupsPosition);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Typed child getters
  // ---------------------------------------------------------------------------

  /// Returns only exact-class [PBXGroup] children (excludes subclasses).
  /// `children.select { |obj| obj.class == PBXGroup }`
  /// Uses `runtimeType == PBXGroup` for exact-class semantics.
  Iterable<PBXGroup> get groups =>
      children.where((c) => c.runtimeType == PBXGroup).cast<PBXGroup>();

  /// Returns all [PBXFileReference] children.
  /// `children.grep(PBXFileReference)`
  Iterable<PBXFileReference> get files =>
      children.whereType<PBXFileReference>();

  /// Returns all [XCVersionGroup] children.
  /// `children.grep(XCVersionGroup)`
  Iterable<XCVersionGroup> get versionGroups =>
      children.whereType<XCVersionGroup>();

  // ---------------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------------

  /// The first file reference among the direct children whose [path] equals
  /// [path] exactly (it is not a basename, a suffix or a hierarchy path), or
  /// `null` if there is none. Only [PBXFileReference]s are considered: groups,
  /// even with the same path, are not.
  /// Port of `find_file_by_path`.
  PBXFileReference? findFileByPath(String path) =>
      files.where((ref) => ref.path == path).firstOrNull;

  /// Walks the children by the names in [path] (`/` separated) and returns the
  /// object it ends at, or `null` if a name is not found. With [create] a
  /// [PBXGroup] named after each missing name is added (`<group>` source tree,
  /// no path) instead. A `null` [path] returns this group.
  ///
  /// Each name is matched, among the children, against the name Ruby calls
  /// `display_name` (a group: its [name], else the basename of its [path]; the
  /// other objects: [displayName]) and the first child that matches wins, so
  /// with duplicated names the first one is returned; files, variant groups and
  /// proxies match like groups and may be returned, which is why the result is
  /// an [AbstractObject]. Names are not trimmed or normalized: `''`, a leading
  /// `/` or `//` give empty names, a trailing `/` is ignored, as with Ruby's
  /// `String#split('/')`. A path that is empty (`''`, `'/'`) looks for a group
  /// with neither name nor path (creating one with [create]).
  ///
  /// Throws a [StateError], where Ruby raises a `NoMethodError`, if a name
  /// that is not the last one resolves to something that is not a group (a
  /// file): nothing is created for the names after it. The array form of
  /// Ruby's [path] is not supported.
  ///
  /// Port of `find_subpath(path, should_create)`.
  AbstractObject? findSubpath(String? path, {bool create = false}) {
    if (path == null) return this;
    // `''.split('/')` is empty in Ruby: the one name looked for is `nil`.
    final names = _splitPath(path);
    if (names.isEmpty) names.add(null);

    PBXGroup current = this;
    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      var child = current.children
          .where((c) => _lookupName(c) == name)
          .firstOrNull;
      if (child == null) {
        if (!create) return null;
        child = current._newGroup(name);
      }
      if (i == names.length - 1) return child;
      if (child is! PBXGroup) {
        throw StateError(
          'findSubpath: "${_lookupName(child)}" is a ${child.isa}, not a '
          'group, so it has no "${names[i + 1]}" child',
        );
      }
      current = child;
    }
    return current; // unreachable: [names] is never empty.
  }

  /// `path.split('/')` as Ruby does it: empty strings at the end are dropped.
  static List<String?> _splitPath(String path) {
    final names = <String?>[...path.split('/')];
    while (names.isNotEmpty && names.last == '') {
      names.removeLast();
    }
    return names;
  }

  /// The name Ruby's `find_subpath` matches [object] against. Ruby's
  /// `PBXGroup#display_name` and `PBXFileReference#display_name` are `nil` for
  /// an object with neither name nor path (where [displayName] falls back to
  /// `Group` or `FileReference`).
  static String? _lookupName(AbstractObject object) {
    if (object is PBXGroup) {
      return object.name ??
          (object.path != null ? p.basename(object.path!) : null);
    }
    if (object is PBXFileReference) {
      if (object.name != null || object.path != null) return object.displayName;
      return null;
    }
    return object.displayName;
  }

  /// Adds a new group named [name] to the children.
  /// Port of `new_group(name)`.
  PBXGroup _newGroup(String? name) {
    final group = project.newObject((g, u) => PBXGroup(g, u));
    group.name = name;
    group.sourceTree = '<group>';
    group.path = null;
    children.add(group);
    return group;
  }

  /// The children of this group and, recursively, of its child groups
  /// (variant and version groups included), each child followed by its own
  /// descendants (depth first, in the order of [children]).
  /// Port of `recursive_children`.
  List<AbstractObject> get recursiveChildren {
    final result = <AbstractObject>[];
    for (final child in children) {
      result.add(child);
      if (child is PBXGroup) result.addAll(child.recursiveChildren);
    }
    return result;
  }
}

// =============================================================================
// PBXVariantGroup
// =============================================================================

/// A group used to gather localized files into one entry.
/// Port of [PBXVariantGroup]. Extends PBXGroup with
/// an optional `lastKnownFileType` attribute. Typically used for `.lproj`
/// localization bundles.
class PBXVariantGroup extends PBXGroup {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'PBXVariantGroup';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kLastKnownFileType = 'lastKnownFileType';

  /// Own attributes — appears before PBXGroup attributes in merged order.
  static const List<String> _ownAttributes = [_kLastKnownFileType];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// The file type guessed by Xcode. Optional.
  /// Port of `attribute :last_known_file_type, String`.
  String? lastKnownFileType;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  PBXVariantGroup(super.project, super.uuid);

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
      case _kLastKnownFileType:
        if (lastKnownFileType != null) {
          into[_kLastKnownFileType] = lastKnownFileType;
        }
      default:
        super.serializeAttribute(key, into);
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
      case _kLastKnownFileType:
        if (value is String) lastKnownFileType = value;
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }
}

// =============================================================================
// XCVersionGroup
// =============================================================================

/// A group containing multiple versions of a resource (e.g., Core Data models).
/// Port of [XCVersionGroup]. Extends PBXGroup with
/// [currentVersion] (has-one PBXFileReference) and [versionGroupType].
/// Key contracts:
/// - [currentVersion] is ref-counted via setter.
/// - XCVersionGroup's own attributes ([currentVersion], [versionGroupType])
/// appear BEFORE PBXGroup's attributes in [attributeOrder].
class XCVersionGroup extends PBXGroup {
  /// ISA string for factory registry and plist output.
  static const String isaStatic = 'XCVersionGroup';

  // ---------------------------------------------------------------------------
  // Attribute key constants
  // ---------------------------------------------------------------------------
  static const String _kCurrentVersion = 'currentVersion';
  static const String _kVersionGroupType = 'versionGroupType';

  /// Own attributes — before PBXGroup's in merged order.
  static const List<String> _ownXCAttributes = [
    _kCurrentVersion,
    _kVersionGroupType,
  ];

  // ---------------------------------------------------------------------------
  // Typed fields
  // ---------------------------------------------------------------------------

  /// has-one PBXFileReference — ref-counted via setter.
  /// Port of `has_one :current_version, PBXFileReference`.
  PBXFileReference? _currentVersion;

  PBXFileReference? get currentVersion => _currentVersion;

  set currentVersion(PBXFileReference? value) {
    if (identical(_currentVersion, value)) return;
    markProjectAsDirty();
    _currentVersion?.removeReferrer(this);
    _currentVersion = value;
    value?.addReferrer(this);
  }

  /// The type of versioned resource. Optional.
  /// Port of `attribute :version_group_type, String, 'wrapper.xcdatamodel'`.
  String? versionGroupType;

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  XCVersionGroup(super.project, super.uuid);

  // ---------------------------------------------------------------------------
  // AbstractObject overrides
  // ---------------------------------------------------------------------------

  @override
  String get isa => isaStatic;

  /// XCVersionGroup own attrs come BEFORE PBXGroup attrs.
  @override
  List<String> get attributeOrder => [
    ..._ownXCAttributes,
    ...super.attributeOrder,
  ];

  @override
  List<String> get referenceAttributes => [
    _kCurrentVersion,
    ...super.referenceAttributes,
  ];

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  @override
  void serializeAttribute(String key, Map<String, dynamic> into) {
    switch (key) {
      case _kCurrentVersion:
        if (_currentVersion != null) {
          into[_kCurrentVersion] = _currentVersion!.uuid;
        }
      case _kVersionGroupType:
        if (versionGroupType != null) {
          into[_kVersionGroupType] = versionGroupType;
        }
      default:
        super.serializeAttribute(key, into);
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
      case _kCurrentVersion:
        if (value is String) {
          final ref = objectWithUuid(value, objectsByUuidPlist);
          if (ref is PBXFileReference) currentVersion = ref;
        }
      case _kVersionGroupType:
        if (value is String) versionGroupType = value;
      default:
        super.readAttribute(key, value, objectsByUuidPlist);
    }
  }

  // ---------------------------------------------------------------------------
  // Relationship lifecycle
  // ---------------------------------------------------------------------------

  @override
  List<ToOneAttribute> get toOneAttributes => [
    ...super.toOneAttributes,
    ToOneAttribute(
      get: () => currentVersion,
      set: (v) => currentVersion = v as PBXFileReference?,
    ),
  ];

  @override
  void clearRelationships() {
    currentVersion = null;
    super.clearRelationships();
  }
}
