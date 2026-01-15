# frozen_string_literal: true

require_relative 'lib/binocs/version'

Gem::Specification.new do |spec|
  spec.name        = 'binocs'
  spec.version     = Binocs::VERSION
  spec.authors     = ['Nate Collins']
  spec.email       = ['n@zincan.com']
  spec.homepage    = 'https://github.com/zincan/binocs'
  spec.summary     = 'Laravel Telescope-like request monitoring for Rails'
  spec.description = 'A Rails engine that provides a beautiful dashboard to monitor and debug HTTP requests, similar to Laravel Telescope. Includes a terminal UI with vim keybindings.'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib,exe}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.bindir = 'exe'
  spec.executables = ['binocs']

  spec.required_ruby_version = '>= 3.0.0'

  spec.add_dependency 'rails', '>= 7.0'
  spec.add_dependency 'stimulus-rails', '>= 1.0'
  spec.add_dependency 'turbo-rails', '>= 1.0'
  spec.add_dependency 'curses', '~> 1.4'
end
