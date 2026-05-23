import 'dart:developer' as developer;

import 'isa_registry.dart';
import 'object_graph.dart';

/// Base class for every Xcode project object (PBXFileReference, PBXNativeTarget, etc.).
/// Port of [AbstractObject]. Each concrete subclass
/// declares typed fields directly attribute name constants
/// and `_ownAttributes` list .
/// Reference counting lifecycle:
/// 1. Object created via [ObjectGraph.newObject].
/// 2. First [addReferrer] call registers it in [ObjectGraph.objectsByUuid].
/// 3. Each subsequent [addReferrer] is idempotent (Set semantics, ).
/// 4. Each [removeReferrer] drops the referrer; when the last one goes,
/// the object is removed from [ObjectGraph.objectsByUuid].
abstract class AbstractObject {
  /// Stable 24-char uppercase hex UUID assigned at construction.
  final String uuid;

  /// The owning project graph. Set at construction and never reassigned.
  final ObjectGraph project;

  /// Set — prevents double-counting from duplicate addReferrer calls.
  /// Port of @referrers in (Ruby uses Array — we use Set for safety).
  final Set<Object> _referrers = <Object>{};

  AbstractObject(this.project, this.uuid);

  /// The ISA string for this class.
  /// Each concrete subclass declares `static const String isa = 'PBXFoo'`
  /// and overrides this getter to return that constant. NEVER derive from
  /// runtimeType.toString() — see (tree-shaking risk).
  String get isa;

  /// Called only for programmatically created objects (NOT for plist-loaded).
  /// Subclasses set default values for their attributes here. List/Map defaults
  /// MUST be new instances (not const shared refs) .
  /// Port of.
  void initializeDefaults() {}

  /// Read-only snapshot of current referrers (for test assertions only).
  /// Returns an unmodifiable view; mutations go through [addReferrer]/[removeReferrer].
  Set<Object> get referrers => Set.unmodifiable(_referrers);

  /// Register [referrer] as holding a reference to this object.
  /// Idempotent — adding the same referrer twice has no effect (Set semantics).
  /// Re-asserts [ObjectGraph.objectsByUuid] registration on every call so that
  /// a re-added object reappears in the map.
  /// Port of.
  void addReferrer(Object referrer) {
    _referrers.add(referrer);
    project.objectsByUuid[uuid] = this;
  }

  /// Drop [referrer]'s reference. When the last referrer is dropped, remove
  /// this object from [ObjectGraph.objectsByUuid] and mark the project dirty.
  /// Port of.
  void removeReferrer(Object referrer) {
    _referrers.remove(referrer);
    if (_referrers.isEmpty) {
      project.markDirty();
      project.objectsByUuid.remove(uuid);
    }
  }

  /// Remove this object from the project entirely.
  /// Marks dirty, removes from objectsByUuid, asks every referrer to drop
  /// its reference (referrer.removeReference(this)), then clears own
  /// relationships. After this method returns, [_referrers] MUST be empty
  /// if not, a referrer failed to null out its field pointing to this object,
  /// which is a bug in a subclass.
  /// Port of.
  void removeFromProject() {
    project.markDirty();
    project.objectsByUuid.remove(uuid);
    // Iterate over a snapshot — referrers will mutate _referrers via removeReferrer.
    for (final referrer in Set.of(_referrers)) {
      if (referrer is AbstractObject) {
        referrer.removeReference(this);
      }
    }
    clearRelationships();
    assert(
      _referrers.isEmpty,
      'BUG: $isa $uuid still has referrers after removeFromProject: $_referrers',
    );
  }

  /// Called by [removeFromProject] on each referrer.
  /// Subclasses override to null out any typed field pointing to [obj].
  /// Port of (`remove_reference`).
  void removeReference(AbstractObject obj) {}

  /// Called by [removeFromProject] on `this`.
  /// Subclasses override to clear all own to_one / to_many references
  /// (which will trigger removeReferrer on the targets).
  /// Port of the relationship-clearing implicit in.
  void clearRelationships() {}

  /// Default display name: ISA with `PBX` or `XC` prefix stripped.
  /// Subclasses with a typed `name` field override to return name ?? super.displayName.
  /// Port of.
  String get displayName => isa.replaceFirst(RegExp(r'^(PBX|XC)'), '');

  /// Inline annotation written in ASCII plist after each UUID reference.
  /// Format: ` $displayName ` (with one space on each side).
  /// `PBXBuildFile` overrides to add ` in $parent ` suffix.
  /// Port of.
  String get asciiPlistAnnotation => ' $displayName ';

  /// The ordered list of plist attribute keys for this class.
  /// Base class returns const []. Each subclass overrides with:
  /// `[..._ownAttributes, ...super.attributeOrder]`
  /// — subclass attributes appear before superclass attributes.
  /// Port of.
  List<String> get attributeOrder => const [];

  /// Notify the project that something changed.
  /// Convenience for subclasses (calls [ObjectGraph.markDirty]).
  /// Port of (`mark_project_as_dirty!`).
  void markProjectAsDirty() => project.markDirty();

  // =============================================================================
  // Serialization (OBJ-02, OBJ-04)
  // =============================================================================

