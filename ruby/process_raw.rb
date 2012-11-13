#!/usr/bin/env ruby
require 'optparse'
require_relative 'process_letters'
require_relative 'keyboard'

# Processor for one line in the tap input data for both Salt and Pepper data
# format.
class TapLineProcessor

  # Initializes a new TapLineProcessor.
  #
  # @param [Symbol] The dataset type, :salt or :petter.
  # @param [Hash] A Hash with keys as the bi letters.
  # @param [Hash] A Hash with keys as the tri letters.
  # @param [Keyboard] A Keyboard instance with a paricular layout.
  def initialize(data_type, bi_letters, tri_letters, keyboard)
    @data_type = data_type
    @keyboard = keyboard

    # Ruby Hashes enumerate their values and keys in the order that the
    # corresponding keys were inserted.
    @bi_letters = bi_letters
    @tri_letters = tri_letters

    reset_prev
  end

  # Header string of the output.
  #
  # @return [String] Header string.
  def header
    h = %w(line_num inputing_finger user_id trial_index key xkeyboard ykeyboard
           systime xtravel ytravel down_time_elapse lr).join ','
    bi_letters = @bi_letters.keys.join ','
    tri_letters = @tri_letters.keys.join ','
    [h, bi_letters, tri_letters].join ','
  end

  # Process one line for tap input data.
  #
  # @param [Hash] A hash of raw data.
  # @param [Fixnum] line number in the raw file.
  # @return [Array] An array of processed data. Returns nil if this line
  #   is nil or is not processed.
  def process(line, index)
    if line.nil?
      reset_prev
      return
    end

    if !line[:is_tap_format]
      raise 'The data is not in tap input data format.'
    end

    # Only checks key DOWN actions.
    if line[:action_type] == 'DOWN' && line[:key]
      update_letter_hist line
      output = []
      output << index
      output << line[:inputing_finger] << line[:user_id]
      output << line[:trial_index] << line[:key]
      output << line[:xkeyboard] << line[:ykeyboard] << line[:systime]
      if next_key? line
        output << line[:xkeyboard] - @prev_xkeyboard
        output << line[:ykeyboard] - @prev_ykeyboard
        output << line[:systime] - @prev_time
        output << (@keyboard.lr_of_keyboard?(@prev_xkeyboard, @prev_ykeyboard,
                   line[:xkeyboard], line[:ykeyboard]) ? 1 : 0)
        output.concat letter_indicators
      end

      @prev_user_id = line[:user_id]
      @prev_task_type = line[:task_type]
      @prev_trial_index = line[:trial_index]
      @prev_pos_char = line[:pos_char_onphrase]
      @prev_xkeyboard = line[:xkeyboard]
      @prev_ykeyboard = line[:ykeyboard]
      @prev_time = line[:systime]

      output
    end
  end

  private
  # Updates the letter history with the current key press.
  #
  # @param [char] The current key (letter).
  def update_letter_hist(line)
    if next_key? line
      @letter_hist = @letter_hist[1..-1]
      @letter_hist << line[:key]
    elsif !(same_trial? line)
      @letter_hist = '##' + line[:key]
    end
  end

  # Checks the prescence of frequenct bi or tri-letters according to the
  # dictionaries.
  #
  # @return [Array] 1 indicates the prescence of the bi or tri-letter, and 0
  #     otherwise.
  def letter_indicators
    reset_letter_dict
    bi = @letter_hist[-2..-1]
    tri = @letter_hist[-3..-1]
    @bi_letters[bi] = 1 if @bi_letters[bi]
    @tri_letters[tri] = 1 if @tri_letters[tri]
    @bi_letters.values.concat(@tri_letters.values)
  end

  # Resets the letter dictionaries
  def reset_letter_dict
    @bi_letters = @bi_letters.each_key { |k| @bi_letters[k] = 0 }
    @tri_letters = @tri_letters.each_key { |k| @tri_letters[k] = 0 }
  end

  # Resets the instance variables that track the previous line values.
  def reset_prev
    @prev_user_id = -1
    @prev_task_type = -1;
    @prev_trial_index = -1;
    @prev_pos_char = -1;
    @prev_xkeyboard = -1;
    @prev_ykeyboard = -1;
    @prev_time = -1;
    @letter_hist = '###'
  end

  # Returns true if the key in the current line of data is the next key press
  # from the previous key press.
  #
  # @param [Hash] Hash of data from one line.
  # @return [bool] True if the key in the current line is the next key press.
  def next_key?(line)
    same_trial?(line) &&
    (@data_type == :salt && line[:pos_char_onphrase] == @prev_pos_char + 1 ||
     @data_type == :pepper)
  end

  # Returns true if the current line is from the same trial as the previous
  # line.
  #
  # @param [Hash] values of the current line.
  # @return [bool] True if the current line is from the same trial as the
  #     previous line.
  def same_trial?(line)
    line[:user_id] == @prev_user_id &&
    line[:task_type] == @prev_task_type &&
    line[:trial_index] == @prev_trial_index
  end
end

# Processes every line in the raw data input from the user studies.
class DatasetProcessor
  # Parses and process the input. Currently only processes the tap input data.
  # Outputs the processed data for each line. The processed data contains the
  # line number of the data in the original raw file.
  #
  # @param [IO] Input form IO.
  # @param [Symbol] Dataset type of the input, either :salt or :pepper.
  # @param [Hash] Frequent bi-letter patterns as keys in the hash.
  # #param [Hash] Frequent tri-letter patterns as keys in the hash.
  def self.process(io, data_type, bi_letters, tri_letters, keyboard)
    processor = TapLineProcessor.new data_type, bi_letters, tri_letters, keyboard
    puts processor.header

    if data_type == :pepper
      parser = PepperParser.new
    else
      parser = SaltParser.new
    end

    io_enum = io.each_with_index
    parser.parse_header io_enum

    loop do
      line, index = io_enum.next
      line = line.chomp.strip
      next if line.empty? || /^\s*#/ =~ line
      parsed_line = parser.parse_line line
      out = parsed_line && processor.process(parsed_line, index + 1)
      puts out.join ',' unless out.nil? || out.empty?
    end
  end
