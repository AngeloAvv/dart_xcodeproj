// Shared MockObjectGraph for all object-layer tests.
// Used by: abstract_object_test.dart, object_list_test.dart,
// object_dictionary_test.dart, isa_registry_test.dart, serialization_test.dart

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/object/object_graph.dart';
import 'package:dart_xcodeproj/src/project/uuid_generator.dart';

/// In-memory [ObjectGraph] implementation used by tests.
/// Per : AbstractObject is testable in isolation without .
class MockObjectGraph implements ObjectGraph {
  @override
  final Map<String, AbstractObject> objectsByUuid = {};

  /// Set to true by [markDirty]; tests assert against this directly.
  bool isDirty = false;

  /// Default object version for tests — pre-v50 (Xcode < 10) to use the
  /// default ARRAY_SETTINGS set. Override in tests that need v50+ behavior.
  @override
  String objectVersion = '46';

  @override
  void markDirty() => isDirty = true;

  @override
  T newObject<T extends AbstractObject>(
    T Function(ObjectGraph, String) factory, {
    String? uuid,
  }) {
    // Same contract as XcodeProject.newObject, so a test cannot pass here where
    // the real project would throw.
    if (uuid != null) {
      if (!UuidGenerator.isValid(uuid)) {
        throw ArgumentError.value(uuid, 'uuid', 'not a valid Xcode UUID');
      }
      final existing = objectsByUuid[uuid];
      if (existing != null) {
        throw ArgumentError.value(
          uuid,
          'uuid',
          'already used by ${existing.isa} in this graph',
        );
      }
    }
    final obj = factory(this, uuid ?? UuidGenerator.generate());
    obj.initializeDefaults();
    return obj;
  }

  /// Resets state between tests.
  void reset() {
    objectsByUuid.clear();
    isDirty = false;
  }
}
