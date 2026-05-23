import 'shell_words.dart';

/// Structured result of parsing OTHER_LDFLAGS.
class OtherLinkerFlags {
  final Set<String> frameworks;
  final Set<String> weakFrameworks;
  final Set<String> libraries;
  final Set<String> argFiles;
  final Set<String> forceLoad;
  final Set<String> simple;

  OtherLinkerFlags({
    Set<String>? frameworks,
    Set<String>? weakFrameworks,
    Set<String>? libraries,
    Set<String>? argFiles,
    Set<String>? forceLoad,
    Set<String>? simple,
  }) : frameworks = frameworks ?? <String>{},
       weakFrameworks = weakFrameworks ?? <String>{},
       libraries = libraries ?? <String>{},
       argFiles = argFiles ?? <String>{},
       forceLoad = forceLoad ?? <String>{},
       simple = simple ?? <String>{};
}

/// Stateless parser for Xcode OTHER_LDFLAGS build setting values.
/// Port of Ruby `Xcodeproj::Config::OtherLinkerFlagsParser` module.
class OtherLinkerFlagsParser {
  OtherLinkerFlagsParser._();

  /// Parses [flags] string and categorizes each token into the appropriate bucket.
  /// Recognizes:
  /// - `-framework <name>` → [OtherLinkerFlags.frameworks]
  /// - `-weak_framework <name>` → [OtherLinkerFlags.weakFrameworks]
  /// - `-l<name>` or `-l <name>` → [OtherLinkerFlags.libraries]
  /// - `@<file>` or `@ <file>` → [OtherLinkerFlags.argFiles]
  /// - `-force_load <path>` → [OtherLinkerFlags.forceLoad]
  /// - Anything else → [OtherLinkerFlags.simple]
  static OtherLinkerFlags parse(String flags) {
    final result = OtherLinkerFlags();
    final tokens = _split(flags);
    String?
    pending; // 'framework' | 'weak_framework' | 'library' | 'arg_file' | 'force_load'

    for (final token in tokens) {
      if (pending != null) {
        switch (pending) {
          case 'framework':
            result.frameworks.add(token);
          case 'weak_framework':
            result.weakFrameworks.add(token);
          case 'library':
            result.libraries.add(token);
          case 'arg_file':
            result.argFiles.add(token);
          case 'force_load':
            result.forceLoad.add(token);
        }
        pending = null;
        continue;
      }
      switch (token) {
        case '-framework':
          pending = 'framework';
        case '-weak_framework':
          pending = 'weak_framework';
        case '-l':
          pending = 'library';
        case '@':
          pending = 'arg_file';
        case '-force_load':
          pending = 'force_load';
        default:
          result.simple.add(token);
      }
    }
    return result;
  }

  /// Splits [flags] via shell tokenization, then expands inline `-l<x>` and `@<x>` tokens.
  static List<String> _split(String flags) {
    final base = shellSplit(flags.trim());
    final out = <String>[];
    for (final token in base) {
      if (RegExp(r'^-l.+').hasMatch(token)) {
        out.add('-l');
        out.add(token.substring(2));
      } else if (RegExp(r'^@.+').hasMatch(token)) {
        out.add('@');
        out.add(token.substring(1));
      } else {
        out.add(token);
      }
    }
    return out;
  }
}
