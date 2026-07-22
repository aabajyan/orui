package orui_test

import orui "../src"
import "core:testing"
import rl "vendor:raylib"

@(private = "file")
scrollbar_test_frame :: proc(
	ctx: ^orui.Context,
	parent_id: orui.Id,
	input: orui.Input_Frame,
	options: orui.Scroll_Bar_Options = {
		axis = .Vertical,
		min_thumb_extent = orui.SCROLL_BAR_DEFAULT_MIN_THUMB_EXTENT,
		hit_extent = 14,
	},
	declare_scrollbar := true,
	dt: f32 = 0,
) -> rl.Vector2 {
	orui.begin_with_input(ctx, 200, 200, dt, input)
	{orui.container(
			orui.id(parent_id),
			{
				position = {.Fixed, {}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				clip = {.Self, {}},
				scroll = orui.scroll(.Vertical),
			},
		)
		{orui.container(
				orui.id("scrollbar content"),
				{width = orui.fixed(100), height = orui.fixed(400)},
			)}

		if declare_scrollbar {
			orui.scrollbar(
				parent_id,
				options,
				{
					position = {.Absolute, {}},
					placement = orui.placement(.Right, .Right),
					width = orui.fixed(2),
					height = orui.grow(),
				},
				{width = orui.fixed(8)},
			)
		}
	}
	orui.end()
	return orui.scroll_offset(parent_id)
}

@(test)
scrollbar_release_while_undeclared_ends_drag :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("conditionally declared scrollbar parent")
	scrollbar_test_frame(ctx, parent_id, {})
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 10},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 80},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		declare_scrollbar = false,
	)
	scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 80}})
	scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 80}})
	offset := scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 80}})

	expect_f32(t, offset.y, 0, "scroll offset after an undeclared release")
}

@(test)
scrollbar_drag_preserves_thumb_grab_offset :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("scrollbar parent")
	scrollbar_test_frame(ctx, parent_id, {})
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 10},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 20}})
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)

	expect_f32(t, offset.y, 40, "scroll offset")
}

@(test)
scrollbar_jump_track_click_centers_thumb_at_pointer :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("scrollbar jump parent")
	options := orui.Scroll_Bar_Options {
		axis        = .Vertical,
		track_click = .Jump,
	}
	scrollbar_test_frame(ctx, parent_id, {}, options)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		options,
	)
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		options,
	)

	expect_f32(t, offset.y, 250, "jumped scroll offset")
}

@(test)
scrollbar_zero_value_track_click_is_inert :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("inert zero-value scrollbar parent")
	options := orui.Scroll_Bar_Options {
		axis = .Vertical,
	}
	scrollbar_test_frame(ctx, parent_id, {}, options)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		options,
	)
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		options,
	)

	expect_f32(t, offset.y, 0, "zero-value track click scroll offset")
}

@(test)
scrollbar_page_track_click_moves_one_viewport :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("scrollbar page parent")
	options := orui.Scroll_Bar_Options {
		axis             = .Vertical,
		track_click      = .Page,
		min_thumb_extent = orui.SCROLL_BAR_DEFAULT_MIN_THUMB_EXTENT,
		hit_extent       = 14,
	}
	scrollbar_test_frame(ctx, parent_id, {}, options)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		options,
	)
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		options,
	)

	expect_f32(t, offset.y, 100, "paged scroll offset")
}

@(test)
scrollbar_page_track_click_repeats_while_held :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("repeating scrollbar page parent")
	options := orui.Scroll_Bar_Options {
		axis        = .Vertical,
		track_click = .Page,
	}
	scrollbar_test_frame(ctx, parent_id, {}, options)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		options,
		dt = 0.1,
	)
	scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 75}}, options, dt = 0.2)
	scrollbar_test_frame(ctx, parent_id, {pointer_position = {99, 75}}, options, dt = 0.3)
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{pointer_position = {99, 75}},
		options,
		dt = 0.1,
	)

	expect_f32(t, offset.y, 200, "repeated page scroll offset")
}

