// The group and project lookups must give what xcodeproj's give.
//
// `test/fixtures/lookups/expected.json` holds, per case, the result Ruby
// returns for the same call on the same project (see generate.rb in that
// directory, which also names the gem versions). Each case is run here on a
// fresh copy of its fixture: the pristine `flutter create` projects in
// test/fixtures/annotations/ and lookups.pbxproj, a hand-made project with
// duplicated names, a name that is both a file and a group, nameless groups,
// files without a path and so on. A result is an object of the fixture by its
// UUID, an object the call created by its attributes, a list of them, `null`,
// or the class of the error Ruby raises. Calls that change the project are
// also compared on the group tree and the object counts afterwards.

import 'dart:convert';
import 'dart:io';

import 'package:dart_xcodeproj/src/object/abstract_object.dart';
import 'package:dart_xcodeproj/src/pbx/group.dart';
import 'package:dart_xcodeproj/src/pbx/groupable_helper.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_build_file.dart';
import 'package:dart_xcodeproj/src/pbx/pbx_file_reference.dart';
import 'package:dart_xcodeproj/src/project/xcode_project.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _dir = 'test/fixtures/lookups';

const _inputs = {
  'ios': 'test/fixtures/annotations/ios.xcodeproj/project.pbxproj',
  'macos': 'test/fixtures/annotations/macos.xcodeproj/project.pbxproj',
  'ios_spm': 'test/fixtures/annotations/ios_spm.xcodeproj/project.pbxproj',
  'macos_spm': 'test/fixtures/annotations/macos_spm.xcodeproj/project.pbxproj',
  'edge': 'test/fixtures/annotations/edge.xcodeproj/project.pbxproj',
  'lookups': '$_dir/lookups.pbxproj',
};

/// The operations this file knows how to run; the cases of any other are
/// skipped.
final _handlers = <String, dynamic Function(_Run)>{
  'recursiveChildren': (run) => (run.receiver as PBXGroup).recursiveChildren,
  'findFileByPath': (run) =>
      (run.receiver as PBXGroup).findFileByPath(run.args['path'] as String),
  'findSubpath': (run) => (run.receiver as PBXGroup).findSubpath(
    run.args['path'] as String?,
    create: run.args['create'] as bool,
  ),
  'clear': (run) {
    (run.receiver as PBXGroup).clear();
    return null;
  },
  'removeChildrenRecursively': (run) {
    (run.receiver as PBXGroup).removeChildrenRecursively();
    return null;
  },
  'nativeTargets': (run) => run.project.nativeTargets,
  'referenceForPath': (run) => run.project.referenceForPath(
    (run.args['path'] as String)
        .replaceFirst('<DIR>', run.dir)
        .replaceFirst('<PARENT>', p.dirname(run.dir)),
  ),
  // Compared as a map of UUID to the path with the directory of the project as
  // `<DIR>`; Ruby's `Pathname('')` is `''`.
  'realPaths': (run) => {
    for (final file in run.project.files)
      file.uuid: (GroupableHelper.realPath(file, run.project) ?? '')
          .replaceFirst(run.dir, '<DIR>')
          .replaceFirst(p.dirname(run.dir), '<PARENT>'),
  },
  // The order of `project.objects`: what a `find` over the objects returns
  // first.
  'objectsOrder': (run) => run.project.objectsByUuid.keys.toList(),
  // Ruby's order is the one referrers were added in; it is not compared.
  'buildFiles': (run) => [
    ...(run.receiver is PBXGroup
        ? (run.receiver as PBXGroup).buildFiles
        : (run.receiver as PBXFileReference).buildFiles),
  ]..sort((a, b) => a.uuid.compareTo(b.uuid)),
};

/// A fixture opened from a `Runner.xcodeproj` bundle in a fresh directory.
class _Run {
  _Run(this.project, this.dir, this.receiver, this.args);

  final XcodeProject project;
  final String dir;
  final AbstractObject receiver;
  final Map<String, dynamic> args;
}

Future<XcodeProject> _open(String fixture, Directory tmp) async {
  final bundle = Directory('${tmp.path}/dir/Runner.xcodeproj')
    ..createSync(recursive: true);
  File(_inputs[fixture]!).copySync('${bundle.path}/project.pbxproj');
  return XcodeProject.open(bundle.path);
}

