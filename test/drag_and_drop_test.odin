package orui_test

import orui "../src"
import "core:testing"
import rl "vendor:raylib"

@(private = "file")
drag_and_drop_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	declare_source := true,
) -> (
	orui.Drag_Response,
	orui.Drop_Response,
) {
	source_id := orui.to_id("drag source")
	target_id := orui.to_id("drop target")

	orui.begin_with_input(ctx, 200, 100, 0, input)
	if declare_source {
		{orui.container(
				orui.id(source_id),
				{position = {.Fixed, {10, 10}}, width = orui.fixed(40), height = orui.fixed(40)},
			)}
	}
	{orui.container(
			orui.id(target_id),
			{position = {.Fixed, {100, 10}}, width = orui.fixed(60), height = orui.fixed(60)},
		)}

	drag := declare_source ? orui.drag_source(source_id) : orui.drag_response(source_id)
	drop := orui.drop_target(target_id, source_id)
	orui.end()
	return drag, drop
}

@(test)
drag_source_uses_a_six_unit_euclidean_threshold :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	drag_and_drop_test_frame(ctx, {})
	drag, _ := drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, drag.flags == {})

	drag, _ = drag_and_drop_test_frame(ctx, {pointer_position = {26, 20}})
	testing.expect(t, drag.flags == {})

	drag, _ = drag_and_drop_test_frame(ctx, {pointer_position = {25, 24}})
	testing.expect(t, .Started in drag.flags)
	testing.expect(t, .Dragged in drag.flags)
	testing.expect_value(t, drag.origin, rl.Vector2{20, 20})
	testing.expect_value(t, drag.position, rl.Vector2{25, 24})
	testing.expect_value(t, drag.delta, rl.Vector2{-1, 4})
	testing.expect_value(t, drag.total_delta, rl.Vector2{5, 4})
	testing.expect_value(t, drag.grab_offset, rl.Vector2{10, 10})
}

@(test)
drop_target_uses_geometry_during_pointer_capture :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	source_id := orui.to_id("drag source")
	target_id := orui.to_id("drop target")
	drag_and_drop_test_frame(ctx, {})
	drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	drag, drop := drag_and_drop_test_frame(ctx, {pointer_position = {120, 30}})
	testing.expect(t, .Dragged in drag.flags)
	testing.expect(t, .Hovered in drop.flags)
	testing.expect_value(t, drop.source, source_id)
	testing.expect(t, .Hovered not_in orui.pointer_response(target_id))

	drag, drop = drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {120, 30},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, .Stopped in drag.flags)
	testing.expect(t, .Dropped in drop.flags)
	testing.expect_value(t, drop.source, source_id)

	drag, drop = drag_and_drop_test_frame(ctx, {pointer_position = {120, 30}})
	testing.expect(t, drag.flags == {})
	testing.expect(t, drop.flags == {})
}

@(test)
drag_release_before_threshold_is_not_a_drop :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	drag_and_drop_test_frame(ctx, {})
	drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	drag, drop := drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {23, 24},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, drag.flags == {})
	testing.expect(t, drop.flags == {})
}

@(test)
escape_cancels_an_active_drag_without_dropping :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	drag_and_drop_test_frame(ctx, {})
	drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	drag_and_drop_test_frame(ctx, {pointer_position = {120, 30}})
	drag, drop := drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {120, 30},
			key_events = []orui.Key_Event{{key = .ESCAPE, kind = .Pressed}},
		},
	)
	testing.expect(t, .Cancelled in drag.flags)
	testing.expect(t, .Dragged not_in drag.flags)
	testing.expect(t, drop.flags == {})

	drag, _ = drag_and_drop_test_frame(ctx, {pointer_position = {120, 30}})
	testing.expect(t, drag.flags == {})
}

@(test)
drag_stops_when_the_source_is_not_declared_on_release :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	drag_and_drop_test_frame(ctx, {})
	drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	drag, drop := drag_and_drop_test_frame(
		ctx,
		{pointer_position = {120, 30}},
		declare_source = false,
	)
	testing.expect(t, .Dragged in drag.flags)

	drag, drop = drag_and_drop_test_frame(
		ctx,
		{
			pointer_position = {120, 30},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		declare_source = false,
	)
	testing.expect(t, .Stopped in drag.flags)
	testing.expect(t, .Dropped in drop.flags)

	drag, _ = drag_and_drop_test_frame(ctx, {}, declare_source = false)
	testing.expect(t, drag.flags == {})
}
