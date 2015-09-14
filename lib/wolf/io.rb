module Wolf
  module IO
    ########
    # Read #
    def self.read(io, size)
      io.readpartial(size)
    end
    def self.read_byte(io)
      io.readpartial(1).unpack('C').first
    end
    def self.read_int(io)
      io.readpartial(4).unpack('l<').first
    end
    def self.read_string(io)
      size = read_int(io)
      return '' if size == 0
      str = io.readpartial(size - 1).encode(Encoding::UTF_8, Encoding::WINDOWS_31J)
      raise "string not null-terminated" unless read_byte(io) == 0
      return str
    end
    def self.verify(io, data)
      got = io.readpartial(data.length)
      if got != data
        raise "could not verify magic data (expecting #{data.unpack('C*')}, got #{got.unpack('C*')})"
      end
    end
    def self.dump(io, length)
      length.times do |i|
        print " %02x" % read_byte(io)
      end
      print "\n"
    end
    def self.dump_until(pattern)
      escaped_pattern = Regexp.escape(pattern)
      str = ''.force_encoding('BINARY')
      until str =~ /#{escaped_pattern}\z/nm
        str << io.readpartial(1)
      end
      str.gsub(/#{escaped_pattern}\z/nm, '').each_byte do |byte|
        print " %02x" % byte
      end
      print "\n"
    end

    #########
    # Write #
    def self.write(io, data)
      io.write(data)
    end
    def self.write_byte(io, data)
      io.write(data.chr)
    end
    def self.write_int(io, data)
      io.write([data].pack('l<'))
    end
    def self.write_string(io, data)
      new_data = data.encode(Encoding::WINDOWS_31J, Encoding::UTF_8)
      write_int(io, new_data.bytesize + 1)
      io.write(new_data)
      write_byte(io, 0)
    end
  end
end
