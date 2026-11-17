# dart_xcodeproj

[![pub package](https://img.shields.io/pub/v/dart_xcodeproj.svg)](https://pub.dev/packages/dart_xcodeproj)
[![Build](https://github.com/AngeloAvv/dart_xcodeproj/actions/workflows/default.yml/badge.svg)](https://github.com/AngeloAvv/dart_xcodeproj/actions/workflows/default.yml)
[![codecov](https://codecov.io/gh/AngeloAvv/dart_xcodeproj/graph/badge.svg)](https://codecov.io/gh/AngeloAvv/dart_xcodeproj)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Dart library for parsing and working with Xcode projects. Manipulate
`.xcodeproj`, `.xcworkspace`, `.xcscheme`, and `.xcconfig` files from pure
Dart code — cross-platform (macOS, Windows, Linux), zero native code. Heavily
inspired by [CocoaPods/Xcodeproj](https://github.com/CocoaPods/Xcodeproj) and
[xcode](https://github.com/nicklockwood/SwiftFormat).

## Why

Flutter and Dart tools that touch Xcode projects often require external tooling
installed on every developer machine and every CI runner. `dart_xcodeproj`
removes that dependency: the same operations are available as a pure-Dart
library and CLI.

## Installation

```yaml
dependencies:
  dart_xcodeproj: ^0.4.0
```

Or via the command line:

```bash
dart pub add dart_xcodeproj
```

## Quick-start

```dart
import 'package:dart_xcodeproj/dart_xcodeproj.dart';

Future<void> main() async {
  // Open an existing project
  final project = await XcodeProject.open('ios/Runner.xcodeproj');

  // Inspect targets
  for (final target in project.targets) {
    print('Target: ${target.name}');
  }

  // Mutate + save
  project.newFile('Generated/AppConfig.swift');
  await project.save();
}
```

See [example/main.dart](example/main.dart) for a complete end-to-end
create-project / add-target / add-file / save workflow.

### Predictable UUIDs

`predictabilizeUuids()` replaces every UUID of a machine-generated project with
the MD5 of the structural path of its object (the output matches Ruby's
`Project#predictabilize_uuids` byte for byte). Regenerating the project gives
the same file only if everything the paths are made of is the same, including
the UUIDs held as strings (`containerPortal`, `remoteGlobalIDString`) of the
proxies of target dependencies, which are part of the path of a target:

```dart
final project = await XcodeProject.open('Pods/Pods.xcodeproj');
project.predictabilizeUuids();
await project.save();
```

Files outside the project that refer to its UUIDs are **not** rewritten: the
`BlueprintIdentifier` of the `BuildableReference`s in `.xcscheme` files keeps
pointing at the old UUIDs and must be regenerated or updated by the caller.

To create objects with stable UUIDs instead, pin them: `newObject` takes an
optional `uuid` (an invalid or already used one throws an `ArgumentError`), and
`UuidGenerator.deterministic` derives a 24 (or 32) char UUID from a seed.
Namespace the seeds, because the truncated 24 chars raise the collision odds:

```dart
final uuid = UuidGenerator.deterministic('my_tool/Runner/config');
final group = project.newObject((g, u) => PBXGroup(g, u), uuid: uuid);
```

### Common edits

```dart
// Groups and files
final group = project.mainGroup.findSubpath('Runner/Generated', create: true);
final ref = project.referenceForPath('/abs/path/to/AppConfig.swift');

// Build phases: found or created on demand, then fill them
final target = project.nativeTargets.first;
target.addFileReferences([if (ref != null) ref], compilerFlags: '-fobjc-arc');
final script = target.newShellScriptBuildPhase('Run Script');

// Build settings, per key or per configuration
target.buildConfigurationList?.setSetting('SWIFT_VERSION', '5.0');
target.buildSettings('Debug')?['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.example.app';
target.addBuildConfiguration('Staging', BuildConfigType.release);

// Scheme actions: getters return the typed action, setters replace it
final scheme = await XCScheme.open('Runner.xcscheme');
scheme.launchAction.buildConfiguration = 'Debug-dev';
scheme.testAction = scheme.testAction; // attach a default action if missing
```

A scheme getter does not add a missing action to the document: assign it, as
above, to save it.

## Library API overview

| Type | Purpose |
|------|---------|
| `XcodeProject` | Open, create, mutate, and save `.xcodeproj` files: `newObject` (optionally with a pinned `uuid`), `predictabilizeUuids`, `nativeTargets`, `referenceForPath` |
| `ProjectHelper` | High-level helpers: `newTarget`, `newResourcesBundle`, `newAggregateTarget` |
| `XCWorkspace` | Read and write `.xcworkspace` files |
| `XCScheme` | Read and write `.xcscheme` files; typed `buildAction`, `testAction`, `launchAction`, `profileAction`, `analyzeAction` and `archiveAction` getters and setters |
| `XcConfig` | Read, merge, and write `.xcconfig` files |
| `Differ` | UUID-agnostic recursive diff between two projects |
| `UuidGenerator` | Generate uppercase hex UUIDs: random (24 chars) and deterministic from a seed (24 or 32 chars), and the structural paths `XcodeProject.predictabilizeUuids` derives them from |
| `Constants` | Xcode file types, product types, SDK versions, and more |
| `OtherLinkerFlagsParser` | Parse `OTHER_LDFLAGS`-style settings |
| `PBXNativeTarget` | Native app/framework/library target: `sourceBuildPhase` and the other find-or-create phases, `addFileReferences`, `addResources`, `newShellScriptBuildPhase`, `newCopyFilesBuildPhase`, `buildSettings(name)`, `addBuildConfiguration` |
| `PBXAggregateTarget` | Aggregate (script-only) target |
| `PBXFileReference` | File reference in the project navigator |
| `PBXGroup` | Group in the project navigator: `findSubpath`, `findFileByPath`, `recursiveChildren` |
| `XCBuildConfiguration` | A single named build configuration |
| `XCConfigurationList` | The list of build configurations for a target or project: `setSetting`, `buildSettings(name)` |

## CLI usage

The package ships a `dart_xcodeproj` executable with four subcommands.

Install globally:

```bash
dart pub global activate dart_xcodeproj
```

### `show` — print a project as YAML

```bash
dart run dart_xcodeproj show path/to/Runner.xcodeproj
dart run dart_xcodeproj show --format=tree_hash path/to/Runner.xcodeproj
```

Format options: `hash`, `tree_hash`, `raw`. Default is a structured
pretty-print.

### `sort` — sort groups and files in place

```bash
dart run dart_xcodeproj sort path/to/Runner.xcodeproj
dart run dart_xcodeproj sort --group-option=above path/to/Runner.xcodeproj
```

Group option: `above` (groups first), `below` (groups last). Omit for
interleaved order.

### `project-diff` — UUID-agnostic diff between two projects

```bash
dart run dart_xcodeproj project-diff P1.xcodeproj P2.xcodeproj
dart run dart_xcodeproj project-diff -i path -i sourceTree P1.xcodeproj P2.xcodeproj
```

Array ordering is ignored. Repeat `--ignore=KEY` (or `-i KEY`) to suppress
specific keys from the comparison.

### `config-dump` — write per-target xcconfig files

```bash
dart run dart_xcodeproj config-dump path/to/Runner.xcodeproj ./out
```

Writes one directory per target under the output directory, each containing
a `{Target}_base.xcconfig` with common settings and one
`{Target}_{configuration}.xcconfig` per build configuration. The source
project is not modified.

## Platform support

Pure Dart. Runs on macOS, Linux, and Windows. No native code, no FFI, no
`xcodebuild` calls — every operation is on-disk file manipulation.

## License

MIT — see [LICENSE](LICENSE).
