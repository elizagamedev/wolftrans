# encoding: utf-8

require 'wolftrans/context'
require 'wolfrpg'

require 'fileutils'
require 'find'

#####################
# Loading Game data #
module WolfTrans
  class Patch
    def load_data(game_dir)
      @game_dir = Util.sanitize_path(game_dir)
      unless Dir.exist? @game_dir
        raise "could not find game folder '#{@game_dir}'"
      end
      @game_data_dir = Util.join_path_nocase(@game_dir, 'data')
      if @game_data_dir == nil
        raise "could not find data folder in '#{@game_dir}'"
      end

      @maps = {}
      @databases = {}

      # Find and read all necessary data
      Dir.entries(@game_data_dir).each do |parent_name|
        parent_name_downcase = parent_name.downcase
        next unless ['basicdata', 'mapdata'].include? parent_name_downcase
        parent_path = "#{@game_data_dir}/#{parent_name}"
        Dir.entries(parent_path).each do |basename|
          basename_downcase = basename.downcase
          extension = File.extname(basename_downcase)
          basename_noext = File.basename(basename_downcase, '.*')
          filename = "#{parent_path}/#{basename}"
          case parent_name_downcase
          when 'mapdata'
            load_map(filename) if extension == '.mps'
          when 'basicdata'
            if basename_downcase == 'game.dat'
              @game_dat_filename = 'Data/BasicData/Game.dat'
              load_game_dat(filename)
            elsif extension == '.project'
              next if basename_downcase == 'sysdatabasebasic.project'
              dat_filename = Util.join_path_nocase(parent_path, "#{basename_noext}.dat")
              next if dat_filename == nil
              load_game_database(filename, dat_filename)
            elsif basename_downcase == 'commonevent.dat'
              load_common_events(filename)
            end
          end
        end
      end

      # Game.dat is in a different place on older versions
      unless @game_dat
        Dir.entries(@game_dir).each do |entry|
          if entry.downcase == 'game.dat'
            @game_dat_filename = 'Game.dat'
            load_game_dat("#{@game_dir}/#{entry}")
            break
          end
        end
      end
    end

    # Apply the patch to the files in the game path and write them to the
    # output directory
    DATA_FILE_EXTENSIONS = ['gif','png','jpg','jpeg','bmp',
                            'ogg','mp3','wav','mid','midi',
                            'dat','project','xxxxx',
                            'txt']
    def apply(out_dir)
      out_dir = Util.sanitize_path(out_dir)
      out_data_dir = "#{out_dir}/Data"

      # Clear out directory
      FileUtils.rm_rf(out_dir)
      FileUtils.mkdir_p("#{out_data_dir}/BasicData")
      FileUtils.mkdir_p("#{out_data_dir}/MapData")

      # Patch all the maps and dump them
      @maps.each do |map_name, map|
        map.events.each do |event|
          next unless event
          event.pages.each do |page|
            page.commands.each_with_index do |command, cmd_index|
              context = Context::MapEvent.from_data(map_name, event, page, cmd_index, command)
              patch_command(command, context)
            end
          end
        end
        map.dump("#{out_data_dir}/MapData/#{map_name}.mps")
      end

      # Patch the databases
      @databases.each do |db_name, db|
        db.types.each_with_index do |type, type_index|
          next if type.name.empty?
          type.data.each_with_index do |datum, datum_index|
            datum.each_translatable do |str, field|
              context = Context::Database.from_data(db_name, type_index, type, datum_index, datum, field)
              yield_translation(str, context) do |newstr|
                datum[field] = newstr
              end
            end
          end
        end
        name_noext = "#{out_data_dir}/BasicData/#{db_name}"
        db.dump("#{name_noext}.project", "#{name_noext}.dat")
      end

      # Patch the common events
      @common_events.events.each do |event|
        event.commands.each_with_index do |command, cmd_index|
          context = Context::CommonEvent.from_data(event, cmd_index, command)
          patch_command(command, context)
        end
      end
      @common_events.dump("#{out_data_dir}/BasicData/CommonEvent.dat")

      # Patch Game.dat
      patch_game_dat
      @game_dat.dump("#{out_dir}/#{@game_dat_filename}")

      # Copy image/sound/music files
      Dir.entries(@game_data_dir, encoding: __ENCODING__).each do |entry|
        # Skip dot and dot-dot and non-directories
        next if entry == '.' || entry == '..'
        path = "#{@game_data_dir}/#{entry}"
        next unless FileTest.directory? path

        # Find the corresponding folder in the out dir
        unless (out_path = Util.join_path_nocase(out_data_dir, entry))
          out_path = "#{out_data_dir}/#{entry}"
          FileUtils.mkdir_p(out_path)
        end

        # Find the corresponding folder in the patch
        if @patch_data_dir && (asset_entry = Util.join_path_nocase(@patch_data_dir, entry))
          copy_data_files(asset_entry, DATA_FILE_EXTENSIONS, out_path)
        end

        # Copy the original game files
        copy_data_files(path, DATA_FILE_EXTENSIONS, out_path)
      end

      # Copy fonts
      if @patch_data_dir
        copy_data_files(@patch_data_dir, ['ttf','ttc','otf'], out_data_dir)
      end
      copy_data_files(@game_data_dir, ['ttf','ttc','otf'], out_data_dir)

      # Copy remainder of files in the base patch/game dirs
      copy_files(@patch_assets_dir, out_dir)
      copy_files(@game_dir, out_dir)
    end

    private
    def load_map(filename)
      map_name = File.basename(filename, '.*')
      patch_filename = "dump/mps/#{map_name}.txt"

      map = WolfRpg::Map.new(filename)
      map.events.each do |event|
        next unless event
        event.pages.each do |page|
          page.commands.each_with_index do |command, cmd_index|
            strings_of_command(command) do |string|
              @strings[string][Context::MapEvent.from_data(map_name, event, page, cmd_index, command)] ||=
                Translation.new(patch_filename)
            end
          end
        end
      end
      @maps[map_name] = map
    end

    def load_game_dat(filename)
      patch_filename = 'dump/GameDat.txt'
      @game_dat = WolfRpg::GameDat.new(filename)
      unless @game_dat.title.empty?
        @strings[@game_dat.title][Context::GameDat.from_data('Title')] = Translation.new(patch_filename)
      end
      unless @game_dat.version.empty?
        @strings[@game_dat.version][Context::GameDat.from_data('Version')] = Translation.new(patch_filename)
      end
      unless @game_dat.font.empty?
        @strings[@game_dat.font][Context::GameDat.from_data('Font')] = Translation.new(patch_filename)
      end
      @game_dat.subfonts.each_with_index do |sf, i|
        unless sf.empty?
          name = 'SubFont' + (i + 1).to_s
          @strings[sf][Context::GameDat.from_data(name)] ||=
            Translation.new(patch_filename)
        end
      end
    end

    def load_game_database(project_filename, dat_filename)
      db_name = File.basename(project_filename, '.*')
      db = WolfRpg::Database.new(project_filename, dat_filename)
      db.types.each_with_index do |type, type_index|
        next if type.name.empty?
        patch_filename = "dump/db/#{db_name}/#{Util.escape_path(type.name)}.txt"
        type.data.each_with_index do |datum, datum_index|
          datum.each_translatable do |str, field|
            context = Context::Database.from_data(db_name, type_index, type, datum_index, datum, field)
            @strings[str][context] ||= Translation.new(patch_filename)
          end
        end
      end
      @databases[db_name] = db
    end

    def load_common_events(filename)
      @common_events = WolfRpg::CommonEvents.new(filename)
      @common_events.events.each do |event|
        patch_filename = "dump/common/#{'%03d' % event.id}_#{Util.escape_path(event.name)}.txt"
        event.commands.each_with_index do |command, cmd_index|
          strings_of_command(command) do |string|
            @strings[string][Context::CommonEvent.from_data(event, cmd_index, command)] ||=
              Translation.new(patch_filename)
          end
        end
      end
    end

    def strings_of_command(command)
      case command
      when WolfRpg::Command::Message
        yield command.text if Util.translatable? command.text
      when WolfRpg::Command::Choices
        command.text.each do |s|
          yield s if Util.translatable? s
        end
      when WolfRpg::Command::StringCondition
        command.string_args.each do |s|
          yield s if Util.translatable? s
        end
      when WolfRpg::Command::SetString
        yield command.text if Util.translatable? command.text
      when WolfRpg::Command::Picture
        if command.type == :text
          yield command.text if Util.translatable? command.text
        end
      when WolfRpg::Command::Database
        yield command.text if Util.translatable? command.text
      end
    end

    def patch_command(command, context)
      case command
      when WolfRpg::Command::Message
        yield_translation(command.text, context) do |str|
          command.text = str
        end
      when WolfRpg::Command::Choices
        command.text.each_with_index do |text, i|
          yield_translation(text, context) do |str|
            command.text[i] = str
          end
        end
      when WolfRpg::Command::StringCondition
        command.string_args.each_with_index do |arg, i|
          next if arg.empty?
          yield_translation(arg, context) do |str|
            command.string_args[i] = str
          end
        end
      when WolfRpg::Command::SetString
        yield_translation(command.text, context) do |str|
          command.text = str
        end
      when WolfRpg::Command::Picture
        if command.type == :text
          yield_translation(command.text, context) do |str|
            command.text = str
          end
        end
      when WolfRpg::Command::Database
        yield_translation(command.text, context) do |str|
          command.text = str
        end
      end
    end

    def patch_game_dat
      yield_translation(@game_dat.title, Context::GameDat.from_data('Title')) do |str|
        @game_dat.title = str
      end
      yield_translation(@game_dat.version, Context::GameDat.from_data('Version')) do |str|
        @game_dat.version = str
      end
      yield_translation(@game_dat.font, Context::GameDat.from_data('Font')) do |str|
        @game_dat.font = str
      end
      @game_dat.subfonts.each_with_index do |sf, i|
        name = 'SubFont' + (i + 1).to_s
        yield_translation(sf, Context::GameDat.from_data(name)) do |str|
          @game_dat.subfonts[i] = str
        end
      end
    end

    # Yield a translation for the given string and context if it exists
    def yield_translation(string, context)
      return unless Util.translatable? string
      if @strings.include? string
        str = @strings[string][context].string
        yield str if Util.translatable? str
      end
    end

    # Copy normal, non-data files
    def copy_files(src_dir, out_dir)
      Find.find(src_dir) do |path|
        basename = File.basename(path)
        basename_downcase = basename.downcase

        # Don't do anything in Data/
        Find.prune if basename_downcase == 'data' && File.dirname(path) == src_dir

        # Skip directories
        next if FileTest.directory? path

        # "Short name", relative to the game base dir
        short_path = path[src_dir.length+1..-1]
        Find.prune if @file_blacklist.include? short_path.downcase

        out_path = "#{out_dir}/#{short_path}"
        next if ['thumbs.db', 'desktop.ini', '.ds_store'].include? basename_downcase
        next if File.exist? out_path
        # Make directory only only when copying a file to avoid making empty directories
        FileUtils.mkdir_p(File.dirname(out_path))
        FileUtils.cp(path, out_path)
      end
    end

    # Copy data files
    def copy_data_files(src_dir, extensions, out_dir)
      Dir.chdir(src_dir) do
        Dir.glob(File.join("**", "*")).each do |entry|
          # Don't care about directories
          next if entry == '.' || entry == '..'
          path = "#{src_dir}/#{entry}"
          next if FileTest.directory? path

          # Skip invalid file extensions
          next unless extensions.include? File.extname(entry)[1..-1]

          # Copy the file if it doesn't already exist
          next if Util.join_path_nocase(out_dir, entry)

          FileUtils.mkdir_p(File.dirname("#{out_dir}/#{entry}")) unless Dir.exist?(File.dirname("#{out_dir}/#{entry}"))
          FileUtils.cp(path, "#{out_dir}/#{entry}")
        end
      end
    end
  end
end
