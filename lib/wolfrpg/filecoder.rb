module WolfRpg
  class FileCoder
    attr_reader :io

    def initialize(io)
      @io = io
    end

    def self.open(filename, mode)
      case mode
      when :read
        file = File.open(filename, 'rb')
      when :write
        file = File.open(filename, 'wb')
      end
      coder = FileCoder.new(file)
      if block_given?
        begin
          yield coder
        ensure
          coder.close
        end
      end
      return coder
    end

    ########
    # Read #
    def read(size = nil)
      if size
        @io.readpartial(size)
      else
        @io.read
      end
    end

    def read_byte
      @io.readpartial(1).ord
    end

    def read_int
      @io.readpartial(4).unpack('l<').first
    end

    def read_string
      size = read_int
      raise "got a string of size <= 0" unless size > 0
      str = read(size - 1).encode(Encoding::UTF_8, Encoding::WINDOWS_31J)
      raise "string not null-terminated" unless read_byte == 0
      return str
    end

    def verify(data)
      got = read(data.length)
      if got != data
        raise "could not verify magic data (expecting #{data.unpack('C*')}, got #{got.unpack('C*')})"
      end
    end

    def skip(size)
      @io.seek(size, IO::SEEK_CUR)
    end

    def dump(size)
      size.times do |i|
        print " %02x" % read_byte
      end
      print "\n"
    end

    def dump_until(pattern)
      str = ''.force_encoding('BINARY')
      until str.end_with? pattern
        str << @io.readpartial(1)
      end
      str[0...-pattern.bytesize].each_byte do |byte|
        print " %02x" % byte
      end
      print "\n"
    end

    #########
    # Write #
    def write(data)
      @io.write(data)
    end
    def write_byte(data)
      @io.write(data.chr)
    end
    def write_int(data)
      @io.write([data].pack('l<'))
    end
    def write_string(str)
      str = str.encode(Encoding::WINDOWS_31J, Encoding::UTF_8)
      write_int(str.bytesize + 1)
      write(str)
      write_byte(0)
    end

    #########
    # Other #
    def close
      @io.close
    end

    def eof?
      @io.eof?
    end

    def tell
      @io.tell
    end
  end
end
