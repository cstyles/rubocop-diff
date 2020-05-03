# frozen_string_literal: true

require_relative 'lib/rubocop/diff/version'

Gem::Specification.new do |spec|
  spec.name          = 'rubocop-diff'
  spec.version       = RuboCop::Diff::VERSION
  spec.authors       = ['Collin Styles']
  spec.email         = ['collingstyles@gmail.com']

  spec.summary       = 'Run rubocop only on the parts of files modified by your git branch.'
  spec.description   = spec.summary
  spec.homepage      = 'https://github.com/cstyles/rubocop-diff'
  spec.files         = `git ls-files bin lib`.split("\n")

  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage

  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'rubocop', '~> 0.63'
  spec.add_runtime_dependency 'rugged', '~> 1.0'
end
