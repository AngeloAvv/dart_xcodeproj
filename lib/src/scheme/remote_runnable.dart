// Wraps the RemoteRunnable node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'buildable_reference.dart';
import 'xml_element_wrapper.dart';

/// Wraps a `<RemoteRunnable>` XML element in a `.xcscheme` file.
/// A RemoteRunnable is a product that is both buildable and runnable remotely
/// (e.g., on an Apple Watch).
class RemoteRunnable extends XmlElementWrapper {
  static const String _tag = 'RemoteRunnable';

  RemoteRunnable([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      // No required defaults — caller sets runnableDebuggingMode, bundleIdentifier,
      // remotePath, and buildableReference as needed.
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// The runnable debugging mode (usually '2').
  String? get runnableDebuggingMode =>
      xmlElement.getAttribute('runnableDebuggingMode');

  set runnableDebuggingMode(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('runnableDebuggingMode');
    } else {
      xmlElement.setAttribute('runnableDebuggingMode', v);
    }
  }

  /// The bundle identifier (usually 'com.apple.Carousel').
  String? get bundleIdentifier => xmlElement.getAttribute('BundleIdentifier');

  set bundleIdentifier(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('BundleIdentifier');
    } else {
      xmlElement.setAttribute('BundleIdentifier', v);
    }
  }

  /// The remote path (not required, unknown usage).
  String? get remotePath => xmlElement.getAttribute('RemotePath');

  set remotePath(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('RemotePath');
    } else {
      xmlElement.setAttribute('RemotePath', v);
    }
  }

  // ---------------------------------------------------------------------------
  // buildableReference child
  // ---------------------------------------------------------------------------

  /// The BuildableReference this remote runnable will build and run.
  /// Returns null if no `<BuildableReference>` child is present.
  BuildableReference? get buildableReference {
    final el = xmlElement.findElements('BuildableReference').firstOrNull;
    return el != null ? BuildableReference(el) : null;
  }

  set buildableReference(BuildableReference? ref) {
    final existing = xmlElement.findElements('BuildableReference').firstOrNull;
    existing?.remove();
    if (ref != null) {
      xmlElement.children.add(ref.xmlElement.copy());
    }
  }
}
