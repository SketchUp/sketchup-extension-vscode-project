# Copyright 2016-2022 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'

Sketchup.require('ex_hello_cube/cube_tool')

module Examples
  module HelloCube

    def self.create_cube
      model = Sketchup.active_model
      model.start_operation('Create Cube', true)
      group = model.active_entities.add_group
      entities = group.entities
      points = [
        Geom::Point3d.new(0,   0,   0),
        Geom::Point3d.new(1.m, 0,   0),
        Geom::Point3d.new(1.m, 1.m, 0),
        Geom::Point3d.new(0,   1.m, 0)
      ]
      face = entities.add_face(points)
      face.pushpull(-1.m)
      model.commit_operation
    end

    def self.activate_cube_tool
      Sketchup.active_model.select_tool(CubeTool.new)
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      menu.add_item('Create Cube Example') {
        self.create_cube
      }
      menu.add_item('Draw Cube Tool') {
        self.activate_cube_tool
      }
      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples
