// Produces Xcode's exact XML indentation style for .xcscheme files.
import 'package:xml/xml.dart';

/// Custom XML formatter that matches Xcode's `.xcscheme` serialization format.
/// Format rules (derived from Ruby `XCScheme::XMLFormatter#write_element`):
/// - XML declaration uses **double quotes** — hardcoded string.
/// - Each element opening tag is followed by a newline.
/// - Each XML attribute is written on its own line, indented
/// `(depth + kIndent)` spaces, with the form `name = "value"`. Attribute
/// values are escaped (`& < > "` and `\n`, `\r`, `\t` as character
/// references) so the output is always well-formed XML.
/// - Comments and non-blank text nodes are kept; blank (whitespace-only) text
/// nodes are dropped. Text is whitespace-collapsed and wrapped like Ruby's
/// `REXML::Formatters::Pretty#write_text`.
/// - Child elements are indented `kIndent` spaces per depth level.
/// - Closing tag is aligned with its opening tag (`depth` spaces indent).
/// - Comments before and after the root element are kept, one per line.
/// - A single trailing newline follows the last top-level node.
/// This class cannot be instantiated.
class SchemeXmlFormatter {
  SchemeXmlFormatter._();

  /// Number of spaces added per depth level.
  static const int kIndent = 3;

  /// Format [doc] as an Xcode-style XML string.
  /// The `<?xml?>` declaration is hardcoded with double quotes.
  static String format(XmlDocument doc) {
    final buf = StringBuffer();
    buf.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    // Document-level comments are kept in their original order around the
    // root element, one per line (as Ruby's REXML formatter does).
    for (final node in doc.children) {
      switch (node) {
        case XmlElement():
          _writeElement(node, 0, buf);
          buf.write('\n');
        case XmlComment():
          buf.write('<!--${node.value}-->\n');
        default:
          break;
      }
    }
    return buf.toString();
  }

  /// Maximum line width used when wrapping text nodes (REXML's default).
  static const int _kWidth = 80;

  /// Escapes [value] for use inside a double-quoted attribute.
  static String _escapeAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll('\n', '&#10;')
      .replaceAll('\r', '&#13;')
      .replaceAll('\t', '&#9;');

  /// Escapes [value] for use as element text.
  static String _escapeText(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Mirrors `REXML::Formatters::Pretty#write_text`: collapses whitespace,
  /// wraps at `80 - level` columns and indents continuation lines.
  static String _formatText(String text, int level) {
    var s = _escapeText(text).replaceAll(RegExp(r'\s'), ' ');
    s = s.replaceAll(RegExp(r' {2,}'), ' ');
    final width = _kWidth - level;
    final parts = <String>[];
    while (s.length > width) {
      // Ruby's `rindex` counts a negative position from the end of the
      // string, which happens when the indentation exceeds the text width.
      final from = width < 0 ? s.length + width : width;
      if (from < 0) break;
      final place = s.lastIndexOf(' ', from);
      if (place < 0) break;
      parts.add(s.substring(0, place));
      s = s.substring(place + 1);
    }
    parts.add(s);
    return parts.join('\n${' ' * level}');
  }

  static void _writeElement(XmlElement node, int level, StringBuffer buf) {
    final pad = ' ' * level;
    buf.write('$pad<${node.name.local}');

    final attrPad = ' ' * (level + kIndent);
    for (final attr in node.attributes) {
      buf.write(
        '\n$attrPad${attr.name.local} = "${_escapeAttribute(attr.value)}"',
      );
    }
    buf.write('>');

    final children = node.children
        .where(
          (c) =>
              c is XmlElement ||
              c is XmlComment ||
              c is XmlCDATA ||
              (c is XmlText && c.value.trim().isNotEmpty),
        )
        .toList(growable: false);
    if (children.isEmpty) {
      buf.write('\n$pad</${node.name.local}>');
      return;
    }
    buf.write('\n');
    for (final child in children) {
      final childLevel = level + kIndent;
      switch (child) {
        case XmlElement():
          _writeElement(child, childLevel, buf);
        case XmlComment():
          buf.write('${' ' * childLevel}<!--${child.value}-->');
        case XmlCDATA():
          buf.write('${' ' * childLevel}<![CDATA[${child.value}]]>');
        case XmlText():
          buf.write(
            '${' ' * childLevel}${_formatText(child.value, childLevel)}',
          );
        default:
          break;
      }
      buf.write('\n');
    }
    buf.write('$pad</${node.name.local}>');
  }
}
