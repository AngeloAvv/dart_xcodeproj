# Regenerates the Ruby-produced expected files used by
# test/pbx/build_settings_helpers_ruby_parity_test.dart.
#
# Usage (from the repository root):
#   ruby test/fixtures/build_settings/generate.rb
#   XCODEPROJ_GEM_VERSION=1.28.1 ruby test/fixtures/build_settings/generate.rb
#
# Requires the `xcodeproj` gem, pinned to 1.27.0 unless XCODEPROJ_GEM_VERSION
# says otherwise (1.28.1 writes the very same files).
#
# Each input is a pristine `flutter create` project of test/fixtures/annotations/
# (iOS and macOS), opened from a bundle named `Runner.xcodeproj`. A scenario
# calls `XCConfigurationList#set_setting`, `AbstractTarget#build_settings` and
# `AbstractTarget#add_build_configuration` (and the project-level
# `Project#add_build_configuration`), then the UUIDs are made predictable with
# `Project#predictabilize_uuids` (the new objects get random UUIDs otherwise)
# and the project is saved, which gives `<input>.<scenario>.pbxproj`.
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

# A native target of the given product type whose Debug, Release and Profile
# configurations start with a copy of `settings` (none by default), so
# `add_build_configuration` finds the platform in them.
def target_with(project, name, product_type, settings = {})
  target = project.new(Xcodeproj::Project::PBXNativeTarget)
  project.targets << target
  target.name = name
  target.product_name = name
  target.product_type = product_type
  target.build_configuration_list = project.new(Xcodeproj::Project::XCConfigurationList)
  %w[Debug Release Profile].each do |config_name|
    config = project.new(Xcodeproj::Project::XCBuildConfiguration)
    config.name = config_name
    config.build_settings = settings.dup
    target.build_configuration_list.build_configurations << config
  end
  target
end

def runner(project)
  project.targets.find { |t| t.name == 'Runner' }
end

APPLICATION = 'com.apple.product-type.application'.freeze
FRAMEWORK = 'com.apple.product-type.framework'.freeze

