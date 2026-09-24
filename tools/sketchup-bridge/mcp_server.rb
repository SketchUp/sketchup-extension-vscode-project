# MCP server giving Claude Code tools that work in SketchUp through the bridge
# (server.rb): `evaluate_ruby` runs code, and `run_tests` runs TestUp tests.
# Claude Code starts it from .mcp.json and talks to it over stdio.
#
# Implements just the part of MCP this needs, so that it runs with any Ruby 2.7
# or newer on PATH and needs no gems.

require 'json'
require_relative 'client'

module SketchUpBridge
  module MCPServer

    # Used when the client doesn't ask for a particular version.
    PROTOCOL_VERSION = '2025-06-18'

    # Loaded into SketchUp by `run_tests`.
    TESTUP_RUNNER = File.expand_path('testup_runner.rb', __dir__)

    EVALUATE_RUBY = {
      name: 'evaluate_ruby',
      description: <<~TEXT,
        Evaluate Ruby code in the running SketchUp instance. Returns the value of
        the last expression, as `inspect` shows it, preceded by anything the code
        printed.

        The code runs at top level on SketchUp's main thread, with the full
        SketchUp Ruby API available, like the Ruby Console. Local variables
        persist between calls. SketchUp is frozen until the code finishes, so
        avoid anything long-running or interactive, such as UI.messagebox.

        Wrap changes to the model in model.start_operation(name, true) and
        model.commit_operation, so that they are a single step the user can undo.
      TEXT
      inputSchema: {
        type: 'object',
        properties: {
          code: { type: 'string', description: 'The Ruby code to evaluate.' }
        },
        required: ['code']
      }
    }.freeze

    RUN_TESTS = {
      name: 'run_tests',
      description: <<~TEXT,
        Run TestUp tests in the running SketchUp instance, and report which
        failed, with their messages and locations.

        Tests run in the active model, and many clear it first. So this refuses
        to run while the model has unsaved changes, unless the only changes
        since the previous run came from the tests. If it refuses, ask the user
        before passing discard_model_changes.

        Test files are loaded again on every run, but the extension code they
        test is not. After changing the extension, pass its folder in `reload`.
      TEXT
      inputSchema: {
        type: 'object',
        properties: {
          suite: {
            type: 'string',
            description: 'The test suite: the folder holding the TC_*.rb files. Relative paths are relative to the project.'
          },
          tests: {
            type: 'array', items: { type: 'string' },
            description: 'Test cases or single tests to run, such as "TC_Main" or "TC_Main#test_create_cube". ' \
                         'The namespace can be left out. Runs the whole suite when omitted.'
          },
          reload: {
            type: 'array', items: { type: 'string' },
            description: 'Files or folders of extension code to load again before running, such as ' \
                         '"src/ex_hello_cube". Folders are searched for .rb files recursively.'
          },
          seed: {
            type: 'integer',
            description: 'Minitest seed, to repeat the test order of an earlier run. Random when omitted.'
          },
          discard_model_changes: {
            type: 'boolean',
            description: 'Run even though the model has unsaved changes, which the tests may throw away.'
          }
        },
        required: ['suite']
      }
    }.freeze

    TOOLS = [EVALUATE_RUBY, RUN_TESTS].freeze

    def self.run
      $stdin.binmode
      $stdout.binmode
      $stdout.sync = true

      $stdin.each_line do |line|
        next if line.strip.empty?

        reply = begin
          handle(JSON.parse(line.force_encoding(Encoding::UTF_8)))
        rescue JSON::ParserError => error
          { jsonrpc: '2.0', id: nil, error: { code: -32_700, message: error.message } }
        end
        $stdout.write("#{JSON.generate(reply)}\n") if reply
      end
    end

    # Returns the reply to send, or nil for notifications, which get none.
    def self.handle(message)
      return nil unless message.key?('id')

      params = message['params'] || {}
      result = case message['method']
               when 'initialize'
                 {
                   protocolVersion: params['protocolVersion'] || PROTOCOL_VERSION,
                   capabilities: { tools: {} },
                   serverInfo: { name: 'sketchup-bridge', version: '1.0.0' }
                 }
               when 'ping'
                 {}
               when 'tools/list'
                 { tools: TOOLS }
               when 'tools/call'
                 arguments = params['arguments'] || {}
                 case params['name']
                 when EVALUATE_RUBY[:name] then call_tool { evaluate_ruby(arguments) }
                 when RUN_TESTS[:name] then call_tool { run_tests(arguments) }
                 else return error_reply(message, -32_602, "Unknown tool: #{params['name']}")
                 end
               else
                 return error_reply(message, -32_601, "Method not found: #{message['method']}")
               end
      { jsonrpc: '2.0', id: message['id'], result: result }
    end

    def self.error_reply(message, code, text)
      { jsonrpc: '2.0', id: message['id'], error: { code: code, message: text } }
    end

    # The block returns the text for the tool result, and whether it's an error.
    def self.call_tool
      text, error = yield
      tool_result(text, error: error)
    rescue NotRunning => error
      tool_result(error.message, error: true)
    rescue StandardError => error
      tool_result("Could not talk to the SketchUp bridge: #{error.class}: #{error.message}", error: true)
    end

    def self.tool_result(text, error:)
      { content: [{ type: 'text', text: text }], isError: error }
    end

    def self.evaluate_ruby(arguments)
      response = SketchUpBridge.evaluate(arguments['code'].to_s)
      text = response['output'].to_s
      if response['success']
        text += "=> #{response['result']}"
      else
        text += error_text(response)
      end
      [text, !response['success']]
    end

    def self.run_tests(arguments)
      options = {
        'suite' => expand_path(arguments['suite'].to_s),
        'tests' => arguments['tests'] || [],
        'reload' => (arguments['reload'] || []).map { |path| expand_path(path) },
        'seed' => arguments['seed'],
        'discard_model_changes' => arguments['discard_model_changes'] == true
      }
      code = "load #{TESTUP_RUNNER.dump}\n" \
             "SketchUpBridge::TestUpRunner.run(JSON.parse(#{JSON.generate(options).dump}))"
      response = SketchUpBridge.evaluate(code)
      return [error_text(response), true] unless response['success']

      report = begin
        JSON.parse(response['output'])
      rescue JSON::ParserError
        return ["Unexpected output from the test runner:\n#{response['output']}", true]
      end
      return [report['refused'], true] if report['refused']
      return [[report['error'], *report['backtrace'], report['output']].compact.join("\n"), true] if report['error']

      [test_report(report), false]
    end

    # Relative to the project. On Windows, also accepts Git Bash style paths,
    # which Ruby would otherwise read as C:/c/Users/...
    def self.expand_path(path)
      path = path.sub(%r{\A/([a-zA-Z])(?=/|\z)}, '\1:') if Gem.win_platform?
      File.expand_path(path)
    end

    def self.test_report(report)
      counts = report['counts']
      summary = %w[passed failed error skipped].map { |state| "#{counts[state]} #{state}" if counts[state] }.compact
      lines = ["#{report['tests']} tests: #{summary.join(', ')} " \
               "(#{report['seconds']} s, seed #{report['seed']}, reloaded #{report['reloaded_files']} files)"]
      report['problems'].each do |problem|
        lines << ''
        lines << "#{problem['status'].upcase}: #{problem['test']}"
        problem['failures'].each do |failure|
          lines << "  #{failure['location']}"
          lines.concat(failure['message'].to_s.lines.map { |line| "  #{line.chomp}" })
        end
      end
      # TestUp's own output is noise when everything passed, but it includes
      # anything the tests printed, and warnings about test files that failed
      # to load.
      if report['tests'].zero? || report['problems'].any?
        lines << ''
        lines << 'Output:'
        lines << report['output']
      end
      lines.join("\n")
    end

    def self.error_text(response)
      ([response['error']] + response['backtrace'].map { |line| "  #{line}" }).join("\n")
    end

  end
end

SketchUpBridge::MCPServer.run
