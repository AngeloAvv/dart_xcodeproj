// Wraps an 'ActionContent' node of type ShellScriptAction.

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps an `<ActionContent>` XML element for
/// `Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction`.
class ShellScriptActionContent extends XmlElementWrapper {
  static const String _tag = 'ActionContent';

  ShellScriptActionContent([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      title = 'Run Script';
    });
  }

  // ---------------------------------------------------------------------------
  // Attributes
  // ---------------------------------------------------------------------------

  /// The title of this ActionContent.
  String? get title => xmlElement.getAttribute('title');
  set title(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('title');
    } else {
      xmlElement.setAttribute('title', v);
    }
  }

  /// The shell script text to execute.
  String? get scriptText => xmlElement.getAttribute('scriptText');
  set scriptText(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('scriptText');
    } else {
      xmlElement.setAttribute('scriptText', v);
    }
  }

  /// The preferred shell to invoke (e.g., '/bin/sh').
  String? get shellToInvoke => xmlElement.getAttribute('shellToInvoke');
  set shellToInvoke(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('shellToInvoke');
    } else {
      xmlElement.setAttribute('shellToInvoke', v);
    }
  }
}
