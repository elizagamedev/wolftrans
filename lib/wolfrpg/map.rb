module WolfRpg
  class Map
    attr_reader :tileset_id
    attr_reader :width
    attr_reader :height
    attr_reader :events

    #DEBUG
    attr_reader :filename

    def initialize(filename)
      @filename = File.basename(filename, '.*')
      FileCoder.open(filename, :read) do |coder|
        coder.verify(MAGIC_NUMBER)

        @tileset_id = coder.read_int

        # Read basic data
        @width = coder.read_int
        @height = coder.read_int
        @events = Array.new(coder.read_int)

        # Read tiles
        #TODO: interpret this data later
        @tiles = coder.read(@width * @height * 3 * 4)

        # Read events
        while (indicator = coder.read_byte) == 0x6F
          event = Event.new(coder)
          @events[event.id] = event
        end
        if indicator != 0x66
          raise "unexpected event indicator: #{indicator.to_s(16)}"
        end
        unless coder.eof?
          raise "file not fully parsed"
        end
      end
    end

    def dump(filename)
      FileCoder.open(filename, :write) do |coder|
        coder.write(MAGIC_NUMBER)
        coder.write_int(@tileset_id)
        coder.write_int(@width)
        coder.write_int(@height)
        coder.write_int(@events.size)
        coder.write(@tiles)
        @events.each do |event|
          next unless event
          coder.write_byte(0x6F)
          event.dump(coder)
        end
        coder.write_byte(0x66)
      end
    end

    #DEBUG method that searches for a string somewhere in the map
    def grep(needle)
      @events.each do |event|
        event.pages.each do |page|
          page.commands.each_with_index do |command, line|
            command.string_args.each do |arg|
              if m = arg.match(needle)
                print "#{@filename}/#{event.id}/#{page.id+1}/#{line+1}: #{command.cid}\n\t#{command.args}\n\t#{command.string_args}\n"
                break
              end
            end
          end
        end
      end
    end

    def grep_cid(cid)
      @events.each do |event|
        event.pages.each do |page|
          page.commands.each_with_index do |command, line|
            if command.cid == cid
              print "#{@filename}/#{event.id}/#{page.id+1}/#{line+1}: #{command.cid}\n\t#{command.args}\n\t#{command.string_args}\n"
            end
          end
        end
      end
    end

    class Event
      attr_accessor :id
      attr_accessor :name
      attr_accessor :x
      attr_accessor :y
      attr_accessor :pages

      def initialize(coder)
        coder.verify(MAGIC_NUMBER1)
        @id = coder.read_int
        @name = coder.read_string
        @x = coder.read_int
        @y = coder.read_int
        @pages = Array.new(coder.read_int)
        coder.verify(MAGIC_NUMBER2)

        # Read pages
        page_id = 0
        while (indicator = coder.read_byte) == 0x79
          page = Page.new(coder, page_id)
          @pages[page_id] = page
          page_id += 1
        end
        if indicator != 0x70
          raise "unexpected event page indicator: #{indicator.to_s(16)}"
        end
      end

      def dump(coder)
        coder.write(MAGIC_NUMBER1)
        coder.write_int(@id)
        coder.write_string(@name)
        coder.write_int(@x)
        coder.write_int(@y)
        coder.write_int(@pages.size)
        coder.write(MAGIC_NUMBER2)

        # Write pages
        @pages.each do |page|
          coder.write_byte(0x79)
          page.dump(coder)
        end
        coder.write_byte(0x70)
      end

      class Page
        attr_accessor :id
        attr_accessor :unknown1
        attr_accessor :graphic_name
        attr_accessor :graphic_direction
        attr_accessor :graphic_frame
        attr_accessor :graphic_opacity
        attr_accessor :graphic_render_mode
        attr_accessor :conditions
        attr_accessor :movement
        attr_accessor :flags
        attr_accessor :route_flags
        attr_accessor :route
        attr_accessor :commands
        attr_accessor :shadow_graphic_num
        attr_accessor :collision_width
        attr_accessor :collision_height

        def initialize(coder, id)
          @id = id

          #TODO ???
          @unknown1 = coder.read_int

          #TODO further abstract graphics options
          @graphic_name = coder.read_string
          @graphic_direction = coder.read_byte
          @graphic_frame = coder.read_byte
          @graphic_opacity = coder.read_byte
          @graphic_render_mode = coder.read_byte

          #TODO parse conditions later
          @conditions = coder.read(1 + 4 + 4*4 + 4*4)
          #TODO parse movement options later
          @movement = coder.read(4)

          #TODO further abstract flags
          @flags = coder.read_byte

          #TODO further abstract flags
          @route_flags = coder.read_byte

          # Parse move route
          @route = Array.new(coder.read_int)
          @route.each_index do |i|
            @route[i] = RouteCommand.create(coder)
          end

          # Parse commands
          @commands = Array.new(coder.read_int)
          @commands.each_index do |i|
            @commands[i] = Command.create(coder)
          end
          coder.verify(COMMANDS_TERMINATOR)

          #TODO abstract these options later
          @shadow_graphic_num = coder.read_byte
          @collision_width = coder.read_byte
          @collision_height = coder.read_byte

          if (terminator = coder.read_byte) != 0x7A
            raise "page terminator not 7A (found #{terminator.to_s(16)})"
          end
        end

        def dump(coder)
          coder.write_int(@unknown1)
          coder.write_string(@graphic_name)
          coder.write_byte(@graphic_direction)
          coder.write_byte(@graphic_frame)
          coder.write_byte(@graphic_opacity)
          coder.write_byte(@graphic_render_mode)
          coder.write(@conditions)
          coder.write(@movement)
          coder.write_byte(@flags)
          coder.write_byte(@route_flags)
          coder.write_int(@route.size)
          @route.each do |cmd|
            cmd.dump(coder)
          end
          coder.write_int(@commands.size)
          @commands.each do |cmd|
            cmd.dump(coder)
          end
          coder.write(COMMANDS_TERMINATOR)
          coder.write_byte(@shadow_graphic_num)
          coder.write_byte(@collision_width)
          coder.write_byte(@collision_height)
          coder.write_byte(0x7A)
        end

        COMMANDS_TERMINATOR = [
          0x03, 0x00, 0x00, 0x00,
        ].pack('C*')
      end

      private
      MAGIC_NUMBER1 = [
        0x39, 0x30, 0x00, 0x00
      ].pack('C*')
      MAGIC_NUMBER2 = [
        0x00, 0x00, 0x00, 0x00
      ].pack('C*')
    end

    private
    MAGIC_NUMBER = [
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x57, 0x4F, 0x4C, 0x46, 0x4D, 0x00,
      0x00, 0x00, 0x00, 0x00,
      0x64, 0x00, 0x00, 0x00,
      0x65,
      0x05, 0x00, 0x00, 0x00,
      0x82, 0xC8, 0x82, 0xB5, 0x00,
    ].pack('C*')
  end
end
