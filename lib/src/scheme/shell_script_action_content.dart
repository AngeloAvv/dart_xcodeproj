// Wraps an 'ActionContent' node of type ShellScriptAction.

import 'package:xml/xml.dart';

import 'buildable_reference.dart';
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

  // ---------------------------------------------------------------------------
  // BuildableReference
  // ---------------------------------------------------------------------------

  /// The Xcode target this shell script runs within the build environment of.
  /// Returns null if no `<EnvironmentBuildable>` child is present.
  BuildableReference? get buildableReference {
    final env = xmlElement.findElements('EnvironmentBuildable').firstOrNull;
    final el = env?.findElements('BuildableReference').firstOrNull;
    return el != null ? BuildableReference(el) : null;
  }

  set buildableReference(BuildableReference? ref) {
    xmlElement
        .findElements('EnvironmentBuildable')
        .toList()
        .forEach((e) => e.remove());
    if (ref != null) {
      final env = XmlElement(XmlName('EnvironmentBuildable'));
      env.children.add(ref.xmlElement.copy());
      xmlElement.children.add(env);
    }
  }
}
