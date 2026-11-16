# Regenerates reference_attributes.json, the reference attributes of every
# object class of xcodeproj, in the order `UUIDGenerator#generate_paths`
# follows them (to-one, then to-many, then references by keys; each in
# attribute order, the class' own attributes before its superclass').
#
# Usage (from the repository root):
#   ruby test/fixtures/predictabilized/reference_attributes.rb
#
# Requires the `xcodeproj` gem, pinned to 1.27.0 below.
require 'json'
gem 'xcodeproj', '1.27.0'
require 'xcodeproj'

objects = Xcodeproj::Project::Object
classes = objects.constants
                 .map { |name| objects.const_get(name) }
                 .select { |klass| klass.is_a?(Class) && klass < objects::AbstractObject }

attributes = classes.sort_by(&:name).each_with_object({}) do |klass, hash|
  hash[klass.name.split('::').last] = {
    'toOne' => klass.to_one_attributes.map(&:plist_name),
    'toMany' => klass.to_many_attributes.map(&:plist_name),
    'referencesByKeys' => klass.references_by_keys_attributes.map(&:plist_name),
  }
end

File.write(File.join(__dir__, 'reference_attributes.json'),
           JSON.pretty_generate(attributes) + "\n")
