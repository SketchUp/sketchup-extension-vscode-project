# SketchUp Bridge

A TCP-based eval bridge that lets external tools (Claude Code, scripts, editors) execute Ruby code inside a running SketchUp instance and read back results.

## How it works

```
┌──────────────┐   TCP :7200  ┌────────────────────────────────────┐
│    Client    │ ──────────── │           SketchUp                 │
│  (terminal)  │  Ruby code → │  ┌──────────────────────────────┐  │
│              │  ← JSON      │  │  server.rb (background       │  │
│  client.rb   │              │  │  thread accepts connections, │  │
│  or any TCP  │              │  │  UI.start_timer evaluates    │  │
│  client      │              │  │  on the main thread)         │  │
└──────────────┘              │  └──────────────────────────────┘  │
                              └────────────────────────────────────┘
```

**Why the main thread?** SketchUp's Ruby API is not thread-safe. The bridge uses a background thread to accept TCP connections (non-blocking), then `UI.start_timer` to drain a queue and evaluate code on the main thread where API calls are safe.

## Quick start

### 1. Launch SketchUp with the bridge

From the terminal:

```sh
ruby tools/sketchup-bridge/launch.rb 2026
```

Or use the VSCode task: **"Launch SketchUp with Bridge"** (via `Ctrl+Shift+P` → `Tasks: Run Task`).

SketchUp will start and print to the Ruby Console:

```
SketchUpBridge: listening on port 7200
```

### 2. Send Ruby code from the terminal

**Inline expression:**

```sh
ruby tools/sketchup-bridge/client.rb "Sketchup.active_model.title"
```

**Multi-line via stdin:**

```sh
ruby tools/sketchup-bridge/client.rb <<'RUBY'
model = Sketchup.active_model
model.start_operation('Bridge Test', true)
group = model.active_entities.add_group
face = group.entities.add_face(
  [0, 0, 0], [1.m, 0, 0], [1.m, 1.m, 0], [0, 1.m, 0]
)
face.pushpull(-1.m)
model.commit_operation
"Created a cube with #{group.entities.length} entities"
RUBY
```

**Pipe a file:**

```sh
ruby tools/sketchup-bridge/client.rb < my_script.rb
```

### 3. Read the response

The client prints the result to stdout. The response from the bridge is JSON:

```json
// Success
{ "success": true, "result": "\"Untitled\"", "stdout": "" }

// Error
{ "success": false, "error": "NameError: undefined local variable 'x'",
  "backtrace": ["(bridge):1:in `<main>'"], "stdout": "" }
```

The client formats this for you — it prints `stdout` (any `puts` output), then the result. On error it prints the error and backtrace to stderr and exits with code 1.

## Files

| File        | Runs in  | Purpose                                           |
| ----------- | -------- | ------------------------------------------------- |
| `server.rb` | SketchUp | TCP server, queues code, evaluates on main thread |
| `client.py` | Terminal | Fast client (Python) — no Ruby startup overhead   |
| `client.rb` | Terminal | Ruby client — same behavior, slower on Windows    |
| `launch.rb` | Terminal | Launches SketchUp with `-RubyStartup server.rb`   |

## VSCode tasks

Two tasks are available in `.vscode/tasks.json`:

- **Launch SketchUp with Bridge** — starts SketchUp with the eval bridge
- **Launch SketchUp with Bridge + Debug** — bridge + Ruby debugger on port 7000

## Options

### Launch flags

```sh
ruby tools/sketchup-bridge/launch.rb 2025          # specific version
ruby tools/sketchup-bridge/launch.rb 2026 --debug  # also attach rdebug on port 7000
```

### Port

The default port is `7200`. The client respects the `SKETCHUP_BRIDGE_PORT` environment variable:

```sh
SKETCHUP_BRIDGE_PORT=7201 ruby tools/sketchup-bridge/client.rb "1 + 1"
```

To change the server port, edit `PORT` in `server.rb`.

## Use with Claude Code

With SketchUp running and the bridge loaded, Claude Code can evaluate Ruby in SketchUp via the Bash tool:

```sh
python tools/sketchup-bridge/client.py "Sketchup.active_model.entities.length"
```

The Python client avoids Ruby's startup overhead on Windows. This lets Claude inspect model state, create geometry, test API calls, and verify changes — all inside the live SketchUp session.

A future improvement would be wrapping this as an MCP server, giving Claude a native `evaluate_ruby` tool instead of going through Bash.

## Security note

The bridge evaluates arbitrary Ruby code. It binds to `127.0.0.1` (localhost only), so it is not accessible from the network. This is intended for local development only.
