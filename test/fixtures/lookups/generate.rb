# Regenerates the Ruby-side expectations of the group and project lookup tests
# (test/project/lookups_ruby_parity_test.dart).
#
# Usage (from the repository root):
#   ruby test/fixtures/lookups/generate.rb                  # gem 1.27.0 (default)
#   XCODEPROJ_GEM_VERSION=1.28.1 ruby test/fixtures/lookups/generate.rb
#   ruby test/fixtures/lookups/generate.rb --rebuild-input  # also rewrites lookups.pbxproj
#
# Writes expected.json: one case per lookup call, with the result Ruby gives
# (objects by UUID, objects Ruby created by their attributes, the Ruby error
# class when it raises) and, for the calls that change the project, the group
# tree and the object counts afterwards. Everything in it was produced by
# xcodeproj, never by Dart. The inputs are the pristine `flutter create`
# projects in test/fixtures/annotations/ and lookups.pbxproj, a hand-made
# project (see `build_lookups_input` below) with the shapes Flutter's lack:
# duplicated names, a name that is both a file and a group, nameless groups,
# files without a path or with an absolute one, and a version group.
#
# Each project is opened from a bundle named `Runner.xcodeproj` in a fresh
# temporary directory (`<DIR>` in the recorded paths, `<PARENT>` for the
# directory that holds it).
require 'fileutils'
require 'json'
require 'tmpdir'

version = ENV.fetch('XCODEPROJ_GEM_VERSION', '1.27.0')
gem 'xcodeproj', version
require 'xcodeproj'

HERE = __dir__
FIXTURES = File.expand_path('..', HERE)
ANNOTATIONS = File.join(FIXTURES, 'annotations')
LOOKUPS_INPUT = File.join(HERE, 'lookups.pbxproj')

# Opens `input` from a `Runner.xcodeproj` bundle in a new temporary directory
# and yields the project and the directory.
# Recorded paths have the directories of the run replaced.
def placeholders(path, dir)
  path.to_s.sub(dir, '<DIR>').sub(File.dirname(dir), '<PARENT>')
end

def with_project(input)
  Dir.mktmpdir do |tmp|
    parent = File.realpath(tmp)
    dir = File.join(parent, 'dir')
    bundle = File.join(dir, 'Runner.xcodeproj')
    FileUtils.mkdir_p(bundle)
    FileUtils.cp(input, File.join(bundle, 'project.pbxproj'))
    yield Xcodeproj::Project.open(bundle), dir
  end
end

# The hand-made input: the macOS project plus the shapes the lookups must cope
# with. Built once and committed, so the UUIDs the expectations refer to stay.
def build_lookups_input
  Dir.mktmpdir do |tmp|
    bundle = File.join(tmp, 'Runner.xcodeproj')
    FileUtils.mkdir_p(bundle)
    FileUtils.cp(File.join(ANNOTATIONS, 'macos.xcodeproj', 'project.pbxproj'),
                 File.join(bundle, 'project.pbxproj'))
    project = Xcodeproj::Project.open(bundle)
    main = project.main_group
    target = project.native_targets.first

    # Two groups with the same name, each with a nested group of the same name
    # and a file of the same path.
    dup1 = main.new_group('Dup')
    dup1.new_reference('same.swift')
    dup1.new_reference('only_first.swift')
    dup1.new_group('Inner').new_reference('inner_first.swift')
    dup2 = main.new_group('Dup')
    same2 = dup2.new_reference('same.swift')
    dup2.new_reference('only_second.swift')
    dup2.new_group('Inner').new_reference('inner_second.swift')

    # A name that is a file first and a group afterwards.
    main.new_reference('Shadow')
    main.new_group('Shadow').new_reference('shadow_child.swift')

    # A group without name and path, and a file without path.
    main << project.new(Xcodeproj::Project::Object::PBXGroup)
    nameless_file = project.new(Xcodeproj::Project::Object::PBXFileReference)
    nameless_file.name = 'NoPath'
    main << nameless_file

    # A version group.
    main.new_reference('Model.xcdatamodeld')

    # Files whose source tree is not the group's.
    root_file = main.new_reference('Runner/Info.plist')
    root_file.source_tree = 'SOURCE_ROOT'
    main.new_reference('/abs/path/absolute.swift', :absolute)
    main.new_reference('usr/lib/libz.tbd', :sdk_root)

    # Paths with `.` and `..` components, anchored at SOURCE_ROOT, whose real
    # path Pathname#+ has to resolve.
    ['../up.swift', './dot.swift', 'a/../b/c.swift', 'a/../../two.swift', 'a//b.swift',
     'trailing/', '..', '.', 'a/./b.swift', '../Runner/Info.plist'].each do |path|
      f = main.new_reference(path)
      f.source_tree = 'SOURCE_ROOT'
    end

    # A group anchored at SOURCE_ROOT, and a file of it that has the same real
    # path as a file elsewhere (Runner/AppDelegate.swift).
    from_root = main.new_group('FromRoot', 'Runner', :project)
    from_root.new_reference('AppDelegate.swift')

    # Build files: one file in two phases, one of a group.
    target.source_build_phase.add_file_reference(same2)
    target.resources_build_phase.add_file_reference(same2)
    target.source_build_phase.add_file_reference(root_file)

    project.save
    FileUtils.cp(File.join(bundle, 'project.pbxproj'), LOOKUPS_INPUT)
  end
