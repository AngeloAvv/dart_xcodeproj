// Wraps the AnalyzeAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';

/// Wraps an `<AnalyzeAction>` XML element in a `.xcscheme` file.
class AnalyzeAction extends AbstractSchemeAction {
  static const String _tag = 'AnalyzeAction';

  /// Wraps [el], or creates a default `<AnalyzeAction>` when [el] is omitted (`Debug`).
  ///
  /// Throws an [ArgumentError] if [el] is not an `<AnalyzeAction>` element.
  AnalyzeAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Debug';
    });
  }
}
