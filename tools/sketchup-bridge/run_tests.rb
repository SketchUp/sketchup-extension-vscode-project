# The part of the `run_tests` tool (mcp_server.rb) that runs inside SketchUp.
# It runs the tests with TestUp's API, and returns the results.
#
# mcp_server.rb `load`s this file through the bridge before every run, so
# changes to it take effect without restarting SketchUp. The result is written
# to $stdout as JSON, and everything else the run prints is captured, so that
# the JSON is the only output the bridge returns.

require 'json'
require 'stringio'

module SketchUpBridge
  module RunTests

    # The first version with the `quiet` option, which returns results from
    # `TestUp::API.run_tests` outside of TestUp's window, and which raises an
    # error for test names that match nothing.
    TESTUP_VERSION = '2.6.0'

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
      error = check_testup
      return { error: error } if error

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

      tests = options['tests'] || []
      tests = tests.empty? ? suite.test_cases.map { |test_case| "#{test_case.title}#" } : full_names(suite, tests)

      seed = (options['seed'] || rand(1..0xFFFF)).to_i
      results = nil
      started = Time.now
      begin
        TestUp::API.run_tests(tests, title: suite.title, path: suite_path,
                                     options: { quiet: true, seed: seed }) { |test_suite| results = test_suite }
      rescue ArgumentError => error
        # Names that match no test. The message lists the suite's test cases.
        return { error: error.message }
      end
      seconds = Time.now - started

      track(Sketchup.active_model)
      summarize(results, seed, seconds, reloaded)
    end

    def self.check_testup
      return 'TestUp is not loaded in this SketchUp.' unless defined?(TestUp::API)

      version = TestUp::PLUGIN_VERSION
      return nil if Gem::Version.new(version) >= Gem::Version.new(TESTUP_VERSION)

      "run_tests needs TestUp #{TESTUP_VERSION} or newer, and this SketchUp has TestUp #{version}."
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

    # TestUp needs the full name of a test case, including its namespace. This
    # adds the namespace to a name given without one, when exactly one test
    # case in the suite has that name. Anything else is passed on as it is, and
    # TestUp reports names that match nothing.
    def self.full_names(suite, tests)
      tests.map do |name|
        case_name, test_name = name.split('#', 2)
        matches = suite.test_cases.map(&:title).select { |title| title.end_with?("::#{case_name}") }
        case_name = matches.first if matches.size == 1
        "#{case_name}##{test_name}"
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

    # @param [TestUp::Report::TestSuite] results
    def self.summarize(results, seed, seconds, reloaded)
      counts = Hash.new(0)
      problems = []
      results.test_cases.each do |test_case|
        test_case.tests.each do |test|
          result = test.result
          state = if result.passed then 'passed'
                  elsif result.skipped then 'skipped'
                  elsif result.error then 'error'
                  else 'failed'
                  end
          counts[state] += 1
          next if state == 'passed'

          problems << {
            test: "#{test_case.title}##{test.title}",
            status: state,
            failures: result.failures.map { |failure| { message: failure.message, location: failure.location } }
          }
        end
      end
      {
        tests: counts.values.sum, counts: counts, seed: seed, seconds: seconds.round(3),
        reloaded_files: reloaded, problems: problems
      }
    end

  end
end
