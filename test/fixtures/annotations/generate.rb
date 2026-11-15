# Regenerates the Ruby-side expectations used by the asciiPlistAnnotation tests.
#
# Usage (from the repository root):
#   ruby test/fixtures/annotations/generate.rb
#
# Requires the `xcodeproj` gem (1.27.0). For every `*.xcodeproj` in this
# directory it writes `<name>.annotations.json`, a `{uuid => annotation}` map
# produced by `AbstractObject#ascii_plist_annotation`. `edge.xcodeproj` is
# (re)built from scratch to cover cases the Flutter templates do not contain.
require 'json'
require 'fileutils'
require 'xcodeproj'

dir = __dir__

edge_path = File.join(dir, 'edge.xcodeproj')
FileUtils.rm_rf(edge_path)
project = Xcodeproj::Project.new(edge_path)
target = project.new_target(:application, 'App', :ios, '13.0')

# Unnamed and named shell script phases.
target.new_shell_script_build_phase
target.new_shell_script_build_phase('Run Script')

# Named copy-files phase.
copy = target.new_copy_files_build_phase('Embed Frameworks')
copy.add_file_reference(project.main_group.new_file('Foo.framework'))

# File reference whose path is nested: display name is the basename.
nested = project.main_group.new_file('../shared/Nested.swift')
target.source_build_phase.add_file_reference(nested)

# Remote Swift package + product dependency (build file with productRef only).
remote = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
remote.repositoryURL = 'https://github.com/apple/swift-collections.git'
remote.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '1.0.0' }
project.root_object.package_references << remote
remote_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
remote_product.package = remote
remote_product.product_name = 'Collections'
target.package_product_dependencies << remote_product
product_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
product_file.product_ref = remote_product
target.frameworks_build_phase.files << product_file

# Local Swift package + product dependency.
local = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local.relative_path = '../Packages/LocalPackage'
project.root_object.package_references << local
local_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
local_product.package = local
local_product.product_name = 'LocalPackage'
target.package_product_dependencies << local_product

# Target dependency (+ container item proxy) on a second target.
other = project.new_target(:framework, 'Other', :ios, '13.0')
target.add_dependency(other)

project.save

Dir.glob(File.join(dir, '*.xcodeproj')).sort.each do |path|
  proj = Xcodeproj::Project.open(path)
  annotations = {}
  proj.objects_by_uuid.sort.each do |uuid, obj|
    annotations[uuid] = obj.ascii_plist_annotation
  end
  # The root object annotation is also what the writer emits for `rootObject`.
  File.write(path.sub(/\.xcodeproj\z/, '.annotations.json'),
             JSON.pretty_generate(annotations) + "\n")
end
