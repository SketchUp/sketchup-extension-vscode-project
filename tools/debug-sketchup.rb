# Helper script to launch SketchUp with Ruby debugging enabled.
#
#   ruby tools/debug-sketchup.rb <version> [port]
#
# The version may be given as either `2026` or `26`.
#
# SketchUp is launched with `-RubyStartup` pointing at
# tools/su_debug_bootstrap.rb, which starts the `debug` gem's server, and with
# the port passed via `-RubyStartupArg`. VSCode then attaches to it over the
# Debug Adapter Protocol. See DEBUGGING.md.
#
# Using `-RubyStartup` means nothing has to be installed into SketchUp's Plugins
# folder. Note that SketchUp runs the `-RubyStartup` file *after* it has loaded
# extensions, so this cannot be used to debug extension startup - see
# DEBUGGING.md for that case.
#
# Requires SketchUp 2024 or newer. For older versions use a commit from before
# this project dropped support for them; those need SURubyDebugger.dll/dylib and
# the `rdebug-ide` protocol instead.

OLDEST_SUPPORTED = 2024

# Avoid 7000: macOS AirPlay Receiver listens there, and 7000-7009 is the
# registered AFS range, so the debug server cannot bind it.
DEFAULT_PORT = '7150'

raw_version = ARGV[0].to_s
port = (ARGV[1] || ENV['RUBY_DEBUG_PORT'] || DEFAULT_PORT).to_s

if raw_version.empty?
  warn 'Usage: ruby tools/debug-sketchup.rb <version> [port]'
  exit(1)
end

# Accept both `2026` and `26`.
year = raw_version.length <= 2 ? "20#{raw_version}" : raw_version
version = year.to_i

if version < OLDEST_SUPPORTED
  warn "SketchUp #{year} is not supported. SketchUp #{OLDEST_SUPPORTED} or newer " \
       'is required, because older versions do not bundle the `debug` gem.'
  exit(1)
end

bootstrap = File.expand_path('su_debug_bootstrap.rb', __dir__)
unless File.exist?(bootstrap)
  warn "Could not find the debug bootstrap at: #{bootstrap}"
  exit(1)
end

mac = RUBY_PLATFORM.include?('darwin')

if mac
  # The installer default is /Applications, but macOS also allows a per-user
  # install under ~/Applications, which is what a locked down machine may end up
  # with. Prefer the system location when both exist.
  candidates = [
    "/Applications/SketchUp #{year}/SketchUp.app",
    File.expand_path("~/Applications/SketchUp #{year}/SketchUp.app")
  ]
  sketchup = candidates.find { |path| File.exist?(path) } || candidates.first
else
  program_files_32 = ENV['ProgramFiles(x86)'] || 'C:/Program Files (x86)'
  program_files_64 = ENV['ProgramW6432'] || 'C:/Program Files'

  relative = "SketchUp/SketchUp #{year}"
  # SketchUp 2025 and newer use a nested folder structure.
  relative = File.join(relative, 'SketchUp') if version >= 2025
  relative = File.join(relative, 'SketchUp.exe')

  sketchup_64 = File.join(program_files_64, relative)
  sketchup_32 = File.join(program_files_32, relative)
  sketchup = File.exist?(sketchup_64) ? sketchup_64 : sketchup_32
end

unless File.exist?(sketchup)
  warn "Could not find SketchUp #{year} at: #{sketchup}"
  exit(1)
end

puts "Launching SketchUp #{year} with the debugger listening on port #{port}."
puts 'Attach with the "Attach to SketchUp" launch configuration.'

# The port is passed in Ruby's ARGV via -RubyStartupArg rather than in the
# environment, so it does not matter how SketchUp gets launched.
startup_arg = "su_debug:port=#{port}"

# Pass arguments as an array so paths containing spaces need no quoting.
if mac
  # SketchUp has to be launched through `open`. Running the binary inside the app
  # bundle directly does not run the `-RubyStartup` file at all. Arguments must
  # come after `--args`, or `open` interprets them itself, and `-n` forces a new
  # instance - without it `open` just activates an already running SketchUp and
  # silently drops the arguments.
  #
  # DYLD_LIBRARY_PATH works around SKEXT-5430. The bundled debug gem's native
  # extension is linked against a libruby path that SketchUp's packaging removes,
  # so it fails to load unless dyld is pointed at the framework directory, which
  # holds a matching `libruby.<major>.<minor>.dylib` symlink. Using
  # `Versions/Current` keeps this independent of the Ruby version. That directory
  # contains only `Ruby` and those symlinks, so nothing else can be shadowed.
  #
  # It has to be passed via `--env` because `open` strips `DYLD_*` from the
  # inherited environment. `--env` requires macOS 13 or newer.
  #
  # Wait for `open` with `system` rather than letting it run detached. `open`
  # returns as soon as it has handed the request to LaunchServices, so there is
  # nothing to gain from backgrounding it - and doing so is a race: this script
  # would exit immediately, and a caller that reaps the process group when the
  # command finishes, such as a VSCode task, then kills `open` before it ever
  # starts SketchUp. Nothing launches and nothing reports an error. Once
  # LaunchServices has taken over, SketchUp is reparented to launchd and is
  # unaffected by anything happening to this script.
  ruby_framework = File.join(sketchup, 'Contents/Frameworks/Ruby.framework/Versions/Current')
  launched = system('open', '-n', '-a', sketchup,
                    '--env', "DYLD_LIBRARY_PATH=#{ruby_framework}",
                    '--args', '-RubyStartup', bootstrap, '-RubyStartupArg', startup_arg)
  unless launched
    warn "`open` failed to launch SketchUp #{year}."
    exit(1)
  end
else
  spawn(sketchup, '-RubyStartup', bootstrap, '-RubyStartupArg', startup_arg)
end
