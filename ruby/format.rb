#!/usr/bin/env ruby
require 'optparse'

# Fomats a dada file that can be used as an input to a machine learning tool.
class Formatter
  # Converts the Arff file to Libsvm format file.
  #
  # @param [IO] Input file in Arff format.
  # @param [Array] Indices of the attributes to select.
  def self.arff_to_libsvm(io, select = [])
    class_label = {}
    io.each_line do |line|
      if /^\s*@/ =~ line
        if /^\s*@attribute\s+class\s+{(?<class_str>.+)}/ =~ line
          classes = class_str.split(',').map(&:strip)
          labels = Array(0...classes.length)
          class_label = Hash[classes.zip labels]
        end
      else
        tokens = line.chomp.split(',').map(&:strip)
        output = [class_label[tokens[0]]]
        index = 1
        (1...tokens.length).each do |i|
          if (select.empty? || select.include?(i))
            output << "#{index}:#{tokens[i]}"
            index += 1
          end
        end
        puts output.join ' '
      end
    end
  end
end

options = {}
option_parser = OptionParser.new do |opts|
  opts.banner = 'Usage: format.rb [options] < <input_file>'

  opts.on('-s', '--select [ATTRIBUTE_INDICES]', Array,
          'List of attribute indices. E.g. 1,3,4') do |input|
    list = input || []
    options[:select] = list.map(&:to_i)
  end
end

if __FILE__ == $0
  option_parser.parse!
  options[:select] ||= []
  Formatter.arff_to_libsvm STDIN, options[:select]
end
