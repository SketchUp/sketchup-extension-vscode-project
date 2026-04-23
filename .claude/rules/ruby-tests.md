---
paths:
  - "tests/**/*.rb"
---

# Ruby Tests

Tests use the [TestUp](https://github.com/SketchUp/testup-2) framework (`TestUp::TestCase`). Tests run inside SketchUp, not standalone Ruby.

## Test structure

Use the AAA pattern (Arrange, Act, Assert). Separate the sections with an empty line. Very small tests (1-2 lines total) can be compact.

```ruby
def test_offset
  point = Geom::Point3d.new(1, 2, 3)
  vector = Geom::Vector3d.new(10, 20, 30)

  result = point.offset(vector)

  assert_kind_of(Geom::Point3d, result)
  assert_equal(Geom::Point3d.new(11, 22, 33), result)
end
```

## Test granularity

Each test should verify one behavior. When a test fails, its name alone should tell you what broke. Prefer many small focused tests over fewer large ones — a full test run should give a complete picture of what works and what doesn't.

## Setup

Keep `setup` minimal and generic — only include what nearly every test in the class needs. Test-specific fixtures belong in dedicated helper methods below `setup`/`teardown`, called explicitly by the tests that need them.
