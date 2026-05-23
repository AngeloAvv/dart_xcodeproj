/// Position of groups relative to files when sorting project hierarchy.
/// Used by [XcodeProject.sort] and [PBXGroup.sort] to control whether
/// group entries appear before or after file references in each sorted group.
/// - [above]: groups appear before files in each sorted group.
/// - [below]: files appear before groups in each sorted group.
/// - null (omit the argument): groups and files are sorted together by name.
/// Port of Ruby xcodeproj `:groups_position` option in sort(options) calls.
enum GroupsPosition { above, below }
