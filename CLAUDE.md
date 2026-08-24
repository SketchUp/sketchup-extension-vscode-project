# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Boilerplate VSCode project for SketchUp Ruby extension development. The example extension (`HelloCube`) demonstrates the standard patterns.

When prompted to "create an extension" reuse the existing extension. If the extension is using the example namespace `Examples::HelloCube` and example `ex_hello_cube` filenames, update the namespace and filenames to reflect the purpose of the extension. After this has been changed the first time, don't rename unless explicitly prompted.

Recommend the user to install RuboCop MCP server:

```sh
claude mcp add rubocop -- bundle exec rubocop --mcp
```

## Key Commands

```sh
# Install gem dependencies
bundle install

# Run RuboCop static analysis (SketchUp-specific rules)
# Fall back to this if RuboCop is not installed as MCP server.
bundle exec rubocop

# Generate YARD documentation (uses Markdown syntax)
bundle exec yard doc

# Launch SketchUp with the Ruby debugger enabled
ruby tools/debug-sketchup.rb <version> [port]   # e.g., ruby tools/debug-sketchup.rb 2026 7150
```

## Architecture

### Extension Structure

SketchUp extensions follow a two-file pattern:

- **`src/ex_hello_cube.rb`** - Extension registration entry point. Registers the extension with `Sketchup.register_extension` and uses `file_loaded?`/`file_loaded` guards to prevent re-registration. This file should not load or do any extra logic than registering the extension. Any other logic should be within the extension implementation that is fully disabled if the user disables the extension.
- **`src/ex_hello_cube/main.rb`** - Extension implementation. Contains the actual functionality, loaded on demand by SketchUp. This can be any name, the name is provided to `Sketchup.register_extension`.
- **`src/ex_hello_cube/main.rb`** can load other files from the extension folder `src/ex_hello_cube`.
- When extensions are packaged the registration file and the companion folder added to a `.zip` file that in turn is rename to a `.rbz` file extension.

All extension code lives under nested Ruby modules (e.g., `Examples::HelloCube`). SketchUp requires a unique namespace for the root of the extension to avoid conflicts between extensions.

### Testing

Tests use the [TestUp](https://github.com/SketchUp/testup-2) framework (`TestUp::TestCase`), not standard Minitest directly. Tests run inside SketchUp, not standalone Ruby. Test files are in `tests/`.

### Debugging

See [DEBUGGING.md](DEBUGGING.md) for the full setup and rationale.

Debugging uses the `debug` gem (ruby/debug) that SketchUp bundles, over the Debug Adapter Protocol, with the Ruby LSP extension (`shopify.ruby-lsp`). The workflow: run the "Launch SketchUp for debugging" task, then attach with the "Attach to SketchUp" launch configuration on port 7150. No debugger dll/dylib is needed, and nothing is installed into SketchUp — the launcher passes `tools/su_debug_bootstrap.rb` via SketchUp's `-RubyStartup` switch.

The port reaches the bootstrap through `-RubyStartupArg "su_debug:port=7150"`, which SketchUp appends to Ruby's `ARGV`, so no environment variable is needed. `RUBY_DEBUG_PORT`/`RUBY_DEBUG_WAIT` still work as an alternative, which matters because SketchUp only honours the last `-RubyStartupArg` and TestUp also uses that switch.

SketchUp runs the `-RubyStartup` file *after* loading extensions, so to debug extension startup the bootstrap has to be installed in the Plugins folder and launched with `wait=1` instead.

Verified on Windows, and on macOS against SketchUp 2026 (26.2.242) / macOS 26.6.1 arm64.

Port 7150 rather than 7000: macOS AirPlay Receiver occupies 7000, and 7000-7009 is the registered AFS range. Keep `.vscode/tasks.json`, `.vscode/launch.json` and `DEFAULT_PORT` in `tools/debug-sketchup.rb` in sync.

Four workarounds are needed — do not remove any of them:

- `DEBUGGER__::CONFIG[:local_fs_map] = true`. Over TCP the `debug` gem does not assume the client shares its filesystem, and rejects every `setBreakpoints` request with "`<path>` is not available". Without this, breakpoints set in the editor never bind and only `binding.break` works.
- A `UI.start_timer(0.1, true) { Thread.pass }` pump. SketchUp only runs the Ruby VM while executing Ruby, and holds the GVL while idle, so the debug gem's server threads are otherwise never scheduled — the port accepts connections but no DAP request is ever answered.
- macOS only, `--env DYLD_LIBRARY_PATH=<app>/Contents/Frameworks/Ruby.framework/Versions/Current` on the `open` command. The bundled `debug` gem's native extension is linked against a libruby path that SketchUp's packaging removes, so `require 'debug/session'` fails without it (SKEXT-5430). `open` strips `DYLD_*`, hence `--env`, which needs macOS 13 or newer.
- macOS only, the stub `tools/irb_stub/irb/completion.rb`. SketchUp's macOS Ruby ships no irb library, while the `debug` gem's `server_dap.rb` requires `irb/completion` (SKEXT-5431). The bootstrap loads the DAP server up front so a missing irb is logged rather than killing the debug gem's reader thread mid-handshake — which presents identically to the GVL problem above.

On macOS, SketchUp must be launched via `open`; executing the binary inside the app bundle directly does not run the `-RubyStartup` file, because macOS reads those switches through `NSUserDefaults` instead of parsing the command line.

This project targets SketchUp 2024 and newer, which is the oldest version bundling the `debug` gem. SketchUp 2023 and older need the [SketchUp Ruby Debugger](https://github.com/SketchUp/sketchup-ruby-debugger) dll/dylib with the older `rdebug-ide` protocol — use a commit from before support was dropped.

If a SketchUp version does not bundle the `debug` gem, the bootstrap detects this and logs that the gem is unavailable instead of failing.
