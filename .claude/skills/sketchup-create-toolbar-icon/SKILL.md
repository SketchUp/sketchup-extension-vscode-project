---
name: sketchup-create-toolbar-icon
description: Create or convert SketchUp toolbar icons and cursor images. Use when authoring new toolbar icons, cursor images, or converting existing .svg files to the macOS .pdf format.
---

# Create a SketchUp Toolbar Icon or Cursor Image

SketchUp extensions distribute to both Windows and macOS users. Each platform uses a different vector format for toolbar icons and cursors.

## Format and sizes

- **Windows:** `.svg`
- **macOS:** `.pdf`
- **Large icons:** 32x32 with a 4px empty padding
- **Small icons:** 24x24 with a 4px empty padding

Both formats should be shipped with the extension. Write a small utility that picks the right extension at runtime and reuse it for each command.

## Authoring workflow

1. Author the icon as `.svg`.
2. Convert to `.pdf` for macOS using Inkscape CLI.

Inkscape may not be on `PATH`. Use the default installation paths:

- **Windows:** `"/c/Program Files/Inkscape/bin/inkscape.exe"`
- **macOS:** `/Applications/Inkscape.app/Contents/MacOS/inkscape`

Conversion command:

```sh
inkscape input.svg --export-filename=output.pdf
```

## Runtime icon selection

Provide a helper that resolves the correct file extension for the current platform and reuse it from every command registration site, instead of branching in each place.
