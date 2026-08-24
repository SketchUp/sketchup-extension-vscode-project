# Stub stand-in for the `irb/completion` that SketchUp's macOS Ruby does not ship.
#
# SketchUp's macOS builds install no irb library at all - the irb gem directory
# contains only `exe/irb`, with no `lib` - even though the default gemspec still
# declares the gem as installed. See SKEXT-5431.
#
# The `debug` gem's `server_dap.rb` opens with an unconditional
# `require 'irb/completion'`, so without this stub a Debug Adapter Protocol client
# can never attach: the require happens lazily when a client connects, and the
# resulting LoadError kills the debug gem's reader thread part way through the
# handshake. The client just sees a connection that is accepted and never answered.
#
# `server_dap.rb` uses irb for exactly one thing, the DAP `completions` request, so
# returning no completion candidates is enough to keep every other DAP feature -
# breakpoints, stepping, variable inspection, watch expressions - working normally.
# Expression evaluation in the Debug Console is unaffected; only its autocomplete
# suggestions are missing.
#
# Delete this file once SketchUp ships irb's library on macOS.

module IRB
  module InputCompletor

    # @return [Array<String>] always empty; see the file comment above
    def self.retrieve_completion_data(*_args, **_options)
      []
    end

  end
end
