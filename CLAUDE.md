# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Boilerplate VSCode project for SketchUp Ruby extension development. The example extension (`HelloCube`) demonstrates the standard patterns.

When prompted to "create an extension" reuse the existing extension. If the extension is using the example namespace `Examples::HelloCube` and example `ex_hello_cube` filenames, update the namespace and filenames to reflect the purpose of the extension. After this has been changed the first time, don't rename unless explicitly prompted.

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

## SketchUp Fundamentals

### Coordinate System

SketchUp uses a right-handed coordinate system where **Z is up**. The axes are: X (red) = right, Y (green) = forward/into screen, Z (blue) = up. Do not confuse this with Y-up systems used by some other 3D applications.

### Units

SketchUp's internal unit is **inches**. All geometric values (points, vectors, distances) are stored in inches internally. The `Length` class handles display formatting — `Length#to_s` formats the value to the user's chosen model units (e.g., millimeters, meters, feet).

Use SketchUp's helper methods on `Numeric`, `String`, `Array`, and `Length` for unit conversions rather than manual arithmetic:
- `10.mm` — converts 10 millimeters to inches (internal unit).
- `45.degrees` — converts 45 degrees to radians (used by the API for angles).
- `"2m".to_l` — parses a string with units into a `Length` in inches.
See the full list of helpers in the SketchUp Ruby API documentation for `Numeric`, `String`, `Array`, and `Length`.

## Best practices

- When starting operations, disable UI updates for the span of the operation by setting the second argument: `model.start_operation('Create Cube', true)`.
- When creating groups with non-axis-aligned geometry, set a `Geom::Transformation` on the group so the geometry is axis-aligned in local space. This makes the group's bounding box tightly fit the geometry. Use `Geom::Transformation.axes` to build the local coordinate system.
- Prefer `pushpull` on a base face over manually creating all six faces of a box. It handles face orientation correctly and is less error-prone. Check `face.normal` against the expected direction to determine the sign of the pushpull distance.

### Documentation

- YARD documentation: add `@param` and `@return` tags for methods with meaningful return values. Do not add `@return [void]` — omit `@return` when the return value is not used.
- For instance variables, use YARD type annotations indicating contents: e.g., `@return [Array<Geom::Point3d>]` for arrays, `@return [Hash{String => Integer}]` for hashes. For variables initialized to `nil`, annotate with the type they will hold: e.g., `@return [Geom::Point3d, nil]`.
- Comments should use proper sentences with capitalization and punctuation.

### Coding pattern

- Important! Don't add `try`/`catch` unless you are highly confident that an error can reasonably be expected and you have some way to recover usefully. Bad example: catch "maybe errors" and ignore or print to Ruby Console. The error is still essentially unhandled, let the normal error mechanisms propagate. Good example: Attempt to read a file, handle exceptions related to reading/accessing the file because file operations are actions where you can reasonable expect a failure and do something useful such as inform the user.
- Important! Don't check for `nil` unless you are highly confident that is a possibility. If the program logic doesn't expect `nil` then it would be a bug to see `nil` and the application/extension is better of throwing an error instead of silently ignoring it. Fail early on unmet program expectations.
- Avoid magic values. Introduce constants that provide semantic meaning (e.g., `PADDING = 4` instead of a bare `4`).
- Keep related data grouped as a single object. For 2D/3D coordinates, store them as `Geom::Point3d` (or `Geom::Point2d`) rather than separate `x`, `y`, `z` variables. Prefer `Geom::Point3d` even for 2D use cases, as most SketchUp API methods expect 3D points. Use plain arrays only when no suitable object type exists.

### Code Organization

- Use `Sketchup.require` with paths relative to the extension root (e.g., `Sketchup.require('my_extension/some_file')`), not `__dir__`. Using `__dir__` has encoding issues on Windows with non-ASCII paths.
- Place `Sketchup.require`/`require` statements at the top of the file, Ruby standard library first, then extension files, in alphabetical order.

### Performance

