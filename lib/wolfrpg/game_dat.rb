# encoding: utf-8

require 'stringio'

module WolfRpg
  class GameDat
    attr_accessor :unknown1
    attr_accessor :file_version # only a guess
    attr_accessor :title
    attr_accessor :unknown2
    attr_accessor :font
    attr_accessor :subfonts
    attr_accessor :default_pc_graphic
    attr_accessor :version
    attr_accessor :unknown3

    def encrypted?
      @crypt_header != nil
    end

    SEED_INDICES = [0, 8, 6]
    #XSEED_INDICES = [3, 4, 5]

    def initialize(filename)
      FileCoder.open(filename, :read, SEED_INDICES) do |coder|
        if coder.encrypted?
          @crypt_header = coder.crypt_header
        else
          coder.verify(MAGIC_NUMBER)
        end

        #TODO what is most of the junk in this file?
        @unknown1 = coder.read_byte_array
        @file_version = coder.read_int
        @title = coder.read_string
        if (magic_string = coder.read_string) != MAGIC_STRING
          raise "magic string invalid (got #{magic_string})"
        end
        @unknown2 = coder.read_byte_array

        @font = coder.read_string
        @subfonts = Array.new(3)
        @subfonts.each_index do |i|
          @subfonts[i] = coder.read_string
        end

        @default_pc_graphic = coder.read_string
        if @file_version >= 9
          @version = coder.read_string
        else
          @version = ''
        end

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
      FileCoder.open(filename, :write, SEED_INDICES, @crypt_header) do |coder|
        coder.write(MAGIC_NUMBER) unless encrypted?

        coder.write_byte_array(@unknown1)
        coder.write_int(@file_version)
        coder.write_string(@title)
        coder.write_string(MAGIC_STRING)
        coder.write_byte_array(@unknown2)
        coder.write_string(@font)
        @subfonts.each do |subfont|
          coder.write_string(subfont)
        end
        coder.write_string(@default_pc_graphic)
        coder.write_string(@version) if @file_version >= 9
        coder.write_int(coder.tell + 4 + @unknown3.bytesize - 1)
        coder.write(@unknown3)
      end
    end

    private
    MAGIC_NUMBER = [
      0x57, 0x00, 0x00, 0x4f, 0x4c, 0x00, 0x46, 0x4d, 0x00
    ].pack('C*')
    MAGIC_STRING = "0000-0000" # who knows what this is supposed to be
  end
end
