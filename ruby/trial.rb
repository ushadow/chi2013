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

CLASSPATH = ["#{ENV['CLASSPATH']}", "#{ENV['WEKA_DIR']}/weka.jar",
             "#{ENV['WEKA_DIR']}/libsvm.jar"].join ':'

OUT_DIR = File.join 'out', 'weka'

class Trial
  include Rake::DSL

  # Initializes a new instance of a Trial.
  #
  # @param [String] Full path of the training file.
  # @param [String] Name of the classifier.
  # @param [Array] (optional) Array of indices of attributes to be removed.
  def initialize(training_file, classifier, params = '', remove_attr_ind = [])
    @training_file = training_file
    @remove_attr_ind = remove_attr_ind
    @classifier = classifier
    @classifier_shortname = classifier.split('.').last
    @params = params
    basename = File.basename training_file, '.arff'

    @model_file = File.join OUT_DIR, "#{basename}-#{trial_setting_str}.model"
    @train_result = File.join OUT_DIR, "#{basename}-#{trial_setting_str}.train"
  end

  def trial_setting_str
    params_str = @params.split(/[-\s]/).reject { |s| s.empty? }.join '-'
    "#{@classifier_shortname}#{@remove_attr_ind.join '-'}#{params_str}"
  end

  # Cross validation training.
  def train_cv
    file @model_file => [OUT_DIR, @training_file] do |t, args|
      cmd = cmd_prefix
      cmd.concat remove_attr_cmd
      sh cmd.join ' '
    end
    task :weka => @model_file
  end

  # Evaluate the classifier on test data.
  #
  # @param [String] Name of the test file.
  def test(test_file)
    basename = File.basename test_file, '.arff'
    test_result = File.join OUT_DIR,
        "#{basename}-#{trial_setting_str}.test"
    test_pred = "#{test_result}-pred"
    cmd = ["java -cp #{CLASSPATH}",
           'weka.classifiers.meta.FilteredClassifier',
           "-T #{test_file}",
           "-l #{@model_file} -c 1"]
    file test_pred => [OUT_DIR, @model_file, test_file] do |t|
      cmd2 = cmd + ['-p 2', "> #{t.name}"]
      sh cmd2.join ' '
    end

    test_pred_table = test_pred + '.table'
    file test_pred_table => [OUT_DIR, test_pred] do |t|
      cmd = "./ruby/parse_weka_result.rb < #{test_pred} > #{test_pred_table}"
      sh cmd
    end
    desc 'Run weka classifiers.'
    task :weka => [test_result, test_pred_table]
  end

  # Evaluates the training result on test data.
  def train_test(test_file)
    file @model_file => [OUT_DIR, @training_file, test_file] do |t|
      cmd = cmd_prefix
      cmd << "-T #{test_file}"
      cmd.concat remove_attr_cmd
      sh cmd.join ' '
    end
    task :weka => @model_file
  end

  # Prefix of the weka command.
  # -k Outputs information-theoretic statistics.
  def cmd_prefix
    ["java -cp #{CLASSPATH}",
     'weka.classifiers.meta.FilteredClassifier',
     "-t #{@training_file}",
     "-d #{@model_file} -i -k -c 1"]
  end

  def remove_attr_cmd
    ['-F "weka.filters.unsupervised.attribute.Remove',
     (@remove_attr_ind.empty? ? '"' : "-R #{@remove_attr_ind.join ','}\""),
     "-W weka.classifiers.#{@classifier} -- #{@params}",
     "> #{@train_result}"]
  end

end

# A training and testing trial using libsvm.
class SvmTrial
  include Rake::DSL

  LIBSVM_DIR = 'libsvm-3.12'
  LIBSVM_OUT = File.join 'out', 'libsvm'
  TRAIN_EXEC = File.join LIBSVM_DIR, 'svm-train'
  PREDICT_EXEC = File.join LIBSVM_DIR, 'svm-predict'

  def initialize(training_file, params = '')
    @training_file = training_file
    basename = File.basename training_file, '.libsvm'
    @params = params
    @model_file = File.join LIBSVM_OUT,
                  "#{basename}#{SvmTrial.to_str params}.model"
  end

  def train
    file @model_file => [LIBSVM_OUT, @training_file] do |t|
      cmd = "#{TRAIN_EXEC} #{@params} #{@training_file} #{@model_file}"
      sh cmd
    end
    task :svm => @model_file
  end

  def self.to_str(params)
    params.split(/[-\s]/).reject { |s| s.empty? }.join '-'
  end

  def test(test_file, params = '')
    basename = File.basename test_file, '.libsvm'
    test_output = File.join LIBSVM_OUT,
                            "#{basename}#{SvmTrial.to_str params}.test"
    test_result = test_output + '-result'
    file test_output => [LIBSVM_OUT, @model_file, test_file] do |t|
      sh ["#{PREDICT_EXEC} #{params} #{test_file} #{@model_file}",
          "#{t.name} > #{test_result}"].join ' '
    end
    task :svm => test_output
  end
end

class Filter
  include Rake::DSL

  def remove_instances(data)
    dir = File.dirname data
    basename = File.basename data, '.arff'
    filtered_data = File.join dir, "#{basename}-removed-instances.arff"
    file filtered_data, [:percent] => [OUT_DIR, data] do |t, args|
      cmd = ["java -cp #{CLASSPATH} weka.filters.MultiFilter",
             '-F "weka.filters.unsupervised.instance.Randomize"',
             '-F "weka.filters.unsupervised.instance.RemovePercentage',
             "-P #{args[:percent]}\"",
             "-i #{data} -o #{filtered_data}"].join ' '
      sh cmd
    end
    desc 'Remove a percentage of instances.'
    task :filter, [:percent] => filtered_data
  end

  def remove(input, output)
    file output => [OUT_DIR, input] do |t|
      cmd = ["java -cp #{CLASSPATH}",
             'weka.filters.unsupervised.attribute.Remove -R 2,3,4',
             "-i #{input} -o #{output}"].join ' '
      sh cmd
    end
    task :filter => output
  end
end

