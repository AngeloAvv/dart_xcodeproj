// Represents a <Group> element inside contents.xcworkspacedata.

import 'workspace_reference.dart';

/// A workspace group reference that can contain child [WorkspaceReference]s.
/// the default [type] is `'container'` (NOT `'group'`), matching
/// Ruby's `GroupReference.new(name, type='container', location='')`.
class WorkspaceGroupReference extends WorkspaceReference {
  @override
  final String type;

  @override
  final String path;

  /// The display name of the group.
  final String name;

  /// Child references contained by this group.
  final List<WorkspaceReference> children;

  /// Creates a group reference.
  /// [type] defaults to `'container'`.
  /// [path] defaults to `''` (empty location path).
  /// [children] defaults to an empty list.
  WorkspaceGroupReference({
    this.type = 'container',
    this.path = '',
    required this.name,
    List<WorkspaceReference>? children,
  }) : children = children ?? <WorkspaceReference>[];

  /// Serializes as a `<Group>` XML fragment (recursively includes [children]).
  /// Attribute order: `location` FIRST then `name` ( — matches
  /// Xcode output from xcworkspace_element_start_xml).
  /// Uses 3-space indent per [depth] level; attributes indented 3 more spaces.
  @override
  String toXmlFragment(int depth) {
    final pad = ' ' * (depth * 3);
    final attrPad = ' ' * (depth * 3 + 3);
    final buf = StringBuffer();
    buf.write('$pad<Group\n');
    buf.write(
      '$attrPad'
      'location = "$location"\n',
    );
    buf.write(
      '$attrPad'
      'name = "$name">\n',
    );
    for (final child in children) {
      buf.write(child.toXmlFragment(depth + 1));
      buf.write('\n');
    }
    buf.write('$pad</Group>');
    return buf.toString();
  }
}
