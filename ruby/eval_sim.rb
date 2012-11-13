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
class SingleTapEvaluator
  HEADER = %w(line_num inputing_finger user_id trial_index key predicted_key xkeyboard
              ykeyboard systime)
  def initialize(io)
    @io = io
    @posture_result = { positive: 0, negative: 0, unknown: 0}
    @key_result = { positive: 0, negative: 0}
  end

  def eval(result_file)
    line_enum = @io.each
    File.open result_file, 'w' do |f|
      f.puts HEADER.join ','
      loop do
        line = line_enum.next
        if /Posture classification: (?<result>.+)$/ =~ line
          tokens = result.chomp.split ','
          posture_hash = Hash[tokens.map { |t| t.split('=').map(&:strip) }]
          if posture_hash['pred_posture'] == posture_hash['true_posture']
            @posture_result[:positive] += 1
          elsif posture_hash['pred_posture'] == '2'
            @posture_result[:unknown] += 1
          else
            @posture_result[:negative] += 1
          end
        elsif /###Key detection: (?<key_result>.+)$/ =~ line
          tokens = key_result.chomp.split ','
          key_hash = Hash[tokens.map { |t| t.split('=').map(&:strip) }]
          if key_hash['predicted_key'] == key_hash['key']
            @key_result[:positive] += 1
          else
            f.puts HEADER.map { |x| key_hash[x] }.join ','
            @key_result[:negative] += 1
          end
        end
      end
    end
  end

  def result
    puts @posture_result
    puts @key_result
    posture_sum = @posture_result.values.reduce :+
    puts "total points = #{posture_sum}"
    puts "posture accuracy = #{@posture_result[:positive].to_f / posture_sum}"
    puts "posture error rate = #{@posture_result[:negative].to_f / posture_sum}"
    key_sum = @key_result.values.reduce :+
    puts "key accuracy = #{@key_result[:positive].to_f / key_sum}"
  end
end

def main(result_file)
  evaluator = SingleTapEvaluator.new STDIN
  evaluator.eval result_file
  evaluator.result
end

if __FILE__ == $0
  main(ARGV[0])
end
