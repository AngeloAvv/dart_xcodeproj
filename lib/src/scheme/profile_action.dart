// Wraps the ProfileAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_product_runnable.dart';

/// Wraps a `<ProfileAction>` XML element in a `.xcscheme` file.
class ProfileAction extends AbstractSchemeAction {
  static const String _tag = 'ProfileAction';

  ProfileAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Release';
      shouldUseLaunchSchemeArgsEnv = true;
      xmlElement.setAttribute('savedToolIdentifier', '');
      xmlElement.setAttribute('useCustomWorkingDirectory', boolToString(false));
      xmlElement.setAttribute('debugDocumentVersioning', boolToString(true));
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  bool get shouldUseLaunchSchemeArgsEnv => stringToBool(
    xmlElement.getAttribute('shouldUseLaunchSchemeArgsEnv') ?? 'NO',
  );
  set shouldUseLaunchSchemeArgsEnv(bool v) =>
      xmlElement.setAttribute('shouldUseLaunchSchemeArgsEnv', boolToString(v));

  // ---------------------------------------------------------------------------
  // BuildableProductRunnable
  // ---------------------------------------------------------------------------

  /// Returns the [BuildableProductRunnable] if present, otherwise null.
  BuildableProductRunnable? get buildableProductRunnable {
    final el = xmlElement.findElements('BuildableProductRunnable').firstOrNull;
    return el != null ? BuildableProductRunnable(el) : null;
  }

  set buildableProductRunnable(BuildableProductRunnable? v) {
    xmlElement.findElements('BuildableProductRunnable').firstOrNull?.remove();
    if (v != null) {
      xmlElement.children.add(v.xmlElement.copy());
    }
  }
}
