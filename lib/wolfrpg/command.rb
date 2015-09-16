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
      def initialize(cid, args, string_args, indent, coder)
        super(cid, args, string_args, indent)
        # Read unknown data
        @unknown = Array.new(5)
        @unknown.each_index do |i|
          @unknown[i] = coder.read_byte
        end
        # Read known data
        #TODO further abstract this
        @flags = coder.read_byte

        # Read route
        @route = Array.new(coder.read_int)
        @route.each_index do |i|
          @route[i] = RouteCommand.create(coder)
        end
      end

      def dump_terminator(coder)
        coder.write_byte(1)
        @unknown.each do |byte|
          coder.write_byte(byte)
        end
        coder.write_byte(@flags)
        coder.write_int(@route.size)
        @route.each do |cmd|
          cmd.dump(coder)
        end
      end
    end

    # Load from the file and create the appropriate class object
    def self.create(coder)
      # Read all data for this command from file
      args = Array.new(coder.read_byte - 1)
      cid = coder.read_int
      args.each_index do |i|
        args[i] = coder.read_int
      end
      indent = coder.read_byte
      string_args = Array.new(coder.read_byte)
      string_args.each_index do |i|
        string_args[i] = coder.read_string
      end

      # Read the move list if necessary
      terminator = coder.read_byte
      if terminator == 0x01
        return Command::Move.new(cid, args, string_args, indent, coder)
      elsif terminator != 0x00
        raise "command terminator is an unexpected value (#{terminator})"
      end

      # Create command
      return CID_TO_CLASS[cid].new(cid, args, string_args, indent)
    end

    def dump(coder)
      coder.write_byte(@args.size + 1)
      coder.write_int(@cid)
      @args.each do |arg|
        coder.write_int(arg)
      end
      coder.write_byte(indent)
      coder.write_byte(@string_args.size)
      @string_args.each do |arg|
        coder.write_string(arg)
      end

      dump_terminator(coder)
    end

    private
    def initialize(cid, args, string_args, indent)
      @cid = cid
      @args = args
      @string_args = string_args
      @indent = indent
    end

    def dump_terminator(coder)
      coder.write_byte(0)
    end
  end
end
