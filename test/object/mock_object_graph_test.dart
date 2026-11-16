// The MockObjectGraph stands in for XcodeProject in the object-layer tests, so
// its newObject has to honour the same supplied-UUID contract: otherwise a
// test could pass with the mock where the real project throws.

import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:test/test.dart';

import 'helpers/mock_object_graph.dart';

void main() {
  late MockObjectGraph graph;

  setUp(() => graph = MockObjectGraph());

  group('MockObjectGraph.newObject with a supplied uuid', () {
    test('uses a valid uuid that is not taken', () {
      final object = graph.newObject(
        (g, u) => PBXFileReference(g, u),
        uuid: 'A' * 24,
      );

      expect(object.uuid, 'A' * 24);
    });

    test('rejects a uuid that is not valid', () {
      expect(
        () => graph.newObject((g, u) => PBXFileReference(g, u), uuid: 'nope'),
        throwsArgumentError,
      );
    });

    test('rejects a uuid already present, and keeps the registered object', () {
      final existing = PBXFileReference(graph, 'B' * 24);
      graph.objectsByUuid[existing.uuid] = existing;

      expect(
        () => graph.newObject((g, u) => PBXFileReference(g, u), uuid: 'B' * 24),
        throwsArgumentError,
      );
      expect(graph.objectsByUuid['B' * 24], same(existing));
    });

    test('still generates a uuid when none is supplied', () {
      final object = graph.newObject((g, u) => PBXFileReference(g, u));

      expect(object.uuid, isNotEmpty);
    });
  });
}
