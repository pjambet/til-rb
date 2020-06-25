require_relative 'lib/til/version'

Gem::Specification.new do |s|
  s.name        = 'til-rb'
  s.version     = Til::VERSION
  s.executables << 'til'
  s.date        = '2020-06-24'
  s.summary     = 'A utility to manage a repo of TILs'
  s.description = 'til-rb helps you manage a repo of TILs similar to https://github.com/jbranchaud/til'
  s.authors     = ['Pierre Jambet']
  s.email       = 'hello@pjam.me'
  s.files       = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md) - %w(til.gif)
  s.homepage    = 'https://github.com/pjambet/til-rb/'
  s.license     = 'MIT'
  s.add_runtime_dependency 'octokit', '~> 4.0'
  s.add_development_dependency 'mocha', '~> 1.11.2'
  s.add_development_dependency 'timecop', '~> 0.9.1'
end