end

build_lookups_input if ARGV.include?('--rebuild-input') || !File.exist?(LOOKUPS_INPUT)

INPUTS = {
  'ios' => File.join(ANNOTATIONS, 'ios.xcodeproj', 'project.pbxproj'),
  'macos' => File.join(ANNOTATIONS, 'macos.xcodeproj', 'project.pbxproj'),
  'ios_spm' => File.join(ANNOTATIONS, 'ios_spm.xcodeproj', 'project.pbxproj'),
  'macos_spm' => File.join(ANNOTATIONS, 'macos_spm.xcodeproj', 'project.pbxproj'),
  'edge' => File.join(ANNOTATIONS, 'edge.xcodeproj', 'project.pbxproj'),
  'lookups' => LOOKUPS_INPUT,
}.freeze

# Group tree without UUIDs, to compare the shape of a project after a change.
def dump_tree(object)
  node = {
    'isa' => object.isa,
    'name' => object.respond_to?(:name) ? object.name : nil,
    'path' => object.respond_to?(:path) ? object.path : nil,
    'sourceTree' => object.source_tree,
  }
  node['children'] = object.children.map { |c| dump_tree(c) } if object.is_a?(Xcodeproj::Project::Object::PBXGroup)
  node
end

# How a result is recorded: an object of the file by its UUID, an object Ruby
# created by its attributes (its UUID is random), a list of either.
def encode(value, known)
  case value
  when nil then nil
  when Array then value.map { |v| encode(v, known) }
  when Xcodeproj::Project::Object::AbstractObject
    if known.include?(value.uuid)
      { 'uuid' => value.uuid }
    else
      { 'created' => dump_tree(value) }
    end
  else value
  end
end

def run(project, known, tmp)
  result = yield
  { 'result' => encode(result, known) }
rescue ArgumentError, NoMethodError => e
  { 'error' => e.class.name }
end

def counts(project)
  {
    'objects' => project.objects.count,
    'buildFiles' => project.objects.grep(Xcodeproj::Project::Object::PBXBuildFile).count,
    'fileReferences' => project.files.count,
    'groups' => project.objects.grep(Xcodeproj::Project::Object::PBXGroup).count,
  }
end

TREE_FIXTURES = %w[ios lookups].freeze

cases = []

