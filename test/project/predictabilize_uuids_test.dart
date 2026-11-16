// Tests for XcodeProject.predictabilizeUuids, the port of Ruby's
// `Project#predictabilize_uuids` (xcodeproj 1.27.0).

import 'package:dart_xcodeproj/src/project/uuid_generator.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:test/test.dart';

String _md5(String path) => UuidGenerator.generateDeterministic(path);

void main() {
  group('XcodeProject.predictabilizeUuids', () {
    test('derives the root and its to-one children from their path', () async {
      final project = await XcodeProject.create('/tmp/Test.xcodeproj');

      project.predictabilizeUuids();

      expect(project.rootObject.uuid, _md5('Test.xcodeproj'));
      expect(project.mainGroup.uuid, _md5('Test.xcodeproj/mainGroup'));
    });
  });
}
