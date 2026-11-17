# Lookup fixtures

Expected results of the group and project lookups of the Ruby reference
implementation, used by `test/project/lookups_ruby_parity_test.dart`:

- `findSubpath`, `findFileByPath`, `recursiveChildren`, `clear` /
  `removeChildrenRecursively` and `buildFiles` of `PBXGroup`, and
  `buildFiles` of `PBXFileReference`;
- `XcodeProject.referenceForPath` and `nativeTargets`;
- `GroupableHelper.realPath` of every file reference (what `referenceForPath`
  compares), and the order of `project.objects` (what its `find` returns first).

Everything here was produced by the Ruby reference implementation, never by
Dart.

## Regenerating

From the repository root:

```sh
ruby test/fixtures/lookups/generate.rb                           # gem 1.27.0 (default)
XCODEPROJ_GEM_VERSION=1.28.1 ruby test/fixtures/lookups/generate.rb
ruby test/fixtures/lookups/generate.rb --rebuild-input           # also rewrites lookups.pbxproj
```

It writes `expected.json`: one case per call, with the project it runs on, the
receiver, the arguments, and what Ruby returns (objects of the fixture by UUID,
objects Ruby creates by their attributes, `null`, or the class of the error it
raises). The calls that change the project also record the group tree and the
count of objects, build files, file references and groups afterwards. Each case
opens the project from a bundle named `Runner.xcodeproj` in a fresh temporary
directory (`<DIR>` in the paths, `<PARENT>` for the directory that holds it).

The committed `expected.json` was generated with the `xcodeproj` gem
**1.27.0**. Gem **1.28.1** generates the very same file (compared with `diff`
apart from the `gem` field): `group.rb` and `project.rb` are identical in both
versions.

| Input | From |
|-------|------|
| `ios`, `macos`, `ios_spm`, `macos_spm`, `edge` | `test/fixtures/annotations/<name>.xcodeproj`: the pristine `flutter create` projects and the hand-written edge cases |
| `lookups` | `lookups.pbxproj`: the macOS project plus what the Flutter ones lack, written once by `generate.rb` and committed so that its UUIDs stay |

`lookups.pbxproj` adds: two groups named `Dup` (each with a group `Inner` and a
file `same.swift`), a file and then a group both named `Shadow`, a group
without name and path, a group whose only file has neither name nor path
(also a `nil` `display_name`), a file without path, a version group, files in the
`SOURCE_ROOT`, `<absolute>` and `SDKROOT` source trees (one of them with the
same real path as a file in a group), files whose paths have `.`, `..` and
`//`, a group anchored at `SOURCE_ROOT`, and build files for one file in two
build phases.

## What the cases show

- `find_subpath` matches the children against `display_name`, which for a group
  is `name`, else the basename of `path`, else **`nil`** (not `Group`): the
  empty path (`''`, `'/'`) finds a group without name and path, and creates one
  with `create`. `String#split('/')` drops the trailing empty names (`Runner/`
  is `Runner`) and keeps the leading ones (`/Runner` looks for a child named
  `''`). The first child that matches wins, a file as well as a group, and a
  name in the middle that is a file raises `NoMethodError`.
- `reference_for_path` raises `ArgumentError` for a relative path and compares
  the path as it is given, so a trailing `/`, `./` or `..` never matches;
  `real_path` is `Pathname#+`, which resolves the leading `..` of a path
  against its source tree (`Runner/..` + `Runner/Assets.xcassets` is
  `Runner/Assets.xcassets`). Among duplicates `objects.find` returns the first in
  load order, which is depth first from the root object, with the plain
  attributes read before the to-one references and those before the to-many.
- `clear` removes the children of a group with `remove_from_project`, which
  does not remove the build files of the *descendants*: Ruby leaves them, and
  the file references and variant groups they keep alive, without a parent.
  Dart removes them too (`PBXGroup.removeFromProject`), so the test only
  expects the difference to be those orphans.
- Known differences that the cases do not cover: Ruby loads only the objects
  the root reaches, Dart also keeps the unreachable ones (after the others), so
  a stale file reference can match `referenceForPath` in Dart only; and Ruby
  raises where an object has no parent while `GroupableHelper.parent` returns
  `null` (taken as the main group).
