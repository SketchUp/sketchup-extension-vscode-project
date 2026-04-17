---
paths:
  - "src/**/*.rb"
---

# Ruby Performance

- Prefer bulk methods for performance. Slow: `entities.each { |e| selection.add(e) if e.is_a?(Sketchup::Face) }`. Fast: `selection.add(entities.grep(Sketchup::Face))`.
- Don't modify the container you iterate: Bad: `model.entities.each { |e| e.erase! }`. Safe (using a copy): `model.entities.to_a.each { |e| e.erase! }`. Best (performance): `model.entities.erase_entities(array_of_entities_to_erase)`.
- Don't use `entity.typename == 'Face'` to check for types, it is _very_ slow. Use the type system: `entity.is_a?(Sketchup::Face)`.
- Prefer SketchUp API geometry methods over manual component arithmetic — they are implemented in C++ and faster:
  - `pt1.vector_to(pt2)` instead of `pt2 - pt1` for vectors between points.
  - `pt.offset(vec)` or `pt.offset(vec, distance)` instead of manually adding components.
  - `v1.dot(v2)` and `v1.cross(v2)` instead of `%` and `*` operators for readability.
  - `Geom.linear_combination(w1, pt1, w2, pt2)` for weighted point interpolation (e.g., midpoints).
