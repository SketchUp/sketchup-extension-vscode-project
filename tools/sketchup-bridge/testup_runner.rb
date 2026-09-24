# Runs TestUp tests inside SketchUp, for the `run_tests` tool in mcp_server.rb.
#
# mcp_server.rb `load`s this file through the bridge before every run, so
# changes to it take effect without restarting SketchUp. The result is written
# to $stdout as JSON, and everything else the run prints is captured, so that
# the JSON is the only output the bridge returns.

require 'json'
require 'stringio'

module SketchUpBridge
  module TestUpRunner

    # Notices changes to the model made after a test run: by the user, or by
    # code sent through the bridge. Changes the tests made themselves are fine
    # to throw away; anything else might be the user's work.
    class ChangeTracker < Sketchup::ModelObserver

      attr_accessor :changed

      def onTransactionCommit(_model)
        @changed = true
      end

      def onTransactionUndo(_model)
        @changed = true
      end

      def onTransactionRedo(_model)
        @changed = true
      end

    end

    # @param [Hash] options
    #   "suite" - absolute path of the test suite folder.
    #   "tests" - test cases or tests to run: `TC_Foo`, `TC_Foo#test_bar`, with
    #             or without their namespace. All tests when empty.
    #   "reload" - absolute paths of files or folders to `load` first.
    #   "seed" - Minitest seed. Random when not given.
    #   "discard_model_changes" - run even if the model has unsaved changes.
    def self.run(options)
      output = StringIO.new
      stdout = $stdout
      stderr = $stderr
      $stdout = output
      $stderr = output
      begin
        result = run_suite(options)
      rescue StandardError, ScriptError => error
        result = { error: "#{error.class}: #{error.message}", backtrace: error.backtrace.first(10) }
      ensure
        $stdout = stdout
        $stderr = stderr
      end
      result[:output] = output.string
      $stdout.write(JSON.generate(result))
      nil
    end

    def self.run_suite(options)
      return { error: 'TestUp is not loaded in this SketchUp.' } unless defined?(TestUp::API)

      suite_path = options['suite']
      return { error: "No such test suite folder: #{suite_path}" } unless File.directory?(suite_path)

      model = Sketchup.active_model
      unless options['discard_model_changes'] || safe_to_change?(model)
        return {
          refused: 'The model has unsaved changes that were not made by a previous test run. ' \
                   'Tests can clear the model, so they were not run. Save the model, or pass ' \
                   'discard_model_changes if the changes can be lost.'
        }
      end

      reloaded = reload(options['reload'] || [])

      suite = TestUp::API.discover_tests([suite_path]).first
      return { error: "No test cases found in #{suite_path}" } if suite.nil? || suite.test_cases.empty?

      patterns = resolve(suite, options['tests'] || [])
      return patterns if patterns.is_a?(Hash) # An error.

      seed = (options['seed'] || rand(1..0xFFFF)).to_i
      started = Time.now
      TestUp::API.run_tests(patterns, title: suite.title, path: suite_path, options: { ui: true, seed: seed })
      seconds = Time.now - started

      track(Sketchup.active_model)
      summarize(TestUp::Reporter.results, seed, seconds, reloaded)
    end

    # Loads extension code again, so the tests run against the latest source.
    # Folders are searched recursively for .rb files.
    def self.reload(paths)
      files = paths.flat_map do |path|
        File.directory?(path) ? Dir.glob(File.join(path, '**', '*.rb')).sort : [path]
      end
      verbose = $VERBOSE
      $VERBOSE = nil # Silence warnings about redefined methods and constants.
      files.each { |file| load(file) }
      files.size
    ensure
      $VERBOSE = verbose
    end

    # Turns the requested names into the patterns TestUp expects: full test case
    # names, followed by `#` to run the whole case or `#test_name` for one test.
    # A pattern that matches nothing makes TestUp silently run no tests, so every
    # name is checked against what the suite contains.
    def self.resolve(suite, requested)
      return suite.test_cases.map { |test_case| "#{test_case.title}#" } if requested.empty?

      requested.map do |name|
        case_name, test_name = name.split('#', 2)
        matches = suite.test_cases.select do |test_case|
          test_case.title == case_name || test_case.title.end_with?("::#{case_name}")
        end
        if matches.size != 1
          problem = matches.empty? ? 'No test case matches' : 'More than one test case matches'
          return { error: "#{problem} `#{name}`. Test cases in this suite: " \
                          "#{suite.test_cases.map(&:title).join(', ')}" }
        end

        test_case = matches.first
        if test_name && !test_name.empty?
          tests = test_case.tests.map(&:title)
          unless tests.include?(test_name)
            return { error: "#{test_case.title} has no test `#{test_name}`. Its tests: #{tests.join(', ')}" }
          end
        end
        "#{test_case.title}##{test_name}"
      end
    end

    def self.safe_to_change?(model)
      return true unless model.modified?

      @model.equal?(model) && !@tracker.changed
    end

    def self.track(model)
      unless @model.equal?(model)
        @model&.remove_observer(@tracker) if @model&.valid?
        @tracker = ChangeTracker.new
        model.add_observer(@tracker)
        @model = model
      end
      @tracker.changed = false
    end

    def self.summarize(results, seed, seconds, reloaded)
      status = lambda do |result|
        if result[:passed] then 'passed'
        elsif result[:skipped] then 'skipped'
        elsif result[:error] then 'error'
        else 'failed'
        end
      end
      counts = Hash.new(0)
      problems = []
      results.each do |result|
        state = status.(result)
        counts[state] += 1
        next if state == 'passed'

        problems << {
          test: "#{result[:test_case_name]}##{result[:test_name]}",
          status: state,
          failures: result[:failures].map { |failure| { message: failure[:message], location: failure[:location] } }
        }
      end
      {
        tests: results.size, counts: counts, seed: seed, seconds: seconds.round(3),
        reloaded_files: reloaded, problems: problems
      }
    end

  end
end
