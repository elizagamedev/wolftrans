require 'wolfrpg/map'
require 'wolfrpg/game_dat'
require 'wolfrpg/database'
require 'wolfrpg/common_events'

module WolfRpg
  # Find strings in binary string and return them inline in an array
  def self.parse_strings(data)
    result = []

    # Scan for strings
    str_len = 0
    can_seek_multibyte = false
    data.each_byte.with_index do |c, i|
      result << c

      if can_seek_multibyte
        if (c >= 0x40 && c <= 0x9E && c != 0x7F) ||
            (c >= 0xA0 && c <= 0xFC)
          str_len += 1
          next
        end
      end
      if (c >= 0x81 && c <= 0x84) || (c >= 0x87 && c <= 0x9F) ||
          (c >= 0xE0 && c <= 0xEA) || (c >= 0xED && c <= 0xEE) ||
          (c >= 0xFA && c <= 0xFC)
        # head of multibyte character
        str_len += 1
        can_seek_multibyte = true
        next
      end

      can_seek_multibyte = false
      if c == 0x0A || c == 0x0D || c == 0x09 || # newline, CR, tab
          (c >= 0x20 && c <= 0x7E) || # printable ascii
          (c >= 0xA1 && c <= 0xDF) # half-width katakana
        str_len += 1
      else
        str = ''
        if c == 0 && str_len > 0
          # End of the string. Make sure it's valid by checking for
          # a length prefix.
          str_len_check = data[i - str_len - 4,4].unpack('V').first
          if str_len_check == str_len + 1
            begin
              str = data[i - str_len,str_len].encode(Encoding::UTF_8, Encoding::WINDOWS_31J)
            rescue
              #do nothing
            end
          end
        end

        # Either append the string or hex bytes
        unless str.empty?
          result.slice!(-(4 + str_len + 1)..-1)
          result << str
        end

        # Reset str length
        str_len = 0
      end
    end
    return result
  end
end
