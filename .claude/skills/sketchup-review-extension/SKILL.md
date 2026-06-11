---
name: sketchup-review-extension
description: Find common extension issues. Based on the Extension Warehouse review.
---

Review a SketchUp extension for Extension Warehouse compliance.

## Inputs

| Input | Path | Description |
|---|---|---|
| Source code | `src/` | Extracted extension files |
| RuboCop results | `rubocop-results.json` | RuboCop-SketchUp static analysis (may be absent) |

## Output

Write the review to `review_report.txt`. Nothing else.

## Workflow

1. Read `rubocop-results.json`.
2. List all files under `src/`. Read every Ruby file, JS file and HTML file.
3. Evaluate the rules below.
4. Write `review_report.txt` in the exact output format specified.

## Developer Feedback

Evaluate every rule below against the code. Each rule is either a **Rejection** (blocks publishing) or a **Note** (recommendation, does not block).

### Rejections

These block publishing. Use the exact wording provided, substituting placeholders.

#### Root file does too much
The root `.rb` file - the one .rb file directly in src/ - should ONLY register the SketchupExtension. No business logic, no loading other files beyond the single support file referenced by the SketchupExtension object, no `require` of gems or stdlib, no file I/O. If the user chooses to disable the extension in Extension Manager, no other code should run.
**Exception:** The root `.rb` may load the extension data from a `.json` file.
**Exception:** The root may define constants.
**Exception:** The root may require "sketchup.rb" and "extension.rb"
```
Rejection: The root .rb file is only allowed to contain the SketchupExtension registration. All other logic should load only through the file referenced by the SketchupExtension object. If the user chooses to disable the extension in the Extension Manager, no other code should run.
https://ruby.sketchup.com/file.extension_requirements.html#label-File+Structure
```
(Excess code should be moved to the main file. Version definitions needed for the SketchupExtension registration should be defined directly in the root file.)

#### No top-level namespace
All class, module, constant and method definitions must be wrapped inside a single uniquely named top-level module.
**Ignore if:** Code outside the module only uses local variables (which go out of scope when the file ends) and does not define methods, constants, or classes.
```
Rejection: To avoid clashes between extensions, the code needs to be wrapped in a single top level namespace module with a unique name. No global methods are allowed.
https://ruby.sketchup.com/file.extension_requirements.html#label-Wrapping+Module
```

#### Multiple top-level namespaces
Only one top-level module is allowed across the entire extension.
```
Rejection: To avoid clashes between extensions, only one top level namespace module is allowed.
https://ruby.sketchup.com/file.extension_requirements.html#label-Wrapping+Module
```

#### Global variables
Global variables (`$foo`) are not permitted. Check setting global variables. Reading existing global variables is okay.
```
Rejection: To avoid clashes between extensions we don't allow global variables. You can use instance variables with getter/setter methods instead.
https://ruby.sketchup.com/file.extension_requirements.html#label-Global+Variables
```

#### Console printing (unconditional)
`puts`, `print`, `p` called unconditionally in production code path.
**Exception:** Printing inside `rescue` blocks is acceptable and should NOT be flagged. Only flag unconditional printing outside error handling.
```
Rejection: This extension prints debug information to the Ruby Console. If every extension does this, it clutters the console and makes it harder to use for other developers. Also this information never reaches typical end users, so it can't be relied upon for important information. Please only print to the console when the extension is set to debug mode, not in production.
https://ruby.sketchup.com/file.extension_requirements.html#label-Printing+to+the+Console
```

#### Load error from require (encrypted extension)
Using Ruby's `require` or `require_relative` with `.rb` extension. EW encrypts `.rb` → `.rbe` by default, breaking these calls. Must use `Sketchup.require` without file extension for files within the extension.
Can use Ruby's `require` for std lib and other files outside of the extension. Files outside of extensions are not encrypted.
```
Rejection: Load error. By default Extension Warehouse encrypts extensions and turns .rb files to .rbe files. To load these files, use Sketchup.require instead of Ruby's own require and omit the file extension.
```
If `require_relative` specifically, append:
```
Instead of require_relative, use Sketchup.require with a path relative to the extension install location (Plugins folder).
```

