# MCP server giving Claude Code an `evaluate_ruby` tool that runs code in
# SketchUp, through the bridge (server.rb). Claude Code starts it from .mcp.json
# and talks to it over stdio.
#
# Implements just the part of MCP this needs, so that it runs with any Ruby 2.7
# or newer on PATH and needs no gems.

require 'json'
require_relative 'client'

module SketchUpBridge
  module MCPServer

    # Used when the client doesn't ask for a particular version.
    PROTOCOL_VERSION = '2025-06-18'

    TOOL = {
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
                 { tools: [TOOL] }
               when 'tools/call'
                 return error_reply(message, -32_602, "Unknown tool: #{params['name']}") unless params['name'] == TOOL[:name]

                 call_tool(params.dig('arguments', 'code').to_s)
               else
                 return error_reply(message, -32_601, "Method not found: #{message['method']}")
               end
      { jsonrpc: '2.0', id: message['id'], result: result }
    end

    def self.error_reply(message, code, text)
      { jsonrpc: '2.0', id: message['id'], error: { code: code, message: text } }
    end

    def self.call_tool(code)
      response = SketchUpBridge.evaluate(code)
      text = response['output'].to_s
      if response['success']
        text += "=> #{response['result']}"
      else
        text += ([response['error']] + response['backtrace'].map { |line| "  #{line}" }).join("\n")
      end
      tool_result(text, error: !response['success'])
    rescue NotRunning => error
      tool_result(error.message, error: true)
    rescue StandardError => error
      tool_result("Could not talk to the SketchUp bridge: #{error.class}: #{error.message}", error: true)
    end

    def self.tool_result(text, error:)
      { content: [{ type: 'text', text: text }], isError: error }
    end

  end
end

SketchUpBridge::MCPServer.run
