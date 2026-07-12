package demo

import orui "../../src"
import "core:fmt"
import rl "vendor:raylib"

HIT_SLOP: f32 : 10
MIN_PANEL_WIDTH: f32 : 180

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(900, 600, "orui pointer routing")
	defer rl.CloseWindow()

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)
	ctx.default_font = rl.GetFontDefault()

	panel_id := orui.to_id("resizable panel")
	panel_x := f32(340)
	panel_width := f32(280)
	dragging := false
	drag_start_mouse_x: f32
	drag_start_x: f32
	drag_start_width: f32

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({24, 26, 32, 255})
		orui.begin(ctx, rl.GetScreenWidth(), rl.GetScreenHeight())

		panel_bounds := orui.bounding_rect(panel_id)
		mouse := orui.pointer_position()
		response := orui.pointer_response(panel_id)
		left_edge := rl.Rectangle {
			panel_bounds.x - HIT_SLOP,
			panel_bounds.y,
			HIT_SLOP * 2,
			panel_bounds.height,
		}
		over_left_edge := .Hovered in response && rl.CheckCollisionPointRec(mouse, left_edge)

		if .Pressed in response && over_left_edge {
			dragging = true
			drag_start_mouse_x = mouse.x
			drag_start_x = panel_x
			drag_start_width = panel_width
		}

		if dragging {
			if .Released in response {
				dragging = false
			} else {
				delta := mouse.x - drag_start_mouse_x
				panel_width = max(MIN_PANEL_WIDTH, drag_start_width - delta)
				panel_x = drag_start_x + drag_start_width - panel_width
			}
		}

		orui.label(
			orui.id("instructions"),
			"Drag panel's thin left border. Hit area extends 10px outside visible border. Child content still routes press to panel.",
			{
				position = {.Fixed, {48, 48}},
				width = orui.fixed(600),
				font_size = 20,
				color = {230, 232, 240, 255},
				overflow = .Wrap,
			},
		)

		{orui.container(
				orui.id(panel_id),
				{
					position = {.Fixed, {panel_x, 170}},
					width = orui.fixed(panel_width),
					height = orui.fixed(260),
					direction = .TopToBottom,
					padding = orui.padding(20),
					gap = 12,
					background_color = {48, 54, 68, 255},
					border = {left = 2, top = 1, right = 1, bottom = 1},
					border_color = over_left_edge || dragging ? rl.ORANGE : rl.GRAY,
				},
			)
			orui.label(
				orui.id("panel title"),
				"Existing ORUI element",
				{width = orui.grow(), font_size = 22, color = rl.RAYWHITE},
			)
			orui.label(
				orui.id("nested child"),
				"Nested child fills panel. pointer_response routes child interaction to panel ID.",
				{
					width = orui.grow(),
					height = orui.grow(),
					padding = orui.padding(16),
					font_size = 18,
					color = {210, 215, 228, 255},
					background_color = {36, 40, 50, 255},
					overflow = .Wrap,
				},
			)
			orui.label(
				orui.id("panel status"),
				fmt.tprintf("x %.0f  width %.0f  dragging %v", panel_x, panel_width, dragging),
				{width = orui.grow(), font_size = 16, color = rl.LIGHTGRAY},
			)
		}
		orui.set_hit_slop(panel_id, {left = HIT_SLOP})

		for command in orui.end() {
			orui.render_command(command)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
