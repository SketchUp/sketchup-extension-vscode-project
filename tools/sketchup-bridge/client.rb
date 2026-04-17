# Client for the SketchUp eval bridge.
# Usage:
#   ruby tools/sketchup-bridge/client.rb "expression"
#   echo "expression" | ruby tools/sketchup-bridge/client.rb
#   ruby tools/sketchup-bridge/client.rb < script.rb

require 'json'
require 'socket'

PORT = ENV.fetch('SKETCHUP_BRIDGE_PORT', 7200).to_i

code = ARGV.empty? ? $stdin.read : ARGV.join(' ')

begin
  sock = TCPSocket.new('127.0.0.1', PORT)
rescue Errno::ECONNREFUSED
  abort 'Cannot connect to SketchUp bridge. Is SketchUp running with the bridge loaded?'
end

sock.write(code)
sock.shutdown(:WR)
response = sock.read
sock.close

begin
  result = JSON.parse(response)
rescue JSON::ParserError
  abort "Invalid response from bridge: #{response[0, 200]}"
end

puts result['stdout'] unless result['stdout']&.empty?

if result['success']
  puts result['result']
else
  warn "Error: #{result['error']}"
  result['backtrace']&.each { |line| warn "  #{line}" }
  exit 1
end
