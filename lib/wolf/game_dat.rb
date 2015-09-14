require 'wolf/io'

module Wolf
  class GameDat
    attr_accessor :unknown1
    attr_accessor :title
    attr_accessor :unknown2
    attr_accessor :font
    attr_accessor :subfonts
    attr_accessor :default_pc_graphic
    attr_accessor :version
    attr_accessor :unknown3

    def initialize(filename)
      File.open(filename, 'rb') do |file|
        IO.verify(file, MAGIC_NUMBER)
        #TODO what is most of the junk in this file?
        @unknown1 = IO.read(file, 25)

        @title = IO.read_string(file)
        if (magic_string = IO.read_string(file)) != MAGIC_STRING
          raise "magic string invalid (got #{magic_string})"
        end

        unknown2_size = IO.read_int(file)
        @unknown2 = IO.read(file, unknown2_size)

        #IO.dump(file, 64)
        #abort
        @font = IO.read_string(file)
        @subfonts = Array.new(3)
        @subfonts.each_index do |i|
          @subfonts[i] = IO.read_string(file)
        end

        @default_pc_graphic = IO.read_string(file)
        @version = IO.read_string(file)

        # This is the size of the file minus one.
        # We don't need it, so discard it.
        file.seek(4, :CUR)

        # We don't care about the rest of this file for translation
        # purposes.
        # Someday we will know what the hell is stored in here... But not today.
        @unknown3 = file.read
      end
    end

    def dump(filename)
      File.open(filename, 'wb') do |file|
        IO.write(file, MAGIC_NUMBER)
        IO.write(file, @unknown1)
        IO.write_string(file, @title)
        IO.write_string(file, MAGIC_STRING)
        IO.write_int(file, @unknown2.bytesize)
        IO.write(file, @unknown2)
        IO.write_string(file, @font)
        @subfonts.each do |subfont|
          IO.write_string(file, subfont)
        end
        IO.write_string(file, @default_pc_graphic)
        IO.write_string(file, @version)
        IO.write_int(file, file.tell + 4 + @unknown3.bytesize - 1)
        IO.write(file, @unknown3)
      end
    end

    private
    MAGIC_NUMBER = [
      0x00, 0x57, 0x00, 0x00, 0x4f, 0x4c, 0x00, 0x46, 0x4d, 0x00,
      0x15, 0x00, 0x00, 0x00, # likely an integer
    ].pack('C*')
    MAGIC_STRING = "0000-0000" # who knows what this is supposed to be
  end
end
