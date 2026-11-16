# Regenerates the Ruby-produced expected files used by
# test/pbx/build_phase_helpers_ruby_parity_test.dart.
#
# Usage (from the repository root):
#   ruby test/fixtures/build_phases/generate.rb
#   XCODEPROJ_GEM_VERSION=1.28.1 ruby test/fixtures/build_phases/generate.rb
#
# Requires the `xcodeproj` gem, pinned to 1.27.0 unless XCODEPROJ_GEM_VERSION
# says otherwise (1.28.1 writes the very same files).
#
# Each input is a pristine `flutter create` project of test/fixtures/annotations/
# (iOS and macOS), opened from a bundle named `Runner.xcodeproj`. A scenario
# calls the build phase helpers of PBXNativeTarget, then the UUIDs are made
# predictable with `Project#predictabilize_uuids` (the new objects get random
# UUIDs otherwise) and the project is saved, which gives
# `<input>.<scenario>.pbxproj`.
#
# The scenarios are mirrored, call for call, by the Dart parity test: change one
# and change the other.
require 'fileutils'
require 'tmpdir'
gem 'xcodeproj', ENV.fetch('XCODEPROJ_GEM_VERSION', '1.27.0')
require 'xcodeproj'

dir = __dir__
annotations = File.expand_path('../annotations', dir)
out_dir = ENV.fetch('OUT_DIR', dir)

# A native target that has no build phase at all, so every helper that creates
# a phase on demand has to.
def bare_target(project)
  target = project.new(Xcodeproj::Project::PBXNativeTarget)
  project.targets << target
  target.name = 'Bare'
  target.product_name = 'Bare'
  target.product_type = 'com.apple.product-type.library.static'
  target.build_configuration_list = project.new(Xcodeproj::Project::XCConfigurationList)
  target
end

def runner(project)
  project.targets.find { |t| t.name == 'Runner' }
end

SCENARIOS = {
  # source/frameworks/resources/headers phases are found, or created in the
  # order they are asked for.
  'on_demand' => lambda do |project|
    bare = bare_target(project)
    bare.source_build_phase
    bare.frameworks_build_phase
    bare.resources_build_phase
    bare.headers_build_phase
    bare.source_build_phase
    runner(project).headers_build_phase
  end,

  # Files go to the sources or the headers phase by extension, compiler flags
  # are appended, files already in a phase are reused.
  'add_file_references' => lambda do |project|
    target = runner(project)
    foo_m = project.new_file('Runner/Foo.m')
    foo_h = project.new_file('Runner/Foo.h')
    upper = project.new_file('Runner/Bar.HPP')
    swift = project.new_file('Runner/Baz.swift')
    dup = project.new_file('Runner/Dup.swift')
    target.add_file_references([foo_m, foo_h, upper, swift], '-fobjc-arc')
    target.add_file_references([foo_m], '-Wall')
    target.add_file_references([foo_m, swift])
    target.add_file_references([swift], '-DX')
    target.add_file_references([dup, dup], '')
    target.add_file_references([])
    existing = target.source_build_phase.files.first.file_ref
    target.add_file_references([existing], '-O')
    target.add_file_references([foo_h], '-fobjc-arc')
    bare = bare_target(project)
    bare.add_file_references([swift])
  end,

  # Resources are added once, to a resources phase created when missing.
  'add_resources' => lambda do |project|
    target = runner(project)
    first = project.new_file('Runner/Assets/a.png')
    second = project.new_file('Runner/b.json')
    third = project.new_file('Runner/c.txt')
    target.add_resources([first, second])
    target.add_resources([first])
    target.add_resources([target.resources_build_phase.files.first.file_ref])
    target.add_resources([])
    target.add_resources([third, third])
    bare = bare_target(project)
    bare.add_resources([first])
  end,

  # Shell script and copy files phases are appended after the existing ones.
  'new_phases' => lambda do |project|
    target = runner(project)
    script = target.new_shell_script_build_phase('Run Foo')
    script.shell_script = 'echo foo'
    target.new_shell_script_build_phase
    target.new_copy_files_build_phase('Copy Foo')
    target.new_copy_files_build_phase
    bare = bare_target(project)
    bare.new_shell_script_build_phase('Only')
  end,
}.freeze

%w[ios macos].each do |name|
  input = File.join(annotations, "#{name}.xcodeproj", 'project.pbxproj')
  SCENARIOS.each do |scenario, run|
    Dir.mktmpdir do |tmp|
      bundle = File.join(tmp, 'Runner.xcodeproj')
      FileUtils.mkdir_p(bundle)
      FileUtils.cp(input, File.join(bundle, 'project.pbxproj'))

      project = Xcodeproj::Project.open(bundle)
      run.call(project)
      project.predictabilize_uuids
      project.save
      FileUtils.cp(File.join(bundle, 'project.pbxproj'),
                   File.join(out_dir, "#{name}.#{scenario}.pbxproj"))
    end
  end
end
