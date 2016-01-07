# encoding: utf-8

require 'wolfrpg/route'

# Special thanks to vgperson for mapping most of these command IDs out.

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

    class Checkpoint < Command
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

    class ForceStopMessage < Command
    end

    class DebugMessage < Command
      def text
        @string_args[0]
      end
    end

    class ClearDebugText < Command
    end

    class VariableCondition < Command
    end

    class StringCondition < Command
    end

    class SetVariable < Command
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

    class InputKey < Command
    end

    class SetVariableEx < Command
    end

    class AutoInput < Command
    end

    class BanInput < Command
    end

    class Teleport < Command
    end

    class Sound < Command
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

    class ChangeColor < Command
    end

    class SetTransition < Command
    end

    class PrepareTransition < Command
    end

    class ExecuteTransition < Command
    end

    class StartLoop < Command
    end

    class BreakLoop < Command
    end

    class BreakEvent < Command
    end

    class EraseEvent < Command
    end

    class ReturnToTitle < Command
    end

    class EndGame < Command
    end

    class LoopToStart < Command
    end

    class StopNonPic < Command
    end

    class ResumeNonPic < Command
    end

    class LoopTimes < Command
    end

    class Wait < Command
    end

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

    class WaitForMove < Command
    end

    class CommonEvent < Command
    end

    class CommonEventReserve < Command
    end

    class SetLabel < Command
    end

    class JumpLabel < Command
    end

    class SaveLoad < Command
    end

    class LoadGame < Command
    end

    class SaveGame < Command
    end

    class MoveDuringEventOn < Command
    end

    class MoveDuringEventOff < Command
    end

    class Chip < Command
    end

    class ChipSet < Command
    end

    class ChipOverwrite < Command
    end

    class Database < Command
      def text
        @string_args[2]
      end
      def text=(value)
        @string_args[2] = value
      end
    end

    class ImportDatabase < Command
    end

    class Party < Command
    end

    class MapEffect < Command
    end

    class ScrollScreen < Command
    end

    class Effect < Command
    end

    class CommonEventByName < Command
    end

    class ChoiceCase < Command
    end

    class SpecialChoiceCase < Command
    end

    class ElseCase < Command
    end

    class CancelCase < Command
    end

    class LoopEnd < Command
    end

    class BranchEnd < Command
    end

    #class

    private
    ##########################
    # Map of CIDs to classes #

    CID_TO_CLASS = {
      0   => Command::Blank,
      99  => Command::Checkpoint,
      101 => Command::Message,
      102 => Command::Choices,
      103 => Command::Comment,
      105 => Command::ForceStopMessage,
      106 => Command::DebugMessage,
      107 => Command::ClearDebugText,
      111 => Command::VariableCondition,
      112 => Command::StringCondition,
      121 => Command::SetVariable,
      122 => Command::SetString,
      123 => Command::InputKey,
      124 => Command::SetVariableEx,
      125 => Command::AutoInput,
      126 => Command::BanInput,
      130 => Command::Teleport,
      140 => Command::Sound,
      150 => Command::Picture,
      151 => Command::ChangeColor,
      160 => Command::SetTransition,
      161 => Command::PrepareTransition,
      162 => Command::ExecuteTransition,
      170 => Command::StartLoop,
      171 => Command::BreakLoop,
      172 => Command::BreakEvent,
      173 => Command::EraseEvent,
      174 => Command::ReturnToTitle,
      175 => Command::EndGame,
      176 => Command::StartLoop,
      177 => Command::StopNonPic,
      178 => Command::ResumeNonPic,
      179 => Command::LoopTimes,
      180 => Command::Wait,
      201 => Command::Move, # special case
      202 => Command::WaitForMove,
      210 => Command::CommonEvent,
      211 => Command::CommonEventReserve,
      212 => Command::SetLabel,
      213 => Command::JumpLabel,
      220 => Command::SaveLoad,
      221 => Command::LoadGame,
      222 => Command::SaveGame,
      230 => Command::MoveDuringEventOn,
      231 => Command::MoveDuringEventOff,
      240 => Command::Chip,
      241 => Command::ChipSet,
      250 => Command::Database,
      251 => Command::ImportDatabase,
      270 => Command::Party,
      280 => Command::MapEffect,
      281 => Command::ScrollScreen,
      290 => Command::Effect,
      300 => Command::CommonEventByName,
      401 => Command::ChoiceCase,
      402 => Command::SpecialChoiceCase,
      420 => Command::ElseCase,
      421 => Command::CancelCase,
      498 => Command::LoopEnd,
      499 => Command::BranchEnd
    }
    CID_TO_CLASS.default = Command

    public
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
