#!/usr/bin/ruby
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
require 'rake'

class Simulation
  include Rake::DSL

  SIMULATOR = 'native/out/simulation_driver'

  def initialize(data_set, input)
    @singletap_model = data_set[:posture_singletap_model]
    @singletap_range = data_set[:singletap_attr_range]
    @timewindow_model = data_set[:posture_timewindow_model]
    @spatial_model = data_set[:spatial_model]
    @keyboard_layout = data_set[:keyboard_layout]
    @input = input
    @log = File.join 'out', 'log', "#{File.basename input}"
  end

  def run_sim
    task :sim, [:flags] do |t, args|
      log = @log
      flags = args[:flags]
      log += flags ? (flags.split('--').map(&:strip).join '-') : ''
      log_result = log + '-result'
      summary_result = log + '-summary'
      run args[:flags], log, log_result, summary_result
    end
  end

  def run_exp
    thresh = [0.5, 0.75, 0.90, 0.95, 0.99, 1]
    args = thresh.map do |thresh|
      flag = "-confidenceThresh #{thresh}"
      log = @log + (flag.split(' ').join '-')
      log_result = log + '-result'
      {thresh: thresh, flag: flag, log: log, log_result: log_result,
       summary_result: log + '-summary'}
    end
    args.each { |args| run args[:flag], args[:log], args[:log_result],
                args[:summary_result] }
    output = @log + '-exp'
    file output => args.map { |args| args[:log_result] } do |t|
      File.open(output, 'w') do |f|
        f.puts %w(thresh posture_accuracy posture_error key_accuracy).join(',')
        args.each do |args|
          enum = File.open(args[:log_result]).each_line
          values = enum.grep(
            /(posture accuracy|posture error rate|key accuracy)\s=\s(.*)$/) { $2 }
          f.puts "#{args[:thresh]},#{values.join ','}"
        end
        end
    end
    task :exp => output
  end

  :private
  def run(flags, log, log_result, summary_result)
    sh ["#{SIMULATOR} #{flags} #{@keyboard_layout} #{@spatial_model}",
        "#{@singletap_model} #{@singletap_range} #{@timewindow_model} #{@input}",
        "> #{log} 2>&1"].join ' '
    sh "ruby/eval_sim.rb #{log_result} < #{log} > #{summary_result}"
    sh "echo #{flags} >> #{summary_result}"
  end
end

