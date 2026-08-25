# Debugging SketchUp Ruby extensions in VSCode

SketchUp is debugged with the modern Ruby debugger stack ([ruby/debug][ruby-debug]
over the [Debug Adapter Protocol][dap]) and the [Ruby LSP][ruby-lsp] extension.
No `SURubyDebugger.dll`/`.dylib` is needed, and breakpoints set in the editor
gutter work.

## Requirements

* SketchUp 2024 or newer. This is the oldest version that bundles the `debug`
  gem; for older versions use a commit from before this project dropped support
  for them, which used the [SketchUp Ruby Debugger][su-debugger] and the
  `rdebug-ide` protocol.
* The [Ruby LSP][ruby-lsp] VSCode extension (`shopify.ruby-lsp`). It contributes
  the `ruby_lsp` debug type; without it VSCode reports *"Configured debug type
  'ruby_lsp' is not supported"*. Reload the window after installing it.
* A Ruby installation on `PATH`, used only to run the launcher script.

Ruby LSP also wants a Ruby of its own to run its language server in, and will
report errors if it cannot find one. That affects language features only —
**debugging attaches over TCP and works regardless**, so you can ignore those
errors while debugging. See the `rubyLsp.rubyVersionManager` comment in
[`.vscode/settings.json`](.vscode/settings.json) for how to point it at a Ruby.

Supported SketchUp versions bundle the gem including its compiled native
extension, so nothing needs installing into SketchUp.

> **Tip:** to check whether a given SketchUp bundles the gem, and which version,
> run this in the Ruby Console:
>
> ```ruby
> Gem::Specification.find_all_by_name('debug').map { |s| [s.version, s.full_gem_path] }
> ```

## Setup

Nothing needs installing. There are only two steps:

1. **Launch SketchUp via the VSCode task.** Run the *Launch SketchUp for
   debugging* task (`Terminal > Run Task…`) and pick a version.

2. **Attach.** Pick the *Attach to SketchUp* launch configuration
   and press <kbd>F5</kbd>.

Set breakpoints in the gutter as usual.

Breakpoints bind a moment after attaching rather than instantly, so wait for them
to render as solid rather than hollow before triggering the code you want to stop
in. If you invoke it too quickly after pressing <kbd>F5</kbd> it can look as though
the breakpoint was ignored.

### Conditional breakpoints

The condition is a bare Ruby *expression*, not a statement — `face.nil?`, not
`if face.nil?`. The latter is incomplete Ruby and fails to parse.

A condition that raises or does not parse makes the breakpoint silently never
fire: the debug gem treats the failed evaluation as false. VSCode still shows the
breakpoint as verified, so there is no hint in the editor. The error is reported to
stdout, which in SketchUp means **the Ruby Console**:

```
[EVAL ERROR]
  expr: if face.nil?
  err: (eval):1: syntax error, unexpected end-of-input, expecting `then' or ';' or '\n'
```

So if a conditional breakpoint never triggers, check the Ruby Console before
assuming the condition was simply false.

### Log points, hit counts and editing variables

VSCode reports that the debugger does not support log points. That is an upstream
`ruby/debug` limitation rather than anything specific to SketchUp — the gem does
not advertise the `supportsLogPoints` capability in any version, so upgrading it
will not help. The same applies to hit counts
(`supportsHitConditionalBreakpoints`) and to changing a value from the Variables
pane (`supportsSetVariable`).

A conditional breakpoint covers the log point case, because the condition is
evaluated every time the line runs and only suspends when the result is truthy.
Log from the condition and make it evaluate to false:

```ruby
(puts("face=#{face.inspect}"); false)
```

The output goes to the Ruby Console, as with any `puts` from an extension. Note
`puts` already returns `nil`, so the explicit `false` is only needed when what you
are logging would itself evaluate truthy.

The launcher uses two SketchUp command line switches, so nothing has to be copied
into the Plugins folder:

```sh
SketchUp.exe -RubyStartup "<repo>/tools/su_debug_bootstrap.rb" -RubyStartupArg "su_debug:port=7150"
```

`-RubyStartup <file>` runs a Ruby file at startup. `-RubyStartupArg <string>` is
appended to Ruby's own `ARGV`, which is how the port reaches the bootstrap. Using
`ARGV` rather than an environment variable means it does not matter how SketchUp
was launched.

The bootstrap also accepts `RUBY_DEBUG_PORT` and `RUBY_DEBUG_WAIT` environment
variables as an alternative. Those are worth knowing about because SketchUp only
honours the **last** `-RubyStartupArg`, so the switch is unusable if something else
already needs it — TestUp uses it for its CI mode.

### macOS

The switches behave the same as on Windows, but the launcher has to work around two
defects in how SketchUp packages its macOS Ruby. Both are handled automatically; this
is here so the workarounds are not mistaken for clutter and removed.

SketchUp must be started through `open`:

```sh
open -n -a "<app>" --env "DYLD_LIBRARY_PATH=<app>/Contents/Frameworks/Ruby.framework/Versions/Current" \
  --args -RubyStartup "<repo>/tools/su_debug_bootstrap.rb" -RubyStartupArg "su_debug:port=7150"
