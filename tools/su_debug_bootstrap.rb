# Bootstrap the `debug` gem (ruby/debug) inside SketchUp so VSCode can attach
# over TCP using the Debug Adapter Protocol.
#
# Normally there is nothing to install: tools/debug-sketchup.rb passes this file
# to SketchUp with the `-RubyStartup` command line switch, and the port with
# `-RubyStartupArg`.
#
# SketchUp runs the `-RubyStartup` file after it has loaded extensions though, so
# to debug extension startup, copy or symlink this file into SketchUp's Plugins
# folder instead and add `wait=1` to the options:
#
#   Windows: %APPDATA%/SketchUp/SketchUp <year>/SketchUp/Plugins
#   macOS:   ~/Library/Application Support/SketchUp <year>/SketchUp/Plugins
#
# Configured either by SketchUp's `-RubyStartupArg`, which arrives in Ruby's ARGV:
#
#   -RubyStartupArg "su_debug:port=7150,wait=1"
#
# or by environment variables (RUBY_DEBUG_PORT, RUBY_DEBUG_WAIT). The ARGV form is
# preferred because it does not depend on the environment surviving however
# SketchUp was launched. Note that SketchUp only honours the last
# `-RubyStartupArg`, so use the environment variables instead if something else
# already needs that switch (TestUp does).
#
# It is inert unless a port is configured, so it is safe to leave installed
# permanently.
#
# Requires the `debug` gem in SketchUp's Ruby. SketchUp 2024 and newer bundle it,
# with its compiled native extension. SketchUp 2023 and older do not, which is why
# this project targets 2024 as its oldest version.

require 'tmpdir'

