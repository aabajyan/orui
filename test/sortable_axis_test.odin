package orui_test

import orui "../src"
import "core:testing"

@(private = "file")
sortable_axis_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	direction := orui.LayoutDirection.TopToBottom,
	release := orui.Sortable_Axis_Release_Policy.Require_Inside,
	first_index := 0,
	interactive_child := false,
	use_child_handle := false,
) -> orui.Sortable_Axis_Response {
	axis_id := orui.to_id("sortable axis")
	child_id := orui.to_id("sortable item child")

	orui.begin_with_input(ctx, 120, 120, 1.0 / 60.0, input)
	{orui.container(
			orui.id(axis_id),
			{
				position = {.Fixed, {10, 10}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				layout = .None,
			},
		)
		for index in first_index ..< 4 {
			item_id := orui.to_id("sortable item", index)
			position := [2]f32{0, f32(index) * 20}
			size := [2]f32{100, 20}
			if direction == .LeftToRight {
				position = {f32(index) * 20, 0}
				size = {20, 100}
			}
			{orui.container(
					orui.id(item_id),
					{
						position = {.Absolute, position},
						width = orui.fixed(size[0]),
						height = orui.fixed(size[1]),
					},
				)}
			if interactive_child && index == 0 {
				{orui.container(
						orui.id(child_id),
						{
							position = {.Absolute, {0, 0}},
							width = orui.fixed(10),
							height = orui.fixed(10),
							block = .True,
						},
					)}
			}
			handle_id := orui.Id(0)
			if use_child_handle && index == 0 {
				handle_id = child_id
			}
			orui.sortable_item(axis_id, item_id, index, handle_id)
		}
	}

	response := orui.sortable_axis(
		axis_id,
		{count = 4, item_extent = 20, direction = direction, release = release},
	)
	orui.end()
	return response
}

@(test)
sortable_axis_reports_insertion_slot_and_normalized_destination :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	sortable_axis_test_frame(ctx, {})
	sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	response := sortable_axis_test_frame(ctx, {pointer_position = {20, 65}})
	testing.expect(t, .Dragged in response.drag.flags)
	testing.expect_value(t, response.source_index, 0)
	testing.expect_value(t, response.insertion_index, 3)
	testing.expect_value(t, response.destination_index, 2)
	testing.expect_value(t, response.marker_offset, f32(60))

	response = sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 65},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect(t, .Stopped in response.drag.flags)
	testing.expect(t, response.dropped)
}

@(test)
sortable_axis_release_policy_controls_outside_drop :: proc(t: ^testing.T) {
	for release in orui.Sortable_Axis_Release_Policy {
		ctx := new(orui.Context)
		orui.init(ctx)

		sortable_axis_test_frame(ctx, {}, release = release)
		sortable_axis_test_frame(
			ctx,
			{
				pointer_position = {20, 20},
				pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
			},
			release = release,
		)
		sortable_axis_test_frame(ctx, {pointer_position = {20, 118}}, release = release)
		response := sortable_axis_test_frame(
			ctx,
			{
				pointer_position = {20, 118},
				pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
			},
			release = release,
		)

		testing.expect(t, .Stopped in response.drag.flags)
		testing.expect_value(t, response.dropped, release == .Clamp_To_Axis)
		orui.destroy(ctx)
		free(ctx)
	}
}

@(test)
sortable_axis_keeps_a_virtualized_source_observable :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	sortable_axis_test_frame(ctx, {})
	sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	response := sortable_axis_test_frame(ctx, {pointer_position = {20, 65}}, first_index = 1)
	testing.expect(t, .Dragged in response.drag.flags)
	testing.expect_value(t, response.drag.source, orui.to_id("sortable item", 0))

	response = sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 65},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		first_index = 1,
	)
	testing.expect(t, .Stopped in response.drag.flags)
	testing.expect(t, response.dropped)
}

