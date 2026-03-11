# Copyright 2016-2022 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'

module Examples
  module HelloCube

    class CubeTool

      PREVIEW_COLOR = Sketchup::Color.new(50, 100, 255, 64)
      EDGE_COLOR = Sketchup::Color.new(50, 100, 255, 192)
      EDGE_WIDTH = 2

      CANCEL_ESC        = 0
      CANCEL_REACTIVATE = 1
      CANCEL_UNDO       = 2

      STATE_PICK_FIRST  = 0
      STATE_PICK_SECOND = 1
      STATE_PICK_THIRD  = 2
      STATE_PICK_HEIGHT = 3

      def activate
        reset_tool
        update_ui
      end

      def deactivate(view)
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def resume(view)
        update_ui
        view.invalidate
      end

      def onCancel(reason, view)
        if reason == CANCEL_ESC && @state > STATE_PICK_FIRST
          @state -= 1
          @picked_points.pop
          @guide_ip.clear
        else
          reset_tool
        end
        update_ui
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        @mouse_ip.pick(view, x, y, @guide_ip)
        @mouse_pos = Geom::Point3d.new(x, y, 0)
        view.tooltip = @mouse_ip.tooltip
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        @mouse_ip.pick(view, x, y, @guide_ip)
        @guide_ip.copy!(@mouse_ip)
        @mouse_pos = Geom::Point3d.new(x, y, 0)

        case @state
        when STATE_PICK_FIRST
          @picked_points[0] = @mouse_ip.position
          @state = STATE_PICK_SECOND
        when STATE_PICK_SECOND
          @picked_points[1] = @mouse_ip.position
          @state = STATE_PICK_THIRD
        when STATE_PICK_THIRD
          @picked_points[2] = @mouse_ip.position
          @state = STATE_PICK_HEIGHT
        when STATE_PICK_HEIGHT
          @height_point = height_point_from_mouse(view)
          create_cube(view)
          reset_tool
        end

        update_ui
        view.invalidate
      end

      def getExtents
        bb = Geom::BoundingBox.new
        bb.add(@picked_points) unless @picked_points.empty?
        bb.add(@mouse_ip.position) if @mouse_ip.valid?
        if @last_preview
          bb.add(@last_preview[:base])
          bb.add(@last_preview[:top]) if @last_preview[:top]
        end
        bb
      end

      def draw(view)
        @last_preview = preview_geometry(view)
        draw_preview(view, @last_preview)
        @mouse_ip.draw(view) if @mouse_ip.display?
      end

      private

      def reset_tool
        @picked_points = []
        @height_point = nil
        @mouse_ip = Sketchup::InputPoint.new
        @guide_ip = Sketchup::InputPoint.new
        @mouse_pos = Geom::Point3d.new(0, 0, 0)
        @last_preview = nil
        @state = STATE_PICK_FIRST
      end

      # Returns a point used by compute_top_quad to determine the height.
      # Prefers the InputPoint position when it snaps to geometry; otherwise
      # projects the mouse ray onto the base normal axis.
      def height_point_from_mouse(view)
        # When the InputPoint snapped to geometry, use its position directly.
        if @mouse_ip.vertex || @mouse_ip.edge || @mouse_ip.face
          return @mouse_ip.position
        end

        base = compute_base_quad(@picked_points[0], @picked_points[1],
                                 @picked_points[2])
        normal = compute_quad_normal(base)
        return @mouse_ip.position if normal.length.zero?

        center = Geom::Point3d.new(
          (base[0].x + base[2].x) / 2.0,
          (base[0].y + base[2].y) / 2.0,
          (base[0].z + base[2].z) / 2.0
        )

        ray = view.pickray(@mouse_pos.x, @mouse_pos.y)

        # Use closest_points between the mouse ray and the normal axis line.
        axis_line = [center, normal]
        mouse_line = [ray[0], ray[1]]
        closest = Geom.closest_points(axis_line, mouse_line)
        closest[0]
      end

      def update_ui
        case @state
        when STATE_PICK_FIRST
          Sketchup.status_text = 'Pick first corner of the base rectangle.'
        when STATE_PICK_SECOND
          Sketchup.status_text = 'Pick second corner of the base rectangle.'
        when STATE_PICK_THIRD
          Sketchup.status_text = 'Pick third corner to define base width.'
        when STATE_PICK_HEIGHT
          Sketchup.status_text = 'Pick a point to define the height.'
        end
      end

      # Returns a hash with :base (4 points) and optionally :top (4 points)
      # based on the current state and mouse position.
      def preview_geometry(view = nil)
        return nil unless @mouse_ip.valid?

        mouse = @mouse_ip.position

        case @state
        when STATE_PICK_SECOND
          nil
        when STATE_PICK_THIRD
          base = compute_base_quad(@picked_points[0], @picked_points[1], mouse)
          { base: base, top: nil }
        when STATE_PICK_HEIGHT
          base = compute_base_quad(@picked_points[0], @picked_points[1],
                                   @picked_points[2])
          height_pt = view ? height_point_from_mouse(view) : mouse
          top = compute_top_quad(base, height_pt)
          { base: base, top: top }
        end
      end

      def draw_preview(view, geom)
        # Draw picked edges before we have a full base quad.
        if @state == STATE_PICK_SECOND && @mouse_ip.valid?
          draw_edges(view, [@picked_points[0], @mouse_ip.position])
        end

        return unless geom

        base = geom[:base]
        top = geom[:top]

        # Draw base face.
        draw_filled_quad(view, base)
        draw_edge_loop(view, base)

        return unless top

        # Draw top face.
        draw_filled_quad(view, top)
        draw_edge_loop(view, top)

        # Draw vertical edges.
        4.times do |i|
          draw_edges(view, [base[i], top[i]])
        end

        # Draw side faces.
        4.times do |i|
          j = (i + 1) % 4
          draw_filled_quad(view, [base[i], base[j], top[j], top[i]])
        end
      end

      def draw_filled_quad(view, quad)
        view.drawing_color = PREVIEW_COLOR
        view.draw(GL_TRIANGLE_FAN, quad)
      end

      def draw_edge_loop(view, quad)
        view.line_stipple = ''
        view.line_width = EDGE_WIDTH
        view.drawing_color = EDGE_COLOR
        edges = quad + [quad[0]]
        view.draw(GL_LINE_STRIP, edges)
      end

      def draw_edges(view, pts)
        return if pts.length < 2

        view.line_stipple = ''
        view.line_width = EDGE_WIDTH
        view.drawing_color = EDGE_COLOR
        view.draw(GL_LINE_STRIP, pts)
      end

      # Computes the four base corners from the first two picked points and a
      # third point that defines the width perpendicular to the first edge.
      def compute_base_quad(pt1, pt2, pt3)
        edge_vec = pt2 - pt1
        return [pt1, pt1, pt1, pt1] if edge_vec.length.zero?

        # Subtract the component of (pt3 - pt1) along the first edge to get
        # the perpendicular offset that defines the rectangle width.
        edge_unit = edge_vec.normalize
        to_pt3 = pt3 - pt1
        proj_along = to_pt3 % edge_unit
        perp_vec = Geom::Vector3d.new(
          to_pt3.x - edge_unit.x * proj_along,
          to_pt3.y - edge_unit.y * proj_along,
          to_pt3.z - edge_unit.z * proj_along
        )

        p1 = pt1
        p2 = pt2
        p3 = Geom::Point3d.new(pt2.x + perp_vec.x, pt2.y + perp_vec.y,
                                pt2.z + perp_vec.z)
        p4 = Geom::Point3d.new(pt1.x + perp_vec.x, pt1.y + perp_vec.y,
                                pt1.z + perp_vec.z)
        [p1, p2, p3, p4]
      end

      # Extrude the base quad upward (along base normal) to match the height
      # implied by the mouse position.
      def compute_top_quad(base, mouse_pt)
        normal = compute_quad_normal(base)
        return base.dup if normal.length.zero?

        # Project mouse onto the normal direction from the base center.
        center = Geom::Point3d.new(
          (base[0].x + base[2].x) / 2.0,
          (base[0].y + base[2].y) / 2.0,
          (base[0].z + base[2].z) / 2.0
        )
        to_mouse = mouse_pt - center
        height = to_mouse % normal # signed projection
        offset = Geom::Vector3d.new(
          normal.x * height,
          normal.y * height,
          normal.z * height
        )
        base.map { |pt|
          Geom::Point3d.new(pt.x + offset.x, pt.y + offset.y, pt.z + offset.z)
        }
      end

      def compute_quad_normal(quad)
        v1 = quad[1] - quad[0]
        v2 = quad[3] - quad[0]
        normal = v1 * v2 # cross product
        return normal if normal.length.zero?

        normal.normalize
      end

      def create_cube(view)
        base = compute_base_quad(@picked_points[0], @picked_points[1],
                                 @picked_points[2])
        distance = compute_height(base, @height_point)
        return if distance.zero?

        model = view.model
        model.start_operation('Create Cube', true)
        group = model.active_entities.add_group
        face = group.entities.add_face(base)
        # The face normal may differ from our computed normal due to
        # SketchUp auto-flipping. Compare them to get the right direction.
        expected_normal = compute_quad_normal(base)
        same_direction = (face.normal % expected_normal) > 0
        face.pushpull(same_direction ? distance : -distance)
        model.commit_operation
      end

      def compute_height(base, point)
        normal = compute_quad_normal(base)
        return 0.0 if normal.length.zero?

        center = Geom::Point3d.new(
          (base[0].x + base[2].x) / 2.0,
          (base[0].y + base[2].y) / 2.0,
          (base[0].z + base[2].z) / 2.0
        )
        (point - center) % normal
      end

    end # class CubeTool

  end # module HelloCube
end # module Examples
