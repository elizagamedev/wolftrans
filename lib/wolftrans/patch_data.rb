require 'wolftrans/context'
require 'wolf'

require 'fileutils'
require 'find'

#####################
# Loading Game data #
module WolfTrans
  class Patch
    def load_data(game_dir)
      @game_dir = WolfTrans.sanitize_path(game_dir)
      unless Dir.exist? @game_dir
        raise "could not find game folder '#{@game_dir}'"
      end
      @game_data_dir = WolfTrans.join_path_nocase(@game_dir, 'data')
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
              load_game_dat(filename)
            elsif extension == '.project'
              next if basename_downcase == 'sysdatabasebasic.project'
              dat_filename = WolfTrans.join_path_nocase(parent_path, "#{basename_noext}.dat")
              next if dat_filename == nil
              load_game_database(filename, dat_filename)
            elsif basename_downcase == 'commonevent.dat'
              load_common_events(filename)
            end
          end
        end
      end
    end

    # Apply the patch to the files in the game path and write them to the
    # output directory
    def apply(out_dir)
      out_dir = WolfTrans.sanitize_path(out_dir)
      out_data_dir = "#{out_dir}/Data"

      # Clear out directory
      FileUtils.rm_rf(out_dir)

      # Patch all the maps and dump them
      FileUtils.mkdir_p("#{out_data_dir}/MapData")
      @maps.each do |map_name, map|
        map.events.each do |event|
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
      FileUtils.mkdir_p("#{out_data_dir}/BasicData")
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
      FileUtils.mkdir_p("#{out_data_dir}/BasicData")
      patch_game_dat
      @game_dat.dump("#{out_data_dir}/BasicData/Game.dat")

      # Copy image files
      [
        'BattleEffect',
        'CharaChip',
        'EnemyGraphic',
        'Fog_BackGround',
        'MapChip',
        'Picture',
        'SystemFile',
      ].each do |dirname|
        copy_data_files(out_data_dir, dirname, ['png','jpg','jpeg','bmp'])
      end

      # Copy sound/music files
      [
        'BGM',
        'SE',
        'SystemFile',
      ].each do |dirname|
        copy_data_files(out_data_dir, dirname, ['ogg','mp3','wav','mid','midi'])
      end

      # Copy BasicData
      copy_data_files(out_data_dir, 'BasicData', ['dat','project','xxxxx','png'])

      # Copy fonts
      copy_data_files(out_data_dir, '', ['ttf','ttc'])

      # Copy remainder of files in the base patch/game dirs
      copy_files(@patch_assets_dir, @patch_data_dir, out_dir)
      copy_files(@game_dir, @game_data_dir, out_dir)
    end

    private
    def load_map(filename)
      map_name = File.basename(filename, '.*')
      patch_filename = "dump/mps/#{map_name}.txt"

      map = Wolf::Map.new(filename)
      map.events.each do |event|
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
      @game_dat = Wolf::GameDat.new(filename)
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
      db = Wolf::Database.new(project_filename, dat_filename)
      db.types.each_with_index do |type, type_index|
        next if type.name.empty?
        patch_filename = "dump/db/#{db.name}/#{WolfTrans.escape_path(type.name)}.txt"
        type.data.each_with_index do |datum, datum_index|
          datum.each_translatable do |str, field|
            context = Context::Database.from_data(db.name, type_index, type, datum_index, datum, field)
            @strings[str][context] ||= Translation.new(patch_filename)
          end
        end
      end
      @databases[db.name] = db
    end

    def load_common_events(filename)
      @common_events = Wolf::CommonEvents.new(filename)
      @common_events.events.each do |event|
        patch_filename = "dump/common/#{'%03d' % event.id}_#{WolfTrans.escape_path(event.name)}.txt"
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
      when Wolf::Command::Message
        yield command.text unless command.text.empty?
      when Wolf::Command::Choices
        command.text.each do |s|
          yield s
        end
      when Wolf::Command::StringCondition
        command.string_args.each do |s|
          yield s unless s.empty?
        end
      when Wolf::Command::SetString
        yield command.text unless command.text.empty?
      when Wolf::Command::Picture
        if command.type == :text
          yield command.text unless command.text.empty?
        end
      end
    end

    def patch_command(command, context)
      case command
      when Wolf::Command::Message
        yield_translation(command.text, context) do |str|
          command.text = str
        end
      when Wolf::Command::Choices
        command.text.each_with_index do |text, i|
          yield_translation(text, context) do |str|
            command.text[i] = str
          end
        end
      when Wolf::Command::StringCondition
        command.string_args.each_with_index do |arg, i|
          next if arg.empty?
          yield_translation(arg, context) do |str|
            command.string_args[i] = str
          end
        end
      when Wolf::Command::SetString
        yield_translation(command.text, context) do |str|
          command.text = str
        end
      when Wolf::Command::Picture
        if command.type == :text
          yield_translation(command.text, context) do |str|
            command.text = str
          end
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
      return if string.empty?
      if @strings.include? string
        unless @strings[string][context].string.empty?
          yield @strings[string][context].string
        end
      end
    end

    # Copy normal, non-data files
    def copy_files(src_dir, src_data_dir, out_dir)
      Find.find(src_dir) do |path|
        next if path == src_dir
        Find.prune if path == src_data_dir
        short_path = path[src_dir.length+1..-1]
        Find.prune if @file_blacklist.include? short_path.downcase
        out_path = "#{out_dir}/#{short_path}"
        if FileTest.directory? path
          FileUtils.mkdir_p(out_path)
        else
          next if ['thumbs.db', 'desktop.ini', '.ds_store'].include? File.basename(path).downcase
          FileUtils.cp(path, out_path) unless File.exist? out_path
        end
      end
    end

    # Copy data files
    def copy_data_files(out_data_dir, dirname, extensions)
      copy_data_files_from(@game_data_dir, out_data_dir, dirname, extensions)
      if @patch_data_dir
        copy_data_files_from(@patch_data_dir, out_data_dir, dirname, extensions)
      end
    end

    def copy_data_files_from(src_data_dir, out_data_dir, dirname, extensions)
      out_dir = File.join(out_data_dir, dirname)
      FileUtils.mkdir_p(out_dir)

      Find.find(src_data_dir) do |path|
        if dirname.empty?
          if FileTest.directory? path
            Find.prune if path != src_data_dir
            next
          end
        else
          next if path == src_data_dir
          if FileTest.directory?(path)
            Find.prune unless File.basename(path).casecmp(dirname) == 0
            next
          end
          next if File.dirname(path) == src_data_dir
        end
        basename = File.basename(path)
        next unless extensions.include? File.extname(basename)[1..-1]
        next if @file_blacklist.include? "data/#{dirname.downcase}/#{basename.downcase}"
        out_name = "#{out_dir}/#{basename}"
        FileUtils.cp(path, out_name) unless File.exist? out_name
      end
    end
  end
end