```

Executing `<app>/Contents/MacOS/SketchUp` directly does **not** run the
`-RubyStartup` file — macOS reads these switches through `NSUserDefaults` rather than
by parsing the command line. Arguments must follow `--args`, and `-n` forces a new
instance, or `open` merely activates a running SketchUp and drops the arguments.

**`DYLD_LIBRARY_PATH` (SKEXT-5430).** The bundled `debug` gem's native extension is
linked against `@executable_path/../lib/libruby.<major>.<minor>.dylib`, which
SketchUp's packaging removes when it repackages Ruby as a framework. Without this,
`require 'debug/session'` fails and the bootstrap logs the gem as unavailable even
though it is present. Pointing dyld at `Versions/Current` resolves it to the
already-loaded `Ruby` binary via a matching symlink; that directory holds only `Ruby`
and those symlinks, so nothing else can be shadowed. It has to be passed with
`--env` because `open` strips `DYLD_*`, which needs macOS 13 or newer.

**A stub `irb/completion` (SKEXT-5431).** SketchUp's macOS Ruby installs no irb
library at all — the irb gem ships only `exe/irb` — while the `debug` gem's
`server_dap.rb` opens with an unconditional `require 'irb/completion'`. Because that
require only runs when a debugger client connects, the `LoadError` kills the debug
gem's reader thread mid-handshake, and the client sees a connection that is accepted
and never answered. That is indistinguishable from the GVL problem described below,
so check the bootstrap log before assuming the thread pump is at fault. The bootstrap
loads the DAP server up front, falling back to
[`tools/irb_stub/irb/completion.rb`](tools/irb_stub/irb/completion.rb) when irb is
missing, so any failure is reported in the log instead of during an attach. Only the
Debug Console's autocomplete depends on it; breakpoints, stepping and inspection are
unaffected.

Because the stub is found relative to the bootstrap, prefer a **symlink** over a copy
if you install the bootstrap into the Plugins folder, so `tools/irb_stub` stays
reachable.

Verified on macOS 26.6.1 (arm64) against SketchUp 2024 through 2027: the handshake
completes and breakpoints set in the editor bind and hit.

### Debugging extension startup

SketchUp runs the `-RubyStartup` file **after** it has finished loading
extensions, so the default setup cannot break in code that runs during extension
load. This is by design, and consistent across versions and platforms.

To debug extension startup, install the bootstrap into the Plugins folder instead
and add `wait=1`:

* Windows: `%APPDATA%/SketchUp/SketchUp <year>/SketchUp/Plugins`
* macOS: `~/Library/Application Support/SketchUp <year>/SketchUp/Plugins`

A symlink is convenient so edits to the file are picked up. Because SketchUp sorts
the Plugins folder alphabetically before loading it, give the file a name that
sorts before your own extension's loader if you need to break during that load.

Then launch with:

```sh
SketchUp.exe -RubyStartupArg "su_debug:port=7150,wait=1"
```

`-RubyStartupArg` still works here, because it is passed to Ruby before extensions
are loaded. `RUBY_DEBUG_PORT=7150` plus `RUBY_DEBUG_WAIT=1` does the same thing.

The bootstrap does nothing unless a port is configured, so it is safe to leave
installed permanently. With `wait=1` SketchUp blocks and appears frozen until you
attach; you then land in `su_debug_bootstrap.rb`, and pressing *Continue* lets
extension loading proceed with your breakpoints live.

The wait is implemented with `binding.break` rather than the gem's own
`nonstop: false` mode. That mode sets a one-shot breakpoint on the line following
the `require`, which in the bootstrap is a `rescue` clause that never executes,
so it would not reliably stop.

## Why the bootstrap is needed

Two SketchUp-specific problems have to be worked around. Both are handled by
`tools/su_debug_bootstrap.rb`; this section explains what it does and why, since
neither failure mode is obvious from the symptoms.

### Breakpoints set in the editor never bind

The `debug` gem only assumes the debugger client shares its filesystem when the
connection is a Unix domain socket. For a TCP connection it leaves the mapping
unset — the loopback special case in `dap_setup` is commented out as a TODO — and
then rejects every `setBreakpoints` request:

```
<path> is not available
```

The result is that breakpoints silently fail to bind and stack frames cannot
open their source files, which is why previous attempts concluded that gutter
breakpoints "don't work" and that `binding.break` was required. `binding.break`
works because it does not depend on a bound breakpoint.

The bootstrap fixes this on the debuggee side with:

```ruby
DEBUGGER__::CONFIG[:local_fs_map] = true
```

Doing it there rather than in `launch.json` means it works regardless of which
debugger client is used. `launch.json` also passes `"localfs": true`, which has
the same effect for clients that send it.

Note that the equivalent `RUBY_DEBUG_LOCAL_FS_MAP` environment variable is not
usable on Windows: the gem parses it by splitting on `:`, which mangles drive
letters.

### The debugger connects but never responds

SketchUp only runs the Ruby VM while it is executing Ruby code. While SketchUp
sits idle in its own event loop it holds Ruby's GVL, and Ruby cannot pre-empt
native code that does not release it. The `debug` gem's server threads are
therefore never scheduled: the TCP connection is accepted by the kernel, but not
a single DAP request is answered, and the debugger appears to hang.

The bootstrap keeps those threads alive with a timer that yields to the Ruby
scheduler:

```ruby
UI.start_timer(0.1, true) { Thread.pass }
```

`Thread.pass` is enough and does not stall the UI. This is also the likely cause
of the intermittent behaviour reported in earlier experiments: whether it worked
depended on how much Ruby happened to be running.

Note that a missing irb library produces the *same* symptom on macOS for an entirely
different reason — see the [macOS](#macos) section. Check the bootstrap log before
concluding the thread pump is at fault.

### User-installed gems break the debugger's own dependencies

RubyGems always searches `Gem.user_dir`, and on Windows SketchUp keeps it on
`GEM_PATH`. Anything installed there for a matching Ruby version leaks into
SketchUp — most easily a per-machine Ruby set up for Ruby LSP that happens to share
SketchUp's Ruby version, which drops `irb`, `reline`, `rbs`, `prism` and friends into
that directory.

RubyGems then activates those newer copies to satisfy the `debug` gem's dependency
chain (`debug` → `irb` → `prism`, …), and a single missing transitive gem makes
`require 'debug/session'` fail outright — so the debugger never initialises at all.

The bootstrap drops the user directory from the gem search path for the duration of
the require, so SketchUp's own bundled gems win, then restores it. Everything the
`debug` gem needs at attach time is loaded during that window, so nothing else in the
session is affected.

The deliberate per-version gem directory,
`SketchUp <year>/SketchUp/Gems`, is left on the path — that one exists precisely so
gems can be installed for SketchUp.

On macOS this is currently inert: SketchUp does not put `Gem.user_dir` on the gem
path there, so there is nothing to filter. It is applied unconditionally rather than
per-platform, so the protection appears automatically if that ever changes.

## Choice of extension

[Ruby LSP][ruby-lsp] is what the Ruby community has converged on, and it is
actively maintained. Its `ruby_lsp` debug type supports TCP attach through
`debugHost`/`debugPort` and is wire-compatible with `ruby/debug` — VSCode talks
DAP straight to the gem, with no adapter in between.

The alternative [vscode-rdbg][vscode-rdbg] extension (`type: "rdbg"`) also works
and its attach config is `"debugPort": "127.0.0.1:7150"` plus `"localfs": true`,
but it has had no release since December 2023.

[ruby-debug]: https://github.com/ruby/debug
[ruby-lsp]: https://github.com/Shopify/ruby-lsp
[vscode-rdbg]: https://github.com/ruby/vscode-rdbg
[dap]: https://microsoft.github.io/debug-adapter-protocol/
[su-debugger]: https://github.com/SketchUp/sketchup-ruby-debugger
