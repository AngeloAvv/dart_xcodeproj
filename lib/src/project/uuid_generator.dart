import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
// import only Random to prevent accidental use of Random() (insecure PRNG).
// UUID generation MUST use Random.secure() exclusively.
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../object/abstract_object.dart';
import '../pbx/group.dart';
import '../pbx/pbx_container_item_proxy.dart';
import '../pbx/pbx_file_reference.dart';
import '../pbx/pbx_project.dart';
import '../pbx/pbx_target_dependency.dart';
import '../pbx/xc_build_configuration.dart';
import 'case_converter.dart';
import 'xcode_project.dart';

/// UUID generation utilities for Xcode project object identifiers.
/// Xcode uses two UUID formats:
/// - Random: 24-char uppercase hex, equivalent to Ruby `SecureRandom.hex(12).upcase`
/// - Deterministic: 32-char uppercase hex (full MD5), equivalent to Ruby `Digest::MD5.hexdigest(path).upcase`
/// See (random) and (deterministic).
class UuidGenerator {
  UuidGenerator._();

  static final Random _random = Random.secure();

  /// Matches the two uppercase hex formats of Xcode object UUIDs: 24 characters
  /// (random) or 32 characters (deterministic, as written by `predictabilizeUuids`).
  /// Rejects RFC4122 UUIDs (which contain hyphens), lowercase, wrong-length strings,
  /// and strings with non-hex characters.
  static final RegExp _uuidPattern = RegExp(r'^(?:[0-9A-F]{24}|[0-9A-F]{32})$');

