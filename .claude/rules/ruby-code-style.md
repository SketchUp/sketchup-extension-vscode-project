---
paths:
  - "src/**/*.rb"
  - "tests/**/*.rb"
---

# Ruby Code Style

## Naming

Use full, human-readable names. Don't use abbreviations unless very common (e.g. `ui`, `id`). Prefer `transformation` over `tr`, `expected_point` over `exp_pt`.

## Coding pattern

- Important! Don't add `try`/`catch` unless you are highly confident that an error can reasonably be expected and you have some way to recover usefully. Bad example: catch "maybe errors" and ignore or print to Ruby Console. The error is still essentially unhandled, let the normal error mechanisms propagate. Good example: Attempt to read a file, handle exceptions related to reading/accessing the file because file operations are actions where you can reasonable expect a failure and do something useful such as inform the user.
- Important! Don't check for `nil` unless you are highly confident that is a possibility. If the program logic doesn't expect `nil` then it would be a bug to see `nil` and the application/extension is better of throwing an error instead of silently ignoring it. Fail early on unmet program expectations.
- Avoid magic values. Introduce constants that provide semantic meaning (e.g., `PADDING = 4` instead of a bare `4`).
- Keep related data grouped as a single object. For 2D/3D coordinates, store them as `Geom::Point3d` (or `Geom::Point2d`) rather than separate `x`, `y`, `z` variables. Prefer `Geom::Point3d` even for 2D use cases, as most SketchUp API methods expect 3D points. Use plain arrays only when no suitable object type exists.

## Code Organization

- Use `Sketchup.require` with paths relative to the extension root (e.g., `Sketchup.require('my_extension/some_file')`), not `__dir__`. Using `__dir__` has encoding issues on Windows with non-ASCII paths.
- Place `Sketchup.require`/`require` statements at the top of the file, Ruby standard library first, then extension files, in alphabetical order.
- Use `require` and `require_relative` for requiring files that are not part of the extension (e.g., Ruby standard library, gems).

## Documentation

- YARD documentation: add `@param` and `@return` tags for methods with meaningful return values. Do not add `@return [void]` — omit `@return` when the return value is not used.
- For instance variables, use YARD type annotations indicating contents: e.g., `@return [Array<Geom::Point3d>]` for arrays, `@return [Hash{String => Integer}]` for hashes. For variables initialized to `nil`, annotate with the type they will hold: e.g., `@return [Geom::Point3d, nil]`.
- Comments should use proper sentences with capitalization and punctuation.
