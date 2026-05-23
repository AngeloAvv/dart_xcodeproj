// Wraps the EnvironmentVariables + EnvironmentVariable nodes.

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps an `<EnvironmentVariables>` XML element (Pattern 5 — composition collection).
/// Composition-based: does NOT extend List.
class EnvironmentVariables extends XmlElementWrapper {
  static const String _tag = 'EnvironmentVariables';

  EnvironmentVariables([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Empty container by default
    });
  }

  // ---------------------------------------------------------------------------
  // Collection accessors
  // ---------------------------------------------------------------------------

  /// All environment variables in this container.
  List<EnvironmentVariable> get allVariables => xmlElement
      .findElements('EnvironmentVariable')
      .map(EnvironmentVariable.new)
      .toList();

  /// Adds a variable (appends the xmlElement child).
  void assignVariable(EnvironmentVariable v) {
    xmlElement.children.add(v.xmlElement.copy());
  }

  /// Removes the variable with the given [key].
  void removeVariable(String key) {
    final toRemove = xmlElement
        .findElements('EnvironmentVariable')
        .where((e) => e.getAttribute('key') == key)
        .toList();
    for (final e in toRemove) {
      e.remove();
    }
  }

  /// Returns the variable with [key], or null if not found.
  EnvironmentVariable? operator [](String key) {
    final match = xmlElement
        .findElements('EnvironmentVariable')
        .where((e) => e.getAttribute('key') == key)
        .firstOrNull;
    return match != null ? EnvironmentVariable(match) : null;
  }
}

/// Wraps an `<EnvironmentVariable>` XML element.
class EnvironmentVariable extends XmlElementWrapper {
  static const String _tag = 'EnvironmentVariable';

  EnvironmentVariable([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Default: isEnabled = YES per Ruby (bool_to_string(true))
      xmlElement.setAttribute('isEnabled', 'YES');
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  String get key => xmlElement.getAttribute('key') ?? '';
  set key(String v) => xmlElement.setAttribute('key', v);

  String get value => xmlElement.getAttribute('value') ?? '';
  set value(String v) => xmlElement.setAttribute('value', v);

  bool get isEnabled =>
      stringToBool(xmlElement.getAttribute('isEnabled') ?? 'YES');
  set isEnabled(bool v) =>
      xmlElement.setAttribute('isEnabled', boolToString(v));
}
