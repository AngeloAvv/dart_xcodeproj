# Writes test/fixtures/predictabilized/kitchen_sink.pbxproj, a project built
# with xcodeproj itself that has the kinds of object the pristine Flutter
# projects lack (build rules, legacy and aggregate targets, version groups,
# headers and copy files phases, a Rez phase, a synchronized folder with an
# exception set...). `generate.rb` predictabilizes it like the other inputs.
#
# Usage (from the repository root):
#   ruby test/fixtures/predictabilized/kitchen_sink.rb
#   ruby test/fixtures/predictabilized/generate.rb
#
# Requires the `xcodeproj` gem, pinned to 1.27.0 below. The UUIDs of the file
# are random, but the file is written once and committed: the predictabilized
# output depends on the UUIDs only where an attribute holds one as a string.
require 'fileutils'
require 'tmpdir'
gem 'xcodeproj', '1.27.0'
require 'xcodeproj'

Dir.mktmpdir do |tmp|
  bundle = File.join(tmp, 'Runner.xcodeproj')
  project = Xcodeproj::Project.new(bundle)
  objects = Xcodeproj::Project::Object

  app = project.new_target(:application, 'App', :ios)
  tests = project.new_target(:unit_test_bundle, 'AppTests', :ios)
  tests.add_dependency(app)

  sources = project.main_group.new_group('Sources', 'Sources')
  swift = sources.new_file('Main.swift')
  header = sources.new_file('Main.h')
  other = sources.new_file('Other.swift')
  app.add_file_references([swift, other])
  app.headers_build_phase.add_file_reference(header, true)

  # Two groups that look the same get the same path, hence the same UUID:
  # predictabilize_uuids warns and keeps one of them.
  2.times { sources.new_group('Duplicate') }

  # A variant group, as Xcode makes for localized resources.
  variant = sources.new_variant_group('Localizable.strings')
  variant.new_reference('en.lproj/Localizable.strings')
  variant.new_reference('it.lproj/Localizable.strings')
  app.resources_build_phase.add_file_reference(variant)

  # A Core Data model, which is a version group.
  model = project.main_group.new_reference('Model.xcdatamodeld')
  app.add_resources([model])

  copy = app.new_copy_files_build_phase('Embed')
  copy.dst_subfolder_spec = '10'
  copy.add_file_reference(other)

  app.new_shell_script_build_phase('Run Script').shell_script = 'echo hello'
  app.build_phases << project.new(objects::PBXRezBuildPhase)

  rule = project.new(objects::PBXBuildRule)
  rule.name = 'Process'
  rule.compiler_spec = 'com.apple.compilers.proxy.script'
  rule.file_type = 'pattern.proxy'
  rule.file_patterns = '*.foo'
  rule.script = 'cat'
  rule.output_files = ['$(DERIVED_FILE_DIR)/out']
  # Ruby leaves this out unless set, Dart's PBXBuildRule always has it.
  rule.output_files_compiler_flags = []
  app.build_rules << rule

  aggregate = project.new(objects::PBXAggregateTarget)
  aggregate.name = 'Aggregate'
  aggregate.build_configuration_list = project.new(objects::XCConfigurationList)
  aggregate.build_configuration_list.build_configurations <<
    project.new(objects::XCBuildConfiguration).tap { |c| c.name = 'Debug' }
  aggregate.add_dependency(app)
  project.root_object.targets << aggregate

  legacy = project.new(objects::PBXLegacyTarget)
  legacy.name = 'Legacy'
  legacy.build_tool_path = '/usr/bin/make'
  legacy.build_configuration_list = project.new(objects::XCConfigurationList)
  legacy.build_configuration_list.build_configurations <<
    project.new(objects::XCBuildConfiguration).tap { |c| c.name = 'Release' }
  project.root_object.targets << legacy

  # A synchronized folder of the app with a build phase exception set. A build
  # file exception set (which has the target as its `target`) would make
  # predictabilize_uuids recurse forever in Ruby: target, folder, exception
  # set, target...
  folder = project.new(objects::PBXFileSystemSynchronizedRootGroup)
  folder.path = 'Synced'
  folder.source_tree = '<group>'
  phase_exceptions = project.new(
    objects::PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
  )
  phase_exceptions.build_phase = copy
  phase_exceptions.membership_exceptions = ['Skipped.swift']
  folder.exceptions << phase_exceptions
  project.main_group << folder
  app.file_system_synchronized_groups << folder

  project.save
  FileUtils.cp(File.join(bundle, 'project.pbxproj'),
               File.join(__dir__, 'kitchen_sink.pbxproj'))
end
