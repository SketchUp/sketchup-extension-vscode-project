# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Boilerplate VSCode project for SketchUp Ruby extension development. The example extension (`HelloCube`) demonstrates the standard patterns.

## Key Commands

```bash
# Install gem dependencies
bundle install

# Run RuboCop static analysis (SketchUp-specific rules)
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

## Important Requirements for publishing extensions

More information: https://ruby.sketchup.com/file.extension_requirements.html

- Everything in the extension should be contained within a single root module. Common pattern is Company/Developer name, then the extension name. That typically ensure high probably uniqueness.
- Don't use global variables.
- Don't modify the SketchUp API, Ruby API.
- Don't use `Gem.install` to consume gems. Extensions run in a shared environment with other extensions. If you need a gem's logic, vendor it into your extension under your extension namespace.
- Always wrap model-modifying operations in `model.start_operation` / `model.commit_operation`.
- Remember that writing attributes (`entity.set_attribute`, `entity.attribute_dictionary('mydict')['key'] = 123` etc are model changes and should also be wrapped in `model.start_operation`).
- Golden rule of undo handling is: "One user action should be undoable in a single undo step".
- The string passed to `model.start_operation` appear in the UI, it will be seen when the user opens the Edit menu (`Edit -> Undo Operation Name`). So make it short and human friendly.
- If the extension makes model changes in an observer event the undo operation must be made transparent, by setting the fourth argument to true: `model.start_operation('Update Attributes', true, false, true)`.
- The third argument in `model.start_operation` is deprecated and _should not_ be used!
- Use `file_loaded?(__FILE__)` / `file_loaded(__FILE__)` guards in both the registration file and main file to prevent duplicate menu items or re-registration on reload.
- Don't modify the Ruby load path (`$LOAD_PATH`). This impact the shared environment extensions use.
- If your extension is going to be encrypted (Default on Extension Warehouse), you _must_ use `Sketchup.require` to load the files in your extension. You can continue to use the normal `require` for the Ruby standard library etc. But when you encrypt your extension all `.rb` files in your RBZ package is replaced by `.rbe` files. So remember to omit the file extension when using `Sketchup.require`. SketchUp will resolve the file extension from the base name first trying `.rbe` then `.rb`.

## Best practices

- When starting operations, disable UI updates for the span of the operation by setting the second argument: `model.start_operation('Create Cube', true)`.
- Important! Don't add `try`/`catch` unless you are highly confident that an error can reasonably be expected and you have some way to recover usefully. Bad example: catch "maybe errors" and ignore or print to Ruby Console. The error is still essentially unhandled, let the normal error mechanisms propagate. Good example: Attempt to read a file, handle exceptions related to reading/accessing the file because file operations are actions where you can reasonable expect a failure and do something useful such as inform the user.
- Important! Don't check for `nil` unless you are highly confident that is a possibility. If the program logic doesn't expect `nil` then it would be a bug to see `nil` and the application/extension is better of throwing an error instead of silently ignoring it. Fail early on unmet program expectations.
- Prefer bulk methods for performance. Slow: `entities.each { |e| selection.add(e) if e.is_a?(Sketchup::Face) }`. Fast: `selection.add(entities.grep(Sketchup::Face))`.
- Don't modify the container you iterate: Bad: `model.entities.each { |e| e.erase! }`. Safe (using a copy): `model.entities.to_a.each { |e| e.erase! }`. Best (performance): `model.entities.erase_entities(array_of_entities_to_erase)`.
- Don't use `entity.typename == 'Face'` to check for types, it is _very_ slow. Use the type system: `entity.is_a?(Sketchup::Face)`.
- Keep Ruby `Sketchup::Tool` implementations slim. Treat them as controllers and place the business logic in other files/classes/modules and mainly orchestrate user input.
- Remember to implement `getExtents` when drawing to the viewport from a `Sketchup::Tool` or `Sketchup::Overlay`. If you draw outside the model bounds the drawing will be clipped if a custom bound is not provided.
- `view.invalidate` is meant to be used from within a `Sketchup::Tool` to signal that the new should redraw. If you find yourself using this outside of a tool to trigger a refresh it's an indication of a bug in SketchUp and we ask you to log a bug report.
- Use `view.invalidate` instead of `view.refresh`. `view.refresh` forces a redraw and can lead to poor performance and order bad side effects. Don't use unless you have a really good reason to workaround some viewport update issues.
- Use `UI::HtmlDialog` instead of `UI::WebDialog` for creating UIs that require more control than what `UI.inputbox` and `UI.messagebox` provides. (https://github.com/SketchUp/htmldialog-examples)