  /// Returns a random 24-char uppercase hex UUID.
  /// Equivalent to Ruby `SecureRandom.hex(12).upcase`:
  /// generates 12 cryptographically random bytes and encodes them as 24 hex chars.
  /// An optional [random] source can be supplied to make the output
  /// deterministic (intended for tests); it defaults to a secure generator.
  static String generate({Random? random}) {
    final rng = random ?? _random;
    final bytes = List<int>.generate(12, (_) => rng.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// Returns a deterministic UUID derived from [structuralPath] via MD5.
  /// Equivalent to Ruby `Digest::MD5.hexdigest(structuralPath).upcase`.
  /// Returns the full 32-char uppercase hex MD5 digest — matching Ruby gem behavior
  /// where `predictabilizeUuids()` replaces random UUIDs with MD5-based identifiers.
  /// Verified test vectors (per and Ruby reference):
  /// - `''` → `'D41D8CD98F00B204E9800998ECF8427E'`
  /// - `'hello'` → `'5D41402ABC4B2A76B9719D911017C592'`
  /// - `'test'` → `'098F6BCD4621D373CADE4E832627B4F6'`
  static String generateDeterministic(String structuralPath) {
    final digest = md5.convert(utf8.encode(structuralPath));
    return digest.toString().toUpperCase();
  }

  /// Returns a deterministic UUID made of the first [length] uppercase hex
  /// characters of the MD5 digest of [seed] (encoded as UTF-8).
  ///
  /// The result depends only on [seed] and [length], so it is stable across
  /// runs, platforms and Dart versions: the same seed always yields the same
  /// UUID, which makes generated projects reproducible.
  ///
  /// [length] can be 24 or 32, the two lengths of Xcode object UUIDs:
  /// - `24` (default) looks like the UUIDs Xcode writes itself, so objects a
  ///   tool adds to an Xcode-authored project blend in with the existing ones.
  /// - `32` is the full digest and returns the same value as
  ///   [generateDeterministic], i.e. Ruby `Digest::MD5.hexdigest(seed).upcase`
  ///   (xcodeproj's `uuid_for_path`).
  ///
  /// Any other [length] throws an [ArgumentError].
  ///
  /// A [seed] that is not well-formed UTF-16 (a lone surrogate) is encoded
  /// with U+FFFD in its place, so it hashes like any other string would.
  ///
  /// Truncating the digest to 24 characters (96 bits) makes collisions more
  /// likely than with the full 128 bits. The risk is negligible for a
  /// project's few thousand objects, but a seed that is not unique inside the
  /// project produces the very same UUID on purpose. Namespace your seeds
  /// with the tool, the target and the thing being identified, e.g.
  /// `tool/<target>/<thing>`, so they cannot clash with the seeds of other
  /// tools or of other targets.
  ///
  /// ```dart
  /// UuidGenerator.deterministic('tool/Runner/Pods'); // 89E916EBEC582DDC4CFB8632
  /// UuidGenerator.deterministic('tool/Runner/Pods', length: 32);
  /// // 89E916EBEC582DDC4CFB863221C1D3F5
  /// ```
  static String deterministic(String seed, {int length = 24}) {
    if (length != 24 && length != 32) {
      throw ArgumentError.value(length, 'length', 'must be 24 or 32');
    }
    return generateDeterministic(seed).substring(0, length);
  }

  /// Returns true if [uuid] is a valid Xcode object UUID: either 24 uppercase hex
  /// characters (random) or 32 uppercase hex characters (deterministic, MD5-based).
  /// Accepts only exactly 24 or 32 uppercase hex characters [0-9A-F].
  /// Rejects: lowercase, hyphens (RFC4122 format), wrong length, non-hex chars.
  static bool isValid(String uuid) => _uuidPattern.hasMatch(uuid);

  /// Converts a nested object into a deterministic string path for use as MD5 input:
  /// - If [depth] == 0: returns `'|'` (cutoff sentinel).
  /// - If [object] is a [Map]: sorts keys lexicographically, formats as `'key:value,'`
  /// for each entry, values are recursed at `depth - 1`.
  /// - If [object] is a [List]: joins elements with `','` (no trailing comma),
  /// elements are recursed at `depth - 1`.
  /// - Otherwise: returns `object.toString()`.
  /// Used by `predictabilizeUuids` `predictabilizeUuids()` to produce structural paths for MD5 seeding.
  static String treeHashToPath(dynamic object, [int depth = 4]) {
    if (depth == 0) return '|';
    if (object is Map) {
      final sb = StringBuffer();
      final sortedKeys = object.keys.toList()
        ..sort((a, b) => a.toString().compareTo(b.toString()));
      for (final key in sortedKeys) {
        sb.write('$key:${treeHashToPath(object[key], depth - 1)},');
      }
      return sb.toString();
    } else if (object is List) {
      return object.map((v) => treeHashToPath(v, depth - 1)).join(',');
    } else {
      return object.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // Predictable UUIDs
  // ---------------------------------------------------------------------------

  /// Computes the structural path of every object reachable from [root].
  ///
  /// The path of an object is where it sits in the project, e.g.
  /// `Runner.xcodeproj/mainGroup/children/<component>`: [rootPath] for the
  /// root, then for each reference one segment per attribute (its plist key)
  /// and, for lists and dictionaries, one segment identifying the element (a
  /// digest of what the element looks like, see [treeHashToPath], plus its
  /// group hierarchy for groups and file references). An object reachable in
  /// several ways keeps the path it was first found with: to-one references
  /// are followed first, then to-many references, then the dictionaries of
  /// references, each in the order of [AbstractObject.attributeOrder].
  ///
  /// The map is keyed by identity and lists the objects in the order they were
  /// found, which is the order [predictabilize] resolves UUID collisions in.
  ///
  /// Port of the path computation of Ruby's `UUIDGenerator#generate_paths`.
  static Map<AbstractObject, String> structuralPaths(
    PBXProject root,
    String rootPath,
  ) => _StructuralPaths(root).compute(rootPath);

  /// Replaces every UUID of [project] with the MD5 of the structural path of
  /// its object (see [structuralPaths]) and rewrites every UUID that is held
  /// as a plain string, so that no reference is left dangling.
  ///
  /// Besides the object UUIDs, the references that are not objects are
  /// rewritten too: `containerPortal` and `remoteGlobalIDString` of a
  /// [PBXContainerItemProxy] and, in the project's `TargetAttributes`, the
  /// target UUID keys and the `TestTargetID` values. A UUID that is not one of
  /// the project's, such as the `remoteGlobalIDString` of a target of another
  /// project, is left untouched. Like Ruby, which compares values only, this
  /// holds for a UUID that is not the old UUID of any object of the project:
  /// if the `remoteGlobalIDString` of a proxy into another project happens to
  /// be one, it is rewritten as well.
  ///
  /// Objects the root cannot reach keep their UUID. If two objects have the
  /// same path they get the same UUID: the later one found replaces the
  /// earlier in [XcodeProject.objectsByUuid] and a warning is logged.
  ///
  /// Throws a [StateError] if an object the root cannot reach already has the
  /// UUID a reachable object would be given, since both cannot be kept (Ruby
  /// never loads such an object, so it has no such case). The project is left
  /// as it was.
  ///
  /// Port of Ruby's `UUIDGenerator#generate!`.
  static void predictabilize(XcodeProject project) {
    final root = project.rootObject;
    final paths = structuralPaths(root, p.basename(project.path));

    // Every object, by the UUID it has before it is switched.
    final objectsByOldUuid = Map<String, AbstractObject>.of(
      project.objectsByUuid,
    );
    final unreachable = objectsByOldUuid.values
        .where((object) => !paths.containsKey(object))
        .toList();

    final newUuids = {
      for (final entry in paths.entries)
        entry.key: generateDeterministic(entry.value),
    };

    // An unreachable object keeps its UUID, so no reachable object may be given
    // it. Check before anything is changed: there is no way to keep both.
    final taken = {for (final object in unreachable) object.uuid};
    final clashes = {
      for (final uuid in newUuids.values)
        if (taken.contains(uuid)) uuid,
    };
    if (clashes.isNotEmpty) {
      throw StateError(
        'Cannot predictabilize the UUIDs: ${clashes.join(', ')} would be given '
        'to an object of the project while an object the root does not reach '
        'already has it. Remove the unreachable object or change its UUID.',
      );
    }

    final switched = <String, AbstractObject>{};
    final overwritten = <AbstractObject>[];
    newUuids.forEach((object, uuid) {
      object.assignUuid(uuid);
      final previous = switched[uuid];
      if (previous != null) overwritten.add(previous);
      switched[uuid] = object;
    });

    if (overwritten.isNotEmpty) {
      developer.log(
        '[dart_xcodeproj] Generated duplicate UUIDs:\n\n'
        '${overwritten.map((o) => '${o.isa} -- ${paths[o]}').join('\n')}',
        name: 'dart_xcodeproj',
        level: 900,
      );
    }

    // The new UUID of the object that had [uuid], else [uuid] itself.
    String relink(String uuid) => objectsByOldUuid[uuid]?.uuid ?? uuid;

    for (final object in [...paths.keys, ...unreachable]) {
      if (object is! PBXContainerItemProxy) continue;
      final portal = object.containerPortal;
      if (portal != null) object.containerPortal = relink(portal);
      final remote = object.remoteGlobalIDString;
      if (remote != null) object.remoteGlobalIDString = relink(remote);
    }

    final targetAttributes = root.attributes['TargetAttributes'];
    if (targetAttributes is Map) {
      root.attributes['TargetAttributes'] = <String, dynamic>{
        for (final entry in targetAttributes.entries)
          relink(entry.key.toString()): _relinkTestTarget(entry.value, relink),
      };
    }

    // Unreachable objects are not part of Ruby's object graph at all; keep
    // them rather than silently dropping them from the project.
    for (final object in unreachable) {
      switched[object.uuid] = object;
    }
    project.objectsByUuid
      ..clear()
      ..addAll(switched);
    project.markDirty();
  }

  /// [attributes] of a target in `TargetAttributes`, with its `TestTargetID`
  /// passed through [relink].
  static dynamic _relinkTestTarget(
    dynamic attributes,
    String Function(String uuid) relink,
  ) {
    if (attributes is! Map) return attributes;
    final testTargetId = attributes['TestTargetID'];
    if (testTargetId is! String) return attributes;
    return <String, dynamic>{
      for (final entry in attributes.entries) entry.key.toString(): entry.value,
      'TestTargetID': relink(testTargetId),
    };
  }
}

/// The traversal behind [UuidGenerator.structuralPaths].
class _StructuralPaths {
  /// The maximum depth [UuidGenerator.treeHashToPath] reads of an object's
  /// tree hash.
  static const int _treeDepth = 4;

  /// What stands in for a part of a tree hash beyond [_treeDepth]: whatever it
  /// is, [UuidGenerator.treeHashToPath] prints it as `|`.
  static const Map<String, dynamic> _cut = <String, dynamic>{};

  final PBXProject _root;
  final Map<AbstractObject, String> _paths = LinkedHashMap.identity();
  final Map<AbstractObject, String> _components = HashMap.identity();

  _StructuralPaths(this._root);

  Map<AbstractObject, String> compute(String rootPath) {
    _visit(_root, rootPath);
    return _paths;
  }

  void _visit(AbstractObject object, String path) {
    // The first path an object is found with is the one it keeps.
    if (_paths.containsKey(object)) return;
    _paths[object] = path;

    final toMany = object.toManyAttributeKeys;
    final references = object.referenceAttributes.toSet();
    final toOneKeys = [
      for (final key in object.attributeOrder)
        if (references.contains(key) && !toMany.contains(key)) key,
    ];

    if (toOneKeys.isNotEmpty) {
      final hash = object.toHash();
      for (final key in toOneKeys) {
        final target = _resolve(object, hash[key]);
        if (target != null) _visit(target, '$path/$key');
      }
    }

    final lists = object.toManyAttributes;
    assert(lists.length == toMany.length, '${object.isa}: toMany mismatch');
    for (var i = 0; i < lists.length; i++) {
      for (final element in lists[i].whereType<AbstractObject>()) {
        _visit(element, '$path/${toMany[i]}/${_component(element)}');
      }
    }

    final byKeys = object.referencesByKeysAttributes;
    final byKeysNames = object.referencesByKeysAttributeKeys;
    assert(byKeys.length == byKeysNames.length, '${object.isa}: refs mismatch');
    for (var i = 0; i < byKeys.length; i++) {
      for (final dictionary in byKeys[i]) {
        for (final entry in dictionary.entries) {
          final key = CaseConverter.toSnakeCase(entry.key);
          _visit(
            entry.value,
            '$path/${byKeysNames[i]}/k:$key/${_component(entry.value)}',
          );
        }
      }
    }
  }

  /// The object [uuid] designates, if any.
  AbstractObject? _resolve(AbstractObject from, dynamic uuid) =>
      uuid is String ? from.project.objectsByUuid[uuid] : null;

  /// Identifies [object] among its siblings.
  String _component(AbstractObject object) =>
      _components.putIfAbsent(object, () {
        final component = UuidGenerator.treeHashToPath(
          _tree(object, _treeDepth),
          _treeDepth,
        );
        return _hasHierarchyPath(object)
            ? '$component${_hierarchyPath(object) ?? ''}'
            : component;
      });

  /// The recursive hash of [object]: its display name, isa and attributes,
  /// with the objects it references expanded in place, cut at [depth] levels
  /// (the most [UuidGenerator.treeHashToPath] reads).
  ///
  /// Port of Ruby's `to_tree_hash`, which has no cut and would never end on
  /// the loops a synchronized folder makes (target, folder, exceptions,
  /// target).
  Map<String, dynamic> _tree(AbstractObject object, int depth) {
    // Ruby's PBXTargetDependency#to_tree_hash leaves its target out: that is
    // what keeps a target from containing itself through its dependencies.
    if (object is PBXTargetDependency) {
      final proxy = object.targetProxy;
      return <String, dynamic>{
        'displayName': object.displayName,
        'isa': object.isa,
        if (proxy != null) 'targetProxy': _node(proxy, depth - 1),
      };
    }

    final hash = object.toHash();
    final toMany = object.toManyAttributeKeys;
    final references = object.referenceAttributes.toSet();
    final lists = object.toManyAttributes;
    final byKeys = object.referencesByKeysAttributes;
    final byKeysNames = object.referencesByKeysAttributeKeys;
    final childDepth = depth - 1;

    final tree = <String, dynamic>{
      'displayName': object.displayName,
      'isa': object.isa,
    };
    for (final key in object.attributeOrder) {
      final manyIndex = toMany.indexOf(key);
      final byKeysIndex = byKeysNames.indexOf(key);
      if (manyIndex >= 0) {
        tree[key] = childDepth <= 0
            ? _cut
            : [
                for (final element in lists[manyIndex])
                  if (element is AbstractObject) _node(element, childDepth - 1),
              ];
      } else if (byKeysIndex >= 0) {
        tree[key] = childDepth <= 0
            ? _cut
            : [
                for (final dictionary in byKeys[byKeysIndex])
                  childDepth - 1 <= 0
                      ? _cut
                      : {
                          for (final entry in dictionary.entries)
                            entry.key: _node(entry.value, childDepth - 2),
                        },
              ];
      } else if (references.contains(key)) {
        final target = _resolve(object, hash[key]);
        if (target != null) tree[key] = _node(target, childDepth);
      } else {
        final value = _rawAttribute(object, key, hash);
        if (value != null && value != false) tree[key] = value;
      }
    }
    return tree;
  }

  /// The value of the simple attribute [key] of [object] as the model holds
  /// it. [hash] is [AbstractObject.toHash] of [object], which writes some
  /// attributes in the form of the file instead: a build setting given as a
  /// space separated string comes back as a list. Ruby's `to_tree_hash` reads
  /// the attribute, `to_hash_as` is where it is normalized.
  dynamic _rawAttribute(
    AbstractObject object,
    String key,
    Map<String, dynamic> hash,
  ) => object is XCBuildConfiguration && key == 'buildSettings'
      ? object.buildSettings
      : hash[key];

  /// The tree hash of [object] standing at [depth], or [_cut] past the end.
  dynamic _node(AbstractObject object, int depth) =>
      depth <= 0 ? _cut : _tree(object, depth);

  /// Whether Ruby gives [object] a `hierarchy_path`.
  bool _hasHierarchyPath(Object object) =>
      object is PBXGroup || object is PBXFileReference;

  /// The names of the groups [object] sits in, from the main group down,
  /// e.g. `/Runner/AppDelegate.swift`; `null` for the main group.
  ///
  /// Port of `GroupableHelper.hierarchy_path`.
  String? _hierarchyPath(AbstractObject object) {
    if (identical(object, _root.mainGroup)) return null;
    final parent = _parent(object);
    final String? parentPath;
    if (_hasHierarchyPath(parent)) {
      parentPath = _hierarchyPath(parent as AbstractObject);
    } else if (parent is PBXProject) {
      parentPath = parent.name;
    } else {
      parentPath = (parent as AbstractObject).displayName;
    }
    return '${parentPath ?? ''}/${object.displayName}';
  }

  /// The group [object] is in. Like Ruby's `GroupableHelper.parent`, an
  /// object referenced from several places has the group among them as its
  /// parent, and a project with none or several groups is inconsistent.
  Object _parent(AbstractObject object) {
    var referrers = object.referrers.toList();
    if (referrers.length > 1) {
      referrers = referrers.whereType<PBXGroup>().toList();
    }
    if (referrers.length != 1) {
      throw StateError(
        referrers.isEmpty
            ? 'Consistency issue: no parent for object `${object.displayName}`'
            : 'Consistency issue: unexpected multiple parents for object '
                  '`${object.displayName}`: '
                  '${referrers.map((r) => r is AbstractObject ? r.displayName : r).join(', ')}',
      );
    }
    return referrers.single;
  }
}
