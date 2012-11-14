#!/usr/bin/env ruby
#
# Copyright:: Copyright 2012 Google Inc.
# License:: All Rights Reserved.
# Original Author:: Ying Yin (mailto:yingyin@google.com)
#
# Key detection accuracy by checking key bounds.
require 'optparse'
require_relative 'keyboard.rb'

class AccuracyEvaluator
  def initialize
    @result = Hash.new { |hash, key| hash[key] = {positive: 0, negative:0} }
  end

  def add_positive(user_id)
    @result[user_id][:positive] += 1
  end

  def add_negative(user_id)
    @result[user_id][:negative] += 1
  end

  def result
    errors = @result.map { |k, v| v[:negative].to_f / (v[:positive] + v[:negative]) }
    sum = errors.inject :+
    mean = sum / errors.length
    var = errors.inject(0) { |sum, n| sum + (n - mean) * (n - mean) } / errors.length
    {mean: mean, sd: Math.sqrt(var), errors: errors}
  end
end

class Simulator
  # @param [IO] processed data.
  def initialize(io, keyboard)
    @io = io
    @keyboard = keyboard
    process_header
    @evaluator = AccuracyEvaluator.new
  end

  def run
    @io.each do |line|
      tokens = line.chomp.split(',').map(&:strip)
      key = tokens[@keyindex].empty? ? ' ' : tokens[@keyindex]
      x = tokens[@xindex].to_f
      y = tokens[@yindex].to_f
      user_id = tokens[@user_index].to_i
      if @keyboard.in_key_bounds? key, x, y
        @evaluator.add_positive user_id
      else
        @evaluator.add_negative user_id
      end
    end
  end

  def result
    @evaluator.result
  end

  private

  def process_header
    header = @io.readline
    @header = header.chomp.split(',').map(&:strip)
    @keyindex = @header.index('key')
    @xindex = @header.index('xkeyboard')
    @yindex = @header.index('ykeyboard')
    @user_index = @header.index('user_id')
  end
end

def main
  options = parse_options ARGV
  File.open options[:keyboard_file] do |key_file|
    keyboard = Keyboard.new key_file
    simulator = Simulator.new STDIN, keyboard
    simulator.run
    simulator.result[:errors].each { |n| puts n }
  end
end

def parse_options(args)
  options = {}
  opts = OptionParser.new do |opts|
    opts.banner = 'Usage: eval_keytaps.rb -k<keyboard_layout_file> ' +
                  '< <dataset_file>'
    opts.on '-k', '--keyboard KEYBOARD_FILE',
        'keyboard layout file in csv format' do |k|
      options[:keyboard_file] = k
    end
  end
  opts.parse! args
  options
end

if __FILE__ == $0
  main()
end