#### Load error from extension registration (encrypted extension)
Hardcoded `.rb` extension in the path passed to `SketchupExtension.new`.
```
Rejection: Load error. By default Extension Warehouse encrypts extensions and turns .rb files to .rbe files. Omit the .rb file extension when registering your extension.
https://ruby.sketchup.com/file.extension_requirements.html#label-Requiring+Files
```

#### Installing gems at runtime
```
Rejection: Installing Gems does not work well in SketchUp. It freezes up the program during installation and some Gems need special build tools to be made functional. Also different extensions may want to use different versions of the same gem. Instead copy the code of the Gem into your own extension support folder and wrap it under your own unique namespace.
https://ruby.sketchup.com/file.extension_requirements.html#label-Gems
```

#### Code injection in execute_script
Interpolating variables directly into `execute_script` strings without escaping.
**Not a rejection if:** The interpolated value is produced by `JSON.generate`, `to_json`, or another mechanism that guarantees proper escaping.
```
Rejection: Interpolating variables directly into `execute_script` is error prone in case the value contains quotation marks and can be used for code injection attacks. Use `to_json` and omit the quotation marks to make sure the value is fully escaped.

# Bad
dialog.execute_script("showMessage('#{message}')")

# Good
require "json"
dialog.execute_script("showMessage(#{message.to_json})")
```
if code uses `gsub`, also explain that `to_json` is more robust.

If every single interpolated variable is clearly coming from safe sources (hardcoded in the source, timestamps etc), downgrade to a Note, but point out it's best practice to escape consistently.

#### Code injection in HTML
Passing unsanitized variables into HTML — either through string interpolation or by assigning directly to `innerHTML` — via `WebDialog.set_html`, `HtmlDialog#set_html`, or JavaScript executed by the extension.
```
Rejection: Passing unsanitized variables into HTML is error prone in case the value contains HTML escape characters and can be used for code injection attacks. Escape strings before interpolating them into HTML, or use `textContent` instead of `innerHTML` when inserting plain text.

# Bad - user data interpreted as HTML via interpolation
name = "<script>alert('Code injection!')</script>"
html = "<div>#{name}</div>"

# Bad - user data assigned directly to innerHTML
element.innerHTML = userProvidedValue

# Good - special characters are escaped (Ruby)
require "cgi"
name = "<script>alert('Code injection!')</script>"
html = "<div>#{CGI.escape_html(name)}</div>"
# Result: <div>&lt;script&gt;alert('Code injection!')&lt;/script&gt;</div>

# Good - use textContent for plain text (JavaScript)
element.textContent = userProvidedValue
```

#### RubyEncoder obfuscation
Source files contain RubyEncoder markers or other obfuscation.
```
Rejection: RubyEncoder obfuscation prevents review of the source code. Please submit without obfuscating the code.
```

#### Obfuscated or minified JavaScript
JavaScript files that are intentionally obfuscated (e.g. hexadecimal variable names, encoded string arrays, control flow flattening) or minified beyond readability, preventing security review.
```
Rejection: The JavaScript code is obfuscated/minified and cannot be reviewed for security. Please either submit readable JavaScript source code, or host the web page on your server and use set_url instead of set_file so the HTML content is sandboxed and not part of the review.
```

#### eval usage
`eval`, `instance_eval`, `class_eval`, `module_eval`, `Binding#eval` on untrusted input.
```
Rejection: `eval` is vulnerable to code injection attacks and should not be used.
https://ruby.sketchup.com/file.extension_requirements.html#label-Eval
```

