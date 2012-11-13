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
require 'rake'

# Analyzes and computes the features for training and testing datasets.
class Analyzer
  include Rake::DSL
  # Initializes an analyzer instance.
  #
  # @param [String] path of the training data.
  # @param [Array] An array of strings of the path of the testing data.
  def initialize(training_data, testing_data)
    @training_data = training_data
    @testing_data = testing_data
    @range_file = File.join 'out', 'analysis',
                            "#{File.basename training_data}.range"
  end

  def analyze_training_data
    analyze_data @training_data, @range_file, true
  end

  def analyze_testing_data
    @testing_data.each { |d| analyze_data d, @range_file, false }
  end

  # Analyzes one date.
  #
  # @param [String] Full path of the data file to be processed.
  # @param [String] Full path of the range file.
  def analyze_data(data, range_file, is_training)
    prefix = File.join 'out/analysis', "#{File.basename data}"
    stats = prefix + '.stats'
    prereqs = ['out/analysis', data]
    prereqs << range_file unless is_training
    range_args = is_training ? range_file : ('NA ' + range_file)
    target = is_training ? range_file : stats
    file target => prereqs do |t|
      cmd = ["R --no-save --slave",
             "--args #{data} #{range_args}",
             "< compute_features.R > #{stats}"]
      sh cmd.join ' '
    end
    desc ['Compute features from the processded data for both the training and ',
          'testing datasets. A range file is produced based on the training data ',
          'and stats files are produced for both training and testing data'].join ''
    task :compute_features => target
  end
end
if __FILE__ == $0
  main()
end