/// The same description of an object `dump_tree` writes in generate.rb.
Map<String, dynamic> _dumpTree(AbstractObject object) {
  dynamic attribute(dynamic Function(dynamic) read) {
    try {
      return read(object);
    } on NoSuchMethodError {
      return null;
    }
  }

  return {
    'isa': object.isa,
    'name': attribute((o) => o.name),
    'path': attribute((o) => o.path),
    'sourceTree': attribute((o) => o.sourceTree),
    if (object is PBXGroup)
      'children': [for (final child in object.children) _dumpTree(child)],
  };
}

/// [value] as the expectations record it: an object of the fixture by UUID,
/// an object created by the call by its attributes.
dynamic _encode(dynamic value, Set<String> known) {
  if (value == null) return null;
  if (value is Iterable) return [for (final v in value) _encode(v, known)];
  if (value is AbstractObject) {
    return known.contains(value.uuid)
        ? {'uuid': value.uuid}
        : {'created': _dumpTree(value)};
  }
  return value;
}

/// The operations that remove objects.
const _removes = {'clear', 'removeChildrenRecursively'};

/// Ruby removes the children of a group and the build files of the group
/// itself, but leaves the build files of the removed descendants behind, and
/// with them the file references and groups (variant groups) those keep
/// alive, without a parent. Dart removes the build files of the descendants
/// too (see `PBXGroup.removeFromProject`), so it ends up with fewer objects,
/// and exactly those orphans are the difference.
void _expectRemovalLikeRuby(Map<String, int> dart, Map<String, int> ruby) {
  var orphans = 0;
  for (final kind in ['buildFiles', 'fileReferences', 'groups']) {
    final difference = ruby[kind]! - dart[kind]!;
    expect(difference, greaterThanOrEqualTo(0), reason: kind);
    orphans += difference;
  }
  expect(ruby['objects']! - dart['objects']!, orphans);
}

Map<String, int> _counts(XcodeProject project) => {
  'objects': project.objectsByUuid.length,
  'buildFiles': project.objectsByUuid.values.whereType<PBXBuildFile>().length,
  'fileReferences': project.objectsByUuid.values
      .whereType<PBXFileReference>()
      .length,
  'groups': project.objectsByUuid.values.whereType<PBXGroup>().length,
};

void main() {
  final expected =
      jsonDecode(File('$_dir/expected.json').readAsStringSync())
          as Map<String, dynamic>;
  final cases = (expected['cases'] as List).cast<Map<String, dynamic>>();

  for (final entry in _handlers.entries) {
    group(entry.key, () {
      for (final c in cases.where((c) => c['op'] == entry.key)) {
        test(c['id'] as String, () async {
          final tmp = Directory.systemTemp.createTempSync('lookups_');
          addTearDown(() => tmp.deleteSync(recursive: true));
          final project = await _open(c['fixture'] as String, tmp);
          final known = project.objectsByUuid.keys.toSet();
          final receiverUuid = c['receiver'] as String?;
          final receiver = receiverUuid == null
              ? project.mainGroup
              : project.objectsByUuid[receiverUuid]!;
          final run = _Run(
            project,
            '${tmp.path}/dir',
            receiver,
            (c['args'] as Map?)?.cast<String, dynamic>() ?? const {},
          );

          if (c.containsKey('error')) {
            // Ruby's NoMethodError (a name that is not a group) is a StateError.
            expect(
              () => entry.value(run),
              c['error'] == 'NoMethodError'
                  ? throwsStateError
                  : throwsArgumentError,
            );
          } else {
            expect(_encode(entry.value(run), known), c['result']);
          }
          if (c.containsKey('counts')) {
            final counts = _counts(project);
            final ruby = (c['counts'] as Map).cast<String, int>();
            if (_removes.contains(entry.key)) {
              _expectRemovalLikeRuby(counts, ruby);
            } else {
              expect(counts, ruby);
            }
          }
          if (c.containsKey('tree')) {
            expect(_dumpTree(project.mainGroup), c['tree']);
          }
        });
      }
    });
  }
}
