// Wraps the AnalyzeAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';

/// Wraps an `<AnalyzeAction>` XML element in a `.xcscheme` file.
class AnalyzeAction extends AbstractSchemeAction {
  static const String _tag = 'AnalyzeAction';

  AnalyzeAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Debug';
    });
  }
}
