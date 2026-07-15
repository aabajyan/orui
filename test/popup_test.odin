package orui_test

import orui "../src"
import "core:testing"

@(test)
popup_opens_declares_and_closes :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	popup_id := orui.to_id("popup")

	orui.begin(ctx, 200, 100, 0)
	orui.open_popup(popup_id)
	opened := orui.begin_popup(
		orui.id(popup_id),
		{position = {.Fixed, {20, 20}}, width = orui.fixed(80), height = orui.fixed(40)},
	)
	testing.expect(t, opened)
	if opened do orui.end_popup()
	orui.end()

	orui.begin(ctx, 200, 100, 0)
	orui.close_popup(popup_id)
	opened = orui.begin_popup(
		orui.id(popup_id),
		{position = {.Fixed, {20, 20}}, width = orui.fixed(80), height = orui.fixed(40)},
	)
	testing.expect(t, !opened)
	orui.end()
}

@(test)
closing_parent_popup_removes_descendants :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("parent popup")
	child_id := orui.to_id("child popup")
	config := orui.ElementConfig {
		width  = orui.fixed(100),
		height = orui.fixed(80),
	}

	orui.begin(ctx, 200, 100, 0)
	orui.open_popup(parent_id)
	if orui.begin_popup(orui.id(parent_id), config) {
		orui.open_popup(child_id)
		if orui.begin_popup(orui.id(child_id), config) do orui.end_popup()
		orui.end_popup()
	}
	orui.end()

	orui.begin(ctx, 200, 100, 0)
	orui.close_popup(parent_id)
	orui.open_popup(parent_id)
	parent_open := orui.begin_popup(orui.id(parent_id), config)
	testing.expect(t, parent_open)
	if parent_open {
		child_open := orui.begin_popup(orui.id(child_id), config)
		testing.expect(t, !child_open)
		orui.end_popup()
	}
	orui.end()
}

@(test)
outside_press_closes_only_topmost_popup_and_is_consumed :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	parent_id := orui.to_id("parent popup")
	child_id := orui.to_id("child popup")

	orui.begin_with_input(ctx, 300, 200, 0, {})
	{orui.container(
			orui.id(background_id),
			{position = {.Fixed, {0, 0}}, width = orui.fixed(300), height = orui.fixed(200)},
		)}
	orui.open_popup(parent_id)
	parent_open := orui.begin_popup(
		orui.id(parent_id),
		{position = {.Fixed, {50, 40}}, width = orui.fixed(150), height = orui.fixed(100)},
	)
	if parent_open {
		orui.open_popup(child_id)
		child_open := orui.begin_popup(
			orui.id(child_id),
			{position = {.Fixed, {100, 70}}, width = orui.fixed(80), height = orui.fixed(60)},
		)
		if child_open do orui.end_popup()
		orui.end_popup()
	}
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		200,
		0,
		{
			pointer_position = {10, 10},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, .Pressed not_in orui.pointer_response(background_id))
	{orui.container(
			orui.id(background_id),
			{position = {.Fixed, {0, 0}}, width = orui.fixed(300), height = orui.fixed(200)},
		)}
	parent_open = orui.begin_popup(
		orui.id(parent_id),
		{position = {.Fixed, {50, 40}}, width = orui.fixed(150), height = orui.fixed(100)},
	)
	testing.expect(t, parent_open)
	if parent_open {
		child_open := orui.begin_popup(
			orui.id(child_id),
			{position = {.Fixed, {100, 70}}, width = orui.fixed(80), height = orui.fixed(60)},
		)
		testing.expect(t, !child_open)
		orui.end_popup()
	}
	orui.end()
}

@(test)
closing_popup_restores_saved_focus_owner :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	opener_id := orui.to_id("opener")
	popup_id := orui.to_id("popup")
	item_id := orui.to_id("popup item")

	orui.begin_with_input(ctx, 300, 200, 0, {})
	{orui.container(
			orui.id(opener_id),
			{
				position = {.Fixed, {0, 0}},
				width = orui.fixed(40),
				height = orui.fixed(40),
				focus = {.Pointer, .Navigation},
			},
		)}
	orui.request_focus(opener_id)
	orui.open_popup(popup_id)
	opened := orui.begin_popup(
		orui.id(popup_id),
		{position = {.Fixed, {100, 50}}, width = orui.fixed(100), height = orui.fixed(80)},
	)
	if opened {
		{orui.container(
				orui.id(item_id),
				{width = orui.fixed(80), height = orui.fixed(30), focus = {.Pointer, .Navigation}},
			)}
		orui.request_focus(item_id)
		orui.end_popup()
	}
	orui.end()
	testing.expect(t, orui.focused(item_id))

	orui.begin_with_input(ctx, 300, 200, 0, {})
	orui.close_popup(popup_id)
	testing.expect(t, orui.focused(opener_id))
	{orui.container(
			orui.id(opener_id),
			{
				position = {.Fixed, {0, 0}},
				width = orui.fixed(40),
				height = orui.fixed(40),
				focus = {.Pointer, .Navigation},
			},
		)}
	orui.end()
}

