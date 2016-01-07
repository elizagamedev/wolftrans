$:.unshift File.expand_path('../lib', __FILE__)

require 'wolftrans/version'

Gem::Specification.new do |s|
  s.name          = 'wolftrans'
  s.version       = WolfTrans::VERSION
  s.summary       = 'A utility to translate Wolf RPG Editor games'
  s.description   = s.summary
  s.authors       = ['Mathew Velasquez']
  s.email         = 'mathewvq@gmail.com'
  s.files         = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.executables   << 'wolftrans'
  s.homepage      = 'https://github.com/mathewv/wolftrans'
  s.license       = 'MPL'
end
