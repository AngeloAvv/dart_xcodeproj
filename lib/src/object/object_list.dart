// move bypasses ref-counting, ObjectDictionary value support]

import 'dart:collection';

import 'abstract_object.dart';
import 'object_dictionary.dart';
import 'object_graph.dart';

/// Ordered collection of object references with reference-count hooks on
/// every mutation method, per OBJ-05 and .
/// Used for `has_many` attributes — every build phase's `files` list,
/// target `dependencies`, `PBXProject.targets`, etc.
/// Composition-based: does NOT extend [List]. Exposes only ref-counted
/// mutation methods. Iteration goes through [IterableMixin] backed by [_items].
class ObjectList<T extends Object> with IterableMixin<T> {
  final Object owner;
  final List<T> _items = [];

  ObjectList(this.owner);

  @override
  Iterator<T> get iterator => _items.iterator;

  @override
  int get length => _items.length;

  @override
  bool get isEmpty => _items.isEmpty;

  @override
  bool get isNotEmpty => _items.isNotEmpty;

  @override
  T get first => _items.first;

  @override
  T get last => _items.last;

  @override
  List<T> toList({bool growable = true}) =>
      List<T>.of(_items, growable: growable);

  T operator [](int index) => _items[index];

  int indexOf(T obj) => _items.indexOf(obj);

  void add(T obj) {
    _performAddition(obj);
    _items.add(obj);
  }

  void insert(int index, T obj) {
    _performAddition(obj);
    _items.insert(index, obj);
  }

  void addAll(Iterable<T> objs) {
    for (final obj in objs) {
      add(obj);
    }
  }

  void prepend(T obj) => insert(0, obj);

  bool remove(Object obj) {
    if (obj is! T) return false;
    final index = _items.indexOf(obj);
    if (index < 0) return false;
    final removed = _items[index];
    _performRemoval(removed);
    _items.removeAt(index);
    return true;
  }

  T removeAt(int index) {
    final obj = _items[index];
    _performRemoval(obj);
    _items.removeAt(index);
    return obj;
  }

  void clear() {
    for (final obj in List<T>.of(_items)) {
      _performRemoval(obj);
    }
    _items.clear();
  }

  // Move WITHOUT ref-count change.
  // The user-supplied newIndex is the desired final index in the post-removal
  // list — no further adjustment is needed. Bypasses _performAddition /
  // _performRemoval entirely to guarantee referrer counts are unchanged.
  void move(T obj, int newIndex) {
    final current = _items.indexOf(obj);
    if (current < 0 || current == newIndex) return;
    _items.removeAt(current);
    _items.insert(newIndex, obj);
    _markDirty();
  }

  void moveFrom(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    final obj = _items.removeAt(fromIndex);
    _items.insert(toIndex, obj);
    _markDirty();
  }

  void sortBy(int Function(T a, T b) compare) {
    _items.sort(compare);
    _markDirty();
  }

  /// Sorts [_items] in-place using the given [comparator].
  /// Does NOT change referrer counts — sort does not add/remove references.
  /// Calls [_markDirty] to notify the project of the change (matches [sortBy] behavior).
  void sortInPlace(Comparator<T> comparator) {
    _items.sort(comparator);
    _markDirty();
  }

  /// Returns a new [List<String>] of UUIDs for every [AbstractObject] in this list.
  /// Guaranteed to return a fresh copy on every call — callers must NOT call
  /// `.toList()` on the result (that would double-copy unnecessarily).
  List<String> get uuids =>
      _items.whereType<AbstractObject>().map((o) => o.uuid).toList();

  void _performAddition(T obj) {
    _markDirty();
    if (obj is AbstractObject) {
      obj.addReferrer(owner);
    } else if (obj is ObjectDictionary) {
      obj.addReferrer(owner);
    }
  }

  void _performRemoval(T obj) {
    _markDirty();
    if (obj is AbstractObject) {
      obj.removeReferrer(owner);
    } else if (obj is ObjectDictionary) {
      obj.removeReferrer(owner);
    }
  }

  void _markDirty() {
    final o = owner;
    if (o is AbstractObject) {
      o.markProjectAsDirty();
    } else if (o is ObjectGraph) {
      o.markDirty();
    }
  }
}
