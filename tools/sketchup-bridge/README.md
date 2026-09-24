# SketchUp bridge

Lets Claude Code run Ruby inside a running SketchUp, so that it can check how the API actually behaves, inspect the model, and try out changes, rather than guessing.

It is a development tool, for use while working on an extension. Nothing here is part of the extension itself.

## Setup

1. Start SketchUp with the bridge, using the **Launch SketchUp for debugging, with Claude bridge** task, or:

   ```sh
   ruby tools/debug-sketchup.rb 2026 --bridge
   ```

   The Ruby Console shows `SketchUp bridge: listening on 127.0.0.1:7200`. The debugger is started as well, so you can still attach to SketchUp as described in [DEBUGGING.md](../../DEBUGGING.md).

2. Start Claude Code in the project. It asks whether to enable the `sketchup-bridge` MCP server from `.mcp.json`. Once you approve it, Claude has two tools: `evaluate_ruby`, and `run_tests` for running TestUp tests.

The MCP server needs Ruby 2.7 or newer on `PATH`, and no gems. Claude Code can be started before or after SketchUp. If SketchUp isn't running, the tool reports that instead of failing.

## From a terminal

`client.rb` sends code to the bridge and prints the result:

```sh
ruby tools/sketchup-bridge/client.rb "Sketchup.active_model.entities.size"
ruby tools/sketchup-bridge/client.rb < script.rb
```

On an error it prints the message and backtrace to stderr, and exits with status 1.

## How the code runs

- On SketchUp's main thread, at top level, like the Ruby Console. Local variables persist between calls.
- The value of the last expression is returned as `inspect` shows it. Anything written to `$stdout` or `$stderr` while the code runs is returned with it, instead of appearing in the Ruby Console.
- SketchUp is frozen until the code finishes.
- Exceptions are reported back, including syntax errors, and `exit` doesn't close SketchUp.

## Running TestUp tests

`run_tests` runs a [TestUp](https://github.com/SketchUp/testup-2) test suite in SketchUp, and reports each failure, error and skip with its message and location. It needs TestUp to be installed in that SketchUp. It doesn't need TestUp's window, and doesn't install any gems.

- **Suite:** the folder holding the `TC_*.rb` files, such as `tests/Cube Example`.
- **Tests:** test cases or single tests, such as `TC_Main` or `TC_Main#test_create_cube`, with or without their namespace. By default the whole suite runs. Names are checked against the suite, because TestUp silently runs nothing for a name that doesn't match.
- **Reload:** folders or files of extension code to `load` again before running, such as `src/ex_hello_cube`. TestUp loads the test files again on every run, but not the code they test, so without this the tests keep running against the code SketchUp loaded at startup. The extension itself is expected to be loaded already.
- **Seed:** the Minitest seed, which is reported with every run, so that an order-dependent failure can be repeated.

Tests run in the active model, and many start by clearing it. So `run_tests` refuses to run while the model has unsaved changes, unless the only changes since its previous run were made by the tests. Claude then asks before overriding that with `discard_model_changes`.

A test that opens a model file, while the current one has unsaved changes, makes SketchUp ask whether to save them. SketchUp is frozen until that is answered. Tests usually close the model first, with `model.close(true)`.


| File               | Runs in     | Purpose                                                                |
| ------------------ | ----------- | ---------------------------------------------------------------------- |
| `server.rb`        | SketchUp    | Listens for code and evaluates it                                      |
| `mcp_server.rb`    | Claude Code | Provides the `evaluate_ruby` and `run_tests` tools, through the bridge |
| `testup_runner.rb` | SketchUp    | Runs TestUp tests for `run_tests`; loaded again on every run           |
| `client.rb`        | Terminal    | Sends code from the command line; used by `mcp_server.rb`              |

## Protocol

Connect to `127.0.0.1:7200`, send the code as UTF-8, then close the sending side of the connection. The bridge replies with one JSON object and closes the connection:

```json
{ "success": true, "result": "42", "output": "hello\n" }
{ "success": false, "error": "NameError: undefined local variable or method 'x' for main", "backtrace": ["(bridge):1:in '<main>'"], "output": "" }
```

Results and output are cut off at 50,000 characters. A connection that hasn't finished sending after 30 seconds is closed.

## Limitations

- **One SketchUp at a time.** The port is fixed, so a second SketchUp started with the bridge reports that the port is in use.
- **Not while code is running.** The bridge doesn't answer while SketchUp is busy, including while a modal dialog is open.
- **Anyone on this machine can run code in SketchUp while the bridge is running.** It only listens on `127.0.0.1` and refuses HTTP requests, so other machines and web pages can't reach it, but there is no authentication. That's the same as the debugger, and the reason neither is started unless you ask for it.

## Why it works this way

SketchUp only runs one `-RubyStartup` file, so when the bridge is started, `server.rb` is that file and it loads the debugger's bootstrap itself.

SketchUp holds Ruby's global VM lock while it is idle, so Ruby threads in SketchUp barely run. Instead of a thread, the bridge uses a `UI.start_timer` on the main thread to check for connections without blocking, which is also where the SketchUp API has to be called from. That answers a request in a few tens of milliseconds, where a thread took seconds.