@(test)
sortable_axis_propagates_cancel_without_dropping :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	sortable_axis_test_frame(ctx, {})
	sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	sortable_axis_test_frame(ctx, {pointer_position = {20, 65}})
	response := sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 65},
			key_events = []orui.Key_Event{{key = .ESCAPE, kind = .Pressed}},
		},
	)

	testing.expect(t, .Cancelled in response.drag.flags)
	testing.expect(t, !response.dropped)
	response = sortable_axis_test_frame(ctx, {pointer_position = {20, 65}})
	testing.expect(t, response.drag.flags == {})
}

@(test)
sortable_item_requires_direct_source_or_explicit_handle :: proc(t: ^testing.T) {
	for handle_index in 0 ..< 2 {
		use_child_handle := handle_index == 1
		ctx := new(orui.Context)
		orui.init(ctx)

		sortable_axis_test_frame(
			ctx,
			{},
			interactive_child = true,
			use_child_handle = use_child_handle,
		)
		sortable_axis_test_frame(
			ctx,
			{
				pointer_position = {15, 15},
				pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
			},
			interactive_child = true,
			use_child_handle = use_child_handle,
		)
		response := sortable_axis_test_frame(
			ctx,
			{pointer_position = {30, 15}},
			interactive_child = true,
			use_child_handle = use_child_handle,
		)

		testing.expect_value(t, .Dragged in response.drag.flags, use_child_handle)
		orui.destroy(ctx)
		free(ctx)
	}
}

@(test)
sortable_axis_horizontal_geometry_locks_the_cross_axis :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	sortable_axis_test_frame(ctx, {}, direction = .LeftToRight)
	sortable_axis_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		direction = .LeftToRight,
	)
	response := sortable_axis_test_frame(
		ctx,
		{pointer_position = {65, 80}},
		direction = .LeftToRight,
	)

	testing.expect(t, .Dragged in response.drag.flags)
	testing.expect_value(t, response.insertion_index, 3)
	testing.expect_value(t, response.destination_index, 2)
	testing.expect_value(t, response.marker_offset, f32(60))
	testing.expect_value(t, response.ghost_rect.x, f32(55))
	testing.expect_value(t, response.ghost_rect.y, f32(10))
}

@(private = "file")
sortable_axis_scroll_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
) -> orui.Sortable_Axis_Response {
	axis_id := orui.to_id("scrollable sortable axis")

	orui.begin_with_input(ctx, 120, 100, 0.5, input)
	{range := orui.virtual_axis(
			axis_id,
			10,
			20,
			0,
			.TopToBottom,
			{position = {.Fixed, {10, 10}}, width = orui.fixed(100), height = orui.fixed(60)},
		)
		for index in range.first ..< range.last {
			item_id := orui.to_id("scrollable sortable item", index)
			cfg := orui.ElementConfig{}
			orui.virtual_axis_item(range, index, &cfg)
			{orui.container(orui.id(item_id), cfg)}
			orui.sortable_item(axis_id, item_id, index)
		}
	}

	response := orui.sortable_axis(
		axis_id,
		{
			count = 10,
			item_extent = 20,
			direction = .TopToBottom,
			release = .Require_Inside,
			edge_scroll_zone = 15,
			edge_scroll_items_per_second = 2,
		},
	)
	orui.end()
	return response
}

@(test)
sortable_axis_auto_scrolls_by_item_extent_near_the_trailing_edge :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	axis_id := orui.to_id("scrollable sortable axis")
	sortable_axis_scroll_test_frame(ctx, {})
	sortable_axis_scroll_test_frame(
		ctx,
		{
			pointer_position = {20, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	response := sortable_axis_scroll_test_frame(ctx, {pointer_position = {20, 66}})
	testing.expect(t, .Dragged in response.drag.flags)
	testing.expect_value(t, response.insertion_index, 4)
	testing.expect_value(t, response.destination_index, 3)
	sortable_axis_scroll_test_frame(
		ctx,
		{
			pointer_position = {20, 66},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	testing.expect_value(t, orui.scroll_offset(axis_id).y, f32(20))
}
