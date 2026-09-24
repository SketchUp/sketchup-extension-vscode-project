# Sends Ruby code to the bridge running inside SketchUp (server.rb).
#
# From a terminal:
#
#   ruby tools/sketchup-bridge/client.rb "Sketchup.active_model.title"
#   ruby tools/sketchup-bridge/client.rb < script.rb
#
# Also required by mcp_server.rb. Runs outside SketchUp, with any Ruby 2.7 or
# newer, and needs no gems.

require 'json'
require 'socket'

module SketchUpBridge

  HOST = '127.0.0.1'
  PORT = 7200 # Keep in sync with server.rb.

  class NotRunning < StandardError; end

  # Returns the bridge's response: a Hash with "success", "output", and either
  # "result", or "error" and "backtrace".
  def self.evaluate(code)
    socket = connect
    begin
      socket.write(code.encode(Encoding::UTF_8))
      socket.close_write
      JSON.parse(socket.read.force_encoding(Encoding::UTF_8))
    ensure
      socket.close
    end
  end

  def self.connect
    TCPSocket.new(HOST, PORT)
  rescue Errno::ECONNREFUSED
    raise NotRunning, "The SketchUp bridge is not running (nothing is listening on #{HOST}:#{PORT}). " \
                      'Start SketchUp with: ruby tools/debug-sketchup.rb <version> --bridge'
  end

end

if $PROGRAM_NAME == __FILE__
  code = ARGV.empty? ? $stdin.read : ARGV.join(' ')

  begin
    response = SketchUpBridge.evaluate(code)
  rescue SketchUpBridge::NotRunning => error
    abort(error.message)
  end

  print(response['output'])
  if response['success']
    puts(response['result'])
  else
    warn(response['error'])
    response['backtrace'].each { |line| warn("  #{line}") }
    exit(1)
  end
end
