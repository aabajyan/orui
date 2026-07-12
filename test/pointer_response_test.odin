package orui_test

import orui "../src"
import "core:testing"
import rl "vendor:raylib"

@(private = "file")
pointer_response_test_frame :: proc(ctx: ^orui.Context, input: orui.Input_Frame) {
	orui.begin_with_input(ctx, 300, 300, 0, input)
	{orui.container(
			orui.id("response background"),
			{position = {.Fixed, {}}, width = orui.fixed(300), height = orui.fixed(300), layer = 1},
		)}
	{orui.container(
			orui.id("response target"),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100), layer = 2},
		)}
	orui.end()
}

@(private = "file")
pointer_response_route_test_frame :: proc(ctx: ^orui.Context, input: orui.Input_Frame) {
	orui.begin_with_input(ctx, 300, 300, 0, input)
	{orui.container(
			orui.id("response route background"),
			{position = {.Fixed, {}}, width = orui.fixed(300), height = orui.fixed(300), layer = 1},
		)}
	{orui.container(
			orui.id("response route parent"),
			{
				position = {.Fixed, {50, 50}},
				width = orui.fixed(200),
				height = orui.fixed(200),
				padding = orui.padding(50),
				layer = 2,
			},
		)
		orui.container(orui.id("response route child"), {width = orui.grow(), height = orui.grow()})
	}
	orui.end()
}

@(test)
pointer_response_routes_press_to_target_and_ancestors :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("response route background")
	parent_id := orui.to_id("response route parent")
	child_id := orui.to_id("response route child")
	pointer_response_route_test_frame(ctx, {})
	pointer_response_route_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Pressed in orui.pointer_response(child_id))
	testing.expect(t, .Pressed in orui.pointer_response(parent_id))
	testing.expect(t, .Held in orui.pointer_response(child_id))
	testing.expect(t, .Held in orui.pointer_response(parent_id))
	testing.expect(t, .Pressed not_in orui.pointer_response(background_id))
	testing.expect_value(t, orui.pointer_position(), rl.Vector2{150, 150})
}

@(test)
pointer_response_keeps_owner_held_outside_and_suppresses_hover :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	target_id := orui.to_id("response target")
	background_id := orui.to_id("response background")
	pointer_response_test_frame(ctx, {})
	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, .Pressed in orui.pointer_response(target_id))

	pointer_response_test_frame(ctx, {pointer_position = {20, 20}})
	testing.expect(t, .Held in orui.pointer_response(target_id))
	testing.expect(t, .Hovered not_in orui.pointer_response(target_id))
	testing.expect(t, .Hovered not_in orui.pointer_response(background_id))
}

@(test)
pointer_response_clicks_only_when_owner_releases_inside :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	target_id := orui.to_id("response target")
	pointer_response_test_frame(ctx, {})
	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, .Released in orui.pointer_response(target_id))
	testing.expect(t, .Clicked in orui.pointer_response(target_id))
	testing.expect(t, .Held not_in orui.pointer_response(target_id))

	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, .Released in orui.pointer_response(target_id))
	testing.expect(t, .Clicked not_in orui.pointer_response(target_id))
}

@(test)
pointer_response_ignores_other_buttons_until_owner_releases :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	target_id := orui.to_id("response target")
	pointer_response_test_frame(ctx, {})
	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .RIGHT, kind = .Pressed}},
		},
	)
	testing.expect(t, .Pressed in orui.pointer_response(target_id, .RIGHT))
	testing.expect(t, .Held in orui.pointer_response(target_id, .RIGHT))

	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, .Pressed not_in orui.pointer_response(target_id, .LEFT))
	testing.expect(t, .Held in orui.pointer_response(target_id, .RIGHT))
	testing.expect(t, orui.pointer_response(orui.to_id("response background"), .LEFT) == {})

	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, .Held in orui.pointer_response(target_id, .RIGHT))

	pointer_response_test_frame(
		ctx,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .RIGHT, kind = .Released}},
		},
	)
	testing.expect(t, .Released in orui.pointer_response(target_id, .RIGHT))
	testing.expect(t, .Held not_in orui.pointer_response(target_id, .RIGHT))
}

@(test)
pointer_response_routes_through_nonblocking_visual_child :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("nonblocking parent")
	child_id := orui.to_id("nonblocking child")
	orui.begin_with_input(ctx, 300, 300, 0, {})
	{orui.container(
			orui.id(parent_id),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100)},
		)
		orui.container(orui.id(child_id), {width = orui.grow(), height = orui.grow(), block = .False})
	}
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		300,
		0,
		{
			pointer_position = {150, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	{orui.container(
			orui.id(parent_id),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100)},
		)
		orui.container(orui.id(child_id), {width = orui.grow(), height = orui.grow(), block = .False})
	}
	orui.end()

	testing.expect(t, .Pressed in orui.pointer_response(parent_id))
	testing.expect(t, orui.pointer_response(child_id) == {})
}

