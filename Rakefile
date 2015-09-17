$:.unshift File.expand_path('../lib', __FILE__)

require 'rake/testtask'
require 'wolftrans/version'

GEM_FILENAME = "wolftrans-#{WolfTrans::VERSION}.gem"

task :build do
  system "gem build wolftrans.gemspec"
end

task :release => :build do
  system "gem push #{GEM_FILENAME}"
end

task :install => :build do
  system "gem install #{GEM_FILENAME}"
end

task :uninstall do
  system "gem uninstall wolftrans --version #{WolfTrans::VERSION}"
end

task :clean do
  File.delete(GEM_FILENAME) if File.exist? GEM_FILENAME
end

Rake::TestTask.new do |t|
  t.libs << 'test'
end

task :default => :build
