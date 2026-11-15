# Regenerates the Ruby-predictabilized fixtures used by the round-trip tests.
#
# Usage (from the repository root):
#   ruby test/fixtures/predictabilized/generate.rb
#
# Requires the `xcodeproj` gem (1.27.0). Each pristine `flutter create` project
# in test/fixtures/annotations/ is opened from a bundle named `Runner.xcodeproj`
# (the name Flutter gives it), has its UUIDs rewritten by
# `Project#predictabilize_uuids` (32-char MD5 UUIDs) and is saved, which gives
# `<name>.predictabilized.pbxproj`. That file is then opened and saved once more
# by Ruby, which gives `<name>.ruby_saved.pbxproj`, the output the Dart round
# trip is compared against.
require 'fileutils'
require 'tmpdir'
require 'xcodeproj'

dir = __dir__
inputs = File.expand_path('../annotations', dir)

%w[ios macos_spm].each do |name|
  Dir.mktmpdir do |tmp|
    bundle = File.join(tmp, 'Runner.xcodeproj')
    pbxproj = File.join(bundle, 'project.pbxproj')
    FileUtils.cp_r(File.join(inputs, "#{name}.xcodeproj"), bundle)

    project = Xcodeproj::Project.open(bundle)
    project.predictabilize_uuids
    project.save
    FileUtils.cp(pbxproj, File.join(dir, "#{name}.predictabilized.pbxproj"))

    Xcodeproj::Project.open(bundle).save
    FileUtils.cp(pbxproj, File.join(dir, "#{name}.ruby_saved.pbxproj"))
  end
end
