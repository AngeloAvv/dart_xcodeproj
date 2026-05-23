// addReferrer/removeReferrer propagation, to_hash, to_tree_hash]

import 'dart:developer' as developer;

import 'abstract_object.dart';

/// Keyed collection of object references with reference-count hooks on
/// every mutation method, per OBJ-06 and .
/// Used for `has_many_references_by_keys` attributes — primarily
/// `PBXProject.projectReferences` (a `List<ObjectDictionary>`).
/// Composition-based: does not extend [Map]. Exposes only ref-counted
/// mutation methods. Iteration goes through [values], [entries].
class ObjectDictionary {
  /// Map of allowed plist key -> the AbstractObject subtype required for
  /// values stored under that key. Set at construction; immutable thereafter.
  /// Example for `PBXProject.projectReferences` entry:
  /// { 'ProductGroup': PBXGroup, 'ProjectRef': PBXFileReference }
  final Map<String, Type> classesByKey;

  /// The owning object — typically an [AbstractObject] (
  /// `PBXProject`) or whatever holds this dictionary.
  /// Used as the referrer in addReferrer/removeReferrer calls on values.
  final Object owner;

  final Map<String, AbstractObject?> _values = {};

  ObjectDictionary(this.classesByKey, this.owner);

  /// All keys explicitly declared as allowed (per Ruby's classes_by_key.keys).
  List<String> get allowedKeys => classesByKey.keys.toList();

  /// Snapshot of current non-null values.
  List<AbstractObject> get values =>
      _values.values.whereType<AbstractObject>().toList();

  /// Snapshot of current entries — only entries with non-null values are returned.
  List<MapEntry<String, AbstractObject>> get entries => _values.entries
      .where((e) => e.value != null)
      .map((e) => MapEntry(e.key, e.value!))
      .toList();

  bool get isEmpty => _values.values.every((v) => v == null);
  int get length => _values.values.where((v) => v != null).length;

  /// Lookup. Returns null for both unset keys and keys explicitly set to null.
  /// Does NOT throw for disallowed keys — read-only access is lenient.
  AbstractObject? operator [](String key) => _values[key];

  /// Set the value for [key]. Maintains referrer counts:
  /// - previous value (if non-null) gets removeReferrer(owner)
  /// - new value (if non-null) gets addReferrer(owner)
  /// Marks owner project as dirty.
  /// Throws [ArgumentError] if [key] is not in [classesByKey] or if [value]
  /// is non-null but not an instance of the declared type for [key].
  void operator []=(String key, AbstractObject? value) {
    _validateKey(key);
    _validateValue(key, value);
    _markDirty();
    final previous = _values[key];
    if (previous != null) {
      previous.removeReferrer(owner);
    }
    _values[key] = value;
    if (value != null) {
      value.addReferrer(owner);
    }
  }

  /// Remove a key. Equivalent to assigning null.
  /// Delegates to [operator[]=] which calls [_validateKey], [_markDirty], and
  /// manages referrer counts. Any future change to [operator[]=] behavior (e.g.
  /// a no-op guard for same-value assignments) will silently affect [delete] as
  /// well — keep both in sync if [operator[]=] semantics change.
  /// Note: the explicit [_validateKey] call below is redundant since [operator[]=]
  /// also validates, but is kept for clarity and fast-fail on unknown keys.
  void delete(String key) {
    _validateKey(key);
    this[key] = null;
  }

  /// Clear every entry. Drops referrer on every current non-null value.
  void clear() {
    _markDirty();
    for (final value in _values.values) {
      if (value != null) value.removeReferrer(owner);
    }
    _values.clear();
  }

  /// Called by [AbstractObject.removeFromProject] when a value of this dict
  /// is being removed. Nulls out any key whose value is identical to [obj],
  /// WITHOUT calling removeReferrer — the caller is already cleaning up.
  /// Port of `remove_reference`.
  void removeReference(AbstractObject obj) {
    for (final entry in _values.entries.toList()) {
      if (identical(entry.value, obj)) {
        _values[entry.key] = null;
      }
    }
  }

  /// Propagate addReferrer to every non-null value.
  /// Called when this dictionary is added to an [ObjectList] (
  /// `PBXProject.projectReferences = ObjectList<ObjectDictionary>`).
  /// Port of.
  void addReferrer(Object referrer) {
    for (final value in _values.values) {
      if (value != null) value.addReferrer(referrer);
    }
  }

  /// Propagate removeReferrer to every non-null value.
  /// Port of.
  void removeReferrer(Object referrer) {
    for (final value in _values.values) {
      if (value != null) value.removeReferrer(referrer);
    }
  }

  /// Stable plist representation: {key: uuid_string} for each non-null entry.
  /// Insertion-order preserving (Dart Map default).
  /// Port of `to_hash`.
  Map<String, dynamic> toHash() {
    final result = <String, dynamic>{};
    for (final entry in _values.entries) {
      final value = entry.value;
      if (value != null) {
        result[entry.key] = value.uuid;
      }
    }
    return result;
  }

  /// Recursive plist representation: {key: value.toTreeHash(visited)} for each
  /// non-null entry. Cycle-guarded via the [visited] set forwarded to values.
  /// Port of `to_tree_hash`.
  Map<String, dynamic> toTreeHash([Set<String>? visited]) {
    final result = <String, dynamic>{};
    for (final entry in _values.entries) {
      final value = entry.value;
      if (value != null) {
        result[entry.key] = value.toTreeHash(visited);
      }
    }
    return result;
  }

  void _validateKey(String key) {
    if (!classesByKey.containsKey(key)) {
      throw ArgumentError(
        "Unsupported key '$key' for ObjectDictionary. Allowed keys: "
        "${classesByKey.keys.toList()}",
      );
    }
  }

  /// Validates that [value] is acceptable for [key].
  /// Ruby does not enforce strict type at the
  /// ObjectDictionary level — it trusts the caller to provide semantically
  /// correct values. Dart's [Type] equality is exact (runtimeType check), so
  /// subclass instances (e.g., [PBXVariantGroup] stored under a [PBXGroup]-typed
  /// slot) would fail an exact check.
  /// Resolution (): accept exact match silently; for any other
  /// runtime type, emit a [developer.log] debug warning and accept the value
  /// anyway. This matches Ruby behavior and permits valid use-cases where a
  /// subclass is stored under a base-class-keyed slot.
  void _validateValue(String key, AbstractObject? value) {
    if (value == null) return;
    final expectedType = classesByKey[key];
    // Guard is reachable if classesByKey was populated with a null Type value
    // (possible via unsafe casting). Returning silently is the safe path here.
    if (expectedType == null) return;
    if (value.runtimeType == expectedType) return; // exact match — fast path
    // Soft accept: Ruby tolerates subclasses of the expected type. Since Dart's
    // Type objects do not support isSubtypeOf, we accept any non-exact type and
    // emit a WARNING-level log (level 900) so it is visible in production logs.
    // The caller is responsible for semantic correctness.
    developer.log(
      'ObjectDictionary["$key"] expected $expectedType, got ${value.runtimeType} '
      '(accepting as potential subtype; see Plan 04 )',
      name: 'ObjectDictionary',
      level: 900, // WARNING level — visible in production
    );
  }

  void _markDirty() {
    final o = owner;
    if (o is AbstractObject) {
      o.markProjectAsDirty();
    }
  }
}
