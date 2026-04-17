---
paths:
  - "src/**/*.rb"
---

# SketchUp Model Undo Operations

Any change to the SketchUp model must be wrapped in a `model.start_operation` / `model.commit_operation` pair so the user can undo it as a single step.

## Rules

- Always wrap model-modifying operations in `model.start_operation` / `model.commit_operation`.
- Writing attributes (`entity.set_attribute`, `entity.attribute_dictionary('mydict')['key'] = 123`) are model changes and also must be wrapped.
- Golden rule of undo handling: "One user action should be undoable in a single undo step".
- The string passed to `model.start_operation` appears in the UI (`Edit -> Undo <Operation Name>`). Keep it short and human friendly.
- If the extension makes model changes in an observer callback, make the undo operation transparent by setting the fourth argument to `true`: `model.start_operation('Update Attributes', true, false, true)`.
- The third argument in `model.start_operation` is deprecated and _should not_ be used.
- Disable UI updates for the span of the operation by setting the second argument: `model.start_operation('Create Cube', true)`.
