module Wolf
  class Database
    attr_accessor :name #DEBUG
    attr_accessor :types

    def initialize(project_filename, dat_filename)
      @name = File.basename(project_filename, '.*')
      File.open(project_filename, 'rb') do |file|
        @types = Array.new(IO.read_int(file))
        @types.each_index do |i|
          @types[i] = Type.new(file)
        end
      end
      File.open(dat_filename, 'rb') do |file|
        IO.verify(file, DAT_MAGIC_NUMBER)
        num_types = IO.read_int(file)
        unless num_types == @types.size
          raise "database project and dat Type count mismatch (#{@types.size} vs. #{num_types})"
        end
        @types.each do |type|
          type.read_dat(file)
        end
        if IO.read_byte(file) != 0xC1
          STDERR.puts "warning: no C1 terminator at the end of '#{dat_filename}'"
        end
      end

      def dump(project_filename, dat_filename)
        File.open(project_filename, 'wb') do |file|
          IO.write_int(file, @types.size)
          @types.each do |type|
            type.dump_project(file)
          end
        end
        File.open(dat_filename, 'wb') do |file|
          IO.write(file, DAT_MAGIC_NUMBER)
          IO.write_int(file, @types.size)
          @types.each do |type|
            type.dump_dat(file)
          end
          IO.write_byte(file, 0xC1)
        end
      end

      def grep(needle)
        @types.each_with_index do |type, type_index|
          type.data.each_with_index do |datum, datum_index|
            datum.each_translatable do |value, field|
              next unless value =~ needle
              puts "DB:#{@name}/[#{type_index}]#{type.name}/[#{datum_index}]#{datum.name}/[#{field.index}]#{field.name}"
              puts "\t" + value
            end
          end
        end
      end
    end

    class Type
      attr_accessor :name
      attr_accessor :fields
      attr_accessor :data
      attr_accessor :description
      attr_accessor :unknown1

      # Initialize from project file IO
      def initialize(file)
        @name = IO.read_string(file)
        @fields = Array.new(IO.read_int(file))
        @fields.each_index do |i|
          @fields[i] = Field.new(file)
        end
        @data = Array.new(IO.read_int(file))
        @data.each_index do |i|
          @data[i] = Data.new(file)
        end
        @description = IO.read_string(file)

        # Add misc data to fields. It's separated for some reason.

        # This appears to always be 0x64, but save it anyway
        @field_type_list_size = IO.read_int(file)
        index = 0
        while index < @fields.size
          @fields[index].type = IO.read_byte(file)
          index += 1
        end
        file.seek(@field_type_list_size - index, :CUR)

        IO.read_int(file).times do |i|
          @fields[i].unknown1 = IO.read_string(file)
        end
        IO.read_int(file).times do |i|
          @fields[i].string_args = Array.new(IO.read_int(file))
          @fields[i].string_args.each_index do |j|
            @fields[i].string_args[j] = IO.read_string(file)
          end
        end
        IO.read_int(file).times do |i|
          @fields[i].args = Array.new(IO.read_int(file))
          @fields[i].args.each_index do |j|
            @fields[i].args[j] = IO.read_int(file)
          end
        end
        IO.read_int(file).times do |i|
          @fields[i].default_value = IO.read_int(file)
        end
      end

      def dump_project(file)
        IO.write_string(file, @name)
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          field.dump_project(file)
        end
        IO.write_int(file, @data.size)
        @data.each do |datum|
          datum.dump_project(file)
        end
        IO.write_string(file, @description)

        # Dump misc field data
        IO.write_int(file, @field_type_list_size)
        index = 0
        while index < @fields.size
          IO.write_byte(file, @fields[index].type)
          index += 1
        end
        while index < @field_type_list_size
          IO.write_byte(file, 0)
          index += 1
        end
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          IO.write_string(file, field.unknown1)
        end
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          IO.write_int(file, field.string_args.size)
          field.string_args.each do |arg|
            IO.write_string(file, arg)
          end
        end
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          IO.write_int(file, field.args.size)
          field.args.each do |arg|
            IO.write_int(file, arg)
          end
        end
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          IO.write_int(file, field.default_value)
        end
      end

      # Read the rest of the data from the dat file
      def read_dat(file)
        IO.verify(file, DAT_TYPE_SEPARATOR)
        @unknown1 = IO.read_int(file)
        num_fields = IO.read_int(file)
        unless num_fields == @fields.size
          raise "database project and dat Field count mismatch (#{@fields.size} vs. #{num_fields})"
        end
        @fields.each do |field|
          field.read_dat(file)
        end
        num_data = IO.read_int(file)
        unless num_data == @data.size
          raise "database project and dat Field count mismatch (#{@data.size} vs. #{num_data})"
        end
        @data.each do |datum|
          datum.read_dat(file, @fields)
        end
      end

      def dump_dat(file)
        IO.write(file, DAT_TYPE_SEPARATOR)
        IO.write_int(file, @unknown1)
        IO.write_int(file, @fields.size)
        @fields.each do |field|
          field.dump_dat(file)
        end
        IO.write_int(file, @data.size)
        @data.each do |datum|
          datum.dump_dat(file)
        end
      end
    end


    class Field
      attr_accessor :name
      attr_accessor :type
      attr_accessor :unknown1
      attr_accessor :string_args
      attr_accessor :args
      attr_accessor :default_value
      attr_accessor :indexinfo

      def initialize(file)
        @name = IO.read_string(file)
      end

      def dump_project(file)
        IO.write_string(file, @name)
      end

      def read_dat(file)
        @indexinfo = IO.read_int(file)
      end

      def dump_dat(file)
        IO.write_int(file, @indexinfo)
      end

      def string?
        @indexinfo >= STRING_START
      end

      def int?
        !string?
      end

      def index
        if string?
          @indexinfo - STRING_START
        else
          @indexinfo - INT_START
        end
      end

      STRING_START = 0x07D0
      INT_START = 0x03E8
    end

    class Data
      attr_accessor :name
      attr_accessor :int_values
      attr_accessor :string_values

      def initialize(file)
        @name = IO.read_string(file)
      end

      def dump_project(file)
        IO.write_string(file, @name)
      end

      def read_dat(file, fields)
        @fields = fields
        @int_values = Array.new(fields.select(&:int?).size)
        @string_values = Array.new(fields.select(&:string?).size)

        @int_values.each_index do |i|
          @int_values[i] = IO.read_int(file)
        end
        @string_values.each_index do |i|
          @string_values[i] = IO.read_string(file)
        end
      end

      def dump_dat(file)
        @int_values.each do |i|
          IO.write_int(file, i)
        end
        @string_values.each do |i|
          IO.write_string(file, i)
        end
      end

      def [](key)
        if key.is_a? Field
          if key.string?
            @string_values[key.index]
          else
            @int_values[key.index]
          end
        elsif value.is_a? Integer
          self[@fields[key]]
        else
          raise "Data[] takes a Field, got a #{value.class}"
        end
      end

      def []=(key, value)
        if key.is_a? Field
          if key.string?
            @string_values[key.index] = value
          else
            @int_values[key.index] = value
          end
        elsif value.is_a? Integer
          self[@fields[key]] = value
        else
          raise "Data[] takes a Field, got a #{value.class}"
        end
      end

      def each_translatable
        @fields.each do |field|
          next unless field.string? && field.type == 0
          value = self[field]
          yield [value, field] unless value.empty? || value.include?("\n")
        end
      end
    end

    DAT_MAGIC_NUMBER = [
      0x00, 0x57, 0x00, 0x00, 0x4F, 0x4C, 0x00, 0x46, 0x4D, 0x00, 0xC1
    ].pack('C*')
    DAT_TYPE_SEPARATOR = [
      0xFE, 0xFF, 0xFF, 0xFF
    ].pack('C*')
  end
end
