$:.push File.expand_path("../lib", __FILE__)

require "reth/version"

Gem::Specification.new do |s|
  s.name        = "reth"
  s.version     = Reth::VERSION
  s.authors     = ["Jan Xie"]
  s.email       = ["jan.h.xie@gmail.com"]
  s.homepage    = "https://github.com/janx/reth"
  s.summary     = "Ethereum full node."
  s.description = "A ethereum full node written in ruby."
  s.license     = 'MIT'

  s.files = Dir["{bin,lib}/**/*"] + ["LICENSE", "README.md"]

  s.add_dependency('ruby-ethereum', '~> 0.9')
  s.add_dependency('devp2p', '~> 0.3')
  s.add_dependency('slop', '~> 4.3')
  s.add_dependency('sinatra', '~> 1.4')
  s.add_dependency('sinatra-contrib', '~> 1.4')

  s.add_development_dependency('rake', '~> 10.5')
  s.add_development_dependency('minitest', '5.8.3')
  s.add_development_dependency('yard', '0.8.7.6')
  s.add_development_dependency('serpent', '~> 0.3')
end
