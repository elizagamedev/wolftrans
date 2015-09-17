module WolfRpg
  class Database
    attr_accessor :types

    def encrypted?
      @crypt_header != nil
    end

    DAT_SEED_INDICES = [0, 3, 9]

    def initialize(project_filename, dat_filename)
      FileCoder.open(project_filename, :read) do |coder|
        @types = Array.new(coder.read_int)
        @types.each_index do |i|
          @types[i] = Type.new(coder)
        end
      end
      FileCoder.open(dat_filename, :read, DAT_SEED_INDICES) do |coder|
        if coder.encrypted?
          @crypt_header = coder.crypt_header
          @unknown_encrypted_1 = coder.read_byte
        else
          coder.verify(DAT_MAGIC_NUMBER)
        end
        num_types = coder.read_int
        unless num_types == @types.size
          raise "database project and dat Type count mismatch (#{@types.size} vs. #{num_types})"
        end
        @types.each do |type|
          type.read_dat(coder)
        end
        if coder.read_byte != 0xC1
          STDERR.puts "warning: no C1 terminator at the end of '#{dat_filename}'"
        end
      end

      def dump(project_filename, dat_filename)
        FileCoder.open(project_filename, :write) do |coder|
          coder.write_int(@types.size)
          @types.each do |type|
            type.dump_project(coder)
          end
        end
        FileCoder.open(dat_filename, :write, DAT_SEED_INDICES, @crypt_header) do |coder|
          if encrypted?
            coder.write_byte(@unknown_encrypted_1)
          else
            coder.write(DAT_MAGIC_NUMBER)
          end
          coder.write_int(@types.size)
          @types.each do |type|
            type.dump_dat(coder)
          end
          coder.write_byte(0xC1)
        end
      end

      def grep(needle)
        @types.each_with_index do |type, type_index|
          type.data.each_with_index do |datum, datum_index|
            datum.each_translatable do |value, field|
              next unless value =~ needle
              puts "DB:[#{type_index}]#{type.name}/[#{datum_index}]#{datum.name}/[#{field.index}]#{field.name}"
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
      def initialize(coder)
        @name = coder.read_string
        @fields = Array.new(coder.read_int)
        @fields.each_index do |i|
          @fields[i] = Field.new(coder)
        end
        @data = Array.new(coder.read_int)
        @data.each_index do |i|
          @data[i] = Data.new(coder)
        end
        @description = coder.read_string

        # Add misc data to fields. It's separated for some reason.

        # This appears to always be 0x64, but save it anyway
        @field_type_list_size = coder.read_int
        index = 0
        while index < @fields.size
          @fields[index].type = coder.read_byte
          index += 1
        end
        coder.skip(@field_type_list_size - index)

        coder.read_int.times do |i|
          @fields[i].unknown1 = coder.read_string
        end
        coder.read_int.times do |i|
          @fields[i].string_args = Array.new(coder.read_int)
          @fields[i].string_args.each_index do |j|
            @fields[i].string_args[j] = coder.read_string
          end
        end
        coder.read_int.times do |i|
          @fields[i].args = Array.new(coder.read_int)
          @fields[i].args.each_index do |j|
            @fields[i].args[j] = coder.read_int
          end
        end
        coder.read_int.times do |i|
          @fields[i].default_value = coder.read_int
        end
      end

      def dump_project(coder)
        coder.write_string(@name)
        coder.write_int(@fields.size)
        @fields.each do |field|
          field.dump_project(coder)
        end
        coder.write_int(@data.size)
        @data.each do |datum|
          datum.dump_project(coder)
        end
        coder.write_string(@description)

        # Dump misc field data
        coder.write_int(@field_type_list_size)
        index = 0
        while index < @fields.size
          coder.write_byte(@fields[index].type)
          index += 1
        end
        while index < @field_type_list_size
          coder.write_byte(0)
          index += 1
        end
        coder.write_int(@fields.size)
        @fields.each do |field|
          coder.write_string(field.unknown1)
        end
        coder.write_int(@fields.size)
        @fields.each do |field|
          coder.write_int(field.string_args.size)
          field.string_args.each do |arg|
            coder.write_string(arg)
          end
        end
        coder.write_int(@fields.size)
        @fields.each do |field|
          coder.write_int(field.args.size)
          field.args.each do |arg|
            coder.write_int(arg)
          end
        end
        coder.write_int(@fields.size)
        @fields.each do |field|
          coder.write_int(field.default_value)
        end
      end

      # Read the rest of the data from the dat file
      def read_dat(coder)
        coder.verify(DAT_TYPE_SEPARATOR)
        @unknown1 = coder.read_int
        fields_size = coder.read_int
        @fields = @fields[0, fields_size] if fields_size != @fields.size
        @fields.each do |field|
          field.read_dat(coder)
        end
        data_size = coder.read_int
        @data = @data[0, data_size] if data_size != @data.size
        @data.each do |datum|
          datum.read_dat(coder, @fields)
        end
      end

      def dump_dat(coder)
        coder.write(DAT_TYPE_SEPARATOR)
        coder.write_int(@unknown1)
        coder.write_int(@fields.size)
        @fields.each do |field|
          field.dump_dat(coder)
        end
        coder.write_int(@data.size)
        @data.each do |datum|
          datum.dump_dat(coder)
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

      def initialize(coder)
        @name = coder.read_string
      end

      def dump_project(coder)
        coder.write_string(@name)
      end

      def read_dat(coder)
        @indexinfo = coder.read_int
      end

      def dump_dat(coder)
        coder.write_int(@indexinfo)
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

      def initialize(coder)
        @name = coder.read_string
      end

      def dump_project(coder)
        coder.write_string(@name)
      end

      def read_dat(coder, fields)
        @fields = fields
        @int_values = Array.new(fields.select(&:int?).size)
        @string_values = Array.new(fields.select(&:string?).size)

        @int_values.each_index do |i|
          @int_values[i] = coder.read_int
        end
        @string_values.each_index do |i|
          @string_values[i] = coder.read_string
        end
      end

      def dump_dat(coder)
        @int_values.each do |i|
          coder.write_int(i)
        end
        @string_values.each do |i|
          coder.write_string(i)
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
      0x57, 0x00, 0x00, 0x4F, 0x4C, 0x00, 0x46, 0x4D, 0x00, 0xC1
    ].pack('C*')
    DAT_TYPE_SEPARATOR = [
      0xFE, 0xFF, 0xFF, 0xFF
    ].pack('C*')
  end
end