INPUTS.each do |fixture, input|
  # Probe (read only): the UUIDs, groups and files this fixture has.
  uuids = nil
  groups = nil
  files = nil
  with_project(input) do |project, _tmp|
    uuids = project.objects_by_uuid.keys
    groups = project.objects.grep(Xcodeproj::Project::Object::PBXGroup).map(&:uuid)
    files = project.files.map(&:uuid)
  end

  # `call` opens a fresh project, finds the receiver, runs the lookup and
  # records result and, when asked, the state afterwards.
  add = lambda do |id, op, receiver: nil, args: {}, after: false, &body|
    with_project(input) do |project, tmp|
      recv = receiver ? project.objects_by_uuid.fetch(receiver) : project.main_group
      entry = { 'id' => "#{fixture}/#{id}", 'fixture' => fixture, 'op' => op,
                'receiver' => receiver, 'args' => args }
      entry.merge!(run(project, uuids, tmp) { body.call(project, recv, tmp) })
      if after
        # The whole tree is recorded for the two projects that cover the shapes
        # (it is big), the object counts for all of them.
        entry['tree'] = dump_tree(project.main_group) if TREE_FIXTURES.include?(fixture)
        entry['counts'] = counts(project)
      end
      cases << entry
    end
  end

  # find_subpath ------------------------------------------------------------
  with_project(input) do |project, _tmp|
    # Every object by its hierarchy path (without the leading `/`).
    project.main_group.recursive_children.each do |child|
      path = child.hierarchy_path.sub(%r{\A/}, '')
      add.call("find_subpath/#{path}", 'findSubpath',
               args: { 'path' => path, 'create' => false }) { |_p, r, _t| r.find_subpath(path, false) }
    end
  end
  add.call('find_subpath/nil', 'findSubpath', args: { 'path' => nil, 'create' => false }) { |_p, r, _t| r.find_subpath(nil, false) }
  add.call('find_subpath/nil_create', 'findSubpath', args: { 'path' => nil, 'create' => true }, after: true) { |_p, r, _t| r.find_subpath(nil, true) }
  ['', '/', '//', 'Missing', 'Missing/Deeper', '/Runner', 'Runner/', 'Runner//Missing', './Runner', 'runner', 'Main Group'].each do |path|
    add.call("find_subpath/odd:#{path.inspect}", 'findSubpath', args: { 'path' => path, 'create' => false }) { |_p, r, _t| r.find_subpath(path, false) }
  end
  # create: true
  ['Missing', 'Missing/Deeper', 'Missing/Deeper/Deepest', '', '/', '/Missing', 'Missing/', 'A//B', 'Products/New', 'Products/Runner.app/x',
   'Runner', 'Runner/New/Nested', 'Flutter/Missing', 'Frameworks/iOS/New', 'Dup/Inner/New', 'Shadow/x', 'Shadow', 'Dup/Missing'].each do |path|
    add.call("find_subpath_create/#{path.inspect}", 'findSubpath', args: { 'path' => path, 'create' => true }, after: true) { |_p, r, _t| r.find_subpath(path, true) }
  end
  # from a group that is not the main one
  with_project(input) do |project, _tmp|
    project.main_group.groups.first(2).each do |group|
      add.call("find_subpath/from:#{group.display_name}/missing_create", 'findSubpath', receiver: group.uuid,
               args: { 'path' => 'Brand/New', 'create' => true }, after: true) { |_p, r, _t| r.find_subpath('Brand/New', true) }
      add.call("find_subpath/from:#{group.display_name}/missing", 'findSubpath', receiver: group.uuid,
               args: { 'path' => 'Brand/New', 'create' => false }) { |_p, r, _t| r.find_subpath('Brand/New', false) }
    end
  end

  # find_file_by_path ---------------------------------------------------------
  groups.each do |uuid|
    with_project(input) do |project, _tmp|
      group = project.objects_by_uuid.fetch(uuid)
      paths = group.files.map(&:path).compact + [File.basename(group.files.first&.path.to_s), 'missing.swift', '']
      paths.uniq.each do |path|
        add.call("find_file_by_path/#{uuid}/#{path.inspect}", 'findFileByPath', receiver: uuid, args: { 'path' => path }) { |_p, r, _t| r.find_file_by_path(path) }
      end
    end
  end

  # recursive_children --------------------------------------------------------
  groups.each do |uuid|
    add.call("recursive_children/#{uuid}", 'recursiveChildren', receiver: uuid) { |_p, r, _t| r.recursive_children }
  end

  # clear ---------------------------------------------------------------------
  with_project(input) do |project, _tmp|
    project.main_group.groups.each do |group|
      add.call("clear/#{group.display_name}", 'clear', receiver: group.uuid, after: true) { |_p, r, _t| r.clear; nil }
      next unless fixture == 'lookups'

      add.call("remove_children_recursively/#{group.display_name}", 'removeChildrenRecursively', receiver: group.uuid, after: true) { |_p, r, _t| r.remove_children_recursively; nil }
    end
  end
  add.call('clear/main_group', 'clear', after: true) { |_p, r, _t| r.clear; nil }

  # build_files -----------------------------------------------------------------
  (files + groups).each do |uuid|
    add.call("build_files/#{uuid}", 'buildFiles', receiver: uuid) { |_p, r, _t| r.build_files.map(&:uuid).sort.map { |u| { 'uuid' => u } } }
  end

  # The order of `project.objects`, which decides what `find` returns first.
  add.call('objects_order', 'objectsOrder') { |p, _r, _t| p.objects.map(&:uuid) }

  # native_targets / targets ----------------------------------------------------
  add.call('native_targets', 'nativeTargets') { |p, _r, _t| p.native_targets }

  # reference_for_path ------------------------------------------------------------
  with_project(input) do |project, tmp|
    paths = project.files.map { |f| placeholders(f.real_path, tmp) }.uniq
    paths += ['<DIR>/Missing.swift', '<DIR>', '<DIR>/', '<DIR>/Runner/AppDelegate.swift/', '<DIR>/Runner/./AppDelegate.swift',
              '<DIR>/Runner/../Runner/AppDelegate.swift', '<DIR>//Runner/AppDelegate.swift', '/abs/path/absolute.swift',
              'Runner/AppDelegate.swift', 'relative.swift', '', '${BUILT_PRODUCTS_DIR}/Runner.app']
    paths.uniq.each do |path|
      add.call("reference_for_path/#{path.inspect}", 'referenceForPath', args: { 'path' => path }) do |p, _r, t|
        p.reference_for_path(path.sub('<DIR>', t).sub('<PARENT>', File.dirname(t)))
      end
    end
    # The real path of every file reference, to compare Dart's with.
    cases << { 'id' => "#{fixture}/real_paths", 'fixture' => fixture, 'op' => 'realPaths',
               'result' => project.files.map { |f| [f.uuid, placeholders(f.real_path, tmp)] }.to_h }
  end
end

# One case per line, to keep the file diffable.
File.write(File.join(HERE, 'expected.json'),
           "{\"gem\":#{version.to_json},\"cases\":[\n#{cases.map { |c| JSON.generate(c) }.join(",\n")}\n]}\n")
puts "#{cases.length} cases (xcodeproj #{version})"
