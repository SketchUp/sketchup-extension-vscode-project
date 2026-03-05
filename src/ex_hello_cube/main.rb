# Copyright 2016-2022 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'

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

    # Returns the platform-appropriate file extension for vector icons.
    def self.icon_extension
      Sketchup.platform == :platform_win ? 'svg' : 'pdf'
    end

    # Returns the full path to an icon file in the images folder.
    def self.icon_path(basename)
      ext = icon_extension
      File.join(__dir__, 'images', "#{basename}.#{ext}")
    end

    unless file_loaded?(__FILE__)
      menu = UI.menu('Plugins')
      menu.add_item('Create Cube Example') {
        self.create_cube
      }

      toolbar = UI::Toolbar.new('Hello Cube')
      cmd = UI::Command.new('Create Cube') {
        self.create_cube
      }
      cmd.small_icon = icon_path('create_cube')
      cmd.large_icon = icon_path('create_cube')
      cmd.tooltip = 'Create Cube'
      cmd.status_bar_text = 'Creates a 1m cube at the origin.'
      toolbar.add_item(cmd)
      toolbar.show

      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples
