# Changelog

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
