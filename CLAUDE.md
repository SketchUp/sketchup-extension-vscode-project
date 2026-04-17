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

# Launch SketchUp in debug mode (via skippy)
skippy sketchup:debug <version>   # e.g., skippy sketchup:debug 2026
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

Tests use the [TestUp](https://github.com/nicholasnelson/testup-2) framework (`TestUp::TestCase`), not standard Minitest directly. Tests run inside SketchUp, not standalone Ruby. Test files are in `tests/`.

### Debugging

VSCode is configured to attach to SketchUp's Ruby debugger (`rdebug-ide`) on port 7000. The workflow: launch SketchUp in debug mode via the VSCode task, then attach using the "Listen for rdebug-ide" launch configuration. Requires the [SketchUp Ruby Debugger](https://github.com/SketchUp/sketchup-ruby-debugger) dll/dylib installed in SketchUp.