#### Command injection via system commands
Any mechanism that executes an OS command — `system`, `exec`, backticks (`` ` ``), `%x{}`, `IO.popen`, `Open3` (`popen2`, `popen3`, `capture2`, `capture3`), `Process.spawn`, `Kernel.spawn`, `PTY.spawn` — where untrusted input is interpolated into the command string without proper sanitization.
Untrusted input includes: data from the SketchUp model (attribute dictionaries, entity names, component paths, file paths from `model.path`), server responses, user-provided strings (inputboxes, file dialogs), and environment variables set by other extensions.
**Not a rejection if:** The command is entirely hardcoded with no dynamic input, or uses the array form of `system`/`spawn`/`Open3` which bypasses shell interpolation (e.g. `system("cmd", arg1, arg2)`).
```
Rejection: Passing unsanitized input to a system command is a command injection vulnerability. An attacker who controls the input (e.g. via a malicious model file or compromised server) can execute arbitrary commands on the user's machine.

# Bad — shell interprets special characters
system("open #{user_path}")

# Good — array form bypasses the shell entirely
system("open", user_path)
```

#### Third-party update mechanism
Code that downloads and installs updates, bypassing EW review.
```
Rejection: SketchUp and Extension Warehouse has infrastructure for extension updates. Adding functionality that downloads and installs updates is not allowed as it bypasses the review.
https://ruby.sketchup.com/file.extension_requirements.html#label-Third+Party+Updates
```

#### Monkey-patching the SketchUp API
Reopening or modifying SketchUp API classes/modules (`Sketchup::Model`, `Geom::*`, `UI::*`, etc.).
```
Rejection: Since SketchUp extensions run in a shared environment, changing the modules and classes of the Ruby API from one extension can clash with another extension. Don't change these modules and classes.
https://ruby.sketchup.com/file.extension_requirements.html#label-Monkey+Patching+the+SketchUp+Ruby+API
```

#### Modifying $LOAD_PATH
```
Rejection: Don't modify the `$LOAD_PATH`. Doing so may cause other extensions to load the wrong files. Instead include your extension support folder name in the path whenever you load a file.
https://ruby.sketchup.com/file.extension_requirements.html#label-24LOAD_PATH
```

#### Modifying environment variables

```
Rejection: Don't modify environment variables. Doing so can cause other extensions to malfunction.
https://ruby.sketchup.com/file.extension_requirements.html#label-Environment+Variables
``` 

#### Using exit/exit!
```
Rejection: `exit` and `exit!` should not be used to stop the Ruby execution, as all Ruby extensions run in a shared interpreter. Instead use `return`, `next`, `break` or `raise` to stop the execution of your own code.
https://ruby.sketchup.com/file.extension_requirements.html#label-Exit
```

#### Attribute changes without undo wrapping
`set_attribute` and `delete_attribute` must always be wrapped in `model.start_operation` / `model.commit_operation`, even for a single call. Without wrapping, the undo entry falls back to a generic "Properties" label.
This also applies inside observers. Model changes within observers should use `start_operation`/`commit_operation` with the 4th argument set to `true` to make the operation transparent to the previous operation (e.g. `model.start_operation('Set Attributes', true, false, true)`).
```
Rejection: Attribute changes (set_attribute, delete_attribute) must be wrapped in model.start_operation and model.commit_operation. Without this, the undo entry shows a generic "Properties" label instead of a descriptive name.
https://ruby.sketchup.com/file.extension_requirements.html#label-Undo+Stack
```

#### Multiple model changes without undo wrapping
When code makes multiple model modifications in sequence (e.g. add_face + pushpull, creating multiple entities, changing material properties), these must be wrapped in `model.start_operation` / `model.commit_operation` so the user can undo them as a single step.
This also applies inside observers. Model changes within observers should use `start_operation`/`commit_operation` with the 4th argument set to `true` to make the operation transparent to the previous operation.
**Not a model modification:** Rendering options, camera, selection, and other transient view properties do not record to the undo stack and do not need wrapping.
```
Rejection: When your extension makes several model changes, join them together as one entry to the undo stack using model.start_operation and model.commit_operation. If the user activates it as a single high level action, let them also undo it in a single step.
https://ruby.sketchup.com/file.extension_requirements.html#label-Undo+Stack
```

#### Model changes not triggered by the user
If the extension causes changes to the SketchUp model that were not triggered by a user action.
Example: Writing attributes at model load
Allowed: Making model changes triggered by buttons and similar direct user actions
Allowed: Making model changes that responds to other model changes using observers
Not allowed: Making model changes when the extension loads, when a model is created or when a model is opened.
```
Rejection: Don't make model changes that are not initiated by the user. It adds to the undo stack and causes SketchUp to ask if the user wants to save when closing the model, even if they didn't do anything to it.
```

#### WebDialog
When the extension uses the WebDialog class.
**Exception:** It's only used as fallback when HtmlDialog is missing (SketchUp versions older to 2017).
**Exception:** It's only used as fallback for opening Extension Warehouse if `UI.show_extension_warehouse` is missing (SketchUp versions older than 206.1).
```
Rejection: WebDialog has been deprecated since SketchUp 2017. Use HtmlDialog instead, which works consistently across platforms and is actively maintained.
```

#### Extension name suggests SketchUp is the author
When the extension name starts with "SketchUp", e.g. "SketchUp MCP Server" or "SketchUp AI Render"
```
Rejection: The name "SketchUp {product name}" suggests SketchUp is the author of this extension. Prefer "{product name} for SketchUp" or similar to avoid such confusion.
```

#### File names suggest SketchUp is the author
When the extension root file/support folder starts with "su_" or "sketchup_"
```
Rejection: The prefix "su_" of the file names suggests SketchUp is the author. Please change to your name/your company name or remove the prefix.
```

#### Silent Purge Unused
If purge_unused is called without it being clearly initialized by the user
```
Rejection: purge_unused removes assets the user may want to use later. Only call it with the user's knowledge, e.g. from a button that says "Purge Unused". Never do it as a hidden side effect.
https://ruby.sketchup.com/file.extension_requirements.html#label-Data+Loss
```

#### Silent Save
If the active model is saved without it clearly being initialized by the user
```
Rejection: Never save the model without the user's knowledge. Saving the model behind the user's back can lead to data loss if they've made some destructive changes they did not intend to save. Only save the model with the user's knowledge, e.g. from a button that says "Save Model".
https://ruby.sketchup.com/file.extension_requirements.html#label-Data+Loss
```

### Notes

These are recommendations. They do not block publishing.

#### Using remote resource in file:// context
Flag when a WebDialog or HtmlDialog running in a local file:// context loads any remote resource. This includes:
- JavaScript network calls: `fetch`, `XMLHttpRequest`, `WebSocket`, `EventSource`
- Remote resource tags in HTML: `<script src="https://...">`, `<link href="https://...">`, `<img src="https://...">`
The dialog runs in a file:// context if:
- the dialog uses `set_html`
- the dialog uses `set_file`
**Not a flag if:** The dialog uses `set_url` pointing to a remote URL (the entire dialog is remote, not file://).
```
Note: Making network requests from local HTML files may be blocked in the future due to security concerns. Prefer choosing if each HtmlDialog is either using local or remote content, not both. To access remote APIs in a local HTML page, prefer making the network calls from Ruby, not JS.
```

#### Outdated copyright year
Check copyright year, if any, on the SketchupExtension#copyright attribute.
Ignore any code comments or file headers not visible to the end user.
```
Note: Your copyright year is outdated.
```

#### Dynamic copyright year
If copyright year is `Time.now.year`
```
Note: Prefer hardcoding the copyright year. Showing the current year can lead to confusion of what version the user is actually on.
```

#### SketchUp version compatibility check in root rb
If the sketchUpExtension setup is wrapped in a Sketchup.version check for compatibility.
```
Note: Prefer checking the SketchUp version inside the main file, not the root file. If the extension is disabled, the message should not be shown.
```

#### Reinventing Length handling
Hardcoded unit conversions instead of using SketchUp's Length class. Also flag when the UI (dialogs, labels, input fields) is hardcoded to a single unit (e.g. all labels say "m" or "mm") rather than using `Length#to_s` and `String#to_l` to respect the model's unit setting.
**Exception:** Ignore speeds (mph, km/h, m/s etc). SketchUp has no built in unit handling for this.
```
Note: When working with lengths in SketchUp, prefer using the power of the SketchUp Length class. Rather than using integers or floats and hard coding for a specific unit, prefer using Length internally, and Length#to_s and String#to_l to convert to and from strings in the UI. This way the extension automatically supports all the SketchUp length units, and by default uses the unit of the open model.
https://developer.sketchup.com/article-lengths-and-units
```

#### Very short namespace (initials)
Skip this note for known early developers who conventionally use initials (TT for ThomThom, AE for Aerelius, etc.).
```
Note: We noticed you have a very short name for your wrapping namespace module. While there is no rule against this, it does increase the risk of clashes with other developers. A full name or company name is better than just your initials.
```

#### Non-descriptive operation names
The string passed to `model.start_operation` should be in title case and descriptive of the change being made.
Good: Draw Cube
Also good: Cube
Bad: make_cube
Bad: cube
**Exception: ** Ignore when the 4th argument is true (`model.start_operation('after move wall', true, false, true)`). This hides this operation from the user.
```
Note: The string argument in model.start_operation is visible to the end user in the Undo/Redo menu entries. Prefer using more descriptive operation names.
```

#### Unsafe license check (Extension ID not locally hardcoded)
License check takes extension ID as a parameter or constant and not a locally hardcoded variable.
Only applies when the license check uses the `Sketchup::Licensing API`. Skip when developer implements their own system.
```
Note: It's recommended to hardcode the extension id as a local variable within the method doing the license check, as constants can be overwritten in Ruby.
```

#### Unsafe license check (Check in separate method)
License check is only made from a separate method.
A separate `licensed?` method can be used too, but should not be the only license check.
Only applies when the license check uses the `Sketchup::Licensing API`. Skip when developer implements their own system.
```
Note: It's recommended to do the license check inside of a core business method as a separate `licensed?` method can be overridden with one always returning `true`.
```

#### Silent rescue
`rescue` that swallows exceptions without logging or re-raising.
**Exception:** `rescue` blocks that print to the console ARE acceptable (see Console printing exception).
**Exception:** Rescuing `ArgumentError` (or similar) when setting rendering options to skip keys unsupported in the current SketchUp version is acceptable and should NOT be flagged.
```
Note: Avoid rescuing without doing anything with the error. Rescuing silently only hides potential bugs. It's better to not rescue at all and have the exception printed to the Ruby console. You may also use a UI.messagebox to display the error to the user.
```

#### Command capitalization
```
Note: Prefer using title case for command titles and sentence case (including trailing period) for the Command status_bar_text.
https://developer.sketchup.com/article-ux-guidelines
```

#### Raster icons
If PNGs are used for mouse cursors or toolbar icons.
**Exception:** ignore if the PNGs are only used as fallbacks in SU versions not supporting vector graphics.
```
Note: Prefer vector icons (SVG on Windows, PDF on Mac) over PNG icons. PNGs scale badly and look blurry on high resolution displays.
```

#### Solid icon background
Only flag icons where the background fills the entire image, with no transparent pixels along the edges.
```
Note: Avoid solid backgrounds on your command icons. It interferes with the style SketchUp uses for hovered buttons and makes it appear like the button is disabled and can't be clicked.
```

#### Writing to extension install directory
**Exception:** Obviously temporary data or log files can be ignored
```
Note: Avoid writing to the extension directory as it gets purged on extension update. You can instead create a folder in ENV['APPDATA'] or Dir.home. For temp files, you can use Sketchup.temp_dir.
```

#### Underscore in title
```
Note: Avoid underscore in extension titles. Underscore is used in code, not in user facing text.
```

---

## RuboCop Results

If `rubocop-results.json` exists, incorporate its findings. RuboCop offenses with `severity: "error"` and cop names starting with `SketchupRequirements/` map to rejections. Cross-reference with the rules above to use the correct wording. Don't duplicate — if RuboCop flags something already caught by your manual review, mention it once.
---

## Output Format

Write `review_report.txt` in exactly this structure:

Each rejection or note as its own paragraph, most severe first.
Use the exact template wording. Rejections above notes.

