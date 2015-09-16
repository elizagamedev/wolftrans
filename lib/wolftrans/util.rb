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
  end
end
