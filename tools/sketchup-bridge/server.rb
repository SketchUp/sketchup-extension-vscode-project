# Runs Ruby code sent over TCP inside SketchUp, so that tools outside SketchUp
# can inspect and drive the running instance: Claude Code through mcp_server.rb,
# or client.rb from a terminal. See README.md.
#
# Started by `ruby tools/debug-sketchup.rb <version> --bridge`, which passes this
# file to SketchUp with the `-RubyStartup` switch.
#
# Protocol: connect to 127.0.0.1:7200, send the code, then half-close the
# connection. The server replies with a single JSON object and closes it.

require 'json'
require 'socket'
require 'stringio'

module SketchUpBridge

  PORT = 7200 # Keep in sync with client.rb.

  # How often to check for new connections and incoming data.
  POLL_INTERVAL = 0.05

  # Drop connections that haven't finished sending by then. Without a limit, a
  # client that never half-closes would be held open forever.
  REQUEST_TIMEOUT = 30

  # Longest result or output returned, in characters.
  MAX_TEXT_LENGTH = 50_000

  # Browsers can send requests to localhost too. Refusing anything that looks
  # like HTTP means a web page can't use the bridge to run code in SketchUp.
  HTTP_REQUEST = %r{\A[A-Z]+ \S+ HTTP/\d}

  Request = Struct.new(:socket, :buffer, :started)

  def self.start
    return if @server

    @server = TCPServer.new('127.0.0.1', PORT)
    @requests = []
    @busy = false
    UI.start_timer(POLL_INTERVAL, true) { poll }
    puts "SketchUp bridge: listening on 127.0.0.1:#{PORT}"
  rescue SystemCallError => error
    puts "SketchUp bridge: could not listen on port #{PORT}: #{error.message}"
  end

  # Everything happens on the main thread, from a timer, and never blocks.
  # SketchUp holds the GVL while it is idle, so a background thread accepting
  # connections only gets to run now and then - an earlier version built that
  # way took seconds to answer `1 + 1`. The SketchUp API has to be called from
  # the main thread in any case.
  def self.poll
    # A timer keeps firing while code it runs shows a modal dialog, such as
    # UI.messagebox. Don't start on another request in the middle of one.
    return if @busy

    begin
      @busy = true
      accept_connections
      @requests.reject! { |request| service(request) }
    rescue StandardError => error
      puts "SketchUp bridge: #{error.class}: #{error.message}"
    ensure
      @busy = false
    end
  end

  def self.accept_connections
    loop do
      socket = @server.accept_nonblock(exception: false)
      break if socket == :wait_readable

      @requests << Request.new(socket, String.new, Time.now)
    end
  end

  # Reads whatever has arrived, and responds once the client has finished
  # sending. Returns true when the request is done with.
  def self.service(request)
    loop do
      chunk = request.socket.read_nonblock(65_536, exception: false)
      case chunk
      when :wait_readable
        return false if Time.now - request.started < REQUEST_TIMEOUT

        request.socket.close
        return true
      when nil
        respond(request.socket, request.buffer)
        return true
      else
        request.buffer << chunk
      end
    end
  rescue SystemCallError, IOError
    request.socket.close
    true
  end

  def self.respond(socket, code)
    response = evaluate(code.force_encoding(Encoding::UTF_8))
    socket.write(JSON.generate(response))
  ensure
    socket.close
  end

  def self.evaluate(code)
    return failure('The request is not valid UTF-8.') unless code.valid_encoding?
    return failure('HTTP requests are not accepted.') if code.match?(HTTP_REQUEST)

    output = StringIO.new
    stdout = $stdout
    stderr = $stderr
    $stdout = output
    $stderr = output
    begin
      # Top level, like the Ruby Console, so local variables persist from one
      # request to the next.
      value = TOPLEVEL_BINDING.eval(code, '(bridge)', 1)
      { success: true, result: text(value.inspect), output: text(output.string) }
    rescue Exception => error # rubocop:disable Lint/RescueException
      # Exception rather than StandardError, to report syntax errors, and to
      # stop `exit` from closing SketchUp.
      failure("#{error.class}: #{error.message}", backtrace(error), output.string)
    ensure
      $stdout = stdout
      $stderr = stderr
    end
  end

  def self.failure(message, backtrace = [], output = '')
    { success: false, error: text(message), backtrace: backtrace, output: text(output) }
  end

  # The frames from the evaluated code, without the bridge's own below them.
  def self.backtrace(error)
    lines = error.backtrace || []
    lines.take_while { |line| !line.start_with?(__FILE__) }.first(20).map { |line| text(line) }
  end

  # JSON needs valid UTF-8, and a huge result helps nobody.
  def self.text(string)
    string = string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace).scrub
    return string if string.length <= MAX_TEXT_LENGTH

    "#{string[0, MAX_TEXT_LENGTH]}\n... (#{string.length - MAX_TEXT_LENGTH} more characters)"
  end

end

SketchUpBridge.start

# SketchUp runs only one -RubyStartup file, so when this is it, it also loads the
# debugger bootstrap. That does nothing unless it is given a debug port.
require_relative '../su_debug_bootstrap'
