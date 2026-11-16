# Regenerates the Ruby-side expectations of
# test/scheme/xc_scheme_typed_actions_test.dart.
#
# Usage (from the repository root):
#   ruby test/fixtures/scheme/typed_actions/generate.rb
#
# Pins the `xcodeproj` gem to 1.27.0 (1.28.1 produces the same output: its
# scheme classes are identical). For each input scheme it writes:
#
# - expected.json: what the typed action getters of Ruby's XCScheme return
#   (`build_action`, `test_action`, `launch_action`, `profile_action`,
#   `analyze_action`, `archive_action`), and whether the action element is in
#   the document after the getters have been called;
# - <name>.build_configuration.ruby_saved.xcscheme: the scheme saved after
#   `launch_action.build_configuration = 'Debug-dev'`;
# - <name>.read_only.ruby_saved.xcscheme: the scheme saved after the getters
#   have been called, nothing else;
# - <name>.replaced_launch.ruby_saved.xcscheme and
#   <name>.replaced_analyze.ruby_saved.xcscheme: the scheme saved after
#   `launch_action = LaunchAction.new` / `analyze_action = AnalyzeAction.new`
#   with a `buildConfiguration` of 'Custom'.
gem 'xcodeproj', '1.27.0'
require 'json'
require 'xcodeproj'

dir = __dir__
fixtures = File.expand_path('..', dir)
inputs = {
  'ios_Runner' => File.join(fixtures, 'flutter', 'ios_Runner.xcscheme'),
  'macos_Runner' => File.join(fixtures, 'flutter', 'macos_Runner.xcscheme'),
  'missing_actions' => File.join(dir, 'missing_actions.xcscheme'),
  'repeated_actions' => File.join(dir, 'repeated_actions.xcscheme'),
  'pre_post_actions' => File.join(dir, 'pre_post_actions.xcscheme')
}

ACTIONS = {
  'build' => 'BuildAction',
  'test' => 'TestAction',
  'launch' => 'LaunchAction',
  'profile' => 'ProfileAction',
  'analyze' => 'AnalyzeAction',
  'archive' => 'ArchiveAction'
}.freeze

def types(list)
  list && list.map(&:action_type)
end

def flag
  yield
rescue Xcodeproj::Informative
  'raises'
end

def describe(action)
  out = {
    'preActionTypes' => types(action.pre_actions),
    'postActionTypes' => types(action.post_actions)
  }
  # Ruby's BuildAction has no build_configuration.
  out['buildConfiguration'] = action.build_configuration if action.respond_to?(:build_configuration)
  case action
  when Xcodeproj::XCScheme::BuildAction
    out['parallelizeBuildables'] = flag { action.parallelize_buildables? }
    out['buildImplicitDependencies'] = flag { action.build_implicit_dependencies? }
    out['entriesCount'] = action.entries && action.entries.length
  when Xcodeproj::XCScheme::TestAction
    out['shouldUseLaunchSchemeArgsEnv'] = flag { action.should_use_launch_scheme_args_env? }
    out['codeCoverageEnabled'] = flag { action.code_coverage_enabled? }
    out['testablesCount'] = action.testables && action.testables.length
  when Xcodeproj::XCScheme::LaunchAction
    out['allowLocationSimulation'] = flag { action.allow_location_simulation? }
  when Xcodeproj::XCScheme::ProfileAction
    out['shouldUseLaunchSchemeArgsEnv'] = flag { action.should_use_launch_scheme_args_env? }
  when Xcodeproj::XCScheme::ArchiveAction
    out['revealArchiveInOrganizer'] = flag { action.reveal_archive_in_organizer? }
    out['customArchiveName'] = action.custom_archive_name
  end
  out
end

expected = {}
inputs.each do |name, path|
  scheme = Xcodeproj::XCScheme.new(path)
  root = scheme.doc.root
  entry = {}
  ACTIONS.each do |key, tag|
    in_document_before = !root.elements[tag].nil?
    action = scheme.send("#{key}_action")
    entry[key] = describe(action).merge(
      'inDocumentBefore' => in_document_before,
      'inDocumentAfter' => !root.elements[tag].nil?,
      'sameObjectOnSecondCall' => scheme.send("#{key}_action").equal?(action)
    )
  end
  expected[name] = entry
  File.write(File.join(dir, "#{name}.read_only.ruby_saved.xcscheme"), scheme.to_s)

  edited = Xcodeproj::XCScheme.new(path)
  edited.launch_action.build_configuration = 'Debug-dev'
  File.write(File.join(dir, "#{name}.build_configuration.ruby_saved.xcscheme"), edited.to_s)

  replaced = Xcodeproj::XCScheme.new(path)
  launch = Xcodeproj::XCScheme::LaunchAction.new
  launch.build_configuration = 'Custom'
  replaced.launch_action = launch
  File.write(File.join(dir, "#{name}.replaced_launch.ruby_saved.xcscheme"), replaced.to_s)

  replaced = Xcodeproj::XCScheme.new(path)
  analyze = Xcodeproj::XCScheme::AnalyzeAction.new
  analyze.build_configuration = 'Custom'
  replaced.analyze_action = analyze
  File.write(File.join(dir, "#{name}.replaced_analyze.ruby_saved.xcscheme"), replaced.to_s)
end

File.write(File.join(dir, 'expected.json'), "#{JSON.pretty_generate(expected)}\n")
