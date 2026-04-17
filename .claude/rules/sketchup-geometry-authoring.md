---
paths:
  - "src/**/*.rb"
---

# SketchUp Geometry Authoring

- When creating groups with non-axis-aligned geometry, set a `Geom::Transformation` on the group so the geometry is axis-aligned in local space. This makes the group's bounding box tightly fit the geometry. Use `Geom::Transformation.axes` to build the local coordinate system.
- Prefer `pushpull` on a base face over manually creating all six faces of a box. It handles face orientation correctly and is less error-prone. Check `face.normal` against the expected direction to determine the sign of the pushpull distance.
