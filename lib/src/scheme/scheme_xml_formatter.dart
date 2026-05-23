// Produces Xcode's exact XML indentation style for .xcscheme files.
import 'package:xml/xml.dart';

/// Custom XML formatter that matches Xcode's `.xcscheme` serialization format.
/// Format rules (derived from Ruby `XCScheme::XMLFormatter#write_element`):
/// - XML declaration uses **double quotes** — hardcoded string.
/// - Each element opening tag is followed by a newline.
/// - Each XML attribute is written on its own line, indented
/// `(depth + kIndent)` spaces, with the form `name = "value"`.
/// - Child elements are indented `kIndent` spaces per depth level.
/// - Closing tag is aligned with its opening tag (`depth` spaces indent).
/// - A single trailing newline follows the root closing tag.
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
    _writeElement(doc.rootElement, 0, buf);
    buf.write('\n');
    return buf.toString();
  }

  static void _writeElement(XmlElement node, int level, StringBuffer buf) {
    final pad = ' ' * level;
    buf.write('$pad<${node.name.local}');

    final attrPad = ' ' * (level + kIndent);
    for (final attr in node.attributes) {
      buf.write('\n$attrPad${attr.name.local} = "${attr.value}"');
    }
    buf.write('>');

    final children = node.children.whereType<XmlElement>().toList(
      growable: false,
    );
    if (children.isEmpty) {
      buf.write('\n$pad</${node.name.local}>');
      return;
    }
    buf.write('\n');
    for (final child in children) {
      _writeElement(child, level + kIndent, buf);
      buf.write('\n');
    }
    buf.write('$pad</${node.name.local}>');
  }
}
