---
paths:
  - "src/**/*.rb"
  - "tests/**/*.rb"
---

# SketchUp Fundamentals

## Coordinate System

SketchUp uses a right-handed coordinate system where **Z is up**. The axes are: X (red) = right, Y (green) = forward/into screen, Z (blue) = up. Do not confuse this with Y-up systems used by some other 3D applications.

## Units

SketchUp's internal unit is **inches**. All geometric values (points, vectors, distances) are stored in inches internally. The `Length` class handles display formatting — `Length#to_s` formats the value to the user's chosen model units (e.g., millimeters, meters, feet).

Use SketchUp's helper methods on `Numeric`, `String`, `Array`, and `Length` for unit conversions rather than manual arithmetic:
- `10.mm` — converts 10 millimeters to inches (internal unit).
- `45.degrees` — converts 45 degrees to radians (used by the API for angles).
- `"2m".to_l` — parses a string with units into a `Length` in inches.
See the full list of helpers in the SketchUp Ruby API documentation for `Numeric`, `String`, `Array`, and `Length`.