end

# Parses and processes data from Salt dataset.
class SaltParser
  # Parses the header of the input, removes the comments at the beginning.
  #
  # @param [Enumerator] IO enumerator with index.
  def parse_header(io_enum_with_index)
    while /(^\s*#)|(^\s*$)/ =~ io_enum_with_index.next[0]
    end
  end

  # Parses one line.
  #
  # @param [String] Line to be pased.
  # @return [Hash] A hash of values with corresponding columns if valid, or nil
  #   if the line of data is invalid, e.g., has missing values.
  def parse_line(line)
    tokens_array = line.chomp.split(',').map { |t| t == ' ' ? t : t.strip }
    tokens = tokens_array.to_enum
    result = {}

    result[:inputing_finger] = tokens.next.upcase
    result[:user_id] = tokens.next.to_i
    result[:task_type] = tokens.next.to_i
    result[:block_index] = tokens.next.to_i
    result[:trial_index] = tokens.next.to_i
    result[:phrase] = tokens.next

    pos = tokens.next.to_i
    tmp = tokens.next
    result[:is_tap_format] = tmp.is_pos_int?
    if result[:is_tap_format]
      result[:pos_char_onphrase] = pos
      key = result[:phrase][pos]
      result[:key] = key && key.downcase
      result[:index_onstroke] = tmp.to_i
    else
      result[:pos_onphrase] = pos
      result[:word] = tmp
      result[:index] = tokens.next.to_i
    end

    result[:pointer_id] = tokens.next.to_i
    result[:xkeyboard] = tokens.next.to_f
    result[:ykeyboard] = tokens.next.to_f
    result[:xscreen] = tokens.next.to_f
    result[:yscreen] = tokens.next.to_f
    result[:time] = tokens.next.to_i
    result[:systime] = tokens.next.to_i
    result[:upnow_time] = tokens.next.to_i
    result[:action_type] = tokens.next.upcase
    begin
      tokens.next
      tokens.next
      guessed_key = tokens.next
      result[:key] = guessed_key.empty? ? nil : guessed_key.downcase
    rescue StopIteration
    end
    if valid? result
      result
    end
  end

  private

  # Checks if the result is valid.
  #
  # @param [Hash] Hash of data from one line.
  # @return [bool] True if the result is valid, false if the result has some
  #     missing values.
  def valid?(result)
    !result[:inputing_finger].empty?
  end
end

# Parser for the Pepper dataset.
class PepperParser
  INPUTING_FINGER = { 1 => 'I', 2 => 'TT', 3 => 'T' }

  # Parses the header of the raw data.
  #
  # #param [Enumerator] Input from IO.
  def parse_header(io_enum)
    io_enum.next
  end

  # Parses one line of data from the dataset.
  #
  # @param [String] One line from the dataset.
  # @return [Hash] A hash of values with corresponding columns if valid, or nil
  #   if the line of dasta is invalid, e.g., empty line.
  def parse_line(line)
    tokens_array = line.chomp.split(',').map(&:strip)
    return if tokens_array.empty?

    tokens = tokens_array.to_enum
    result = {}

    tokens.next
    result[:user_id] = tokens.next.to_i
    posture_id = tokens.next.to_i
    result[:inputing_finger]  = INPUTING_FINGER[posture_id]
    result[:task_type] = posture_id
    result[:block_index] = tokens.next.to_i
    result[:trial_index] = tokens.next.to_i
    tokens.next
    result[:key] = tokens.next.gsub(/^"(.*?)"$/, '\1').downcase
    result[:xkeyboard] = tokens.next.to_f
    result[:ykeyboard] = tokens.next.to_f
    result[:systime] = tokens.next.to_i
    result[:action_type] = 'DOWN'
    result[:is_tap_format] = true
    result[:pos_char_onphrase] = -1
    result
  end
end

class String
  # Returns true if the string represents a positive integer. The string should
  # not have trailing and leadning spaces, otherwise it is not an integer.
  # @return [bool]
  def is_pos_int?
    /^\d+$/ === self
  end
end

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = <<EOS
Usage: process_raw.rb [options] keyboard_layout_file < <dataset_file>
keyboard_layout_file: the path to the file containing keyboard layout data.
EOS

  opts.on "-t", "--type DATA_TYPE", [:salt, :pepper],
          "Type of the input dataset (pepper, salt)." do |t|
    options[:type] = t
  end
end

if __FILE__ == $0
  option_parser.parse!
  raise OptionParser::MissingArgument if options[:type].nil?
  parent_dir = File.expand_path '..', File.dirname(__FILE__)
  freq_letter_file = File.join parent_dir, 'out', 'raw',
                               'salt-wordRep-letters.yml'

  keyboard_file= ARGV[0]
  File.open freq_letter_file do |f|
    File.open keyboard_file do | kf |
      letter_parser = LetterParser.new f
      keyboard = Keyboard.new kf
      DatasetProcessor.process STDIN, options[:type], letter_parser.bi_letters,
                               letter_parser.tri_letters, keyboard
    end
  end
end
