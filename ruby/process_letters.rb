#!/usr/bin/env ruby
#
# Copyright:: Copyright 2012 Google Inc.
# License:: All Rights Reserved.
# Original Author:: Ying Yin (mailto:yingyin@google.com)
#
# Processes the words in the Salt wordRep data sets to count frequent letter
# combinations.
#
# This doc string should contain an overall description of the module/script
# and can optionally briefly describe exported classes and functions.
#
#    ClassFoo:      One line summary.
#    function_foo:  One line summary.
#
require 'set'
require 'psych'

class LetterProcessor
  def process_header(io)
    while /^\s*#/ =~ io.readline
    end
  end

  def process(io)
    words = Set.new
    io.each do |line|
      tokens = line.chomp.split(',').map(&:strip)
      phrase = tokens[5].split.first
      words << phrase
    end
    out = { word_count: words.count, words: words.to_a }
    out[:biletters] = process_letters(words, 2)
    out[:biletters_count] = out[:biletters].count
    out[:triletters] = process_letters(words, 3)
    out[:triletters_count] = out[:triletters].count
    puts out.to_yaml
  end

  def process_letters(dict, num_letters)
    counts = {}
    dict.each do |phrase|
      (0...phrase.length - num_letters + 1).each do |i|
        letters = phrase[i..i + num_letters - 1]
        counts[letters] = counts[letters] ? counts[letters] + 1 : 1
      end
    end
    counts.sort_by { |letters, freq| freq }.reverse
  end
end

class LetterParser
  def initialize(io)
    @hash = Psych.load(io.read)
  end

  def bi_letters
    Hash[@hash[:biletters]]
  end

  def tri_letters
    Hash[@hash[:triletters]]
  end
end

def main()
  processor = LetterProcessor.new
  input = STDIN
  processor.process_header input
  processor.process input
end

if __FILE__ == $0
  main()
end

