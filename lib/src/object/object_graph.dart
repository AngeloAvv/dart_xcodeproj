import 'abstract_object.dart';

/// Minimal contract that [AbstractObject] requires from the owning project.
/// [XcodeProject] extends this. defines the interface only.
/// Port of the three operations AbstractObject calls on `project`
/// - objects_by_uuid[uuid] = self (line 201)
/// - objects_by_uuid.delete(uuid) (line 218)
/// - mark_project_as_dirty! (line 216)
abstract class ObjectGraph {
  /// All objects currently registered, keyed by UUID.
  /// Objects enter via [AbstractObject.addReferrer]; leave when last referrer dropped.
  Map<String, AbstractObject> get objectsByUuid;

  /// Mark the project as having unsaved changes.
  /// Called by every mutation that changes the object graph.
  void markDirty();

  /// Create a new object, assign a UUID, call `initializeDefaults()`.
  /// Does NOT register in [objectsByUuid] — registration happens via
  /// [AbstractObject.addReferrer] when the new object is first referenced.
  T newObject<T extends AbstractObject>(
    T Function(ObjectGraph, String) factory,
  );

  /// The plist object version string (e.g., '54').
  /// Used by [XCBuildConfiguration._normalizeArraySettings] to select the correct
  /// ARRAY_SETTINGS set for round-trip fidelity (Xcode 10+ uses v50+).
  /// tests use a mock that returns '46' (pre-v50 default).
  String get objectVersion;
}
