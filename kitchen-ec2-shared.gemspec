# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/ec2_shared_version.rb'

Gem::Specification.new do |gem|
  gem.name          = 'kitchen-ec2-shared'
  gem.version       = Kitchen::Driver::EC2_SHARED_VERSION
  gem.license       = 'Apache 2.0'
  gem.authors       = ['Andrey Linko']
  gem.email         = ['AndreyLinko@gmail.com']
  gem.description   = 'A Test Kitchen Driver for Amazon EC2 with shared node config'
  gem.summary       = gem.description
  gem.homepage      = 'http://kitchen.ci/'

  gem.files         = `git ls-files`.split("\n")
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ['lib']

  gem.add_dependency 'kitchen-ec2', '~> 0.8'
  gem.add_dependency 'rubocop'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'pry'
end