@(test)
pointer_state_routes_from_child_to_parent :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("parent")
	child_id := orui.to_id("child")
	orui.begin(ctx, 200, 200, 0)
	{orui.container(
			orui.id(parent_id),
			{
				position = {.Fixed, {40, 40}},
				width = orui.fixed(120),
				height = orui.fixed(120),
				padding = orui.padding(20),
			},
		)
		orui.container(orui.id(child_id), {width = orui.grow(), height = orui.grow()})
	}
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		200,
		0,
		{
			pointer_position = {100, 100},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Hovered in orui.pointer_response(parent_id))
	testing.expect(t, .Pressed in orui.pointer_response(parent_id))
	testing.expect(t, .Hovered in orui.pointer_response(child_id))
	testing.expect(t, .Pressed in orui.pointer_response(child_id))
	testing.expect(t, orui.pointer_response(orui.to_id("other")) == {})
	orui.end()
}

@(test)
hit_slop_routes_press_without_changing_layout_bounds :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	target_id := orui.to_id("target")
	orui.begin(ctx, 300, 300, 0)
	{orui.container(
			orui.id(background_id),
			{position = {.Fixed, {}}, width = orui.fixed(300), height = orui.fixed(300), layer = 1},
		)
	}
	{orui.container(
			orui.id(target_id),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100), layer = 2},
		)
	}
	orui.set_hit_slop(target_id, {left = 10})
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		300,
		0,
		{
			pointer_position = {95, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Pressed in orui.pointer_response(target_id))
	testing.expect(t, .Pressed not_in orui.pointer_response(background_id))
	bounds := orui.bounding_rect(target_id)
	testing.expect_value(t, bounds.x, f32(100))
	testing.expect_value(t, bounds.y, f32(100))
	testing.expect_value(t, bounds.width, f32(100))
	testing.expect_value(t, bounds.height, f32(100))
	orui.end()
}

@(test)
higher_layer_blocks_hit_slop :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	target_id := orui.to_id("target")
	blocker_id := orui.to_id("blocker")
	orui.begin(ctx, 300, 300, 0)
	{orui.container(
			orui.id(target_id),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100), layer = 2},
		)
	}
	orui.set_hit_slop(target_id, {left = 10})
	{orui.container(
			orui.id(blocker_id),
			{position = {.Fixed, {90, 140}}, width = orui.fixed(20), height = orui.fixed(20), layer = 3},
		)
	}
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		300,
		0,
		{
			pointer_position = {95, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Pressed in orui.pointer_response(blocker_id))
	testing.expect(t, .Pressed not_in orui.pointer_response(target_id))
	orui.end()
}

@(test)
pointer_outside_hit_slop_routes_to_element_behind :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	target_id := orui.to_id("target")
	orui.begin(ctx, 300, 300, 0)
	{orui.container(
			orui.id(background_id),
			{position = {.Fixed, {}}, width = orui.fixed(300), height = orui.fixed(300), layer = 1},
		)
	}
	{orui.container(
			orui.id(target_id),
			{position = {.Fixed, {100, 100}}, width = orui.fixed(100), height = orui.fixed(100), layer = 2},
		)
	}
	orui.set_hit_slop(target_id, {left = 10})
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		300,
		0,
		{
			pointer_position = {89, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Pressed in orui.pointer_response(background_id))
	testing.expect(t, .Pressed not_in orui.pointer_response(target_id))
	orui.end()
}

@(test)
clip_rejects_hit_slop_outside_visual_bounds :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	target_id := orui.to_id("target")
	orui.begin(ctx, 300, 300, 0)
	{orui.container(
			orui.id(background_id),
			{position = {.Fixed, {}}, width = orui.fixed(300), height = orui.fixed(300), layer = 1},
		)
	}
	{orui.container(
			orui.id(target_id),
			{
				position = {.Fixed, {100, 100}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				layer = 2,
				clip = {.Self, {}},
			},
		)
	}
	orui.set_hit_slop(target_id, {left = 10})
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		300,
		0,
		{
			pointer_position = {95, 150},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)

	testing.expect(t, .Pressed in orui.pointer_response(background_id))
	testing.expect(t, .Pressed not_in orui.pointer_response(target_id))
	orui.end()
}
