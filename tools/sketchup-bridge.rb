# SketchUp eval bridge - TCP server for remote Ruby evaluation.
# Loaded via: SketchUp.exe -RubyStartup "path/to/sketchup-bridge.rb"
#
# Listens on 127.0.0.1:7200 and evaluates received Ruby code on the
# main thread (required for SketchUp API access).

require 'json'
require 'socket'
require 'stringio'
require 'thread'

module SketchUpBridge

  PORT = 7200
  POLL_INTERVAL = 0.05 # seconds
  MAX_RESULT_LENGTH = 50_000

  @queue = Queue.new
  @server = nil

  def self.start
    @server = TCPServer.new('127.0.0.1', PORT)

    Thread.new do
      loop do
        client = @server.accept
        Thread.new(client) { |conn| receive(conn) }
      rescue => e
        $stderr.puts("SketchUpBridge: accept error: #{e.message}")
      end
    end

    UI.start_timer(POLL_INTERVAL, true) { process_queue }
    puts "SketchUpBridge: listening on port #{PORT}"
  rescue Errno::EADDRINUSE
    puts "SketchUpBridge: port #{PORT} already in use. Bridge may already be running."
  end

  def self.receive(conn)
    code = conn.read
    @queue.push([code, conn])
  rescue => e
    conn.close rescue nil
  end

  def self.process_queue
    until @queue.empty?
      code, conn = @queue.pop(true)
      begin
        response = evaluate(code)
        conn.write(JSON.generate(response))
      rescue => e
        # Connection may have been closed by client.
      ensure
        conn&.close rescue nil
      end
    end
  rescue ThreadError
    # Queue drained between empty? check and pop.
  end

  def self.evaluate(code)
    stdout_capture = StringIO.new
    original_stdout = $stdout
    $stdout = stdout_capture

    begin
      result = TOPLEVEL_BINDING.eval(code, '(bridge)', 1)
      {
        success: true,
        result: truncate(result.inspect),
        stdout: stdout_capture.string,
      }
    rescue Exception => e
      {
        success: false,
        error: "#{e.class}: #{e.message}",
        backtrace: e.backtrace&.first(10),
        stdout: stdout_capture.string,
      }
    ensure
      $stdout = original_stdout
    end
  end

  def self.truncate(str)
    return str if str.length <= MAX_RESULT_LENGTH

    str[0, MAX_RESULT_LENGTH] + "\n... (truncated)"
  end

end

SketchUpBridge.start
