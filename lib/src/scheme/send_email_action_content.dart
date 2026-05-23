// Wraps an 'ActionContent' node of type SendEmailAction.

import 'package:xml/xml.dart';

import 'xml_element_wrapper.dart';

/// Wraps an `<ActionContent>` XML element for
/// `Xcode.IDEStandardExecutionActionsCore.ExecutionActionType.SendEmailAction`.
class SendEmailActionContent extends XmlElementWrapper {
  static const String _tag = 'ActionContent';

  SendEmailActionContent([XmlElement? el]) {
    createXmlElementWithFallback(el, _tag, () {
      title = 'Send Email';
      // attachLogToEmail is always NO per Ruby comment — not visible in Xcode UI
      xmlElement.setAttribute('attachLogToEmail', 'NO');
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

  /// The email recipient.
  String? get emailRecipient => xmlElement.getAttribute('emailRecipient');
  set emailRecipient(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('emailRecipient');
    } else {
      xmlElement.setAttribute('emailRecipient', v);
    }
  }

  /// The email subject (note: Ruby uses 'emailSubject' attribute name).
  String? get subject => xmlElement.getAttribute('emailSubject');
  set subject(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('emailSubject');
    } else {
      xmlElement.setAttribute('emailSubject', v);
    }
  }

  /// The email body.
  String? get emailBody => xmlElement.getAttribute('emailBody');
  set emailBody(String? v) {
    if (v == null) {
      xmlElement.removeAttribute('emailBody');
    } else {
      xmlElement.setAttribute('emailBody', v);
    }
  }

  /// Whether to attach the log to the email.
  bool get attachLogToEmail =>
      stringToBool(xmlElement.getAttribute('attachLogToEmail') ?? 'NO');
  set attachLogToEmail(bool v) =>
      xmlElement.setAttribute('attachLogToEmail', boolToString(v));
}
