// Wraps the ExecutionAction node of a .xcscheme XML file.

import 'package:xml/xml.dart';

import 'send_email_action_content.dart';
import 'shell_script_action_content.dart';
import 'xml_element_wrapper.dart';

/// Known action type identifiers.
const String kShellScriptActionType =
    'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.ShellScriptAction';
const String kSendEmailActionType =
    'Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction';

/// Wraps an `<ExecutionAction>` XML element in a `.xcscheme` file.
/// An ExecutionAction represents a pre- or post-action that runs either a shell
/// script or sends an email.
class ExecutionAction extends XmlElementWrapper {
  static const String _tag = 'ExecutionAction';

  ExecutionAction([XmlElement? el, String? actionType]) {
    createXmlElementWithFallback(el, _tag, () {
      if (actionType != null) {
        xmlElement.setAttribute('ActionType', actionType);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // ActionType
  // ---------------------------------------------------------------------------

  /// The ActionType string. One of [kShellScriptActionType] or [kSendEmailActionType].
  String? get actionType => xmlElement.getAttribute('ActionType');

  set actionType(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('ActionType');
    } else {
      xmlElement.setAttribute('ActionType', v);
    }
  }

  // ---------------------------------------------------------------------------
  // ActionContent
  // ---------------------------------------------------------------------------

  /// Returns the [ShellScriptActionContent] if the ActionContent child corresponds
  /// to a shell script action; otherwise null.
  ShellScriptActionContent? get shellScriptActionContent {
    final c = xmlElement.findElements('ActionContent').firstOrNull;
    if (c == null) return null;
    final type = actionType;
    if (type == kShellScriptActionType ||
        c.getAttribute('scriptText') != null) {
      return ShellScriptActionContent(c);
    }
    return null;
  }

  /// Returns the [SendEmailActionContent] if the ActionContent child corresponds
  /// to a send email action; otherwise null.
  SendEmailActionContent? get sendEmailActionContent {
    final c = xmlElement.findElements('ActionContent').firstOrNull;
    if (c == null) return null;
    final type = actionType;
    if (type == kSendEmailActionType ||
        c.getAttribute('emailRecipient') != null ||
        (c.getAttribute('scriptText') == null &&
            c.getAttribute('shellToInvoke') == null &&
            c.getAttribute('attachLogToEmail') != null)) {
      return SendEmailActionContent(c);
    }
    return null;
  }

  /// Sets the action content, replacing any existing `<ActionContent>` child.
  void setActionContent(XmlElementWrapper content) {
    final existing = xmlElement.findElements('ActionContent').firstOrNull;
    existing?.remove();
    xmlElement.children.add(content.xmlElement.copy());
  }
}
