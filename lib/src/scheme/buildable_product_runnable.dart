// Wraps the BuildableProductRunnable node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'buildable_reference.dart';
import 'xml_element_wrapper.dart';

/// Wraps a `<BuildableProductRunnable>` XML element in a `.xcscheme` file.
/// A BuildableProductRunnable is a product that is both buildable
/// (contains a BuildableReference) and runnable (can be launched and debugged).
class BuildableProductRunnable extends XmlElementWrapper {
  static const String _tag = 'BuildableProductRunnable';

  BuildableProductRunnable([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // No defaults required — runnableDebuggingMode and buildableReference
      // are set by the caller.
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// The runnable debugging mode (usually '0').
  String? get runnableDebuggingMode =>
      xmlElement.getAttribute('runnableDebuggingMode');

  set runnableDebuggingMode(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('runnableDebuggingMode');
    } else {
      xmlElement.setAttribute('runnableDebuggingMode', v);
    }
  }

  // ---------------------------------------------------------------------------
  // buildableReference child
  // ---------------------------------------------------------------------------

  /// The BuildableReference this runnable will build and run.
  /// Returns null if no `<BuildableReference>` child is present.
  BuildableReference? get buildableReference {
    final el = xmlElement.findElements('BuildableReference').firstOrNull;
    return el != null ? BuildableReference(el) : null;
  }

  set buildableReference(BuildableReference? ref) {
    // Remove existing child
    final existing = xmlElement.findElements('BuildableReference').firstOrNull;
    existing?.remove();
    if (ref != null) {
      xmlElement.children.add(ref.xmlElement.copy());
    }
  }
}
