module WolfTrans
  module Debug
    def self.grep(dir, needle)
      Find.find(dir) do |path|
        next if FileTest.directory? path

        basename = File.basename(path)
        basename_downcase = basename.downcase
        basename_noext = File.basename(basename_downcase, '.*')
        parent_path = File.dirname(path)
        ext = File.extname(basename_downcase)

        if ext.downcase == '.mps'
          WolfRpg::Map.new(path).grep(needle)
        elsif ext.downcase == '.project'
          next if basename_downcase == 'sysdatabasebasic.project'
          dat_filename = WolfTrans.join_path_nocase(parent_path, "#{basename_noext}.dat")
          next if dat_filename == nil
          WolfRpg::Database.new(path, dat_filename).grep(needle)
        elsif basename_downcase == 'commonevent.dat'
          WolfRpg::CommonEvents.new(path).grep(needle)
        end
      end
    end

    def self.grep_cid(dir, cid)
      Find.find(dir) do |path|
        next if FileTest.directory? path
        if File.extname(path).downcase == '.mps'
          WolfRpg::Map.new(path).grep_cid(cid)
        end
      end
    end
  end
end
