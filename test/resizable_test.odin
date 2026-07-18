package orui_test

import orui "../src"
import "core:testing"
import rl "vendor:raylib"

@(private = "file")
resizable_test_frame :: proc(
	ctx: ^orui.Context,
	panel_id, background_id: orui.Id,
	rect: ^rl.Rectangle,
	edges: orui.Resize_Edges,
	input: orui.Input_Frame,
	min_width: f32 = 0,
	max_width: f32 = 0,
	min_height: f32 = 0,
	max_height: f32 = 0,
) -> bool {
	orui.begin_with_input(ctx, 500, 400, 0, input)
	{orui.container(
			orui.id(background_id),
			{
				position = {.Fixed, {}},
				width = orui.fixed(500),
				height = orui.fixed(400),
				layer = 1,
			},
		)}
	{orui.container(
			orui.id(panel_id),
			{
				position = {.Fixed, {rect.x, rect.y}},
				width = orui.fixed(rect.width),
				height = orui.fixed(rect.height),
				layer = 2,
			},
		)}
	active := orui.resizable(
		panel_id,
		edges,
		rect,
		min_width = min_width,
		max_width = max_width,
		min_height = min_height,
		max_height = max_height,
	)
	orui.end()
	return active
}

@(test)
resizable_left_edge_keeps_right_edge_fixed_when_clamped :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	panel_id := orui.to_id("resizable left panel")
	background_id := orui.to_id("resizable background")
	rect := rl.Rectangle{100, 50, 200, 150}
	edges := orui.Resize_Edges{.Left}

	resizable_test_frame(ctx, panel_id, background_id, &rect, edges, {})
	active := resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {100, 125},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		min_width = 120,
	)
	testing.expect(t, active)

	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {140, 125}},
		min_width = 120,
	)
	expect_f32(t, rect.x, 140, "left edge")
	expect_f32(t, rect.width, 160, "width")
	expect_f32(t, rect.x + rect.width, 300, "fixed right edge")

	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {260, 125}},
		min_width = 120,
	)
	expect_f32(t, rect.x, 180, "clamped left edge")
	expect_f32(t, rect.width, 120, "clamped width")
	expect_f32(t, rect.x + rect.width, 300, "fixed right edge after clamp")
}

@(test)
resizable_top_edge_keeps_bottom_edge_fixed_when_clamped :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	panel_id := orui.to_id("resizable top panel")
	background_id := orui.to_id("resizable top background")
	rect := rl.Rectangle{100, 50, 200, 150}
	edges := orui.Resize_Edges{.Top}

	resizable_test_frame(ctx, panel_id, background_id, &rect, edges, {})
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {200, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		min_height = 100,
	)
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {200, 130}},
		min_height = 100,
	)

	expect_f32(t, rect.y, 100, "clamped top edge")
	expect_f32(t, rect.height, 100, "clamped height")
	expect_f32(t, rect.y + rect.height, 200, "fixed bottom edge after clamp")
}

@(test)
resizable_bottom_right_corner_grows_both_axes_without_max :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	panel_id := orui.to_id("resizable bottom right panel")
	background_id := orui.to_id("resizable bottom right background")
	rect := rl.Rectangle{100, 50, 200, 150}
	edges := orui.Resize_Edges{.Right, .Bottom}

	resizable_test_frame(ctx, panel_id, background_id, &rect, edges, {})
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {300, 200},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {380, 270}},
	)

	expect_f32(t, rect.x, 100, "fixed left edge")
	expect_f32(t, rect.y, 50, "fixed top edge")
	expect_f32(t, rect.width, 280, "grown width")
	expect_f32(t, rect.height, 220, "grown height")
}

@(test)
resizable_positive_max_clamps_bottom_right_corner :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	panel_id := orui.to_id("resizable max panel")
	background_id := orui.to_id("resizable max background")
	rect := rl.Rectangle{100, 50, 200, 150}
	edges := orui.Resize_Edges{.Right, .Bottom}

	resizable_test_frame(ctx, panel_id, background_id, &rect, edges, {})
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {300, 200},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		max_width = 250,
		max_height = 180,
	)
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {400, 300}},
		max_width = 250,
		max_height = 180,
	)

	expect_f32(t, rect.width, 250, "maximum width")
	expect_f32(t, rect.height, 180, "maximum height")
}

@(test)
resizable_corner_owns_drag_and_releases_session :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	panel_id := orui.to_id("resizable routed panel")
	background_id := orui.to_id("resizable routed background")
	rect := rl.Rectangle{100, 50, 200, 150}
	edges := orui.Resize_Edges{.Left, .Bottom}

	resizable_test_frame(ctx, panel_id, background_id, &rect, edges, {})
	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {100, 200},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, .Pressed not_in orui.pointer_response(background_id))

	resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {80, 220}},
	)
	expect_f32(t, rect.x, 80, "dragged left edge")
	expect_f32(t, rect.width, 220, "dragged width")
	expect_f32(t, rect.height, 170, "dragged height")

	active_on_release := resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{
			pointer_position = {80, 220},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, active_on_release)
	active_after_release := resizable_test_frame(
		ctx,
		panel_id,
		background_id,
		&rect,
		edges,
		{pointer_position = {20, 20}},
	)
	testing.expect(t, !active_after_release)
}
