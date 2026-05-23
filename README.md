# dart_xcodeproj

[![pub package](https://img.shields.io/pub/v/dart_xcodeproj.svg)](https://pub.dev/packages/dart_xcodeproj)
[![Build](https://github.com/AngeloAvv/dart_xcodeproj/actions/workflows/default.yml/badge.svg)](https://github.com/AngeloAvv/dart_xcodeproj/actions/workflows/default.yml)
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
  dart_xcodeproj: ^0.1.0
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

## Library API overview

| Type | Purpose |
|------|---------|
| `XcodeProject` | Open, create, mutate, and save `.xcodeproj` files |
| `ProjectHelper` | High-level helpers: `newTarget`, `newResourcesBundle`, `newAggregateTarget` |
| `XCWorkspace` | Read and write `.xcworkspace` files |
| `XCScheme` | Read and write `.xcscheme` files |
| `XcConfig` | Read, merge, and write `.xcconfig` files |
| `Differ` | UUID-agnostic recursive diff between two projects |
| `UuidGenerator` | Generate 24-char uppercase hex UUIDs (random + deterministic) |
| `Constants` | Xcode file types, product types, SDK versions, and more |
| `OtherLinkerFlagsParser` | Parse `OTHER_LDFLAGS`-style settings |
| `PBXNativeTarget` | Native app/framework/library target |
| `PBXAggregateTarget` | Aggregate (script-only) target |
| `PBXFileReference` | File reference in the project navigator |
| `PBXGroup` | Group in the project navigator |
| `XCBuildConfiguration` | A single named build configuration |
| `XCConfigurationList` | The list of build configurations for a target or project |

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
