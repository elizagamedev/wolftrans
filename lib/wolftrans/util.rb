module WolfTrans
  module Util
    # Sanitize a path; i.e., standardize path separators remove trailing separator
    def self.sanitize_path(path)
      if File::ALT_SEPARATOR
        path = path.gsub(File::ALT_SEPARATOR, '/')
      end
      path.sub(/\/$/, '')
    end

    # Get the name of a path case-insensitively
    def self.join_path_nocase(parent, child)
      child_downcase = child.downcase
      child_case = Dir.entries(parent).select { |e| e.downcase == child_downcase }.first
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

    # Determine if a string should be added to the translation map.
    # All non-nill, non-empty, and "black square" character strings are good.
    def self.translatable?(string)
      string && !string.empty? && string != "\u25A0"
    end

    # Read all lines of a txt file as UTF-8, rejecting
    # anything with a BOM
    def self.read_txt(filename)
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
      # text.gsub(/\r\n?/, "\n")
	  text.encode(universal_newline: true)
    end
  end
end
