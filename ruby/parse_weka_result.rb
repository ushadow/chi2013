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
#
# $Id: //depot/google3/devtools/editors/autogen/genrb#1 $
class WekaParser
  def self.parse io
    puts header.join ','

    regex = /^\s*\d+\s+\d+:(?<actual_label>[^\s]+)\s+\d+:(?<pred_label>[^\s]+)\s+\+?\s+(?<prob>[\d\.]+)\s*\((?<line>\d+)\)/ 
    io.each do |line|
      if md = regex.match(line)
        output = []
        output << md[:line] << md[:actual_label] << md[:pred_label] << md[:prob]
        puts output.join ','
      end
    end
  end

  def self.header
    %w(line_num actual_class predicted_class prob)
  end
end

def main()
  WekaParser.parse STDIN
end

if __FILE__ == $0
  main()
end

