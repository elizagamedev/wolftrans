require 'wolfrpg/route'

module WolfRpg
  class Command
    attr_reader :cid
    attr_reader :args
    attr_reader :string_args
    attr_reader :indent

    #############################
    # Command class definitions #

    class Blank < Command
    end

    class Message < Command
      def text
        @string_args[0]
      end
      def text=(value)
        @string_args[0] = value
      end
    end

    class Choices < Command
      def text
        @string_args
      end
    end

    class Comment < Command
      def text
        @string_args[0]
      end
    end

    class DebugMessage < Command
      def text
        @string_args[0]
      end
    end

    class StringCondition < Command
    end

    class SetString < Command
      def text
        if @string_args.length > 0
          @string_args[0]
        else
          ''
        end
      end

      def text=(value)
        @string_args[0] = value
      end
    end

    class Picture < Command
      def type
        case (args[0] >> 4) & 0x07
        when 0
          :file
        when 1
          :file_string
        when 2
          :text
        when 3
          :window_file
        when 4
          :window_string
        else
          nil
        end
      end

      def num
        args[1]
      end

      def text
        if type != :text
          raise "picture type #{type} has no text"
        end
        return '' if string_args.empty?
        string_args[0]
      end
      def text=(value)
        if type != :text
          raise "picture type #{type} has no text"
        end
        if string_args.empty?
          string_args << value
        else
          string_args[0] = value
        end
      end

      def filename
        if type != :file && type != :window_file
          raise "picture type #{type} has no filename"
        end
        string_args[0]
      end
      def filename=(value)
        if type != :file && type != :window_file
          raise "picture type #{type} has no filename"
        end
        string_args[0] = value
      end
    end

    #class

    private
    ##########################
    # Map of CIDs to classes #

    CID_TO_CLASS = {
      0   => Command::Blank,
      101 => Command::Message,
      102 => Command::Choices,
      103 => Command::Comment,
      106 => Command::DebugMessage,
      112 => Command::StringCondition,
      122 => Command::SetString,
      150 => Command::Picture,
    }
    CID_TO_CLASS.default = Command

    public
    class Move < Command
      def initialize(cid, args, string_args, indent, file)
        super(cid, args, string_args, indent)
        # Read unknown data
        @unknown = Array.new(5)
        @unknown.each_index do |i|
          @unknown[i] = IO.read_byte(file)
        end
        # Read known data
        #TODO further abstract this
        @flags = IO.read_byte(file)

        # Read route
        @route = Array.new(IO.read_int(file))
        @route.each_index do |i|
          @route[i] = RouteCommand.create(file)
        end
      end

      def dump_terminator(file)
        IO.write_byte(file, 1)
        @unknown.each do |byte|
          IO.write_byte(file, byte)
        end
        IO.write_byte(file, @flags)
        IO.write_int(file, @route.size)
        @route.each do |cmd|
          cmd.dump(file)
        end
      end
    end

    # Load from the file and create the appropriate class object
    def self.create(file)
      # Read all data for this command from file
      args = Array.new(IO.read_byte(file) - 1)
      cid = IO.read_int(file)
      args.each_index do |i|
        args[i] = IO.read_int(file)
      end
      indent = IO.read_byte(file)
      string_args = Array.new(IO.read_byte(file))
      string_args.each_index do |i|
        string_args[i] = IO.read_string(file)
      end

      # Read the move list if necessary
      terminator = IO.read_byte(file)
      if terminator == 0x01
        return Command::Move.new(cid, args, string_args, indent, file)
      elsif terminator != 0x00
        raise "command terminator is an unexpected value (#{terminator})"
      end

      # Create command
      return CID_TO_CLASS[cid].new(cid, args, string_args, indent)
    end

    def dump(file)
      IO.write_byte(file, @args.size + 1)
      IO.write_int(file, @cid)
      @args.each do |arg|
        IO.write_int(file, arg)
      end
      IO.write_byte(file, indent)
      IO.write_byte(file, @string_args.size)
      @string_args.each do |arg|
        IO.write_string(file, arg)
      end

      dump_terminator(file)
    end

    private
    def initialize(cid, args, string_args, indent)
      @cid = cid
      @args = args
      @string_args = string_args
      @indent = indent
    end

    def dump_terminator(file)
      IO.write_byte(file, 0)
    end
  end
end
