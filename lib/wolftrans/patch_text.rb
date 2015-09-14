require 'wolftrans/context'
require 'wolfrpg'

require 'fileutils'
require 'find'

module WolfTrans
  class Patch
    ######################
    # Loading Patch data #
    def load_patch(patch_dir)
      @patch_dir = WolfTrans.sanitize_path(patch_dir)
      @patch_assets_dir = "#{@patch_dir}/Assets"
      @patch_strings_dir = "#{@patch_dir}/Patch"

      # Make sure these directories all exist
      [@patch_assets_dir, @patch_strings_dir].each do |dir|
        FileUtils.mkdir_p dir
      end

      # Find data dir
      @patch_data_dir = WolfTrans.join_path_nocase(@patch_assets_dir, 'data')

      # Load blacklist
      @file_blacklist = []
      if File.exists? "#{patch_dir}/blacklist.txt"
        IO.read_txt("#{patch_dir}/blacklist.txt").each_line do |line|
          line.strip!
          next if line.empty?
          if line.include? '\\'
            raise "file specified in blacklist contains a backslash (use a forward slash instead)"
          end
          @file_blacklist << line.downcase!
        end
      end

      # Load strings
      Find.find(@patch_strings_dir) do |path|
        next if FileTest.directory? path
        next unless File.extname(path).casecmp '.txt'
        process_patch_file(path, :load)
      end

      # Write back to patch files
      processed_filenames = []

      Find.find(@patch_strings_dir) do |path|
        next if FileTest.directory? path
        next unless File.extname(path).casecmp '.txt'
        process_patch_file(path, :update)
        processed_filenames << path[@patch_strings_dir.length+1..-1]
      end

      # Now "process" any files that should be generated
      @strings.each do |string, contexts|
        contexts.each do |context, trans|
          unless processed_filenames.include? trans.patch_filename
            process_patch_file("#{@patch_strings_dir}/#{trans.patch_filename}", :update)
            processed_filenames << trans.patch_filename
          end
        end
      end
    end

    # Load the translation strings indicated in the patch file,
    # generate a new patch file with updated context information,
    # and overwrite the patch
    def process_patch_file(filename, mode)
      patch_filename = filename[@patch_strings_dir.length+1..-1]

      txt_version = nil

      # Parser state information
      state = :expecting
      original_string = ''
      contexts = []
      translated_string = ''
      new_contexts = nil

      # Variables for the revised patch
      context_comments = {}

      # The revised patch
      output = ''
      output_write = false
      pristine_translated_string = ''

      if File.exists? filename
        output_write = true if mode == :update
        IO.read_txt(filename).each_line.with_index do |pristine_line, index|
          # Remove comments and strip
          pristine_line.gsub!(/\n$/, '')
          line = pristine_line.gsub(/(?!\\)#.*$/, '').rstrip
          comment = pristine_line.match(/(?<!\\)#.*$/).to_s.rstrip
          line_num = index + 1

          if line.start_with? '>'
            instruction = line.gsub(/^>\s+/, '')

            # Parse the patch version
            parse_instruction(instruction, 'WOLF TRANS PATCH FILE VERSION') do |args|
              unless txt_version == nil
                raise "two version strings in file (line #{line_num})"
              end
              txt_version = Version.new(str: args.first)
              if txt_version > TXT_VERSION
                raise "patch version (#{new_version}) newer than can be read (#{TXT_VERSION})"
              end
              if mode == :update
                output << "> WOLF TRANS PATCH FILE VERSION #{TXT_VERSION}"
                output << comment unless comment.empty?
                output << "\n"
              end
            end

            # Make sure we have a version specified before reading other instructions
            if txt_version == nil
              raise "no version specified before first instruction"
            end

            # Now parse the instructions
            parse_instruction(instruction, 'BEGIN STRING') do |args|
              unless state == :expecting
                raise "began another string without ending previous string (line #{line_num})"
              end
              state = :reading_original
              original_string = ''
              if mode == :update
                output << pristine_line << "\n"
              end
            end

            parse_instruction(instruction, 'END STRING') do |args|
              if state == :expecting
                raise "ended string without a begin (line #{line_num})"
              elsif state == :reading_original
                raise "ended string without a translation block (line #{line_num})"
              end
              state = :expecting
              new_contexts = []
            end

            parse_instruction(instruction, 'CONTEXT') do |args|
              if state == :expecting
                raise "context outside of begin/end block (line #{line_num})"
              end
              if args.empty?
                raise "no context string provided in context line (line #{line_num})"
              end

              # After a context, we're no longer reading the original text.
              state = :reading_translation
              begin
                new_context = Context.from_string(args.shift)
              rescue => e
                raise e, "#{e} (line #{line_num})", e.backtrace
              end
              # Append context if translated_string is empty, since that means
              # no translation was given.
              if translated_string.empty?
                contexts << new_context
              else
                new_contexts = [new_context]
              end
              if mode == :update
                # Save the comment for later
                context_comments[new_context] = comment
              end
            end

            # If we have a new context list queued, flush the translation to all
            # of the collected contexts
            if new_contexts
              original_string_new = unescape_string(original_string, false)
              translated_string_new = unescape_string(translated_string, true)
              contexts.each do |context|
                if mode == :update
                  # Write an appropriate context line to the output
                  output << '> CONTEXT '
                  if @strings.include?(original_string_new) &&
                      @strings[original_string_new].include?(context)
                    output << @strings[original_string_new].select { |k,v| k.eql? context }.keys.first.to_s
                    output << ' < UNTRANSLATED' if translated_string_new.empty?
                  else
                    output << context.to_s << ' < UNUSED'
                  end
                  output << " " << context_comments[context] unless comment.empty?
                  output << "\n"
                else
                  # Put translation in hash
                  @strings[original_string_new][context] = Translation.new(patch_filename, translated_string_new, false)
                end
              end
              if mode == :update
                # Write the translation
                output << pristine_translated_string.rstrip << "\n"
                # If the state is "expecting", that means we need to write the END STRING
                # line to the output too.
                if state == :expecting
                  output << pristine_line << "\n"
                end
              end

              # Reset variables for next read
              translated_string = ''
              pristine_translated_string = ''
              contexts = new_contexts

              new_contexts = nil
            end
          else
            # Parse text
            if state == :expecting
              unless line.empty?
                raise "stray text outside of begin/end block (line #{line_num})"
              end
            elsif state == :reading_original
              original_string << line << "\n"
            elsif state == :reading_translation
              translated_string << line << "\n"
              if mode == :update
                pristine_translated_string << pristine_line << "\n"
              end
            end
            # Make no modifications to the patch line if we're not reading translations
            unless state == :reading_translation
              if mode == :update
                output << pristine_line << "\n"
              end
            end
          end
        end

        # Final error checking
        if state != :expecting
          raise "final begin/end block has no end"
        end
      else
        # It's a new file, so just stick a header on it
        if mode == :update
          output << "> WOLF TRANS PATCH FILE VERSION #{TXT_VERSION}\n"
        end
      end

      if mode == :update
        # Write all the new strings to the file
        @strings.each do |orig_string, contexts|
          if contexts.values.any? { |trans| trans.autogenerate? && trans.patch_filename == patch_filename }
            output_write = true
            output << "\n> BEGIN STRING\n#{escape_string(orig_string)}\n"
            contexts.each do |context, trans|
              next unless trans.autogenerate?
              trans.autogenerate = false
              output << "> CONTEXT " << context.to_s << " < UNTRANSLATED\n"
            end
            output << "\n> END STRING\n"
          end
        end

        # Write the output to the file
        if output_write
          FileUtils.mkdir_p(File.dirname(filename))
          File.open(filename, 'wb') { |file| file.write(output) }
        end
      end
    end

    private
    # Yields the arguments of the instruction if it matches tested_instruction
    def parse_instruction(instruction, tested_instruction)
      if instruction.start_with? tested_instruction
        args = instruction.slice(tested_instruction.length..-1).strip.split(/\s+<\s+/)
        if args.first == nil || args.first.empty?
          yield []
        else
          yield args
        end
      end
    end

    # Unescapes a patch file string
    def unescape_string(string, do_rtrim)
      # Remove trailing whitespace or just newline
      if do_rtrim
        string = string.rstrip
      else
        string = string.gsub(/\n\z/m, '')
      end
      # Change escape sequences
      string.match(/(?<!\\)\\[^sntr><#\\]/) do |match|
        raise "unknown escape sequence '#{match}' #{string}"
      end
      string.gsub!("\\\\", "\x00") #HACK
      string.gsub!("\\s", " ")
      string.gsub!("\\n", "\n")
      string.gsub!("\\t", "\t")
      string.gsub!("\\r", "\r")
      string.gsub!("\\>", ">")
      string.gsub!("\\#", "#")
      string.gsub!("\x00") { "\\" } #HACK
      string
    end

    # Escapes a string for writing into a patch file
    def escape_string(string)
      string = string.gsub("\\", "\x00") #HACK
      string.gsub!("\t", "\\t")
      string.gsub!("\r", "\\r")
      string.gsub!(">", "\\>")
      string.gsub!("#", "\\#")
      string.gsub!("\x00") { "\\\\" } #HACK
      # Replace trailing spaces with \s
      string.gsub!(/ *$/) { |m| "\\s" * m.length }
      # Replace trailing newlines with \n
      string.gsub!(/\n*\z/m) { |m| "\\n" * m.length }
      string
    end
  end
end
