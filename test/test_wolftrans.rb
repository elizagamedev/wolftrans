require 'wolftrans'
require 'tmpdir'
require 'open3'

# Attempt to generate patches from any games found in the test directory.

# https://stackoverflow.com/questions/11784109/detecting-operating-systems-in-ruby
def run_exe(filename)
  if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    cmd = [filename]
  else
    cmd = ['env', 'LC_CTYPE=ja_JP.UTF-8', 'wine', filename]
  end
  Open3.popen3(*cmd) do |stdin, stdout, stderr, thread|
    thread.join
  end
end

TEST_DIR = File.dirname(__FILE__)
Dir.entries(TEST_DIR).sort.each do |entry|
  # Skip all non-directories
  next if entry == '.' || entry == '..'
  path = "#{TEST_DIR}/#{entry}"
  next unless File.directory? path

  # Attempt to generate a patch from this game
  Dir.mktmpdir do |tmpdir|
    patch_dir = "#{tmpdir}/patch"
    out_dir = "#{tmpdir}/out"
    puts "==Attempting '#{entry}'"
    WolfTrans::Patch.new(path, patch_dir).apply(out_dir)
    run_exe("#{out_dir}/Game.exe")
  end
end
