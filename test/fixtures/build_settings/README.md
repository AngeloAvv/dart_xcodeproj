# Build settings helper fixtures

Expected output of Ruby's build settings helpers (`XCConfigurationList#set_setting`,
`#build_settings`, `AbstractTarget#build_settings`, `#add_build_configuration`
and `Project#add_build_configuration`), used by
`test/pbx/build_settings_helpers_ruby_parity_test.dart`: the Dart helpers run on
the same pristine `flutter create` project, followed by `predictabilizeUuids()`
and `save()`, must write `<project>.<scenario>.pbxproj` exactly.

Everything here was produced by the Ruby reference implementation, never by
Dart.

## Regenerating

From the repository root:

```sh
ruby test/fixtures/build_settings/generate.rb
```

The script pins the `xcodeproj` gem to **1.27.0**; `XCODEPROJ_GEM_VERSION=1.28.1`
runs it with 1.28.1 instead, and `OUT_DIR=<dir>` writes the files somewhere
else. Both versions write the very same files (checked with `cmp` on every
file), and `configuration_list.rb`, `native_target.rb` and `project_helper.rb`
are identical in the two gems (`constants.rb` differs only in the last known
SDK and object versions, which these helpers do not use).

Each input is `test/fixtures/annotations/<project>.xcodeproj/project.pbxproj`
(`ios` or `macos`, pristine `flutter create` projects) copied into a bundle
called `Runner.xcodeproj` (the name Flutter gives its projects). A scenario
calls the helpers, then the script runs

```ruby
project.predictabilize_uuids # the new objects get random UUIDs otherwise
project.save
```

| Scenario | What it does |
|----------|--------------|
| `set_setting` | `set_setting` on the `Runner` list: an existing key, a new one, the same key twice, array settings given as a string (`OTHER_LDFLAGS`) and as an array (`HEADER_SEARCH_PATHS`), `$(inherited)`, `[sdk=...]` conditional keys; on the project list; on a target with the three configurations and on one with none |
| `build_settings` | Key level edits of `Debug`, `Release`, `Profile` and a configuration added with `add_build_configuration` through `build_settings(name)`, a removed key, and the `nil` of an unknown name |
| `add_build_configuration` | New debug and release configurations on `Runner`, an existing name (returned as is, whatever the type), the same new name twice, and on targets without platform, and of tvOS, watchOS, visionOS, macOS (deployment target below `10.7` and above), iOS (below `5`) and an unknown product type |
| `project_add_build_configuration` | `Project#add_build_configuration`: a new release and debug configuration, an existing name and the same new name twice |

The Dart parity test mirrors each scenario call for call: change one and
change the other.

Ruby compares deployment targets as strings (`'13.0' < '5'`), so a configuration
of the Flutter iOS project (deployment target `13.0`) and the macOS one
(`10.15 < 10.7`) gets `CLANG_ENABLE_OBJC_WEAK = NO`: the Dart helpers do the same.
