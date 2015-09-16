module WolfRpg
  class CommonEvents
    attr_accessor :events

    def initialize(filename)
      FileCoder.open(filename, :read) do |coder|
        coder.verify(MAGIC_NUMBER)
        @events = Array.new(coder.read_int)
        @events.each_index do |i|
          event = Event.new(coder)
          events[event.id] = event
        end
        if (terminator = coder.read_byte) != 0x8F
          raise "CommonEvents terminator not 0x8F (got 0x#{terminator.to_s(16)})"
        end
      end
    end

    def dump(filename)
      FileCoder.open(filename, :write) do |coder|
        coder.write(MAGIC_NUMBER)
        coder.write_int(@events.size)
        @events.each do |event|
          event.dump(coder)
        end
        coder.write_byte(0x8F)
      end
    end

    def grep(needle)
    end

    class Event
      attr_accessor :id
      attr_accessor :name
      attr_accessor :commands

      def initialize(coder)
        if (indicator = coder.read_byte) != 0x8E
          raise "CommonEvent header indicator not 0x8E (got 0x#{indicator.to_s(16)})"
        end
        @id = coder.read_int
        @unknown1 = coder.read_int
        @unknown2 = coder.read(7)
        @name = coder.read_string
        @commands = Array.new(coder.read_int)
        @commands.each_index do |i|
          @commands[i] = Command.create(coder)
        end
        @unknown11 = coder.read_string
        @description = coder.read_string
        if (indicator = coder.read_byte) != 0x8F
          raise "CommonEvent data indicator not 0x8F (got 0x#{indicator.to_s(16)})"
        end
        coder.verify(MAGIC_NUMBER)
        @unknown3 = Array.new(10)
        @unknown3.each_index do |i|
          @unknown3[i] = coder.read_string
        end
        coder.verify(MAGIC_NUMBER)
        @unknown4 = Array.new(10)
        @unknown4.each_index do |i|
          @unknown4[i] = coder.read_byte
        end
        coder.verify(MAGIC_NUMBER)
        @unknown5 = Array.new(10)
        @unknown5.each_index do |i|
          @unknown5[i] = Array.new(coder.read_int)
          @unknown5[i].each_index do |j|
            @unknown5[i][j] = coder.read_string
          end
        end
        coder.verify(MAGIC_NUMBER)
        @unknown6 = Array.new(10)
        @unknown6.each_index do |i|
          @unknown6[i] = Array.new(coder.read_int)
          @unknown6[i].each_index do |j|
            @unknown6[i][j] = coder.read_int
          end
        end
        @unknown7 = coder.read(0x1D)
        @unknown8 = Array.new(100)
        @unknown8.each_index do |i|
          @unknown8[i] = coder.read_string
        end
        if (indicator = coder.read_byte) != 0x91
          raise "expected 0x91, got 0x#{indicator.to_s(16)}"
        end
        @unknown9 = coder.read_string
        if (indicator = coder.read_byte) != 0x92
          raise "expected 0x92, got 0x#{indicator.to_s(16)}"
        end
        @unknown10 = coder.read_string
        @unknown12 = coder.read_int
        if (indicator = coder.read_byte) != 0x92
          raise "expected 0x92, got 0x#{indicator.to_s(16)}"
        end
      end

      def dump(coder)
        coder.write_byte(0x8E)
        coder.write_int(@id)
        coder.write_int(@unknown1)
        coder.write(@unknown2)
        coder.write_string(@name)
        coder.write_int(@commands.size)
        @commands.each do |cmd|
          cmd.dump(coder)
        end
        coder.write_string(@unknown11)
        coder.write_string(@description)
        coder.write_byte(0x8F)
        coder.write(MAGIC_NUMBER)
        @unknown3.each do |i|
          coder.write_string(i)
        end
        coder.write(MAGIC_NUMBER)
        @unknown4.each do |i|
          coder.write_byte(i)
        end
        coder.write(MAGIC_NUMBER)
        @unknown5.each do |i|
          coder.write_int(i.size)
          i.each do |j|
            coder.write_string(j)
          end
        end
        coder.write(MAGIC_NUMBER)
        @unknown6.each do |i|
          coder.write_int(i.size)
          i.each do |j|
            coder.write_int(j)
          end
        end
        coder.write(@unknown7)
        @unknown8.each do |i|
          coder.write_string(i)
        end
        coder.write_byte(0x91)
        coder.write_string(@unknown9)
        coder.write_byte(0x92)
        coder.write_string(@unknown10)
        coder.write_int(@unknown12)
        coder.write_byte(0x92)
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
