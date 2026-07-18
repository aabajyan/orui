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
	panel_rect := rl.Rectangle{340, 170, 280, 260}
	resizing := false

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({24, 26, 32, 255})
		orui.begin(ctx, rl.GetScreenWidth(), rl.GetScreenHeight())

		orui.label(
			orui.id("instructions"),
			"Drag panel's thin left border. ORUI keeps the right edge fixed, and the hit area extends 10px outside the visible border.",
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
					position = {.Fixed, {panel_rect.x, panel_rect.y}},
					width = orui.fixed(panel_rect.width),
					height = orui.fixed(panel_rect.height),
					direction = .TopToBottom,
					padding = orui.padding(20),
					gap = 12,
					background_color = {48, 54, 68, 255},
					border = {left = 2, top = 1, right = 1, bottom = 1},
					border_color = resizing ? rl.ORANGE : rl.GRAY,
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
				fmt.tprintf(
					"x %.0f  width %.0f  resizing %v",
					panel_rect.x,
					panel_rect.width,
					resizing,
				),
				{width = orui.grow(), font_size = 16, color = rl.LIGHTGRAY},
			)
		}
		resizing = orui.resizable(
			panel_id,
			{.Left},
			&panel_rect,
			min_width = MIN_PANEL_WIDTH,
			hit_size = HIT_SLOP * 2,
		)

		for command in orui.end() {
			orui.render_command(command)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
