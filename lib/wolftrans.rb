require 'wolftrans/patch_text'
require 'wolftrans/patch_data'
require 'wolf'

module WolfTrans
  class Patch
    def initialize(game_path, patch_path)
      @strings = Hash.new { |hash, key| hash[key] = Hash.new }
      load_data(game_path)
      load_patch(patch_path)
    end
  end

  # Represents a translated string
  class Translation
    attr_reader :patch_filename
    attr_reader :string
    attr_accessor :autogenerate
    alias_method :autogenerate?, :autogenerate

    def initialize(patch_filename, string='', autogenerate=true)
      @patch_filename = patch_filename
      @string = string
      @autogenerate = autogenerate
    end

    def to_s
      @string
    end
  end

  # Version; represents a major/minor version scheme
  class Version
    include Comparable
    attr_accessor :major
    attr_accessor :minor

    def initialize(major: nil, minor: nil, flt: nil, str: nil)
      # See if we need to parse from a string
      if flt
        string = flt.to_s
      elsif str
        string = str
      else
        string = nil
      end

      # Extract major and minor numbers
      if string
        if match = string.match(/(\d+)\.(\d+)/)
          @major, @minor = match.captures.map { |s| s.to_i }
        else
          raise "could not parse version string '#{string}'"
        end
      elsif major && minor
        @major = major
        @minor = minor
      else
        @major = 0
        @minor = 0
      end
    end

    def to_s
      "#{@major}.#{@minor}"
    end

    def <=>(other)
      case other
      when Version
        return 0 if major == other.major && minor == other.minor
        return 1 if major > other.major || (major == other.major && minor >= other.minor)
        return -1
      when String
        return self == Version.new(str = other)
      when Float
        return self == Version.new(flt = other)
      end
      return nil
    end
  end

  # IO functions
  module IO
    def self.read_txt(filename)
      # Read file into memory, forcing UTF-8 without BOM.
      text = nil
      File.open(filename, 'rb:UTF-8') do |file|
        if text = file.read(3)
          if text == "\xEF\xBB\xBF"
            raise "UTF-8 BOM detected; refusing to read file"
          end
          text << file.read
        else
          STDERR.puts "warning: empty patch file '#{filename}'"
          return ''
        end
      end
      # Convert Windows newlines and return
      text.gsub(/\r\n?/, "\n")
    end
  end

  #####################
  # Utility functions #

  # Sanitize a path; i.e., standardize path separators remove trailing separator
  def self.sanitize_path(path)
    if File::ALT_SEPARATOR
      path = path.gsub(File::ALT_SEPARATOR, '/')
    end
    path.sub(/\/$/, '')
  end

  # Get the name of a path case-insensitively
  def self.join_path_nocase(parent, child)
    child_case = Dir.entries(parent).select { |e| e.downcase == child }.first
    return nil unless child_case
    return "#{parent}/#{child_case}"
  end

  # Strip all leading/trailing whitespace, including fullwidth spaces
  def self.full_strip(str)
    str.strip.sub(/^\u{3000}*/, '').sub(/\u{3000}*$/, '')
  end

  # Escape a string for use as a path on the filesystem
  # https://stackoverflow.com/questions/2270635/invalid-chars-filter-for-file-folder-name-ruby
  def self.escape_path(path)
    full_strip(path).gsub(/[\x00\/\\:\*\?\"<>\|]/, '_')
  end

  ###################
  # Debug functions #
  def self.grep(dir, needle)
    Find.find(dir) do |path|
      next if FileTest.directory? path

      basename = File.basename(path)
      basename_downcase = basename.downcase
      basename_noext = File.basename(basename_downcase, '.*')
      parent_path = File.dirname(path)
      ext = File.extname(basename_downcase)

      if ext.downcase == '.mps'
        Wolf::Map.new(path).grep(needle)
      elsif ext.downcase == '.project'
        next if basename_downcase == 'sysdatabasebasic.project'
        dat_filename = WolfTrans.join_path_nocase(parent_path, "#{basename_noext}.dat")
        next if dat_filename == nil
        Wolf::Database.new(path, dat_filename).grep(needle)
      elsif basename_downcase == 'commonevent.dat'
        Wolf::CommonEvents.new(path).grep(needle)
      end
    end
  end

  def self.grep_cid(dir, cid)
    Find.find(dir) do |path|
      next if FileTest.directory? path
      if File.extname(path).downcase == '.mps'
        Wolf::Map.new(path).grep_cid(cid)
      end
    end
  end

  # Latest patch version format that can be read
  TXT_VERSION = Version.new(major: 1, minor: 0)
end
