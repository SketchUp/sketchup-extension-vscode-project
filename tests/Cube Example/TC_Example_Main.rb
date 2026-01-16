require 'testup/testcase'

require 'ex_hello_cube/main'

module Examples
module Tests

class TC_Main < TestUp::TestCase

  def setup
    start_with_empty_model
  end

  def teardown
    # ...
  end


  def test_create_cube
    model = Sketchup.active_model
    entities = model.active_entities
    assert_equal(0, entities.size)

    HelloCube.create_cube

    assert_equal(1, entities.size)
    group = entities.first
    assert_kind_of(Sketchup::Group, group)

    assert_equal(18, group.entities.size)
    assert_equal(12, group.entities.grep(Sketchup::Edge).size)
    assert_equal(6, group.entities.grep(Sketchup::Face).size)

    bounds = group.bounds
    assert_equal(ORIGIN, bounds.min)
    assert_equal(Geom::Point3d.new(1.0.m, 1.0.m, 1.0.m), bounds.max)
  end # test

end # class

end # module Tests
end # module Example
