module WolfTrans
  # Represents the context of a translatable string
  class Context
    def eql?(other)
      self.class == other.class
    end

    # Parse a string to determine context
    def self.from_string(string)
      pair = string.split(':', 2)
      if pair.size != 2
        raise "malformed context line"
      end
      type, path = pair
      path = path.split('/')

	  case type
      when 'MPS'
        return MapEvent.from_string(path)
      when 'GAMEDAT'
        return GameDat.from_string(path)
      when 'DB'
        return Database.from_string(path)
      when 'COMMONEVENT'
        return CommonEvent.from_string(path)
      end
      raise "unrecognized context type '#{type}'"
    end

    class MapEvent < Context
      attr_reader :map_name
      attr_reader :event_num
      attr_reader :page_num
      attr_reader :line_num
      attr_reader :command_name

      def initialize(map_name, event_num, page_num, line_num, command_name)
        @map_name = map_name
        @event_num = event_num
        @page_num = page_num
        @line_num = line_num
        @command_name = command_name
      end

      def eql?(other)
        super &&
          @map_name == other.map_name &&
          @event_num == other.event_num &&
          @page_num == other.page_num
      end

      def hash
        [@map_name, @event_num, @page_num].hash
      end

      def to_s
        "MPS:#{@map_name}/events/#{@event_num}/pages/#{@page_num}/#{@line_num}/#{@command_name}"
      end

      def self.from_data(map_name, event, page, cmd_index, command)
        MapEvent.new(map_name, event.id, page.id + 1, cmd_index + 1, command.class.name.split('::').last)
      end

      def self.from_string(path)
        map_name, events_str, event_num, pages_str, page_num, line_num, command_name = path
        if events_str != 'events' || pages_str != 'pages'
          raise "unexpected path element in MPS context line"
        end
        MapEvent.new(map_name, event_num.to_i, page_num.to_i, line_num.to_i, command_name)
      end
    end

    class CommonEvent < Context
      attr_reader :event_num
      attr_reader :line_num
      attr_reader :command_name

      def initialize(event_num, line_num, command_name)
        @event_num = event_num
        @line_num = line_num
        @command_name = command_name
      end

      def eql?(other)
        super && @event_num == other.event_num
      end

      def hash
        @event_num.hash
      end

      def to_s
        "COMMONEVENT:#{@event_num}/#{@line_num}/#{@command_name}"
      end

      def self.from_data(event, cmd_index, command)
        CommonEvent.new(event.id, cmd_index + 1, command.class.name.split('::').last)
      end

      def self.from_string(path)
        event_num, line_num, command_name = path
        CommonEvent.new(event_num.to_i, line_num.to_i, command_name)
      end
    end

    class GameDat < Context
      attr_reader :name

      def initialize(name)
        @name = name
      end

      def eql?(other)
        super && @name == other.name
      end

      def hash
        @name.hash
      end

      def to_s
        "GAMEDAT:#{@name}"
      end

      def self.from_data(name)
        GameDat.new(name)
      end

      def self.from_string(path)
        if path.size != 1
          raise "invalid path specified for GAMEDAT context line"
        end
        GameDat.new(path.first)
      end
    end

    class Database < Context
      attr_reader :db_name
      attr_reader :type_index
      attr_reader :type_name
      attr_reader :datum_index
      attr_reader :datum_name
      attr_reader :field_index
      attr_reader :field_name

      def initialize(db_name, type_index, type_name, datum_index, datum_name, field_index, field_name)
        @db_name = db_name
        @type_index = type_index
        @type_name = Util.full_strip(type_name)
        @datum_index = datum_index
        @datum_name = Util.full_strip(datum_name)
        @field_index = field_index
        @field_name = Util.full_strip(field_name)
      end

      def eql?(other)
        super &&
          @db_name == db_name &&
          @type_index == other.type_index &&
          @datum_index == other.datum_index &&
          @field_index == other.field_index
      end

      def hash
        [@db_name, @type_index, @datum_index, @field_index].hash
      end

      def to_s
        "DB:#{@db_name}/[#{@type_index}]#{@type_name}/[#{@datum_index}]#{@datum_name}/[#{@field_index}]#{@field_name}"
      end

      def self.from_data(db_name, type_index, type, datum_index, datum, field)
        Database.new(db_name, type_index, type.name, datum_index, datum.name, field.index, field.name)
      end

      def self.from_string(path)
        if path.size != 4
          path = path.join("/")
          path = path.split(/\/(?=\[\d+\])/)
          if path.size != 4
            raise "invalid path specified for DB context line"
          end
        end
        indices = Array.new(3)
        path.each_with_index do |str, i|
          next if i == 0
          str.match(/^\[\d+\]/) do |m|
            indices[i-1] = m.to_s[1..-2].to_i
          end
          str.sub!(/^\[\d+\]/, '')
        end

        Database.new(path[0], indices[0], path[1], indices[1], path[2], indices[2], path[3])
      end
    end
  end
end
