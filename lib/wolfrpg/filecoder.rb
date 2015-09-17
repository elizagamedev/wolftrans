module WolfRpg
  class FileCoder
    ##############
    # Attributes #
    attr_reader :io
    attr_reader :crypt_header
    def encrypted?
      @crypt_header != nil
    end

    #############
    # Constants #
    CRYPT_HEADER_SIZE = 10
    DECRYPT_INTERVALS = [1, 2, 5]

    #################
    # Class methods #
    def self.open(filename, mode, seed_indices = nil, crypt_header = nil)
      case mode
      when :read
        coder = FileCoder.new(File.open(filename, 'rb'))

        # If encryptable,
        # we need to make an extra check to see if it needs decrypting
        if seed_indices
          unless (indicator = coder.read_byte) == 0
            header = [indicator]
            (CRYPT_HEADER_SIZE - 1).times { |i| header << coder.read_byte }
            seeds = seed_indices.map { |i| header[i] }
            data = crypt(coder.read, seeds)
            coder = FileCoder.new(StringIO.new(data, 'rb'), header)
          end
        end
      when :write
        # If encryptable, open a StringIO and pass the encryption options
        # to the FileCoder
        if seed_indices && crypt_header
          coder = FileCoder.new(StringIO.new(''.force_encoding('BINARY'), 'wb'),
                                crypt_header, filename, seed_indices)
          coder.write(crypt_header.pack('C*'))
        else
          coder = FileCoder.new(File.open(filename, 'wb'))
          coder.write_byte(0) if seed_indices
        end
      end

      if block_given?
        begin
          yield coder
        ensure
          coder.close
        end
      end
      return coder
    end

    ##############
    # Initialize #
    def initialize(io, crypt_header = nil, filename = nil, seed_indices = nil)
      @io = io
      @crypt_header = crypt_header
      @filename = filename
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

    def read_byte_array
      bytes = Array.new(read_int)
      bytes.each_index do |i|
        bytes[i] = read_byte
      end
      return bytes
    end

    def read_int_array
      ints = Array.new(read_int)
      ints.each_index do |i|
        ints[i] = read_int
      end
      return ints
    end

    def read_string_array
      strings = Array.new(read_int)
      strings.each_index do |i|
        strings[i] = read_string
      end
      return strings
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

    def write_byte_array(bytes)
      write_int(bytes.size)
      bytes.each do |b|
        write_byte(b)
      end
    end

    def write_int_array(ints)
      write_int(ints.size)
      ints.each do |i|
        write_int(i)
      end
    end

    def write_string_array(strings)
      write_int(strings.size)
      strings.each do |s|
        write_string(s)
      end
    end

    #########
    # Other #
    def close
      if @crypt_header && @filename && @seed_indices
        File.open(@filename, 'wb') do |file|
          file.write(@crypt_header.pack('C*'))
          seeds = @seed_indices.map { |i| crypt_header[i] }
          file.write(FileCoder.crypt(@io.string, seeds))
        end
      end
      @io.close
    end

    def eof?
      @io.eof?
    end

    def tell
      if encrypted?
        @io.tell + CRYPT_HEADER_SIZE
      else
        @io.tell
      end
    end

    #################
    # Private class #
    private
    def self.crypt(data_str, seeds)
      data = data_str.unpack('C*')
      seeds.each_with_index do |seed, s|
        (0...data.size).step(DECRYPT_INTERVALS[s]) do |i|
          seed = (seed * 0x343FD + 0x269EC3) & 0xFFFFFFFF
          data[i] ^= (seed >> 28) & 7
        end
      end
      return data.pack('C*')
    end
  end
end
