# Changelog

## 0.4.0

### Breaking Changes

- `XCScheme.buildAction`, `testAction`, `launchAction`, `profileAction`, `analyzeAction` and `archiveAction` no longer add an element to the document when the scheme lacks it. Like Ruby's `XCScheme#launch_action` and friends they return a default action that is not saved until it is assigned, and the same instance on every call, so reading a getter never changes what `save` writes. Code that relied on the getter attaching the missing element must now assign it (`scheme.testAction = scheme.testAction`)
- `ObjectGraph.newObject` takes a new optional `uuid` parameter (see Features): classes implementing `ObjectGraph` must accept it
- `AbstractObject.asciiPlistAnnotation` is now `String?`: `null` (no annotation) for the main group. `AsciiPlistWriter.write` given a plain map no longer annotates anything, only the annotated nodes of `AbstractObject.toAsciiPlist()` are printed
- `XCConfigurationList.getSetting` returns `Map<String, dynamic>` (was `Map<String, String?>`), `AbstractTarget.resolvedBuildSetting` returns `Map<String, dynamic>` and `commonResolvedBuildSetting` returns `dynamic`, because array settings such as `LD_RUNPATH_SEARCH_PATHS` are returned as lists instead of throwing a `TypeError`. Code that assigned the result to a `String?` map or value needs a cast
- `AbstractObject.removeReference` is no longer a no-op: it is generic, driven by the new `toOneAttributes`, `toManyAttributes` and `referencesByKeysAttributes` hooks. A subclass of `AbstractObject` that holds references and overrode `removeReference` should declare its attributes through these hooks (subclasses append to `super`'s lists) instead
- The saved output of a project can change: pbxproj annotations now come only from the object model, objects are registered in Ruby's load order, and removing a file reference, group or reference proxy removes its build files too (see Bug Fixes)

### Bug Fixes

- `XCScheme` output is well-formed XML: `SchemeXmlFormatter` escapes `& < > "` in attribute values (and `\n`, `\r`, `\t` as `&#10;`, `&#13;`, `&#9;`) and keeps comments and non-blank text nodes, so opening and saving a pristine Flutter `Runner.xcscheme` (whose PreAction `scriptText` has `&quot;` / `&#10;`) round-trips byte-identically. Entities beyond those, such as `&apos;`, are decoded by the XML parser instead of preserved verbatim, which is equivalent
- Saving a project no longer guesses `/* ... */` annotations from the shape of strings: the pbxproj writer prints only the annotations carried by the object model, like Ruby's `Project#to_ascii_plist`. String attributes that hold a UUID (`remoteGlobalIDString`, `TestTargetID`) are no longer annotated, and an open + save of a pristine Flutter iOS/macOS project now matches what Ruby writes
- `PBXReferenceProxy` annotates `path` by its basename, `XCConfigurationList` reads `Build configuration list for <isa> "<name>"` from its owner, and `XCBuildConfiguration.displayName` is its `name`
- `PBXTargetDependency.displayName` falls back to the proxy's `remoteInfo` (a dependency on a target of another project), and `PBXBuildRule.displayName` is its `name`, like Ruby's `display_name`
- `UuidGenerator.isValid` accepts the 32-char uppercase hex UUIDs that `predictabilizeUuids` and CocoaPods write (and `generateDeterministic` returns), next to the 24-char ones, so such projects keep their annotations. RFC4122, lowercase, non-hex and other lengths are still rejected
- Batches of random UUIDs exclude the ones already in `objectsByUuid` (and the ones already generated), like Ruby's `generate_available_uuid_list`, so a collision can no longer replace an existing object. `UuidGenerator.generate` takes an optional `random` and `XcodeProject.uuidRandom` lets tests inject one
- `AbstractObject.removeReference` removes the object from the to-one, to-many and dictionary attributes that point to it, like Ruby's `remove_reference`. `buildFile.removeFromProject()` no longer leaves its UUID in the `files` of the build phase (it was written to disk), and removing an object held in `PBXProject.projectReferences` no longer leaves the project among its referrers
- `PBXFileReference.removeFromProject` and `PBXReferenceProxy.removeFromProject` remove their build files first (and so their entry in the build phases) instead of leaving an empty `{isa = PBXBuildFile; }` behind; the container proxy of a reference proxy goes with it once nothing else refers to it. `PBXGroup.removeFromProject` (also `PBXVariantGroup` and `XCVersionGroup`) clears the group, so its descendants go too, and removes the build files that point to the group or to them. Unlike Ruby, which only removes the group's own build files, the build files of the descendants are removed as well
- `XCConfigurationList.getSetting` (and so `resolvedBuildSetting` and `commonResolvedBuildSetting`) no longer throws a `TypeError` on array-valued settings such as `LD_RUNPATH_SEARCH_PATHS` or `OTHER_LDFLAGS`; `$(inherited)` is spliced into array values and values are de-duplicated with deep equality, like Ruby
- `GroupableHelper.realPath` resolves the leading `.` and `..` of a path against its source tree like Ruby's `Pathname#+` (`<DIR>/Runner` + `../Flutter/x` is `<DIR>/Flutter/x`, not `<DIR>/Runner/../Flutter/x`)
- `AbstractTarget.resolvedBuildSetting` (and so `commonResolvedBuildSetting`) includes the configurations only the project has, with the project value, like Ruby's `Hash#merge`: a target with `Debug` and `Release` in a project that also has `Profile` now sees the three, and the consistency check of `commonResolvedBuildSetting` counts the project's `Profile` value too
- `XcodeProject.open` registers the objects in the order Ruby loads them (depth first from the root object, plain attributes before to-one before to-many references), so `objectsByUuid`, `files` and `groups` list them in that order. Objects the root does not reach come last
- A new `PBXShellScriptBuildPhase` has Ruby's placeholder script (`# Type a script or drag a script file from your workspace to insert its path.`) instead of `# Type a script...`

### Features

- Annotated plist output: `AbstractObject.toAsciiPlist()` / `toAsciiPlistHash()` and the `AnnotatedString` / `AnnotatedDictionary` plist nodes, which `AsciiPlistWriter` prints annotations from
- `PBXProject.name`, `PBXContainerItemProxy.isRemote` and `PBXGroup.isMainGroup`
- `XcodeProject.newObject` (and `ObjectGraph.newObject`) takes an optional `uuid` so tools that create objects idempotently can pin stable UUIDs. A UUID that is invalid per `UuidGenerator.isValid` or already present in `objectsByUuid` throws an `ArgumentError` and never replaces the registered object; without `uuid` a generated one is used as before. This is new API: Ruby only offers the private `Klass.new(project, uuid)`
- `UuidGenerator.deterministic(seed, {length = 24})` returns the first 24 or 32 uppercase hex characters of the MD5 of `seed`, so tools can create stable, Xcode-looking 24-char UUIDs. With `length: 32` it equals `generateDeterministic` (Ruby's `uuid_for_path`); any other length throws an `ArgumentError`. Truncation raises the collision odds, so namespace seeds, e.g. `tool/<target>/<thing>`
- `XcodeProject.predictabilizeUuids()` replaces every UUID of the project with the MD5 of the structural path of its object, ported from Ruby's `Project#predictabilize_uuids` (the saved file is byte-identical to xcodeproj's on the Flutter iOS and macOS projects). Object references, `containerPortal`, `remoteGlobalIDString` and the `TargetAttributes` keys and `TestTargetID`s are rewritten together, so no UUID is left dangling. Files outside the project that refer to its UUIDs, such as the `BlueprintIdentifier` of a scheme, are not rewritten. Objects with the same path share a UUID (a warning is logged), and objects the root cannot reach keep theirs (a `StateError` is thrown, and the project left as it was, if one of them already has the UUID a reachable object would get). The paths include the build settings as they are in the model (a space separated string stays one, like Ruby) and the UUIDs held as strings by the proxies of target dependencies, so the output is reproducible only if those are
- `UuidGenerator.structuralPaths` returns the structural path of every object of a project, and `AbstractObject.toManyAttributeKeys` / `referencesByKeysAttributeKeys` expose the plist keys those paths are made of
- `PBXNativeTarget.sourceBuildPhase`, `frameworksBuildPhase`, `resourcesBuildPhase` and `headersBuildPhase` return the build phase of that class, creating and appending it to `buildPhases` when the target has none, like Ruby's `find_or_create_build_phase_by_class`. Unlike Ruby they do not memoize it, so a phase removed from the target is created again
- `PBXNativeTarget.addFileReferences(refs, {compilerFlags, onBuildFile})` adds a build file per reference to the sources phase, or to the headers phase for a header extension (any case), reusing the build file a reference already has. A non-empty `compilerFlags` is appended, after a space, to the `COMPILER_FLAGS` of the build file of a source file (even when they repeat, like Ruby) and `onBuildFile` stands for Ruby's block. A reference without a `path` throws an `ArgumentError` before anything is added, where Ruby raises a `TypeError` midway. `PBXNativeTarget.addResources(refs)` does the same for the resources phase, skipping references it already has. Neither creates a phase when given no reference
- `AbstractTarget.shellScriptBuildPhases` and `copyFilesBuildPhases` list the phases of that class, `newShellScriptBuildPhase([name])` and `newCopyFilesBuildPhase([name])` append a new one to `buildPhases` (a new phase every time) and `buildConfigurations` returns the configurations of the target's configuration list (a `StateError` when it has none). The output on the Flutter iOS and macOS projects is byte-identical to xcodeproj's
- `PBXGroup.findSubpath(path, {create})`, `findFileByPath(path)`, `recursiveChildren`, `clear` / `removeChildrenRecursively` and `buildFiles` (also on `PBXFileReference` and `PBXReferenceProxy`), ported from xcodeproj. `findSubpath` walks `/` separated names matched against Ruby's `display_name` (a group without name and path has none, so only `''` or `'/'` find it), the first match wins, and `create: true` adds a `PBXGroup` for each missing name. It returns an `AbstractObject?`, as Ruby returns files too, and throws a `StateError` where Ruby raises `NoMethodError` (a file in the middle of the path)
- `XcodeProject.nativeTargets` (the `PBXNativeTarget`s of `targets`, without aggregate and legacy ones) and `XcodeProject.referenceForPath(absolutePath)`, which returns the first `PBXFileReference` whose real path is `absolutePath` (an `ArgumentError` for a relative one; it is not normalized, like Ruby's `Pathname#==`). `GroupableHelper.realPath` has a new `projectDir` parameter, for projects opened from a relative path. `referenceForPath` anchors `SOURCE_ROOT` paths at the absolute project directory the project had when it was opened or created, so changing `Directory.current` afterwards does not move it (Ruby's `project_dir` is absolute from `Project.new` on)
- `XCConfigurationList.setSetting(key, value)` sets one build setting in every configuration of the list and leaves the other keys alone, `XCConfigurationList.buildSettings(name)` and `AbstractTarget.buildSettings(name)` return the live settings map of the named configuration (`null` for an unknown name), so a key level edit no longer needs to replace `buildSettings` wholesale. The same instance of an array value is stored in each configuration, like Ruby
- `AbstractTarget.addBuildConfiguration(name, type)` adds a configuration with the default settings of Ruby for the platform, deployment target and product type of the target, appends it to `buildConfigurations` and returns the existing configuration, untouched, when the name is taken. It uses `AbstractTarget.sdk`, `platformName` and `deploymentTarget`, also new. Like Ruby, deployment targets compare as strings (`'13.0' < '5'`, so a new iOS 13 configuration gets `CLANG_ENABLE_OBJC_WEAK = NO`). A target without configuration list throws a `StateError` where Ruby raises a `NoMethodError`. The output on the Flutter iOS and macOS projects is byte-identical to xcodeproj's
- `ProjectHelper.commonBuildSettings` accepts a `null` platform and a `deploymentTarget`, and returns copies of the constants
- `XCScheme.buildAction`, `testAction`, `launchAction`, `profileAction`, `analyzeAction` and `archiveAction` now have setters, like Ruby's `XCScheme#launch_action=` and friends: the first existing element is removed and the action is appended to `<Scheme>` (a copy, if it already belongs to a document). The getters return the typed actions, so `scheme.launchAction.buildConfiguration = 'Debug-dev'` changes only that attribute and keeps every other attribute, `PreActions`/`PostActions` and unknown child element as they were

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
