// Port of Ruby Shellwords.shellsplit (minimal POSIX subset for xcconfig use).

/// Splits [input] into tokens using a minimal POSIX shell-split subset.
/// Rules:
/// - Whitespace (space, tab) separates tokens.
/// - Double-quoted strings (`"..."`) are treated as a single token; quotes stripped.
/// - Single-quoted strings (`'...'`) are treated as a single token; quotes stripped.
/// - Backslash escapes the next character outside quotes: `foo\ bar` → `foo bar`.
/// - Empty or whitespace-only input returns `<String>[]`.
/// - Unterminated quote throws [FormatException] with message `"Unmatched quote in: $input"`.
List<String> shellSplit(String input) {
  if (input.trim().isEmpty) return <String>[];

  final tokens = <String>[];
  final buf = StringBuffer();
  var i = 0;
  final len = input.length;

  while (i < len) {
    final ch = input[i];

    if (ch == ' ' || ch == '\t') {
      // Token delimiter
      if (buf.isNotEmpty) {
        tokens.add(buf.toString());
        buf.clear();
      }
      i++;
      continue;
    }

    if (ch == '"') {
      // Double-quoted token — scan until closing `"`
      i++; // skip opening quote
      while (i < len && input[i] != '"') {
        if (input[i] == '\\' && i + 1 < len) {
          // POSIX: backslash inside double quotes is special only before
          // $, `, ", \, and newline; elsewhere the backslash is literal.
          final next = input[i + 1];
          if (next == r'$' ||
              next == '`' ||
              next == '"' ||
              next == '\\' ||
              next == '\n') {
            i++;
            buf.write(input[i]);
          } else {
            buf.write('\\'); // literal backslash
          }
        } else {
          buf.write(input[i]);
        }
        i++;
      }
      if (i >= len) {
        throw FormatException('Unmatched quote in: $input');
      }
      i++; // skip closing quote
      continue;
    }

    if (ch == "'") {
      // Single-quoted token — no escape processing inside single quotes
      i++; // skip opening quote
      while (i < len && input[i] != "'") {
        buf.write(input[i]);
        i++;
      }
      if (i >= len) {
        throw FormatException('Unmatched quote in: $input');
      }
      i++; // skip closing quote
      continue;
    }

    if (ch == '\\') {
      // Backslash escape outside quotes
      if (i + 1 < len) {
        i++;
        buf.write(input[i]);
        i++;
      } else {
        // Trailing backslash — consume it
        i++;
      }
      continue;
    }

    buf.write(ch);
    i++;
  }

  if (buf.isNotEmpty) {
    tokens.add(buf.toString());
  }

  return tokens;
}
