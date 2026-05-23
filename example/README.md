# dart_xcodeproj example

Demonstrates the dart_xcodeproj public API end-to-end:
create a new project, add a native target, add a file reference,
wire it into the Sources build phase, and save to disk.

## Run

```bash
dart run example/main.dart
```

Writes a fresh `Example.xcodeproj` to a scoped system temp directory,
prints a summary of what was created, then cleans up.

See [../README.md](../README.md) for the full library overview.
