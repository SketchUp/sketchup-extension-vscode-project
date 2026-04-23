---
paths:
  - "src/**/*.rb"
---

# SketchUp Geometry Authoring

- When creating groups with non-axis-aligned geometry, set a `Geom::Transformation` on the group so the geometry is axis-aligned in local space. This makes the group's bounding box tightly fit the geometry. Use `Geom::Transformation.axes` to build the local coordinate system.
- Prefer `pushpull` on a base face over manually creating all six faces of a box. It handles face orientation correctly and is less error-prone.

## Face orientation and winding order

SketchUp faces have a front and back side. For a free-standing, non-horizontal face, the front is determined by vertex winding order: counter-clockwise winding (when viewed from the front) puts the front toward the viewer. SketchUp overrides this in two situations:

- **Ground plane (faces lying exactly on Z = 0):** SketchUp forces the front to face down (-Z) regardless of winding order. A face built on the ground plane will need `face.reverse!` if you want the front facing up. This override is specific to Z = 0 — a horizontal face at any other elevation follows winding normally.
- **Connected to existing geometry:** when a new face shares edges with existing faces, SketchUp orients it to be consistent with its neighbors, overriding winding order.

Because of these overrides, don't rely on winding order alone. After creating a face, check `face.normal` and call `face.reverse!` if the orientation isn't what you need. In particular, check `face.normal` against the intended extrusion direction before `pushpull` — the sign of the distance you pass is relative to the face normal, so a face that points the wrong way will extrude the wrong direction.

## Curves and follow-me

- Use the high-level constructors for curved edges: `entities.add_arc`, `entities.add_circle`, `entities.add_ngon`. They return an array of edges that SketchUp internally tags as a single curve, which preserves smooth rendering and enables subsequent operations (e.g. `face.followme`) to treat the curve as a unit.
- For follow-me extrusions, use `face.followme(path)` where `path` is an edge or an array of edges. Orient the profile face perpendicular to the first segment of the path before calling `followme` — otherwise the swept geometry will be skewed.
