// Wraps the ArchiveAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'abstract_scheme_action.dart';

/// Wraps an `<ArchiveAction>` XML element in a `.xcscheme` file.
class ArchiveAction extends AbstractSchemeAction {
  static const String _tag = 'ArchiveAction';

  ArchiveAction([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      buildConfiguration = 'Release';
      revealArchiveInOrganizer = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  bool get revealArchiveInOrganizer =>
      stringToBool(xmlElement.getAttribute('revealArchiveInOrganizer') ?? 'NO');
  set revealArchiveInOrganizer(bool v) =>
      xmlElement.setAttribute('revealArchiveInOrganizer', boolToString(v));

  String? get customArchiveName => xmlElement.getAttribute('customArchiveName');
  set customArchiveName(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('customArchiveName');
    } else {
      xmlElement.setAttribute('customArchiveName', v);
    }
  }
}
