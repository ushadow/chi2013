#!/usr/bin/env rake
require_relative 'ruby/trial.rb'
require_relative 'ruby/analyzer.rb'
require_relative 'ruby/simulation.rb'

classifiers = %w(functions.LibSVM)

exec_module = 'native/out/simulation_driver'

raw_files = ['pepper-tapping-phrase.log', 'salt-tapping-phrase-aligned.log']

def push(data_set)
  android_device_dir = '/sdcard/LatinImeGoogle/spatial/models/'
  data_set.each { |k, v| sh "adb push #{v} #{android_device_dir}#{k}" }
end

def copy_dataset(data_set)
  android_source_dir = '/usr/local/google/users/yingyin/android/source/'
  ime_res_dir = 'vendor/google/apps/LatinImeGoogle/java/res/raw/'
  data_set.each { |k, v| cp "#{v}", "#{android_source_dir}#{ime_res_dir}#{k}" }
end

def run_r(r_script, *args, output)
  cmd = "R --no-save --slave --args #{args.join ' '} < ./#{r_script}"
  cmd += " > #{output}" if output
  sh cmd
end

directory 'out/processed'
directory 'out/analysis'
directory 'out/weka'
directory 'out/libsvm'
directory 'out/log'

raw_files.each do |f|
  input_file = File.join 'out/raw', f
  keyboard_layout_file = ''
  type = f.split('-').first
  if type == 'pepper'
    keyboard_file = 'nexus-s.csv'
    user_file = 'pepper-user.table'
  elsif type == 'salt'
    keyboard_file = 'galaxy-nexus.csv'
    user_file = 'salt-user.table'
  end
  keyboard_file = File.join 'out', 'raw', keyboard_file
  keyboard_table = keyboard_file.gsub /.csv$/, '.table'
  user_file = File.join 'out', 'raw', "#{user_file}"

  basename = File.basename(f, '.log')
  processed_file = File.join 'out/processed', basename
  file processed_file => ['out/processed', input_file] do |t|
    sh ["./ruby/process_raw.rb -t #{type} #{keyboard_file}",
        "< #{input_file} > #{t.name}"].join(' ')
  end
  desc 'Processes all raw files.'
  task :process_raw => processed_file

  filtered_file = processed_file + '-filtered'
  file filtered_file => ['out/processed', processed_file] do |t|
    sh "./ruby/filter.rb #{keyboard_file} < #{processed_file} > #{t.name}"
  end
  desc 'Filter outliers from the processed data.'
  task :filter_outliers => filtered_file

  filtered_noleft = filtered_file + '-noleft'
  file filtered_noleft => ['out/processed', filtered_file] do |t|
    sh ["R --no-save --slave --args #{filtered_file} #{user_file} #{t.name}",
       "< filter_left.R"].join ' '
  end
  desc 'Remove the left handed users.'
  task :filter_left => filtered_noleft

  ['EvalBaseModel', 'EvalKeyModel', 'EvalKeyModelByRow',
   'EvalKeyDetectionByPosture', 'EvalKeyDetectionByPostureGroup',
   'EvalPostureModelWithDistance'].each do |model|
    cv_model = File.join 'out', 'analysis',
                         "#{File.basename filtered_noleft}-#{model}"
    file cv_model => ['out/analysis', filtered_noleft, user_file,
                      keyboard_table] do |t|
      sh ["R --no-save --slave --args #{filtered_noleft} #{user_file}",
          "#{keyboard_table} #{t.name} #{model} < ./cross_validation.R",
          "> #{cv_model}-output"].join ' '
    end
    task :cv_model => cv_model
  end

  cv_output = File.join 'out', 'analysis',
                        "#{File.basename filtered_file}-cv-posture"
  file cv_output => ['out/analysis', filtered_file, user_file,
                     keyboard_table] do |t|
    sh ["R --no-save --slave --args #{filtered_file} #{user_file}",
        "#{keyboard_table} < ./cross_validation.R > #{t.name}"].join ' '
  end
  task :cv_posture => cv_output

  cv_key_output = File.join 'out', 'analysis',
                     "#{File.basename filtered_file}-cv-posture-key"
  file cv_key_output => ['out/analysis', filtered_file, user_file,
                     keyboard_table] do |t|
    sh ["R --no-save --slave --args #{filtered_file} #{user_file}",
        "#{keyboard_table} #{t.name} < ./cross_validation_by_key.R"].join ' '
  end
  task :cv_posture_key => cv_key_output

  stats_file = File.join 'out/analysis',
                         "#{File.basename filtered_noleft}.stats"
  file stats_file => ['out/analysis', filtered_noleft] do |t|
    sh ["R --no-save --slave --args #{filtered_noleft} #{keyboard_table}",
        "< ./compute_stats.R > #{t.name}"].join ' '
  end
  desc 'Compute stats and graphs for the data.'
  task :stats => stats_file

  within_user_output = File.join 'out', 'log',
                                 "#{File.basename filtered_file}-withinuser"
  file within_user_output => ['out/log', filtered_file] do |t|
    sh ["R --no-save --slave --args #{filtered_file} #{keyboard_table}",
        "#{user_file} < detect_keys_within_user.R > #{t.name}"].join ' '
  end
  task :within_user => within_user_output

  biletter_output = File.join 'out', 'log',
                              "#{File.basename filtered_file}-biletter"
  file biletter_output => ['out/log', filtered_file] do |t|
    sh ["R --no-save --slave --args #{filtered_file}",
        "< detect_keys_biletter.R > #{t.name}"].join ' '
  end
  task :biletter => biletter_output

  train_file = filtered_noleft + '-train'
  test_file = filtered_noleft + '-test'
  file train_file => ['out/processed', filtered_noleft] do |t|
    sh "R --no-save --slave --args #{filtered_noleft} < split.R"
  end
  desc 'Splits the processed dataset into training and testing sets.'
  task :split => train_file

  [['EvalKeyModel', 'T'],
   ['EvalPostureKeyModel', 'T', 'TT']].each do |model, *postures|
    postures.each do |p|
      image_file = File.join 'out', 'analysis',
                   "#{File.basename train_file}-#{model}-#{p}.pdf"
      file image_file => [train_file, keyboard_table] do |t|
        run_r 'plot_key_boundary.R', train_file, keyboard_table, t.name, model,
              p, nil
        sh "convert #{t.name} #{image_file.gsub /.pdf$/, '.png'}"
      end
      task :plot_key_boundary => image_file
    end
  end

  key_bound_detection = File.join 'out', 'log',
                                  "#{File.basename test_file}-keybound"
  detect_script = File.join 'ruby', 'detect_keys_bounds.rb'
  file key_bound_detection => [detect_script, 'out/log', test_file] do |t|
    sh "#{detect_script} #{keyboard_file} < #{test_file} > #{t.name}"
  end
  key_bound_all = File.join 'out', 'log',
      "#{File.basename filtered_noleft}-keybound"
  file key_bound_all => [detect_script, 'out/log', filtered_noleft] do |t|
    sh "#{detect_script} #{keyboard_file} < #{filtered_noleft} > #{t.name}"
  end
  desc 'Evaludate key detection accuracy with key bounds checking.'
  task :detect_by_keybound => [key_bound_detection, key_bound_all]

  gaussian_output = "out/log/#{File.basename test_file}-gaussian"
  file gaussian_output => ['out/log', filtered_file, user_file,
                           keyboard_file] do |t|
    sh ["R --no-save --slave --args #{filtered_file} #{user_file}",
        "#{keyboard_file} < detect_keys.R > #{t.name}"].join ' '
  end
  desc 'Evalutate key detection accuracy with Gaussian models.'
  task :detect_by_gaussian => gaussian_output

  # Analyzes and computes features.
  analyzer = Analyzer.new train_file, [test_file]
  analyzer.analyze_training_data
  analyzer.analyze_testing_data

  train_test_set = {train: train_file, test: test_file}
  train_test_set.each do |type, file|
    arff = File.join 'out', 'analysis', "#{File.basename file}-2c.arff"
    libsvm_out = arff.sub /\.arff$/, '.libsvm'
    file libsvm_out => ['out/analysis', arff] do |t|
      sh "./ruby/format.rb -s 2,3,4 < #{arff} > #{t.name}"
    end
    desc 'Convert arff file to libsvm file.'
    task :convert => libsvm_out
  end

  train_test_arff = train_test_set.each_with_object({}) {
        |(k, v), h| h[k] = File.join 'out', 'analysis',
                                     "#{File.basename v}-2c.arff" }

  train_test_libsvm = train_test_set.each_with_object({}) {
        |(k, v), h| h[k] = File.join 'out', 'analysis',
                                      "#{File.basename v}-2c.libsvm" }

  classifiers.each do |c|
    trial = Trial.new train_test_arff[:train], c, '-H -B', [2]
    trial.train_test train_test_arff[:test]
    trial.test train_test_arff[:train]
  end

  svm_trial = SvmTrial.new train_test_libsvm[:train], '-h 0 -b 1'
  svm_trial.train
  svm_trial.test train_test_libsvm[:test], '-b 1'

  train_gaussian = File.join 'out', 'analysis',
      "#{File.basename train_file}-gaussians"
  file train_gaussian => ['out/analysis', train_file, keyboard_table] do |t|
    sh ["R --no-save --slave --args #{train_file} #{keyboard_table}",
        "< ./compute_gaussians.R > #{t.name}"].join ' '
  end
  desc 'Compute Gaussian spatial models.'
  task :compute_gaussians => train_gaussian

  timewindow_train_arff = File.join 'out', 'analysis',
                        "#{File.basename train_file}-timewindow.arff"
  timewindow_train_libsvm = timewindow_train_arff.sub /.arff$/, '.libsvm'
  pred_result = File.join 'out', 'weka',
      "#{File.basename train_file}-2c-LibSVM2H-B.test-pred.table"
  file timewindow_train_arff  => [train_file, pred_result] do |t|
    cmd = ['R --no-save --slave --args',
           "#{train_file} #{pred_result} #{t.name}",
           "#{timewindow_train_libsvm} < ./compute_timewindow_features.R"]
    sh cmd.join ' '
  end
  task :timewindow => timewindow_train_arff

  classifiers.each do |c|
    trial = Trial.new timewindow_train_arff, c, '-H'
    trial.train_cv
  end

  svm_trial = SvmTrial.new timewindow_train_libsvm, '-b 1'
  svm_trial.train

  singletap_model = File.join 'out', 'libsvm',
                    "#{File.basename train_file}-2ch-0-b-1.model"
  singletap_range = File.join 'out', 'analysis',
                              "#{File.basename train_file}.range"
  timewindow_model = File.join 'out', 'libsvm',
                     "#{File.basename train_file}-timewindowb-1.model"
  input = test_file
  log = File.join 'out', 'log', "#{File.basename input}"
  basename = File.basename train_file
  data_set = {
    singletap_attr_range: File.join('out', 'analysis', "#{basename}.range"),
    posture_singletap_model: File.join('out', 'libsvm', "#{basename}-2ch-0-b-1.model"),
    posture_timewindow_model: File.join('out', 'libsvm', "#{basename}-timewindowb-1.model"),
    keyboard_layout: keyboard_file, spatial_model: train_gaussian}

  simulation = Simulation.new data_set, test_file
  simulation.run_sim

  if type == 'salt'
    task :push_galaxy do |t|
      push data_set
    end

    task :copy_salt do |t|
      copy_dataset data_set
    end

  else
    task :push_nexus do |t|
      push data_set
    end
  end
end

task :test_r do |t|
  sh 'R --no-save --slave < ./test/testdriver.R'
end

task :default => :process_raw

# Tests
task :test_process_raw do |t|
  sh 'test/test_process_raw.rb'
end

task :test_keyboard do |t|
  sh 'test/test_keyboard.rb'
end

task :test_process_letters do |t|
  sh 'test/test_process_letters.rb'
end
desc 'Run tests on ruby scripts.'
task :test_ruby => [:test_process_raw, :test_keyboard, :test_process_letters]