- Prefer bulk methods for performance. Slow: `entities.each { |e| selection.add(e) if e.is_a?(Sketchup::Face) }`. Fast: `selection.add(entities.grep(Sketchup::Face))`.
- Don't modify the container you iterate: Bad: `model.entities.each { |e| e.erase! }`. Safe (using a copy): `model.entities.to_a.each { |e| e.erase! }`. Best (performance): `model.entities.erase_entities(array_of_entities_to_erase)`.
- Don't use `entity.typename == 'Face'` to check for types, it is _very_ slow. Use the type system: `entity.is_a?(Sketchup::Face)`.
- Prefer SketchUp API geometry methods over manual component arithmetic — they are implemented in C++ and faster:
  - `pt1.vector_to(pt2)` instead of `pt2 - pt1` for vectors between points.
  - `pt.offset(vec)` or `pt.offset(vec, distance)` instead of manually adding components.
  - `v1.dot(v2)` and `v1.cross(v2)` instead of `%` and `*` operators for readability.
  - `Geom.linear_combination(w1, pt1, w2, pt2)` for weighted point interpolation (e.g., midpoints).

### Toolbars

- Use vector images for toolbar icons and cursors. On Windows the format is `.svg` on macOS it is `.pdf`. The sizes are 32x32 (with a 4px empty padding) for large icons and 24x24 (with a 4px empty padding) for small icons. Both formats should be provided as extensions are distrobuted to both Windows and macOS users. Usually you want to make a utility function to pick the right extension and reuse that for each command.
- When creating toolbar icons or cursor images, author them as `.svg` and convert to `.pdf` for macOS using Inkscape CLI. Inkscape may not be on PATH; use the default installation paths:
  - **Windows:** `"/c/Program Files/Inkscape/bin/inkscape.exe"`
  - **macOS:** `/Applications/Inkscape.app/Contents/MacOS/inkscape`
  - **Conversion command:** `inkscape input.svg --export-filename=output.pdf`

### Sketchup::Tool patterns

- Keep implementations slim. Treat tools as controllers and place the business logic in other files/classes/modules.
- Initialize all instance variables in `initialize`, not just in `activate` or a reset method. This ensures tools have a well-defined initial state.
- Remember to implement `getExtents` when drawing to the viewport. If you draw outside the model bounds the drawing will be clipped if a custom bound is not provided.
- Always call `view.invalidate` in both `deactivate` and `suspend` callbacks, in addition to the other callbacks that modify state. This is flagged by the `SketchupSuggestions/ToolInvalidate` RuboCop cop.
- For multi-step input: use a second `Sketchup::InputPoint` as a guide and pass it to the primary InputPoint's `pick` method for snapping inference. Copy the primary InputPoint to the guide after each accepted click.
- When `InputPoint` may not snap to geometry (e.g., looking top-down during a height pick), fall back to projecting the mouse ray onto the constraint axis using `view.pickray` and `Geom.closest_points`.
- Update the statusbar text (`Sketchup.status_text=`) whenever the tool state changes. The statusbar should tell the user what action to take next (e.g., "Click to set the start point", "Click to set the end point").
- In `onCancel`, check the `reason` parameter: `0` = ESC key, `1` = reactivate, `2` = undo. ESC should typically step back one state; other reasons should fully reset the tool.
- `view.invalidate` is meant to be used from within a `Sketchup::Tool` to signal that the view should redraw. If you find yourself using this outside of a tool to trigger a refresh it's an indication of a bug in SketchUp and we ask you to log a bug report.
- Use `view.invalidate` instead of `view.refresh`. `view.refresh` forces a redraw and can lead to poor performance and other bad side effects. Don't use unless you have a really good reason to workaround some viewport update issues.

### UI::WebDialog and UI::HtmlDialog

- Use `UI::HtmlDialog` instead of `UI::WebDialog` for creating UIs that require more control than what `UI.inputbox` and `UI.messagebox` provides. (https://github.com/SketchUp/htmldialog-examples)
