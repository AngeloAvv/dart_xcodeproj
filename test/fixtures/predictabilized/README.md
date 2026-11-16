# Predictabilized fixtures

Expected output of Ruby's `Project#predictabilize_uuids`, used by:

- `test/project/predictabilize_uuids_ruby_parity_test.dart`: Dart's
  `XcodeProject.predictabilizeUuids()` followed by `save()` must write
  `<name>.predictabilized.pbxproj` exactly;
- `test/project/predictabilized_round_trip_test.dart`: open + save of a
  predictabilized project must write `<name>.ruby_saved.pbxproj`;
- `test/project/reference_attributes_order_test.dart`: the references of every
  class are followed in the order of `reference_attributes.json`.

Everything here was produced by the Ruby reference implementation, never by
Dart.

## Regenerating

From the repository root:

```sh
ruby test/fixtures/predictabilized/generate.rb              # *.predictabilized.pbxproj, *.ruby_saved.pbxproj
ruby test/fixtures/predictabilized/reference_attributes.rb  # reference_attributes.json
ruby test/fixtures/predictabilized/kitchen_sink.rb          # kitchen_sink.pbxproj (input only, then rerun generate.rb)
```

All of them pin the `xcodeproj` gem to **1.27.0** (`gem 'xcodeproj', '1.27.0'`).
Gem 1.28.1 writes the very same files (checked by running `generate.rb` with
it). For each input, `generate.rb` does, in a bundle called `Runner.xcodeproj`
(the name Flutter gives its projects, and the seed of every path):

```ruby
project = Xcodeproj::Project.open('Runner.xcodeproj')
project.predictabilize_uuids
project.save
```

| Input | From |
|-------|------|
| `ios`, `macos`, `ios_spm`, `macos_spm`, `edge` | `test/fixtures/annotations/<name>.xcodeproj`: pristine `flutter create` projects (iOS, macOS, with and without Swift Package Manager) and the hand-written edge cases |
| `subproject` | `test/fixtures/subproject.pbxproj`: a project reference and test target attributes |
| `kitchen_sink` | `kitchen_sink.pbxproj`: build rules, legacy and aggregate targets, version and variant groups, a synchronized folder, headers/copy files/Rez/shell script phases |

`kitchen_sink` leaves out a synchronized folder exception set that points at
its target: Ruby recurses forever on it (`SystemStackError`), which Dart does
not.

The paths include the string attributes of the objects, so the old UUID that
`containerPortal` and `remoteGlobalIDString` hold is part of the path of a
target with dependencies. Predictable output therefore needs the same input
UUIDs: the inputs here are committed files, and `kitchen_sink.pbxproj` is
generated once and committed rather than rebuilt on each run.
