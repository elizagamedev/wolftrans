require 'stringio'

module WolfRpg
  class GameDat
    attr_reader :legacy
    alias_method :legacy?, :legacy

    attr_accessor :unknown1
    attr_accessor :unknown4
    attr_accessor :title
    attr_accessor :unknown2
    attr_accessor :font
    attr_accessor :subfonts
    attr_accessor :default_pc_graphic
    attr_accessor :version
    attr_accessor :unknown3

    def initialize(filename)
      FileCoder.open(filename, :read) do |coder|
        if (first_byte = coder.read_byte) == 0
          @legacy = false
          coder.verify(MAGIC_NUMBER)
        else
          @legacy = true
          @seeds = Array.new(3)
          @xseeds = Array.new(3)
          @seeds[0] = first_byte
          coder.skip(1) # garbage
          @xseeds[0] = coder.read_byte
          @xseeds[1] = coder.read_byte
          @xseeds[2] = coder.read_byte
          coder.skip(1) # garbage
          @seeds[2] = coder.read_byte
          coder.skip(1) # garbage
          @seeds[1] = coder.read_byte
          coder.skip(1) # garbage
          coder = FileCoder.new(StringIO.new(crypt(coder.read)))
        end

        #TODO what is most of the junk in this file?
        unknown1_size = coder.read_int
        @unknown1 = coder.read(unknown1_size)
        @unknown4 = coder.read_int

        @title = coder.read_string
        if (magic_string = coder.read_string) != MAGIC_STRING
          raise "magic string invalid (got #{magic_string})"
        end

        unknown2_size = coder.read_int
        @unknown2 = coder.read(unknown2_size)

        @font = coder.read_string
        @subfonts = Array.new(3)
        @subfonts.each_index do |i|
          @subfonts[i] = coder.read_string
        end

        @default_pc_graphic = coder.read_string
        @version = coder.read_string

        # This is the size of the file minus one.
        # We don't need it, so discard it.
        coder.skip(4)

        # We don't care about the rest of this file for translation
        # purposes.
        # Someday we will know what the hell is stored in here... But not today.
        @unknown3 = coder.read
      end
    end

    def dump(filename)
      begin
        if @legacy
          coder = FileCoder.new(StringIO.new('', 'wb'))
        else
          coder = FileCoder.open(filename, :write)
          coder.write_byte(0)
          coder.write(MAGIC_NUMBER)
        end

        coder.write_int(@unknown1.size)
        coder.write(@unknown1)
        coder.write_int(@unknown4)
        coder.write_string(@title)
        coder.write_string(MAGIC_STRING)
        coder.write_int(@unknown2.bytesize)
        coder.write(@unknown2)
        coder.write_string(@font)
        @subfonts.each do |subfont|
          coder.write_string(subfont)
        end
        coder.write_string(@default_pc_graphic)
        coder.write_string(@version)
        coder.write_int(coder.tell + 4 + @unknown3.bytesize - 1 + (@legacy ? 10 : 0))
        coder.write(@unknown3)

        if @legacy
          data = crypt(coder.io.string)
          FileCoder.open(filename, :write) do |coder|
            coder.write_byte(@seeds[0])
            coder.write_byte(0) # garbage
            coder.write_byte(@xseeds[0])
            coder.write_byte(@xseeds[1])
            coder.write_byte(@xseeds[2])
            coder.write_byte(0) # garbage
            coder.write_byte(@seeds[2])
            coder.write_byte(0) # garbage
            coder.write_byte(@seeds[1])
            coder.write_byte(0) # garbage
            coder.write(data)
          end
        end
      ensure
        coder.close
      end
    end

    def crypt(data_str)
      data = data_str.unpack('C*')
      @seeds.each_with_index do |seed, s|
        (0...data.size).step(DECRYPT_INTERVALS[s]) do |i|
          seed = (seed * 0x343FD + 0x269EC3) & 0xFFFFFFFF
          data[i] ^= (seed >> 28) & 7
        end
      end
      return data.pack('C*')
    end

    private
    MAGIC_NUMBER = [
      0x57, 0x00, 0x00, 0x4f, 0x4c, 0x00, 0x46, 0x4d, 0x00
    ].pack('C*')
    MAGIC_STRING = "0000-0000" # who knows what this is supposed to be
    DECRYPT_INTERVALS = [1, 2, 5]
  end
end
