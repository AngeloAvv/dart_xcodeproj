// Abstract base class for scheme action types that have buildConfiguration,
// preActions, and postActions.

import 'package:xml/xml.dart';

import 'execution_action.dart';
import 'xml_element_wrapper.dart';

/// Abstract base class for XCScheme action wrappers.
/// Each concrete action (TestAction, LaunchAction, etc.) extends this class
/// to inherit [buildConfiguration], [preActions], and [postActions] support.
abstract class AbstractSchemeAction extends XmlElementWrapper {
  // ---------------------------------------------------------------------------
  // buildConfiguration
  // ---------------------------------------------------------------------------

  /// The build configuration associated with this action (typically 'Debug' or 'Release').
  String? get buildConfiguration =>
      xmlElement.getAttribute('buildConfiguration');

  set buildConfiguration(String? value) {
    if (value == null) {
      xmlElement.removeAttribute('buildConfiguration');
    } else {
      xmlElement.setAttribute('buildConfiguration', value);
    }
  }

  // ---------------------------------------------------------------------------
  // preActions
  // ---------------------------------------------------------------------------

  /// The list of actions to run before this scheme action.
  List<ExecutionAction> get preActions {
    final container = xmlElement.findElements('PreActions').firstOrNull;
    if (container == null) return <ExecutionAction>[];
    return container
        .findElements('ExecutionAction')
        .map(ExecutionAction.new)
        .toList();
  }

  /// Add an action to the list of pre-actions.
  void addPreAction(ExecutionAction action) {
    var container = xmlElement.findElements('PreActions').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('PreActions'));
      xmlElement.children.add(container);
    }
    container.children.add(action.xmlElement.copy());
  }

  // ---------------------------------------------------------------------------
  // postActions
  // ---------------------------------------------------------------------------

  /// The list of actions to run after this scheme action.
  List<ExecutionAction> get postActions {
    final container = xmlElement.findElements('PostActions').firstOrNull;
    if (container == null) return <ExecutionAction>[];
    return container
        .findElements('ExecutionAction')
        .map(ExecutionAction.new)
        .toList();
  }

  /// Add an action to the list of post-actions.
  void addPostAction(ExecutionAction action) {
    var container = xmlElement.findElements('PostActions').firstOrNull;
    if (container == null) {
      container = XmlElement(XmlName('PostActions'));
      xmlElement.children.add(container);
    }
    container.children.add(action.xmlElement.copy());
  }
}