SCENARIOS = {
  # One key in every configuration of a list: an existing key, a new one, a key
  # set twice, array settings (as a string and as an array), `$(inherited)` and
  # `[sdk=...]` conditional keys. The project list and a target with no
  # configuration take it too.
  'set_setting' => lambda do |project|
    list = runner(project).build_configuration_list
    list.set_setting('PRODUCT_BUNDLE_IDENTIFIER', 'com.example.changed')
    list.set_setting('DEVELOPMENT_TEAM', 'ABCDE12345')
    list.set_setting('DEVELOPMENT_TEAM', 'ZZZZZZZZZZ')
    list.set_setting('OTHER_LDFLAGS', '-ObjC -lc++')
    list.set_setting('HEADER_SEARCH_PATHS', ['$(inherited)', '$(SRCROOT)/Pods/Headers'])
    list.set_setting('OTHER_CFLAGS', '$(inherited) -DFOO')
    list.set_setting('HEADER_SEARCH_PATHS[sdk=iphoneos*]', '$(inherited) "$(SRCROOT)/Device"')
    list.set_setting('LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]', %w[a b])
    list.set_setting('LD_RUNPATH_SEARCH_PATHS', '$(inherited) @executable_path/Frameworks')
    project.build_configuration_list.set_setting('SWIFT_VERSION', '5.0')
    project.build_configuration_list.set_setting('FRAMEWORK_SEARCH_PATHS', '$(inherited) $(PROJECT_DIR)/Flutter')
    target_with(project, 'Bare', APPLICATION, 'SDKROOT' => 'iphoneos')
      .build_configuration_list.set_setting('ONLY_BARE', 'YES')
    empty = target_with(project, 'Empty', APPLICATION)
    empty.build_configuration_list.build_configurations.clear
    empty.build_configuration_list.set_setting('NOTHING', 'HAPPENS')
  end,

  # Key level edits of one configuration through `build_settings(name)`, and
  # the nil of an unknown name.
  'build_settings' => lambda do |project|
    target = runner(project)
    target.build_settings('Debug')['FOO'] = 'debug-only'
    target.build_settings('Release')['OTHER_LDFLAGS'] = ['-a', '-b']
    target.build_settings('Profile')['BAR'] = '$(inherited) profile'
    target.build_settings('Profile').delete('CODE_SIGN_STYLE')
    target.build_settings('Debug')['LIBRARY_SEARCH_PATHS[sdk=iphoneos*]'] = '$(inherited) lib'
    target.add_build_configuration('Debug-dev', :debug)
    target.build_settings('Debug-dev')['GCC_PREPROCESSOR_DEFINITIONS'] = ['$(inherited)', 'DEV=1']
    raise 'unknown name must be nil' unless target.build_settings('Nope').nil?
  end,

  # Configurations added to targets: a name that is new, one that exists
  # (idempotent, whatever the type), the same new name twice, and targets of
  # several platforms, product types and deployment targets.
  'add_build_configuration' => lambda do |project|
    target = runner(project)
    target.add_build_configuration('Debug-dev', :debug)
    target.add_build_configuration('Release-dev', :release)
    target.add_build_configuration('Release', :debug)
    target.add_build_configuration('Debug-dev', :release)
    target.add_build_configuration('Profile-dev', :release)

    # No platform: neither the target nor the project says one.
    project.build_configuration_list.build_configurations.each { |c| c.build_settings.delete('SDKROOT') }
    no_platform = target_with(project, 'NoPlatform', FRAMEWORK)
    no_platform.add_build_configuration('Debug-dev', :debug)
    no_platform.add_build_configuration('Release-dev', :release)

    # Other platforms and product types.
    tv = target_with(project, 'Tv', APPLICATION, 'SDKROOT' => 'appletvos', 'TVOS_DEPLOYMENT_TARGET' => '12.0')
    tv.build_configuration_list.set_setting('SDKROOT', 'appletvos')
    project.build_configuration_list.set_setting('SDKROOT', 'appletvos')
    tv.add_build_configuration('Debug-dev', :debug)
    tv.add_build_configuration('Release-dev', :release)

    watch = target_with(project, 'Watch', 'com.apple.product-type.application.watchapp2',
                        'SDKROOT' => 'watchos', 'WATCHOS_DEPLOYMENT_TARGET' => '7.0')
    project.build_configuration_list.set_setting('SDKROOT', 'watchos')
    watch.add_build_configuration('Release-dev', :release)

    vision = target_with(project, 'Vision', 'com.apple.product-type.bundle.unit-test',
                         'SDKROOT' => 'xros', 'XROS_DEPLOYMENT_TARGET' => '1.0')
    project.build_configuration_list.set_setting('SDKROOT', 'xros')
    vision.add_build_configuration('Debug-dev', :debug)

    mac = target_with(project, 'Mac', 'com.apple.product-type.library.static',
                      'SDKROOT' => 'macosx', 'MACOSX_DEPLOYMENT_TARGET' => '10.6')
    project.build_configuration_list.set_setting('SDKROOT', 'macosx')
    mac.add_build_configuration('Debug-dev', :debug)
    mac.add_build_configuration('Release-dev', :release)

    mac_new = target_with(project, 'MacNew', 'com.apple.product-type.framework',
                          'SDKROOT' => 'macosx', 'MACOSX_DEPLOYMENT_TARGET' => '14.0')
    mac_new.add_build_configuration('Release-dev', :release)

    ios_old = target_with(project, 'IosOld', 'com.apple.product-type.app-extension',
                          'SDKROOT' => 'iphoneos', 'IPHONEOS_DEPLOYMENT_TARGET' => '4.3')
    project.build_configuration_list.set_setting('SDKROOT', 'iphoneos')
    ios_old.add_build_configuration('Debug-dev', :debug)

    unknown = target_with(project, 'Unknown', 'com.example.product-type.custom',
                          'SDKROOT' => 'iphoneos')
    unknown.add_build_configuration('Debug-dev', :debug)

    # Debug is also the name of the project configuration: not copied from it.
    unknown.add_build_configuration('Release', :release)
  end,

  # The configurations of a target are looked up in the target list only, and
  # the project one is added by name to the root list.
  'project_add_build_configuration' => lambda do |project|
    project.add_build_configuration('Staging', :release)
    project.add_build_configuration('Staging-debug', :debug)
    project.add_build_configuration('Release', :debug)
    project.add_build_configuration('Staging', :debug)
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
