// Wraps the MacroExpansion node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'buildable_reference.dart';
import 'xml_element_wrapper.dart';

/// Wraps a `<MacroExpansion>` XML element in a `.xcscheme` file.
class MacroExpansion extends XmlElementWrapper {
  static const String _tag = 'MacroExpansion';

  MacroExpansion([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // Empty by default — caller sets buildableReference if needed.
    });
  }

  // ---------------------------------------------------------------------------
  // buildableReference child
  // ---------------------------------------------------------------------------

  /// The BuildableReference this MacroExpansion refers to.
  /// Returns null if no `<BuildableReference>` child is present.
  BuildableReference? get buildableReference {
    final el = xmlElement.findElements('BuildableReference').firstOrNull;
    return el != null ? BuildableReference(el) : null;
  }

  /// Sets the BuildableReference for this MacroExpansion.
  void setBuildableReference(BuildableReference ref) {
    final existing = xmlElement.findElements('BuildableReference').firstOrNull;
    existing?.remove();
    xmlElement.children.add(ref.xmlElement.copy());
  }
}
