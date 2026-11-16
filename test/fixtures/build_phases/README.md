# Build phase helper fixtures

Expected output of Ruby's build phase helpers of `PBXNativeTarget`
(`source_build_phase`, `frameworks_build_phase`, `resources_build_phase`,
`headers_build_phase`, `add_file_references`, `add_resources`,
`new_shell_script_build_phase`, `new_copy_files_build_phase`), used by
`test/pbx/build_phase_helpers_ruby_parity_test.dart`: the Dart helpers run on
the same pristine `flutter create` project, followed by `predictabilizeUuids()`
and `save()`, must write `<project>.<scenario>.pbxproj` exactly.

Everything here was produced by the Ruby reference implementation, never by
Dart.

## Regenerating

From the repository root:

```sh
ruby test/fixtures/build_phases/generate.rb
```

The script pins the `xcodeproj` gem to **1.27.0**; `XCODEPROJ_GEM_VERSION=1.28.1`
runs it with 1.28.1 instead, and `OUT_DIR=<dir>` writes the files somewhere
else. Both versions write the very same files (checked with `diff -r`), and
`native_target.rb` and `build_phase.rb` are identical in the two gems.

Each input is `test/fixtures/annotations/<project>.xcodeproj/project.pbxproj`
(`ios` or `macos`, pristine `flutter create` projects) copied into a bundle
called `Runner.xcodeproj` (the name Flutter gives its projects). A scenario
calls the helpers on the `Runner` target and on a `Bare` native target without
any build phase, then the script runs

```ruby
project.predictabilize_uuids # the new objects get random UUIDs otherwise
project.save
```

| Scenario | What it does |
|----------|--------------|
| `on_demand` | Asks a bare target for its sources, frameworks, resources and headers phases (each is created, in that order, and found the second time), and `Runner` for its headers phase |
| `add_file_references` | Adds `.m`, `.h`, upper case `.HPP` and `.swift` references with `-fobjc-arc`, adds one again with other flags (the flags are joined with a space), with no flags, the same reference twice in a list, empty flags, an empty list, a file already in the sources phase, a header with flags (ignored), and a file to a bare target |
| `add_resources` | Adds resources, adds one again, a resource that was already there, an empty list, the same reference twice in a list, and a resource to a bare target |
| `new_phases` | Appends shell script and copy files phases, named and unnamed, to `Runner` and to a bare target |

The Dart parity test mirrors each scenario call for call: change one and
change the other.
