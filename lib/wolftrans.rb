require 'wolftrans/util.rb'

require 'wolftrans/patch_text'
require 'wolftrans/patch_data'

require 'wolftrans/debug.rb'

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

  # Latest patch version format that can be read
  TXT_VERSION = Version.new(major: 1, minor: 0)
end