  /// Serialize this object to its plist dictionary form.
  /// Output shape:
  /// { 'isa': this.isa, ...attributes in attributeOrder }
  /// - `isa` is always first.
  /// - Simple attributes: value as-is (String, num, bool, List, Map). Null omitted.
  /// - to-one references: value = referenced obj.uuid (String). Null omitted.
  /// - to-many: value = `List<String>` of UUIDs. Always included (even if empty).
  /// - ObjectDictionary: value = dict.toHash().
  /// Stability: repeated calls return deeply-equal maps.
  /// Port of.
  Map<String, dynamic> toHash() {
    final hash = <String, dynamic>{'isa': isa};
    for (final key in attributeOrder) {
      serializeAttribute(key, hash);
    }
    return hash;
  }

  /// Recursive plist representation with referenced objects expanded inline.
  /// Output shape:
  /// { 'displayName': displayName, 'isa': isa, ...attributes recursively expanded }
  /// to-one and to-many reference values are replaced with the referenced
  /// object's toTreeHash() output (UUID-agnostic — used by the differ in ).
  /// Cycle guard: if a referenced object's uuid is already in [visited], the
  /// referenced value is replaced by `'<cycle: $uuid>'`.
  /// Stability: repeated calls return deeply-equal maps.
  /// Port of.
  Map<String, dynamic> toTreeHash([Set<String>? visited]) {
    final v = visited ?? <String>{};
    v.add(uuid);
    final hash = <String, dynamic>{'displayName': displayName, 'isa': isa};
    for (final key in attributeOrder) {
      serializeAttributeAsTree(key, hash, v);
    }
    return hash;
  }

  /// Pretty-printed representation for human inspection.
  /// Default: returns [displayName].
  /// Subclasses with a single to-many attribute override to return
  /// `{displayName: [children.prettyPrint()...]}`.
  /// Port of.
  dynamic prettyPrint() => displayName;

  /// Subclass hook: write the value of [key] into [into].
  /// Called by [toHash] for each key in [attributeOrder]. The default
  /// implementation does nothing — subclasses with attributes must override
  /// to switch on [key] and emit the appropriate value.
  /// Convention: omit null simple/to-one values; emit empty arrays for to-many.
  void serializeAttribute(String key, Map<String, dynamic> into) {}

  /// Subclass hook: write the recursively-expanded value of [key] into [into].
  /// Called by [toTreeHash]. The default implementation does nothing.
  /// Subclasses receive the [visited] set so they can pass it through when
  /// recursing on to-one / to-many references (cycle guard).
  void serializeAttributeAsTree(
    String key,
    Map<String, dynamic> into,
    Set<String> visited,
  ) {}

  // =============================================================================
  // Deserialization (OBJ-03)
  // =============================================================================

  /// Populate this object from the plist representation in [objectsByUuidPlist].
  /// [objectsByUuidPlist] is the full project's `objects` dictionary — the
  /// caller may need to recurse into other UUIDs to resolve to-one / to-many
  /// references (via [objectWithUuid]).
  /// Behaviour:
  /// 1. Fetch this UUID's plist dict and copy it (so we can track which keys
  /// were consumed).
  /// 2. Validate the `isa` key matches this object's class.
  /// 3. For each key in [attributeOrder]: if the working copy contains it,
  /// delegate to [readAttribute] and remove the key from the working copy.
  /// 4. After all attributes processed, if the working copy still has keys,
  /// emit a `developer.log` warning listing the unknown keys.
  /// Port of.
  void configureWithPlist(Map<String, dynamic> objectsByUuidPlist) {
    final raw = objectsByUuidPlist[uuid];
    if (raw is! Map) {
      throw StateError('No plist entry for UUID $uuid in objectsByUuidPlist');
    }
    final ownPlist = <String, dynamic>{};
    raw.forEach((k, v) => ownPlist[k.toString()] = v);

    // Validate ISA.
    final plistIsa = ownPlist['isa'];
    if (plistIsa != isa) {
      throw StateError(
        "ISA mismatch on UUID $uuid: object expects '$isa' but plist says '$plistIsa'",
      );
    }
    ownPlist.remove('isa');

    // Consume attributes in declared order.
    for (final key in attributeOrder) {
      if (ownPlist.containsKey(key)) {
        readAttribute(key, ownPlist[key], objectsByUuidPlist);
        ownPlist.remove(key);
      }
    }

    // Warn on leftover keys.
    if (ownPlist.isNotEmpty) {
      developer.log(
        "[dart_xcodeproj] $isa $uuid has unknown plist keys: ${ownPlist.keys.toList()}",
        name: 'dart_xcodeproj',
      );
    }
  }

  /// Subclass hook: consume the value of [key] from a plist into this object.
  /// Default implementation does nothing — subclasses with attributes
  /// override to switch on [key] and assign to typed fields.
  /// For to-one / to-many references, the subclass calls [objectWithUuid] to
  /// resolve UUID -> AbstractObject.
  void readAttribute(
    String key,
    dynamic value,
    Map<String, dynamic> objectsByUuidPlist,
  ) {}

  /// Resolve a UUID reference during plist loading.
  /// First checks [ObjectGraph.objectsByUuid] (memoized — avoids infinite
  /// recursion on cycles per ). If not yet constructed, dispatches
  /// through [objectFromPlist] which creates, registers, and configures the
  /// referenced object.
  /// Returns null if the referenced UUID has an unknown ISA.
  /// Port of `object_with_uuid` lines 349-363.
  AbstractObject? objectWithUuid(
    String refUuid,
    Map<String, dynamic> objectsByUuidPlist,
  ) {
    final existing = project.objectsByUuid[refUuid];
    if (existing != null) return existing;
    return objectFromPlist(refUuid, objectsByUuidPlist, project);
  }
}
