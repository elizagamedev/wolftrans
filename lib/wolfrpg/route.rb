module WolfRpg
  class RouteCommand
    def self.create(file)
      # Read all data for this movement command from file
      id = IO.read_byte(file)
      args = Array.new(IO.read_byte(file))
      args.each_index do |i|
        args[i] = IO.read_int(file)
      end
      IO.verify(file, TERMINATOR)

      #TODO Create proper route command
      return RouteCommand.new(id, args)
    end

    def dump(file)
      IO.write_byte(file, @id)
      IO.write_byte(file, @args.size)
      @args.each do |arg|
        IO.write_int(file, arg)
      end
      IO.write(file, TERMINATOR)
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
