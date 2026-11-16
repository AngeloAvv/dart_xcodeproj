# Changelog

## Unreleased

### Bug Fixes

- Saving a project no longer guesses `/* ... */` annotations from the shape of strings: the pbxproj writer prints only the annotations carried by the object model, like Ruby's `Project#to_ascii_plist`. String attributes that hold a UUID (`remoteGlobalIDString`, `TestTargetID`) are no longer annotated, and an open + save of a pristine Flutter iOS/macOS project now matches what Ruby writes
- `PBXReferenceProxy` annotates `path` by its basename, `XCConfigurationList` reads `Build configuration list for <isa> "<name>"` from its owner, and `XCBuildConfiguration.displayName` is its `name`
- `PBXTargetDependency.displayName` falls back to the proxy's `remoteInfo` (a dependency on a target of another project), and `PBXBuildRule.displayName` is its `name`, like Ruby's `display_name`
- `XCScheme.buildAction`, `testAction`, `launchAction`, `profileAction`, `analyzeAction` and `archiveAction` no longer add an element to the document when the scheme lacks it. Like Ruby's `XCScheme#launch_action` and friends they return a default action that is not saved until it is assigned, and the same instance on every call, so reading a getter never changes what `save` writes. Code that relied on the getter attaching the missing element must now assign it (`scheme.testAction = scheme.testAction`)

### Features

- `AbstractObject.toAsciiPlist()` / `toAsciiPlistHash()` and the `AnnotatedString` / `AnnotatedDictionary` plist nodes, which `AsciiPlistWriter` prints annotations from. `AbstractObject.asciiPlistAnnotation` is now `String?`: `null` (no annotation) for the main group. `AsciiPlistWriter.write` given a plain map no longer annotates anything
- `PBXProject.name`, `PBXContainerItemProxy.isRemote` and `PBXGroup.isMainGroup`
- `XcodeProject.newObject` (and `ObjectGraph.newObject`) now takes an optional `uuid` so tools that create objects idempotently can pin stable UUIDs. A UUID that is invalid per `UuidGenerator.isValid` or already present in `objectsByUuid` throws an `ArgumentError` and never replaces the registered object; without `uuid` a generated one is used as before. Classes implementing `ObjectGraph` must accept the new parameter. This is new API: Ruby only offers the private `Klass.new(project, uuid)`
- `UuidGenerator.deterministic(seed, {length = 24})` returns the first 24 or 32 uppercase hex characters of the MD5 of `seed`, so tools can create stable, Xcode-looking 24-char UUIDs. With `length: 32` it equals `generateDeterministic` (Ruby's `uuid_for_path`); any other length throws an `ArgumentError`. Truncation raises the collision odds, so namespace seeds, e.g. `tool/<target>/<thing>`
- `XcodeProject.predictabilizeUuids()` replaces every UUID of the project with the MD5 of the structural path of its object, ported from Ruby's `Project#predictabilize_uuids` (the saved file is byte-identical to xcodeproj's on the Flutter iOS and macOS projects). Object references, `containerPortal`, `remoteGlobalIDString` and the `TargetAttributes` keys and `TestTargetID`s are rewritten together, so no UUID is left dangling. Files outside the project that refer to its UUIDs, such as the `BlueprintIdentifier` of a scheme, are not rewritten. Objects with the same path share a UUID (a warning is logged), and objects the root cannot reach keep theirs (a `StateError` is thrown, and the project left as it was, if one of them already has the UUID a reachable object would get). The paths include the build settings as they are in the model (a space separated string stays one, like Ruby) and the UUIDs held as strings by the proxies of target dependencies, so the output is reproducible only if those are
- `UuidGenerator.structuralPaths` returns the structural path of every object of a project, and `AbstractObject.toManyAttributeKeys` / `referencesByKeysAttributeKeys` expose the plist keys those paths are made of
- `XCScheme.buildAction`, `testAction`, `launchAction`, `profileAction`, `analyzeAction` and `archiveAction` now have setters, like Ruby's `XCScheme#launch_action=` and friends: the first existing element is removed and the action is appended to `<Scheme>` (a copy, if it already belongs to a document). The getters return the typed actions, so `scheme.launchAction.buildConfiguration = 'Debug-dev'` changes only that attribute and keeps every other attribute, `PreActions`/`PostActions` and unknown child element as they were. Checked against the typed getters of Ruby's xcodeproj 1.27.0 and 1.28.1 on the Flutter iOS and macOS schemes, and on schemes with missing or repeated actions and on schemes with `PreActions`/`PostActions`
- Dartdoc for the public members of `LaunchAction`, `TestAction`, `ProfileAction`, `AnalyzeAction` and `ArchiveAction`

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