module SketchUpDebugBootstrap

  # Where to write diagnostics. SketchUp has no stderr console on Windows, so a
  # log file is the only reliable way to see what happened during startup.
  LOG_PATH = File.join(Dir.tmpdir, 'sketchup_debug_bootstrap.log')

  # Prefix identifying our own `-RubyStartupArg` value in ARGV.
  ARGV_PREFIX = 'su_debug:'

  # How often to let the Ruby VM schedule the debugger's background threads.
  PUMP_INTERVAL = 0.1

  # Directory holding a stub `irb/completion`, for builds that ship no irb.
  IRB_STUB_DIR = 'irb_stub'

  def self.log(message)
    File.open(LOG_PATH, 'a') { |file| file.puts("#{Time.now.strftime('%H:%M:%S')} #{message}") }
  rescue StandardError
    nil
  end

  # Parses `su_debug:port=7150,wait=1` out of ARGV. ARGV is shared with the rest
  # of SketchUp, so it is only read, never modified.
  def self.argv_options
    argument = ARGV.find { |value| value.to_s.downcase.start_with?(ARGV_PREFIX) }
    return {} if argument.nil?

    argument[ARGV_PREFIX.length..-1].to_s.split(',').each_with_object({}) do |pair, options|
      key, value = pair.split('=', 2)
      options[key.to_s.strip.downcase] = value.to_s.strip
    end
  end

  # Load the debugger with only SketchUp's own gem paths visible.
  #
  # RubyGems always searches Gem.user_dir (~/.gem/ruby/<abi>), and SketchUp keeps
  # it on GEM_PATH. Anything installed there for the matching Ruby version leaks
  # into SketchUp - most commonly a per-machine Ruby set up for Ruby LSP that
  # happens to share SketchUp's Ruby version, dropping irb/reline/rbs/prism and
  # friends into that directory. RubyGems then activates those newer versions to
  # satisfy the debug gem's dependencies (debug -> irb -> prism, ...), and a
  # single missing transitive gem makes `require 'debug/session'` fail outright.
  #
  # Dropping the user dir for the duration of the require lets SketchUp's bundled
  # debug/irb/reline and Ruby's default gems win. The paths are restored
  # afterwards so nothing else in the session is affected - everything the debug
  # gem needs at attach time is loaded here via preload_dap_server.
  def self.with_sketchup_gems_only
    home = Gem.paths.home
    original = Gem.paths.path.dup
    user_dir = File.expand_path(Gem.user_dir)
    Gem.use_paths(home, original.reject { |path| File.expand_path(path) == user_dir })
    log("loading debugger with gem paths: #{Gem.paths.path.join(File::PATH_SEPARATOR)}")
    yield
  ensure
    Gem.use_paths(home, original)
  end

  def self.start
    options = argv_options
    port = options['port']
    port = ENV['RUBY_DEBUG_PORT'] if port.nil? || port.empty?
    return if port.nil? || port.empty?

    wait = options['wait'] == '1' || ENV['RUBY_DEBUG_WAIT'] == '1'

    log("starting: port=#{port} wait=#{wait} SketchUp=#{Sketchup.version} Ruby=#{RUBY_VERSION}")

    loaded = with_sketchup_gems_only do
      begin
        require 'debug/session'
      rescue LoadError => error
        log("the `debug` gem is not available in this SketchUp's Ruby: #{error.message}")
        next false
      end

      # The debug gem only auto-enables local filesystem path mapping for Unix
      # domain sockets. For TCP it leaves the mapping unset, and then rejects every
      # `setBreakpoints` request with "<path> is not available" - which is why
      # breakpoints set in the editor never bind. Setting this makes the debuggee
      # treat the client as sharing its filesystem, which it does.
      DEBUGGER__::CONFIG[:local_fs_map] = true

      preload_dap_server
      true
    end
    return unless loaded

    # Passing the port explicitly rather than relying on RUBY_DEBUG_PORT also
    # forces TCP instead of a Unix domain socket. The host defaults to
    # CONFIG[:host], which is 127.0.0.1, so this never listens beyond loopback.
    # Always nonstop: the gem's own initial-suspend mode sets a one-shot
    # breakpoint on the line following the `require` above, which here is a
    # rescue clause that never runs, so it cannot be relied on.
    DEBUGGER__.open(port: port.to_s, nonstop: true)
    log("listening on port #{port}")

    # Must be running before the wait below, and before SketchUp goes idle.
    start_thread_pump

    wait_for_client if wait
  rescue Exception => error
    log("failed: #{error.class}: #{error.message}")
    log(error.backtrace.first(10).join("\n"))
  end

  # Load the debug gem's DAP server now rather than letting it be required lazily
  # when a client connects.
  #
  # `server_dap.rb` opens with an unconditional `require 'irb/completion'`, and
  # SketchUp's macOS builds ship no irb library (SKEXT-5431). Left to itself the
  # LoadError surfaces inside the debug gem's reader thread part way through the
  # handshake, killing that thread: the client's connection is accepted and then
  # never answered, which looks exactly like the GVL problem the thread pump below
  # solves. Loading it here means a missing irb is reported in this log instead,
  # and a failure cannot happen later during an attach.
  def self.preload_dap_server
    stub = nil

    begin
      require 'irb/completion'
    rescue LoadError
      stub = File.join(__dir__, IRB_STUB_DIR)
      if Dir.exist?(stub)
        $LOAD_PATH.unshift(stub)
        log('no irb library in this Ruby; using the bundled irb/completion stub')
      else
        stub = nil
        log("no irb library in this Ruby and no stub at #{File.join(__dir__, IRB_STUB_DIR)}; " \
            'debugger clients will not be able to attach')
      end
    end

    begin
      require 'debug/server_dap'
      log('DAP server loaded')
    ensure
      # Never leave $LOAD_PATH modified - it is shared with every extension.
      $LOAD_PATH.delete(stub) if stub
    end
  end

  # SketchUp only runs the Ruby VM while it is executing Ruby code. While
  # SketchUp sits idle in its own event loop it holds the GVL, so the debug
  # gem's server threads are never scheduled and the debugger appears to hang -
  # it accepts the TCP connection but never answers a single DAP request.
  # A repeating timer that yields to the scheduler keeps those threads alive.
  def self.start_thread_pump
    @pump_timer = UI.start_timer(PUMP_INTERVAL, true) { Thread.pass }
    log('thread pump started')
  end

  # Block SketchUp here until a debugger attaches, so that extensions loading
  # after this file can be debugged as they load. SketchUp will appear frozen
  # until you attach, and will resume when you continue from this breakpoint.
  def self.wait_for_client
    log('waiting for a debugger to attach...')
    binding.break # rubocop:disable Lint/Debugger
    log('debugger attached')
  end

end

SketchUpDebugBootstrap.start
