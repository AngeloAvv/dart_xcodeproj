# Typed scheme action fixtures

Expected output of Ruby's `XCScheme` typed action getters and setters, used by
`test/scheme/xc_scheme_typed_actions_test.dart`. Everything that ends in
`expected.json` or `.ruby_saved.xcscheme` was produced by the Ruby reference
implementation, never by Dart.

## Inputs

| Scheme | From |
|--------|------|
| `ios_Runner`, `macos_Runner` | `test/fixtures/scheme/flutter/`: the schemes `flutter create` writes (the iOS one has the `PreActions` script of Flutter's Swift Package Manager support) |
| `missing_actions.xcscheme` | the iOS scheme with only `BuildAction` and `LaunchAction` |
| `repeated_actions.xcscheme` | the iOS scheme with a second `LaunchAction` (`buildConfiguration = "Debug-second"`) after the first |
| `pre_post_actions.xcscheme` | hand written: `PostActions` on the test and archive actions, `PreActions` on the launch (shell script) and profile (send email) actions, unknown children (`AdditionalOptions`), flavored build configurations, `NO` flags and a `customArchiveName` |

## Regenerating

From the repository root:

```sh
ruby test/fixtures/scheme/typed_actions/generate.rb
```

The script pins the `xcodeproj` gem to **1.27.0** (`gem 'xcodeproj', '1.27.0'`).
Gem **1.28.1** writes the very same files (checked by running the script with
it): `lib/xcodeproj/scheme.rb` and `lib/xcodeproj/scheme/*.rb` are identical in
both versions. For each input scheme it does:

```ruby
scheme = Xcodeproj::XCScheme.new(path)
scheme.build_action   # .test_action, .launch_action, .profile_action,
                      # .analyze_action, .archive_action: dumped to expected.json
File.write('<name>.read_only.ruby_saved.xcscheme', scheme.to_s)

scheme = Xcodeproj::XCScheme.new(path)
scheme.launch_action.build_configuration = 'Debug-dev'
File.write('<name>.build_configuration.ruby_saved.xcscheme', scheme.to_s)

scheme = Xcodeproj::XCScheme.new(path)
scheme.launch_action = LaunchAction.new   # with build_configuration = 'Custom'
File.write('<name>.replaced_launch.ruby_saved.xcscheme', scheme.to_s)

scheme = Xcodeproj::XCScheme.new(path)
scheme.analyze_action = AnalyzeAction.new # with build_configuration = 'Custom'
File.write('<name>.replaced_analyze.ruby_saved.xcscheme', scheme.to_s)

scheme = Xcodeproj::XCScheme.new('repeated_actions.xcscheme')
second = LaunchAction.new(scheme.doc.root.get_elements('LaunchAction')[1])
scheme.launch_action = second
File.write('repeated_actions.moved_second_launch.ruby_saved.xcscheme', scheme.to_s)

source = Xcodeproj::XCScheme.new('missing_actions.xcscheme')
dest = Xcodeproj::XCScheme.new('missing_actions.xcscheme')
dest.archive_action = source.archive_action
source.archive_action.build_configuration = 'Release-dev'
File.write('missing_actions.aliased_archive.ruby_saved.xcscheme', dest.to_s)
```

## What the expectations say about Ruby

- A scheme that lacks an action gets a default one from the getter, and the
  element is **not** in the document afterwards (`inDocumentAfter: false`), so
  `to_s` does not write it.
- `pre_actions`/`post_actions` are `nil` when there is no `PreActions` /
  `PostActions` container (Dart answers an empty list).
- A boolean attribute that is absent makes the reader raise
  (`"raises"` in `expected.json`; Dart answers `false`).
- A repeated action element is not an error: the getter uses the first one.
- Assigning an element that is already a child of `<Scheme>` (the second of
  two `LaunchAction`s) does not move it: REXML adds it again, so the output
  has it twice. Dart copies the element, which gives the same file.
- The detached default of a scheme that lacks an action is cached by that
  scheme. Assigning it to another scheme (`dest.archive_action =
  source.archive_action`) inserts that very element, so a later edit of
  `source.archive_action` changes `dest` (`missing_actions.aliased_archive`),
  while `source` still has no element in its document. Dart behaves the same.
