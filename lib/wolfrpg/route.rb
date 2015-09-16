module WolfRpg
  class RouteCommand
    def self.create(coder)
      # Read all data for this movement command from file
      id = coder.read_byte
      args = Array.new(coder.read_byte)
      args.each_index do |i|
        args[i] = coder.read_int
      end
      coder.verify(TERMINATOR)

      #TODO Create proper route command
      return RouteCommand.new(id, args)
    end

    def dump(coder)
      coder.write_byte(@id)
      coder.write_byte(@args.size)
      @args.each do |arg|
        coder.write_int(arg)
      end
      coder.write(TERMINATOR)
    end

    attr_accessor :id
    attr_accessor :args

    def initialize(id, args)
      @id = id
      @args = args
    end

    private
    TERMINATOR = [0x01, 0x00].pack('C*')
  end
end
