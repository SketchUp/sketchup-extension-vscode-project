---
paths:
  - "src/**/*.rb"
---

# SketchUp Extension Publishing Requirements

More information: https://ruby.sketchup.com/file.extension_requirements.html

- Everything in the extension should be contained within a single root module. Common pattern is Company/Developer name, then the extension name. That typically ensure high probably uniqueness.
- Don't use global variables.
- Don't modify the SketchUp API, Ruby API.
- Don't use `Gem.install` to consume gems. Extensions run in a shared environment with other extensions. If you need a gem's logic, vendor it into your extension under your extension namespace.
- Use `file_loaded?(__FILE__)` / `file_loaded(__FILE__)` guards in both the registration file and main file to prevent duplicate menu items or re-registration on reload.
- Don't modify the Ruby load path (`$LOAD_PATH`). This impact the shared environment extensions use.
- If your extension is going to be encrypted (Default on Extension Warehouse), you _must_ use `Sketchup.require` to load the files in your extension. You can continue to use the normal `require` for the Ruby standard library etc. But when you encrypt your extension all `.rb` files in your RBZ package is replaced by `.rbe` files. So remember to omit the file extension when using `Sketchup.require`. SketchUp will resolve the file extension from the base name first trying `.rbe` then `.rb`.
