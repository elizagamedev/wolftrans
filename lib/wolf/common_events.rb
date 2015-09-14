require 'wolf/command'

module Wolf
  class CommonEvents
    attr_accessor :events

    def initialize(filename)
      File.open(filename, 'rb') do |file|
        IO.verify(file, MAGIC_NUMBER)
        @events = Array.new(IO.read_int(file))
        @events.each_index do |i|
          event = Event.new(file)
          events[event.id] = event
        end
        if (terminator = IO.read_byte(file)) != 0x8F
          raise "CommonEvents terminator not 0x8F (got 0x#{terminator.to_s(16)})"
        end
      end
    end

    def dump(filename)
      File.open(filename, 'wb') do |file|
        IO.write(file, MAGIC_NUMBER)
        IO.write_int(file, @events.size)
        @events.each do |event|
          event.dump(file)
        end
        IO.write_byte(file, 0x8F)
      end
    end

    def grep(needle)
    end

    class Event
      attr_accessor :id
      attr_accessor :name
      attr_accessor :commands

      def initialize(file)
        if (indicator = IO.read_byte(file)) != 0x8E
          raise "CommonEvent header indicator not 0x8E (got 0x#{indicator.to_s(16)})"
        end
        @id = IO.read_int(file)
        @unknown1 = IO.read_int(file)
        @unknown2 = IO.read(file, 7)
        @name = IO.read_string(file)
        @commands = Array.new(IO.read_int(file))
        @commands.each_index do |i|
          @commands[i] = Command.create(file)
        end
        @unknown11 = IO.read_string(file)
        @description = IO.read_string(file)
        if (indicator = IO.read_byte(file)) != 0x8F
          raise "CommonEvent data indicator not 0x8F (got 0x#{indicator.to_s(16)})"
        end
        IO.verify(file, MAGIC_NUMBER)
        @unknown3 = Array.new(10)
        @unknown3.each_index do |i|
          @unknown3[i] = IO.read_string(file)
        end
        IO.verify(file, MAGIC_NUMBER)
        @unknown4 = Array.new(10)
        @unknown4.each_index do |i|
          @unknown4[i] = IO.read_byte(file)
        end
        IO.verify(file, MAGIC_NUMBER)
        @unknown5 = Array.new(10)
        @unknown5.each_index do |i|
          @unknown5[i] = Array.new(IO.read_int(file))
          @unknown5[i].each_index do |j|
            @unknown5[i][j] = IO.read_string(file)
          end
        end
        IO.verify(file, MAGIC_NUMBER)
        @unknown6 = Array.new(10)
        @unknown6.each_index do |i|
          @unknown6[i] = Array.new(IO.read_int(file))
          @unknown6[i].each_index do |j|
            @unknown6[i][j] = IO.read_int(file)
          end
        end
        @unknown7 = IO.read(file, 0x1D)
        @unknown8 = Array.new(100)
        @unknown8.each_index do |i|
          @unknown8[i] = IO.read_string(file)
        end
        if (indicator = IO.read_byte(file)) != 0x91
          raise "expected 0x91, got 0x#{indicator.to_s(16)}"
        end
        @unknown9 = IO.read_string(file)
        if (indicator = IO.read_byte(file)) != 0x92
          raise "expected 0x92, got 0x#{indicator.to_s(16)}"
        end
        @unknown10 = IO.read_string(file)
        @unknown12 = IO.read_int(file)
        if (indicator = IO.read_byte(file)) != 0x92
          raise "expected 0x92, got 0x#{indicator.to_s(16)}"
        end
      end

      def dump(file)
        IO.write_byte(file, 0x8E)
        IO.write_int(file, @id)
        IO.write_int(file, @unknown1)
        IO.write(file, @unknown2)
        IO.write_string(file, @name)
        IO.write_int(file, @commands.size)
        @commands.each do |cmd|
          cmd.dump(file)
        end
        IO.write_string(file, @unknown11)
        IO.write_string(file, @description)
        IO.write_byte(file, 0x8F)
        IO.write(file, MAGIC_NUMBER)
        @unknown3.each do |i|
          IO.write_string(file, i)
        end
        IO.write(file, MAGIC_NUMBER)
        @unknown4.each do |i|
          IO.write_byte(file, i)
        end
        IO.write(file, MAGIC_NUMBER)
        @unknown5.each do |i|
          IO.write_int(file, i.size)
          i.each do |j|
            IO.write_string(file, j)
          end
        end
        IO.write(file, MAGIC_NUMBER)
        @unknown6.each do |i|
          IO.write_int(file, i.size)
          i.each do |j|
            IO.write_int(file, j)
          end
        end
        IO.write(file, @unknown7)
        @unknown8.each do |i|
          IO.write_string(file, i)
        end
        IO.write_byte(file, 0x91)
        IO.write_string(file, @unknown9)
        IO.write_byte(file, 0x92)
        IO.write_string(file, @unknown10)
        IO.write_int(file, @unknown12)
        IO.write_byte(file, 0x92)
      end

      private
      MAGIC_NUMBER = [
        0x0A, 0x00, 0x00, 0x00
      ].pack('C*')
    end

    private
    MAGIC_NUMBER = [
      0x00, 0x57, 0x00, 0x00, 0x4F, 0x4C, 0x00, 0x46, 0x43, 0x00, 0x8F
    ].pack('C*')
  end
end
