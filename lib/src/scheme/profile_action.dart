// Wraps the ProfileAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';
import 'buildable_product_runnable.dart';

/// Wraps a `<ProfileAction>` XML element in a `.xcscheme` file.
class ProfileAction extends AbstractSchemeAction {
  static const String _tag = 'ProfileAction';

  /// Wraps [el], or creates a default `<ProfileAction>` when [el] is omitted (`Release`).
  ///
  /// Throws an [ArgumentError] if [el] is not a `<ProfileAction>` element.
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

  /// Whether this action uses the arguments and environment variables of the
  /// launch action.
  ///
  /// A missing attribute reads as `false`.
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
