lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'awskeyring/version'

Gem::Specification.new do |spec|
  spec.name          = 'awskeyring'
  spec.version       = Awskeyring::VERSION
  spec.authors       = ['Tristan Morgan']
  spec.email         = ['tristanmorgan@users.noreply.github.com']

  spec.summary       = 'Manages AWS credentials in the macOS keychain'
  spec.description   = 'Manages AWS credentials in the macOS keychain'
  spec.homepage      = 'https://github.com/tristanmorgan/awskeyring'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('aws-sdk-iam')
  spec.add_dependency('highline')
  spec.add_dependency('ruby-keychain')
  spec.add_dependency('thor')

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end