@(test)
opening_popup_releases_background_keyboard_focus :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	popup_id := orui.to_id("popup")
	item_id := orui.to_id("popup item")

	orui.begin_with_input(ctx, 300, 200, 0, {})
	{orui.container(
		orui.id(background_id),
		{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
	)}
	orui.request_focus(background_id)
	testing.expect(t, orui.focused(background_id))
	orui.open_popup(popup_id)
	testing.expect(t, !orui.focused(background_id))
	if orui.begin_popup(
		orui.id(popup_id),
		{width = orui.fixed(100), height = orui.fixed(80)},
	) {
		{orui.container(
			orui.id(item_id),
			{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
		)}
		orui.end_popup()
	}
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .ENTER, kind = .Pressed}},
	}
	orui.begin_with_input(ctx, 300, 200, 0, input)
	{orui.container(
		orui.id(background_id),
		{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
	)}
	orui.request_focus(background_id)
	testing.expect(t, !orui.focused(background_id))
	testing.expect(t, !orui.key_pressed(.ENTER, focus = background_id))
	if orui.begin_popup(
		orui.id(popup_id),
		{width = orui.fixed(100), height = orui.fixed(80)},
	) {
		{orui.container(
			orui.id(item_id),
			{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
		)}
		orui.request_focus(item_id)
		orui.request_focus(background_id)
		testing.expect(t, orui.focused(item_id))
		testing.expect(t, orui.key_pressed(.ENTER, focus = item_id))
		orui.end_popup()
	}
	orui.end()
}

@(test)
tab_focus_stays_inside_top_popup :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	popup_id := orui.to_id("popup")
	item_id := orui.to_id("popup item")

	for frame in 0 ..< 3 {
		input := orui.Input_Frame{}
		if frame > 0 {
			input.key_events = []orui.Key_Event{{key = .TAB, kind = .Pressed}}
		}
		orui.begin_with_input(ctx, 300, 200, 0, input)
		{orui.container(
				orui.id(background_id),
				{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
			)}
		if frame == 0 do orui.open_popup(popup_id)
		if orui.begin_popup(
			orui.id(popup_id),
			{width = orui.fixed(100), height = orui.fixed(80)},
		) {
			{orui.container(
					orui.id(item_id),
					{width = orui.fixed(80), height = orui.fixed(30), focus = {.Navigation}},
				)}
			orui.end_popup()
		}
		orui.end()

		if frame > 0 {
			testing.expect(t, orui.focused(item_id))
			testing.expect(t, !orui.focused(background_id))
		}
	}
}

@(test)
popup_routes_before_ordinary_caller_layers :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	background_id := orui.to_id("background")
	popup_id := orui.to_id("popup")

	inputs := [2]orui.Input_Frame {
		{},
		{
			pointer_position = {60, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	}
	for input in inputs {
		orui.begin_with_input(ctx, 300, 200, 0, input)
		if len(input.pointer_events) > 0 {
			testing.expect(t, .Pressed in orui.pointer_response(popup_id))
			testing.expect(t, .Pressed not_in orui.pointer_response(background_id))
		}
		{orui.container(
				orui.id(background_id),
				{
					position = {.Fixed, {0, 0}},
					width = orui.fixed(300),
					height = orui.fixed(200),
					layer = 10_000,
				},
			)}
		if len(input.pointer_events) == 0 do orui.open_popup(popup_id)
		opened := orui.begin_popup(
			orui.id(popup_id),
			{
				position = {.Fixed, {40, 30}},
				width = orui.fixed(100),
				height = orui.fixed(80),
				layer = -100,
			},
		)
		if opened do orui.end_popup()
		orui.end()
	}
}
