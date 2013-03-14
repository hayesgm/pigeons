# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pigeons/version'

Gem::Specification.new do |gem|
  gem.name          = "pigeons"
  gem.version       = Pigeons::VERSION
  gem.authors       = ["Geoff Hayes"]
  gem.email         = ["geoff@safeshepherd.com"]
  gem.description   = %q{Pigeons makes it a breeze to send your users lifecycle e-mails.}
  gem.summary       = %q{Pigeons provides an extensible way to send our lifecycle e-mails through simple human-readable syntax}
  gem.homepage      = "https://github.com/hayesgm/pigeons"

  gem.add_dependency('activesupport')
  gem.add_dependency('activerecord')
  gem.add_dependency('actionmailer')

  gem.add_development_dependency('mocha')
  gem.add_development_dependency('shoulda')
  gem.add_development_dependency('test-unit')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('sqlite3')

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
