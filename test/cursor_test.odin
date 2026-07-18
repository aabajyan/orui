package orui_test

import orui "../src"
import "core:testing"
import rl "vendor:raylib"

@(private = "file")
cursor_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	request := true,
	kind := rl.MouseCursor.IBEAM,
) -> []orui.RenderCommand {
	orui.begin_with_input(ctx, 200, 100, 0, input)
	target_id := orui.to_id("cursor target")
	{orui.container(
			orui.id(target_id),
			{position = {.Fixed, {50, 25}}, width = orui.fixed(100), height = orui.fixed(50)},
		)}
	if request {
		orui.request_cursor(target_id, kind)
	}
	return orui.end()
}

@(private = "file")
cursor_route_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	request := true,
) -> []orui.RenderCommand {
	orui.begin_with_input(ctx, 200, 100, 0, input)
	parent_id := orui.to_id("cursor parent")
	child_id := orui.to_id("cursor child")
	{orui.container(
			orui.id(parent_id),
			{
				position = {.Fixed, {25, 10}},
				width = orui.fixed(150),
				height = orui.fixed(80),
				padding = orui.padding(20),
			},
		)
		{orui.container(orui.id(child_id), {width = orui.grow(), height = orui.grow()})}
	}
	if request {
		orui.request_cursor(child_id, .IBEAM)
		orui.request_cursor(parent_id, .POINTING_HAND)
	}
	return orui.end()
}

@(private = "file")
find_cursor_command :: proc(commands: []orui.RenderCommand) -> (rl.MouseCursor, bool) {
	for command in commands {
		if command.type == .Cursor {
			data := command.data.(orui.RenderCommandDataCursor)
			return data.kind, true
		}
	}
	return .DEFAULT, false
}

@(private = "file")
pointing_hand_cursor_style :: proc(element: ^orui.Element) {
	element.cursor = rl.MouseCursor.POINTING_HAND
}

@(private = "file")
declarative_cursor_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	declaration: Maybe(rl.MouseCursor) = rl.MouseCursor.IBEAM,
	requested: Maybe(rl.MouseCursor) = nil,
	modifier := false,
) -> []orui.RenderCommand {
	orui.begin_with_input(ctx, 200, 100, 0, input)
	target_id := orui.to_id("declarative cursor target")
	config := orui.ElementConfig {
		position = {.Fixed, {50, 25}},
		width    = orui.fixed(100),
		height   = orui.fixed(50),
		cursor   = declaration,
	}
	if modifier {
		{orui.container(orui.id(target_id), config, pointing_hand_cursor_style)}
	} else {
		{orui.container(orui.id(target_id), config)}
	}
	if cursor, ok := requested.?; ok {
		orui.request_cursor(target_id, cursor)
	}
	return orui.end()
}

@(private = "file")
declarative_cursor_route_test_frame :: proc(
	ctx: ^orui.Context,
	input: orui.Input_Frame,
	child_cursor: Maybe(rl.MouseCursor) = nil,
) -> []orui.RenderCommand {
	orui.begin_with_input(ctx, 200, 100, 0, input)
	{orui.container(
			orui.id("declarative cursor ancestor"),
			{
				position = {.Fixed, {25, 10}},
				width = orui.fixed(150),
				height = orui.fixed(80),
				padding = orui.padding(20),
				cursor = .IBEAM,
			},
		)
		{orui.container(
				orui.id("declarative cursor child"),
				{width = orui.grow(), height = orui.grow(), cursor = child_cursor},
			)}
	}
	return orui.end()
}

@(test)
declarative_element_cursor_is_emitted_when_hovered :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	declarative_cursor_test_frame(ctx, {})
	commands := declarative_cursor_test_frame(ctx, {pointer_position = {100, 50}})

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.IBEAM)
}

@(test)
element_modifier_can_declare_cursor :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	declarative_cursor_test_frame(ctx, {}, nil, nil, true)
	commands := declarative_cursor_test_frame(ctx, {pointer_position = {100, 50}}, nil, nil, true)

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.POINTING_HAND)
}

@(test)
manual_request_can_override_declaration_for_the_same_element :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	declarative_cursor_test_frame(ctx, {}, .IBEAM, .CROSSHAIR)
	commands := declarative_cursor_test_frame(
		ctx,
		{pointer_position = {100, 50}},
		.IBEAM,
		.CROSSHAIR,
	)

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.CROSSHAIR)
}

@(test)
unset_child_cursor_does_not_cancel_ancestor_declaration :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	declarative_cursor_route_test_frame(ctx, {})
	commands := declarative_cursor_route_test_frame(ctx, {pointer_position = {100, 50}})

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.IBEAM)
}

@(test)
explicit_default_child_cursor_overrides_ancestor_declaration :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	declarative_cursor_route_test_frame(ctx, {}, .DEFAULT)
	declarative_cursor_route_test_frame(ctx, {pointer_position = {30, 15}}, .DEFAULT)
	commands := declarative_cursor_route_test_frame(ctx, {pointer_position = {100, 50}}, .DEFAULT)

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.DEFAULT)
}

@(test)
cursor_change_is_emitted_as_a_render_command :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_test_frame(ctx, {})
	commands := cursor_test_frame(ctx, {pointer_position = {100, 50}})

	testing.expect(t, .Hovered in orui.pointer_response(orui.to_id("cursor target")))
	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.IBEAM)
}

@(test)
cursor_render_command_source_is_the_requesting_element :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_test_frame(ctx, {})
	commands := cursor_test_frame(ctx, {pointer_position = {100, 50}})

	for command in commands {
		if command.type != .Cursor do continue
		testing.expect(t, command.source != nil)
		if command.source != nil {
			testing.expect_value(t, command.source.id, orui.to_id("cursor target"))
		}
		return
	}
	testing.expect(t, false)
}

@(test)
unchanged_cursor_does_not_emit_another_render_command :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_test_frame(ctx, {})
	cursor_test_frame(ctx, {pointer_position = {100, 50}})
	commands := cursor_test_frame(ctx, {pointer_position = {100, 50}})

	_, ok := find_cursor_command(commands)
	testing.expect(t, !ok)
}

@(test)
cursor_change_back_to_default_is_emitted :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_test_frame(ctx, {})
	cursor_test_frame(ctx, {pointer_position = {100, 50}})
	commands := cursor_test_frame(ctx, {pointer_position = {10, 10}})

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.DEFAULT)
}

@(test)
direct_hovered_element_cursor_beats_a_later_ancestor_request :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_route_test_frame(ctx, {}, false)
	commands := cursor_route_test_frame(ctx, {pointer_position = {100, 50}})

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.IBEAM)
}

@(test)
active_pointer_owner_keeps_its_cursor_outside_the_element :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	cursor_test_frame(ctx, {}, false)
	cursor_test_frame(
		ctx,
		{
			pointer_position = {100, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
		false,
	)
	testing.expect(t, .Held in orui.pointer_response(orui.to_id("cursor target")))

	commands := cursor_test_frame(ctx, {pointer_position = {10, 10}}, true, .RESIZE_ALL)

	kind, ok := find_cursor_command(commands)
	testing.expect(t, ok)
	testing.expect_value(t, kind, rl.MouseCursor.RESIZE_ALL)
}
