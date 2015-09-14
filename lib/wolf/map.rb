require 'wolf/io'
require 'wolf/route'
require 'wolf/command'

module Wolf
  class Map
    attr_reader :tileset_id
    attr_reader :width
    attr_reader :height
    attr_reader :events

    #DEBUG
    attr_reader :filename

    def initialize(filename)
      @filename = File.basename(filename, '.*')
      File.open(filename, 'rb') do |file|
        IO.verify(file, MAGIC_NUMBER)

        @tileset_id = IO.read_int(file)

        # Read basic data
        @width = IO.read_int(file)
        @height = IO.read_int(file)
        @events = Array.new(IO.read_int(file))

        # Read tiles
        #TODO: interpret this data later
        @tiles = IO.read(file, @width * @height * 3 * 4)

        # Read events
        while (indicator = IO.read_byte(file)) == 0x6F
          event = Event.new(file)
          @events[event.id] = event
        end
        if indicator != 0x66
          raise "unexpected event indicator: #{indicator.to_s(16)}"
        end
        unless file.eof?
          raise "file not fully parsed"
        end
      end
    end

    def dump(filename)
      File.open(filename, 'wb') do |file|
        IO.write(file, MAGIC_NUMBER)
        IO.write_int(file, @tileset_id)
        IO.write_int(file, @width)
        IO.write_int(file, @height)
        IO.write_int(file, @events.size)
        IO.write(file, @tiles)
        @events.each do |event|
          IO.write_byte(file, 0x6F)
          event.dump(file)
        end
        IO.write_byte(file, 0x66)
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

      def initialize(file)
        IO.verify(file, MAGIC_NUMBER1)
        @id = IO.read_int(file)
        @name = IO.read_string(file)
        @x = IO.read_int(file)
        @y = IO.read_int(file)
        @pages = Array.new(IO.read_int(file))
        IO.verify(file, MAGIC_NUMBER2)

        # Read pages
        page_id = 0
        while (indicator = IO.read_byte(file)) == 0x79
          page = Page.new(file, page_id)
          @pages[page_id] = page
          page_id += 1
        end
        if indicator != 0x70
          raise "unexpected event page indicator: #{indicator.to_s(16)}"
        end
      end

      def dump(file)
        IO.write(file, MAGIC_NUMBER1)
        IO.write_int(file, @id)
        IO.write_string(file, @name)
        IO.write_int(file, @x)
        IO.write_int(file, @y)
        IO.write_int(file, @pages.size)
        IO.write(file, MAGIC_NUMBER2)

        # Write pages
        @pages.each do |page|
          IO.write_byte(file, 0x79)
          page.dump(file)
        end
        IO.write_byte(file, 0x70)
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

        def initialize(file, id)
          @id = id

          #TODO ???
          @unknown1 = IO.read_int(file)

          #TODO further abstract graphics options
          @graphic_name = IO.read_string(file)
          @graphic_direction = IO.read_byte(file)
          @graphic_frame = IO.read_byte(file)
          @graphic_opacity = IO.read_byte(file)
          @graphic_render_mode = IO.read_byte(file)

          #TODO parse conditions later
          @conditions = IO.read(file, 1 + 4 + 4*4 + 4*4)
          #TODO parse movement options later
          @movement = IO.read(file, 4)

          #TODO further abstract flags
          @flags = IO.read_byte(file)

          #TODO further abstract flags
          @route_flags = IO.read_byte(file)

          # Parse move route
          @route = Array.new(IO.read_int(file))
          @route.each_index do |i|
            @route[i] = RouteCommand.create(file)
          end

          # Parse commands
          @commands = Array.new(IO.read_int(file))
          @commands.each_index do |i|
            @commands[i] = Command.create(file)
          end
          IO.verify(file, COMMANDS_TERMINATOR)

          #TODO abstract these options later
          @shadow_graphic_num = IO.read_byte(file)
          @collision_width = IO.read_byte(file)
          @collision_height = IO.read_byte(file)

          if (terminator = IO.read_byte(file)) != 0x7A
            raise "page terminator not 7A (found #{terminator.to_s(16)})"
          end
        end

        def dump(file)
          IO.write_int(file, @unknown1)
          IO.write_string(file, @graphic_name)
          IO.write_byte(file, @graphic_direction)
          IO.write_byte(file, @graphic_frame)
          IO.write_byte(file, @graphic_opacity)
          IO.write_byte(file, @graphic_render_mode)
          IO.write(file, @conditions)
          IO.write(file, @movement)
          IO.write_byte(file, @flags)
          IO.write_byte(file, @route_flags)
          IO.write_int(file, @route.size)
          @route.each do |cmd|
            cmd.dump(file)
          end
          IO.write_int(file, @commands.size)
          @commands.each do |cmd|
            cmd.dump(file)
          end
          IO.write(file, COMMANDS_TERMINATOR)
          IO.write_byte(file, @shadow_graphic_num)
          IO.write_byte(file, @collision_width)
          IO.write_byte(file, @collision_height)
          IO.write_byte(file, 0x7A)
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
