// Describes a file or group reference inside an Xcode workspace.

/// Abstract base for all workspace reference types (FileRef, Group).
/// Subclasses provide [toXmlFragment] to serialize themselves in Xcode's
/// custom 3-space-indent XML style.
abstract class WorkspaceReference {
  /// The reference kind: 'group', 'container', 'absolute', 'self', 'developer'.
  String get type;

  /// The path component of the reference (may be empty for 'self').
  String get path;

  /// Combined location string in the form `'$type:$path'`.
  String get location => '$type:$path';

  /// Serialize as an XML fragment with 3-space indent per [depth] level.
  /// Attribute lines are indented 3 additional spaces beyond the tag line.
  /// The closing tag is aligned with the opening tag (attribute
  /// order per element type is hard-coded).
  String toXmlFragment(int depth);
}
