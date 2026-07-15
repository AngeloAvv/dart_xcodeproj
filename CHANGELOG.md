# Changelog

## 0.3.0

### Bug Fixes

- `EnvironmentVariables.assignVariable` and `CommandLineArguments.assignArgument` now replace any existing entry with the same key/argument instead of appending a duplicate, matching xcodeproj's update-by-key semantics

### Features

- `TestAction` now exposes `macroExpansions` and `addMacroExpansion`, matching CocoaPods xcodeproj's `TestAction#add_macro_expansion` (inserted before `Testables` when present)
- `ShellScriptActionContent` now exposes `buildableReference` (get/set), matching xcodeproj's `ShellScriptActionContent#buildable_reference`, so a pre/post-build shell script can run within a specific target's build environment
- `TestAction` now exposes `codeCoverageTargets`/`addCodeCoverageTarget`, matching xcodeproj's per-target code coverage filtering (flips `onlyGenerateCoverageForSpecifiedTargets`)
- `TestableReference` now exposes `parallelizable`, `testExecutionOrdering`/`randomized`, `skippedTests`/`addSkippedTest`, `selectedTests`/`addSelectedTest`, `useTestSelectionWhitelist`, and `removeBuildableReference`, matching xcodeproj's test-selection and execution controls

## 0.2.0

- Updated `propertylistserialization` and `xml` dependencies to latest versions

## 0.1.1

### Bug Fixes

- Export all scheme types from public barrel (`BuildableProductRunnable`, `BuildableReference`, `BuildAction`, `LaunchAction`, `TestAction`, `AnalyzeAction`, `ArchiveAction`, `ProfileAction`, and related types)

## 0.1.0

Initial release. Dart library for parsing and working with Xcode projects, heavily inspired by CocoaPods XcodeProj and xcode.

### Features

- ASCII plist read/write with byte-identical round-trip
- Full PBX object model (25+ ISA types) with reference counting
- `XcodeProject` open / create / mutate / save
- `XCWorkspace`, `XCScheme`, `XcConfig` read/write
- UUID-agnostic `Differ` for project comparison
- CLI: `show`, `sort`, `project-diff`, `config-dump`
- Zero native code; runs on macOS, Linux, Windows
