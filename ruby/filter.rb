#!/usr/bin/env ruby
#
# Copyright:: Copyright 2012 Google Inc.
# License:: All Rights Reserved.
# Original Author:: Ying Yin (mailto:yingyin@google.com)
#
# Summary description of library or script.
#
# This doc string should contain an overall description of the module/script
# and can optionally briefly describe exported classes and functions.
#
#    ClassFoo:      One line summary.
#    function_foo:  One line summary.
require 'optparse'
require_relative 'keyboard.rb'

# A utility class that provides functions to filter outliers from the processed
# data.
class Filter
  def self.filter_outlier(io, keyboard)
    header = io.readline.chomp
    puts header
    header = header.split(',').map(&:strip)
    xindex = header.index 'xkeyboard'
    yindex = header.index 'ykeyboard'
    keyindex = header.index 'key'
    keyheight = keyboard.params[:keyheight]
    io.each do |line|
      line.chomp!
      tokens = line.split(',').map(&:strip)
      key = tokens[keyindex].empty? ? ' ' : tokens[keyindex]
      key_center = keyboard.relative_key_center key
      puts line unless self.outlier? tokens[xindex].to_f, tokens[yindex].to_f,
                                     key_center, keyheight * 1.5
    end
  end

  def self.outlier?(x, y, key_center, tolerance)
    x < key_center[:x] - tolerance || x > key_center[:x] + tolerance ||
    y < key_center[:y] - tolerance || y > key_center[:y] + tolerance
  end
end

def create_optparser
  OptionParser.new do |opts|
    opts.banner = 'Usage: filter.rb keyboard_file < <processed_data_file>'
  end
end

def main
  create_optparser.parse!
  File.open  ARGV[0] do |f|
    keyboard = Keyboard.new f
    Filter.filter_outlier STDIN, keyboard
  end
end

if __FILE__ == $0
  main()
end

