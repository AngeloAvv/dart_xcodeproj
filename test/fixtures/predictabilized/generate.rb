# Regenerates the Ruby-predictabilized fixtures used by the predictabilize
# tests and by the round-trip tests.
#
# Usage (from the repository root):
#   ruby test/fixtures/predictabilized/generate.rb
#
# Requires the `xcodeproj` gem, pinned to 1.27.0 below (1.28.1 writes the very
# same files). Each input is opened from a bundle named `Runner.xcodeproj` (the
# name Flutter gives its projects, and the seed of every path), has its UUIDs
# rewritten by `Project#predictabilize_uuids` (32-char MD5 UUIDs) and is saved,
# which gives `<name>.predictabilized.pbxproj`:
#
# - the pristine `flutter create` projects in test/fixtures/annotations/ (iOS
#   and macOS, with and without Swift Package Manager integration, and the
#   hand-written edge cases);
# - test/fixtures/subproject.pbxproj, which has a `projectReferences`
#   dictionary and test target attributes;
# - kitchen_sink.pbxproj next to this script (written by kitchen_sink.rb),
#   which has the kinds of object the Flutter projects lack.
#
# For the two projects the round-trip tests use, that file is then opened and
# saved once more by Ruby, which gives `<name>.ruby_saved.pbxproj`, the output
# the Dart round trip is compared against.
require 'fileutils'
require 'tmpdir'
gem 'xcodeproj', '1.27.0'
require 'xcodeproj'

dir = __dir__
fixtures = File.expand_path('..', dir)
annotations = File.join(fixtures, 'annotations')

inputs = {}
%w[ios macos ios_spm macos_spm edge].each do |name|
  inputs[name] = File.join(annotations, "#{name}.xcodeproj", 'project.pbxproj')
end
inputs['subproject'] = File.join(fixtures, 'subproject.pbxproj')
inputs['kitchen_sink'] = File.join(dir, 'kitchen_sink.pbxproj')

round_trip = %w[ios macos_spm]

inputs.each do |name, input|
  Dir.mktmpdir do |tmp|
    bundle = File.join(tmp, 'Runner.xcodeproj')
    pbxproj = File.join(bundle, 'project.pbxproj')
    FileUtils.mkdir_p(bundle)
    FileUtils.cp(input, pbxproj)

    project = Xcodeproj::Project.open(bundle)
    project.predictabilize_uuids
    project.save
    FileUtils.cp(pbxproj, File.join(dir, "#{name}.predictabilized.pbxproj"))

    next unless round_trip.include?(name)

    Xcodeproj::Project.open(bundle).save
    FileUtils.cp(pbxproj, File.join(dir, "#{name}.ruby_saved.pbxproj"))
  end
end
