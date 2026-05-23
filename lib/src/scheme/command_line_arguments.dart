// Wraps the CommandLineArguments + CommandLineArgument nodes.

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps a `<CommandLineArguments>` XML element (Pattern 5 — composition collection).
/// Composition-based: does NOT extend List.
class CommandLineArguments extends XmlElementWrapper {
  static const String _tag = 'CommandLineArguments';

  CommandLineArguments([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Empty container by default
    });
  }

  // ---------------------------------------------------------------------------
  // Collection accessors
  // ---------------------------------------------------------------------------

  /// All command-line arguments in this container.
  List<CommandLineArgument> get allArguments => xmlElement
      .findElements('CommandLineArgument')
      .map(CommandLineArgument.new)
      .toList();

  /// Adds an argument (appends the xmlElement child).
  void assignArgument(CommandLineArgument a) {
    xmlElement.children.add(a.xmlElement.copy());
  }

  /// Removes the argument with the given [argument] string.
  void removeArgument(String argument) {
    final toRemove = xmlElement
        .findElements('CommandLineArgument')
        .where((e) => e.getAttribute('argument') == argument)
        .toList();
    for (final e in toRemove) {
      e.remove();
    }
  }

  /// Returns the argument with [argument] string, or null if not found.
  CommandLineArgument? operator [](String argument) {
    final match = xmlElement
        .findElements('CommandLineArgument')
        .where((e) => e.getAttribute('argument') == argument)
        .firstOrNull;
    return match != null ? CommandLineArgument(match) : null;
  }
}

/// Wraps a `<CommandLineArgument>` XML element.
class CommandLineArgument extends XmlElementWrapper {
  static const String _tag = 'CommandLineArgument';

  CommandLineArgument([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Default: isEnabled = NO (false)
      xmlElement.setAttribute('isEnabled', 'NO');
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  String get argument => xmlElement.getAttribute('argument') ?? '';
  set argument(String v) => xmlElement.setAttribute('argument', v);

  bool get isEnabled =>
      stringToBool(xmlElement.getAttribute('isEnabled') ?? 'NO');
  set isEnabled(bool v) =>
      xmlElement.setAttribute('isEnabled', boolToString(v));
}
