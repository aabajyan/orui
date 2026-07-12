package orui

import "core:testing"

@(test)
pointer_state_routes_from_child_to_parent :: proc(t: ^testing.T) {
	ctx := new(Context)
	defer free(ctx)
	init(ctx)
	defer destroy(ctx)

	parent_id := to_id("parent")
	child_id := to_id("child")
	begin(ctx, 200, 200, 0)
	{container(
			id(parent_id),
			{
				position = {.Fixed, {40, 40}},
				width = fixed(120),
				height = fixed(120),
				padding = padding(20),
			},
		)
		container(id(child_id), {width = grow(), height = grow()})
	}
	end()

	ctx.frame += 1
	handle_input_state_with(ctx, position = {100, 100}, mouse_down = true, pressed = true)

	testing.expect(t, pointer_hovered_within(parent_id))
	testing.expect(t, pointer_pressed_within(parent_id))
	testing.expect(t, pointer_hovered_within(child_id))
	testing.expect(t, pointer_pressed_within(child_id))
	testing.expect(t, !pointer_hovered_within(to_id("other")))
	testing.expect(t, !pointer_pressed_within(to_id("other")))
}

@(test)
hit_slop_routes_press_without_changing_layout_bounds :: proc(t: ^testing.T) {
	ctx := new(Context)
	defer free(ctx)
	init(ctx)
	defer destroy(ctx)

	background_id := to_id("background")
	target_id := to_id("target")
	begin(ctx, 300, 300, 0)
	{container(
			id(background_id),
			{position = {.Fixed, {}}, width = fixed(300), height = fixed(300), layer = 1},
		)
	}
	{container(
			id(target_id),
			{position = {.Fixed, {100, 100}}, width = fixed(100), height = fixed(100), layer = 2},
		)
	}
	set_hit_slop(target_id, {left = 10})
	end()

	ctx.frame += 1
	handle_input_state_with(ctx, position = {95, 150}, mouse_down = true, pressed = true)

	testing.expect(t, pointer_pressed_within(target_id))
	testing.expect(t, !pointer_pressed_within(background_id))
	bounds := bounding_rect(target_id)
	testing.expect_value(t, bounds.x, f32(100))
	testing.expect_value(t, bounds.y, f32(100))
	testing.expect_value(t, bounds.width, f32(100))
	testing.expect_value(t, bounds.height, f32(100))
}

@(test)
higher_layer_blocks_hit_slop :: proc(t: ^testing.T) {
	ctx := new(Context)
	defer free(ctx)
	init(ctx)
	defer destroy(ctx)

	target_id := to_id("target")
	blocker_id := to_id("blocker")
	begin(ctx, 300, 300, 0)
	{container(
			id(target_id),
			{position = {.Fixed, {100, 100}}, width = fixed(100), height = fixed(100), layer = 2},
		)
	}
	set_hit_slop(target_id, {left = 10})
	{container(
			id(blocker_id),
			{position = {.Fixed, {90, 140}}, width = fixed(20), height = fixed(20), layer = 3},
		)
	}
	end()

	ctx.frame += 1
	handle_input_state_with(ctx, position = {95, 150}, mouse_down = true, pressed = true)

	testing.expect(t, pointer_pressed_within(blocker_id))
	testing.expect(t, !pointer_pressed_within(target_id))
}

@(test)
pointer_outside_hit_slop_routes_to_element_behind :: proc(t: ^testing.T) {
	ctx := new(Context)
	defer free(ctx)
	init(ctx)
	defer destroy(ctx)

	background_id := to_id("background")
	target_id := to_id("target")
	begin(ctx, 300, 300, 0)
	{container(
			id(background_id),
			{position = {.Fixed, {}}, width = fixed(300), height = fixed(300), layer = 1},
		)
	}
	{container(
			id(target_id),
			{position = {.Fixed, {100, 100}}, width = fixed(100), height = fixed(100), layer = 2},
		)
	}
	set_hit_slop(target_id, {left = 10})
	end()

	ctx.frame += 1
	handle_input_state_with(ctx, position = {89, 150}, mouse_down = true, pressed = true)

	testing.expect(t, pointer_pressed_within(background_id))
	testing.expect(t, !pointer_pressed_within(target_id))
}

@(test)
clip_rejects_hit_slop_outside_visual_bounds :: proc(t: ^testing.T) {
	ctx := new(Context)
	defer free(ctx)
	init(ctx)
	defer destroy(ctx)

	background_id := to_id("background")
	target_id := to_id("target")
	begin(ctx, 300, 300, 0)
	{container(
			id(background_id),
			{position = {.Fixed, {}}, width = fixed(300), height = fixed(300), layer = 1},
		)
	}
	{container(
			id(target_id),
			{
				position = {.Fixed, {100, 100}},
				width = fixed(100),
				height = fixed(100),
				layer = 2,
				clip = {.Self, {}},
			},
		)
	}
	set_hit_slop(target_id, {left = 10})
	end()

	ctx.frame += 1
	handle_input_state_with(ctx, position = {95, 150}, mouse_down = true, pressed = true)

	testing.expect(t, pointer_pressed_within(background_id))
	testing.expect(t, !pointer_pressed_within(target_id))
}