@(private = "file")
scrollbar_visibility_test_frame :: proc(
	ctx: ^orui.Context,
	parent_id: orui.Id,
	visibility: orui.Scroll_Bar_Visibility,
) -> (
	track_count, thumb_count: int,
) {
	orui.begin_with_input(ctx, 200, 200, 0, {})
	{orui.container(
			orui.id(parent_id),
			{
				position = {.Fixed, {}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				scroll = orui.scroll(.Vertical),
			},
		)
		{orui.container(
				orui.id("fitting scrollbar content"),
				{width = orui.fixed(100), height = orui.fixed(50)},
			)}
		orui.scrollbar(
			parent_id,
			{axis = .Vertical, visibility = visibility},
			{
				position = {.Absolute, {}},
				placement = orui.placement(.Right, .Right),
				width = orui.fixed(2),
				height = orui.grow(),
				background_color = rl.RED,
			},
			{width = orui.fixed(8), background_color = rl.BLUE},
		)
	}
	commands := orui.end()
	for command in commands {
		if command.type != .Rectangle do continue
		data := command.data.(orui.RenderCommandDataRectangle)
		if data.color == rl.RED do track_count += 1
		if data.color == rl.BLUE do thumb_count += 1
	}
	return
}

@(test)
scrollbar_when_needed_hides_visuals_when_content_fits :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("fitting scrollbar parent")
	scrollbar_visibility_test_frame(ctx, parent_id, .When_Needed)
	track_count, thumb_count := scrollbar_visibility_test_frame(ctx, parent_id, .When_Needed)

	testing.expect_value(t, track_count, 0)
	testing.expect_value(t, thumb_count, 0)
}

@(test)
scrollbar_hidden_ignores_press_routed_from_visible_frame :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("hidden scrollbar parent")
	visible_options := orui.Scroll_Bar_Options {
		axis        = .Vertical,
		visibility  = .Always,
		track_click = .Jump,
	}
	hidden_options := visible_options
	hidden_options.visibility = .Hidden
	scrollbar_test_frame(ctx, parent_id, {}, visible_options)
	scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		hidden_options,
	)
	offset := scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {99, 75},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
		hidden_options,
	)

	expect_f32(t, offset.y, 0, "hidden scrollbar scroll offset")
}

@(test)
scrollbar_centers_wider_thumb_over_thin_track :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("centered scrollbar parent")
	thumb_x: f32
	for frame in 0 ..< 2 {
		orui.begin_with_input(ctx, 200, 200, 0, {})
		{orui.container(
				orui.id(parent_id),
				{
					position = {.Fixed, {}},
					width = orui.fixed(100),
					height = orui.fixed(100),
					scroll = orui.scroll(.Vertical),
				},
			)
			{orui.container(
					orui.id("centered scrollbar content"),
					{width = orui.fixed(100), height = orui.fixed(400)},
				)}
			orui.scrollbar(
				parent_id,
				{axis = .Vertical},
				{
					position = {.Absolute, {}},
					placement = orui.placement(.Right, .Right),
					width = orui.fixed(2),
					height = orui.grow(),
				},
				{width = orui.fixed(8), background_color = rl.BLUE},
			)
		}
		commands := orui.end()
		if frame == 1 {
			for command in commands {
				if command.type != .Rectangle do continue
				data := command.data.(orui.RenderCommandDataRectangle)
				if data.color == rl.BLUE do thumb_x = data.position.x
			}
		}
	}

	expect_f32(t, thumb_x, 95, "thumb x")
}

@(private = "file")
horizontal_scrollbar_test_frame :: proc(
	ctx: ^orui.Context,
	parent_id: orui.Id,
	input: orui.Input_Frame,
) -> rl.Vector2 {
	orui.begin_with_input(ctx, 200, 200, 0, input)
	{orui.container(
			orui.id(parent_id),
			{
				position = {.Fixed, {}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				clip = {.Self, {}},
				scroll = orui.scroll(.Horizontal),
			},
		)
		{orui.container(
				orui.id("horizontal scrollbar content"),
				{width = orui.fixed(400), height = orui.fixed(100)},
			)}
		orui.scrollbar(
			parent_id,
			{axis = .Horizontal, hit_extent = 14},
			{
				position = {.Absolute, {}},
				placement = orui.placement(.Bottom, .Bottom),
				width = orui.grow(),
				height = orui.fixed(2),
			},
			{height = orui.fixed(8)},
		)
	}
	orui.end()
	return orui.scroll_offset(parent_id)
}

@(test)
horizontal_scrollbar_drag_preserves_thumb_grab_offset :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("horizontal scrollbar parent")
	horizontal_scrollbar_test_frame(ctx, parent_id, {})
	horizontal_scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {10, 99},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	horizontal_scrollbar_test_frame(ctx, parent_id, {pointer_position = {20, 99}})
	offset := horizontal_scrollbar_test_frame(
		ctx,
		parent_id,
		{
			pointer_position = {20, 99},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)

	expect_f32(t, offset.x, 40, "horizontal scroll offset")
}
