# Regenerates the Ruby-side expectations used by the round-trip golden tests.
#
# Usage (from the repository root):
#   ruby test/fixtures/golden/generate.rb
#
# Requires the `xcodeproj` gem (1.27.0). The pristine inputs are the
# `flutter create` projects in test/fixtures/annotations/. Each one is opened
# and saved by Ruby from a bundle named `Runner.xcodeproj` (the name Flutter
# gives it, which the saved file embeds in the project's configuration list
# annotation), and the result is stored as `<name>.ruby_saved.pbxproj`.
# The Dart test asserts that its own open + save differs from the input on no
# line where Ruby's does not.
require 'fileutils'
require 'tmpdir'
require 'xcodeproj'

dir = __dir__
inputs = File.expand_path('../annotations', dir)

%w[ios macos ios_spm macos_spm].each do |name|
  Dir.mktmpdir do |tmp|
    bundle = File.join(tmp, 'Runner.xcodeproj')
    FileUtils.cp_r(File.join(inputs, "#{name}.xcodeproj"), bundle)
    Xcodeproj::Project.open(bundle).save
    FileUtils.cp(File.join(bundle, 'project.pbxproj'),
                 File.join(dir, "#{name}.ruby_saved.pbxproj"))
  end
end
