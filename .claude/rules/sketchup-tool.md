---
paths:
  - "src/**/*.rb"
---

# Sketchup::Tool Patterns

- Keep implementations slim. Treat tools as controllers and place the business logic in other files/classes/modules.
- Initialize all instance variables in `initialize`, not just in `activate` or a reset method. This ensures tools have a well-defined initial state. Use meaningful defaults (`nil`, `[]`, an empty hash, or a sensible zero value) and annotate the intended type with YARD — e.g. `@return [Geom::Point3d, nil]` for a nil-initialized slot, `@return [Array<Sketchup::Face>]` for a collection. See the YARD guidance in `ruby-code-style` for details.
- Remember to implement `getExtents` when drawing to the viewport. If you draw outside the model bounds the drawing will be clipped if a custom bound is not provided.
- Always call `view.invalidate` in both `deactivate` and `suspend` callbacks, in addition to the other callbacks that modify state. This is flagged by the `SketchupSuggestions/ToolInvalidate` RuboCop cop.
- For multi-step input: use a second `Sketchup::InputPoint` as a guide and pass it to the primary InputPoint's `pick` method for snapping inference. Copy the primary InputPoint to the guide after each accepted click.
- When `InputPoint` may not snap to geometry (e.g., looking top-down during a height pick), fall back to projecting the mouse ray onto the constraint axis using `view.pickray` and `Geom.closest_points`.
- Update the statusbar text (`Sketchup.status_text=`) whenever the tool state changes. The statusbar should tell the user what action to take next (e.g., "Click to set the start point", "Click to set the end point").
- In `onCancel`, check the `reason` parameter: `0` = ESC key, `1` = reactivate, `2` = undo. ESC should typically step back one state; other reasons should fully reset the tool.
- `view.invalidate` is meant to be used from within a `Sketchup::Tool` to signal that the view should redraw. If you find yourself using this outside of a tool to trigger a refresh it's an indication of a bug in SketchUp and we ask you to log a bug report.
- Use `view.invalidate` instead of `view.refresh`. `view.refresh` forces a redraw and can lead to poor performance and other bad side effects. Don't use unless you have a really good reason to workaround some viewport update issues.
