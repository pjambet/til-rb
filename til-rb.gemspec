Gem::Specification.new do |s|
  s.name        = 'til-rb'
  s.version     = '0.0.1'
  s.executables << 'til'
  s.date        = '2020-06-24'
  s.summary     = 'A utility to manage a repo of TILs'
  s.description = 'til-rb helps you manage a repo of TILs similar to https://github.com/jbranchaud/til'
  s.authors     = ['Pierre Jambet']
  s.email       = 'hello@pjam.me'
  s.files       = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md)
  s.homepage    = 'https://rubygems.org/gems/til-rb'
  s.license     = 'MIT'
  s.add_runtime_dependency 'octokit', '~> 4.0'
  s.add_development_dependency 'mocha', '~> 1.11.2'
end
