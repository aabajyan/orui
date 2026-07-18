package orui_test

import orui "../src"
import "core:strings"
import "core:testing"

@(test)
shortcut_chord_resolves_semantic_modifiers_for_the_platform :: proc(t: ^testing.T) {
	shortcut := orui.Shortcut {
		key       = .K,
		modifiers = {.Primary, .Control, .Alt, .Shift, .Super},
	}

	expected: orui.Key_Modifiers = {.Control, .Alt, .Shift}
	expected += {.Command} when ODIN_OS == .Darwin else {.Super}

	testing.expect_value(
		t,
		orui.shortcut_chord(shortcut),
		orui.Key_Chord{key = .K, modifiers = expected},
	)
}

@(test)
shortcut_press_matches_the_exact_chord_and_is_consumed_once :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	input := orui.Input_Frame {
		key_events = []orui.Key_Event {
			{key = .K, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
		},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	shortcut := orui.Shortcut {
		key       = .K,
		modifiers = {.Primary},
	}
	testing.expect(t, orui.shortcut_pressed(shortcut))
	testing.expect(t, !orui.shortcut_pressed(shortcut))
	orui.end()
}

@(test)
shortcut_press_rejects_undeclared_modifiers :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	input := orui.Input_Frame {
		key_events = []orui.Key_Event {
			{key = .K, modifiers = orui.SHORTCUT_MODIFIER + {.Shift}, kind = .Pressed},
		},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	testing.expect(t, !orui.shortcut_pressed({key = .K, modifiers = {.Primary}}))
	testing.expect(t, orui.shortcut_pressed({key = .K, modifiers = {.Primary, .Shift}}))
	orui.end()
}

@(test)
shortcut_key_repeat_is_opt_in :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .K, kind = .Pressed, repeat = true}},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	shortcut := orui.Shortcut {
		key = .K,
	}
	testing.expect(t, !orui.shortcut_pressed(shortcut))
	testing.expect(t, orui.shortcut_pressed(shortcut, repeat = true))
	orui.end()
}

@(test)
shortcut_label_uses_platform_modifier_style :: proc(t: ^testing.T) {
	shortcut := orui.Shortcut {
		key       = .K,
		modifiers = {.Primary, .Control, .Alt, .Shift},
	}
	label := orui.shortcut_label(shortcut)
	defer delete(label)

	expected := "Ctrl+Alt+Shift+Cmd+K" when ODIN_OS == .Darwin else "Ctrl+Alt+Shift+K"
	testing.expect_value(t, label, expected)
}

@(test)
shortcut_label_formats_punctuation_key :: proc(t: ^testing.T) {
	label := orui.shortcut_label({key = .EQUAL, modifiers = {.Primary}})
	defer delete(label)

	expected := "Cmd+=" when ODIN_OS == .Darwin else "Ctrl+="
	testing.expect_value(t, label, expected)
}

@(test)
shortcut_label_distinguishes_keypad_key :: proc(t: ^testing.T) {
	label := orui.shortcut_label({key = .KP_ADD})
	defer delete(label)

	testing.expect_value(t, label, "Numpad +")
}

@(test)
shortcut_label_formats_named_key :: proc(t: ^testing.T) {
	label := orui.shortcut_label({key = .PAGE_DOWN})
	defer delete(label)

	testing.expect_value(t, label, "Page Down")
}

@(private = "file")
focus_test_frame :: proc(ctx: ^orui.Context, input: orui.Input_Frame) {
	orui.begin_with_input(ctx, 300, 100, 0, input)
	{orui.container(
			orui.id("pointer focus"),
			{
				position = {.Fixed, {0, 0}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				focus = {.Pointer},
			},
		)}
	{orui.container(
			orui.id("tab focus"),
			{
				position = {.Fixed, {100, 0}},
				width = orui.fixed(100),
				height = orui.fixed(100),
				focus = {.Navigation},
			},
		)}
	{orui.container(
			orui.id("decorative"),
			{position = {.Fixed, {200, 0}}, width = orui.fixed(100), height = orui.fixed(100)},
		)}
	orui.end()
}

@(private = "file")
tab_focus_test_frame :: proc(
	ctx: ^orui.Context,
	move := false,
	direction: orui.Focus_Direction = .Forward,
	input: orui.Input_Frame = {},
) {
	orui.begin_with_input(ctx, 300, 100, 0, input)
	if move do orui.move_focus(direction)
	{orui.container(
			orui.id("first"),
			{width = orui.fixed(100), height = orui.fixed(100), focus = {.Navigation}},
		)}
	{orui.container(
			orui.id("disabled"),
			{
				width = orui.fixed(100),
				height = orui.fixed(100),
				focus = {.Navigation},
				disabled = .True,
			},
		)}
	{orui.container(
			orui.id("last"),
			{width = orui.fixed(100), height = orui.fixed(100), focus = {.Navigation}},
		)}
	orui.end()
}

@(private = "file")
declare_key_target :: proc(ctx: ^orui.Context, id: orui.Id) {
	{orui.container(
			orui.id(id),
			{width = orui.fixed(100), height = orui.fixed(40), focus = {.Navigation}},
		)}
}

@(test)
queued_key_press_is_delivered_once_on_the_next_frame :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	orui.queue_key_event(ctx, {key = .TAB, modifiers = {.Control}, kind = .Pressed})
	testing.expect(t, orui.has_pending_input(ctx))

	orui.begin(ctx, 100, 40, 0)
	testing.expect(t, !orui.has_pending_input(ctx))
	testing.expect(t, orui.key_pressed(.TAB, required = {.Control}))
	testing.expect(t, !orui.key_pressed(.TAB, required = {.Control}))
	orui.end()
}

@(test)
queued_key_press_is_merged_with_injected_input :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	orui.queue_key_event(ctx, {key = .TAB, modifiers = {.Control}, kind = .Pressed})
	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .ENTER, kind = .Pressed}},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	testing.expect(t, !orui.has_pending_input(ctx))
	testing.expect(t, orui.key_pressed(.TAB, required = {.Control}))
	testing.expect(t, orui.key_pressed(.ENTER))
	testing.expect(t, !orui.key_pressed(.TAB, required = {.Control}))
	testing.expect(t, !orui.key_pressed(.ENTER))
	orui.end()
}

@(test)
focused_key_press_is_delivered_once_to_its_owner :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	owner_id := orui.to_id("owner")
	other_id := orui.to_id("other")
	orui.begin_with_input(ctx, 200, 100, 0, {})
	declare_key_target(ctx, owner_id)
	declare_key_target(ctx, other_id)
	orui.request_focus(owner_id)
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .ENTER, kind = .Pressed}},
	}
	orui.begin_with_input(ctx, 200, 100, 0, input)
	declare_key_target(ctx, owner_id)
	declare_key_target(ctx, other_id)
	testing.expect(t, !orui.key_pressed(.ENTER, focus = other_id))
	testing.expect(t, orui.key_pressed(.ENTER, focus = owner_id))
	testing.expect(t, !orui.key_pressed(.ENTER, focus = owner_id))
	orui.end()
}

@(test)
unclaimed_key_press_is_available_outside_the_focus_owner :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	id := orui.to_id("focused elsewhere")
	orui.begin_with_input(ctx, 100, 40, 0, {})
	declare_key_target(ctx, id)
	orui.request_focus(id)
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .TAB, modifiers = {.Control}, kind = .Pressed}},
		modifiers  = {.Control},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	declare_key_target(ctx, id)
	testing.expect(t, orui.key_pressed(.TAB, required = {.Control}))
	testing.expect(t, !orui.key_pressed(.TAB, required = {.Control}))
	testing.expect(t, orui.focused(id))
	orui.end()
}

@(test)
key_filter_requires_and_allows_only_declared_modifiers :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	id := orui.to_id("modified")
	orui.begin_with_input(ctx, 100, 40, 0, {})
	declare_key_target(ctx, id)
	orui.request_focus(id)
	orui.end()

	shift_event := orui.Key_Event {
		key       = .ENTER,
		modifiers = {.Shift},
		kind      = .Pressed,
	}
	orui.begin_with_input(ctx, 100, 40, 0, {key_events = []orui.Key_Event{shift_event}})
	declare_key_target(ctx, id)
	testing.expect(t, !orui.key_pressed(.ENTER, focus = id))
	testing.expect(t, orui.key_pressed(.ENTER, focus = id, required = {.Shift}))
	orui.end()

	orui.begin_with_input(ctx, 100, 40, 0, {key_events = []orui.Key_Event{shift_event}})
	declare_key_target(ctx, id)
	testing.expect(t, orui.key_pressed(.ENTER, focus = id, optional = {.Shift}))
	orui.end()

	modified_event := orui.Key_Event {
		key       = .ENTER,
		modifiers = {.Shift, .Control},
		kind      = .Pressed,
	}
	orui.begin_with_input(ctx, 100, 40, 0, {key_events = []orui.Key_Event{modified_event}})
	declare_key_target(ctx, id)
	testing.expect(t, !orui.key_pressed(.ENTER, focus = id, required = {.Shift}))
	testing.expect(
		t,
		orui.key_pressed(.ENTER, focus = id, required = {.Shift}, optional = {.Control}),
	)
	orui.end()
}

@(test)
key_release_is_ignored_and_repeat_is_a_press :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	id := orui.to_id("repeat")
	orui.begin_with_input(ctx, 100, 40, 0, {})
	declare_key_target(ctx, id)
	orui.request_focus(id)
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event {
			{key = .RIGHT, kind = .Released},
			{key = .RIGHT, kind = .Pressed, repeat = true},
		},
	}
	orui.begin_with_input(ctx, 100, 40, 0, input)
	declare_key_target(ctx, id)
	testing.expect(t, orui.key_pressed(.RIGHT, focus = id))
	testing.expect(t, !orui.key_pressed(.RIGHT, focus = id))
	orui.end()
}

@(test)
multiline_text_input_consumes_enter_and_inserts_newline :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("textarea")

	orui.begin_with_input(ctx, 200, 100, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .ENTER, kind = .Pressed}},
	}
	orui.begin_with_input(ctx, 200, 100, 0, input)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	testing.expect(t, !orui.key_pressed(.ENTER, focus = id))
	orui.end()

	testing.expect_value(t, strings.to_string(text), "a\n")
}

@(test)
multiline_text_input_consumes_keypad_enter_and_inserts_newline :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("keypad textarea")

	orui.begin_with_input(ctx, 200, 100, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	input := orui.Input_Frame {
		key_events = []orui.Key_Event{{key = .KP_ENTER, kind = .Pressed}},
	}
	orui.begin_with_input(ctx, 200, 100, 0, input)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	testing.expect(t, !orui.key_pressed(.KP_ENTER, focus = id))
	orui.end()

	testing.expect_value(t, strings.to_string(text), "a\n")
}

@(test)
focused_text_input_deletes_the_previous_word_with_the_platform_shortcut :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello world")
	id := orui.to_id("word delete input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	word_modifier :=
		orui.Key_Modifiers{.Alt} when ODIN_OS == .Darwin else orui.Key_Modifiers{.Control}
	input := orui.Input_Frame {
		key_events = []orui.Key_Event {
			{key = .BACKSPACE, modifiers = word_modifier, kind = .Pressed},
		},
		modifiers  = word_modifier,
	}
	orui.begin_with_input(ctx, 200, 40, 0, input)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "hello ")
}

@(test)
focused_text_input_deletes_the_next_word_with_the_platform_shortcut :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello world")
	id := orui.to_id("forward word delete input")
	word_modifier :=
		orui.Key_Modifiers{.Alt} when ODIN_OS == .Darwin else orui.Key_Modifiers{.Control}

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .LEFT, modifiers = word_modifier, kind = .Pressed},
			},
			modifiers = word_modifier,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .DELETE, modifiers = word_modifier, kind = .Pressed},
			},
			modifiers = word_modifier,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "hello ")
}

@(test)
focused_multiline_text_input_moves_to_line_start_with_command_left_on_macos :: proc(
	t: ^testing.T,
) {
	when ODIN_OS != .Darwin {
		return
	}

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first\nsecond")
	id := orui.to_id("command line start input")

	orui.begin_with_input(ctx, 200, 80, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event{{key = .LEFT, modifiers = {.Command}, kind = .Pressed}},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(ctx, 200, 80, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "first\nXsecond")
}

@(test)
focused_multiline_text_input_moves_to_line_end_with_command_right_on_macos :: proc(t: ^testing.T) {
	when ODIN_OS != .Darwin {
		return
	}

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first\nsecond")
	id := orui.to_id("command line end input")

	orui.begin_with_input(ctx, 200, 80, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{key_events = []orui.Key_Event{{key = .HOME, kind = .Pressed}}},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event{{key = .RIGHT, modifiers = {.Command}, kind = .Pressed}},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(ctx, 200, 80, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "first\nsecondX")
}

@(test)
focused_multiline_text_input_moves_to_document_start_with_command_up_on_macos :: proc(
	t: ^testing.T,
) {
	when ODIN_OS != .Darwin {
		return
	}

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first\nsecond")
	id := orui.to_id("command document start input")

	orui.begin_with_input(ctx, 200, 80, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event{{key = .UP, modifiers = {.Command}, kind = .Pressed}},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(ctx, 200, 80, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "Xfirst\nsecond")
}

@(test)
focused_multiline_text_input_moves_to_document_end_with_command_down_on_macos :: proc(
	t: ^testing.T,
) {
	when ODIN_OS != .Darwin {
		return
	}

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first\nsecond")
	id := orui.to_id("command document end input")

	orui.begin_with_input(ctx, 200, 80, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event{{key = .HOME, modifiers = {.Command}, kind = .Pressed}},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event{{key = .DOWN, modifiers = {.Command}, kind = .Pressed}},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	orui.begin_with_input(ctx, 200, 80, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "first\nsecondX")
}

@(test)
focused_multiline_text_input_deletes_to_line_start_with_command_backspace_on_macos :: proc(
	t: ^testing.T,
) {
	when ODIN_OS != .Darwin {
		return
	}

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first\nsecond")
	id := orui.to_id("command line delete input")

	orui.begin_with_input(ctx, 200, 80, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		80,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .BACKSPACE, modifiers = {.Command}, kind = .Pressed},
			},
			modifiers = {.Command},
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "first\n")
}

@(test)
focused_text_input_undoes_the_last_edit_with_the_primary_shortcut :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("undo input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {text_events = []rune{'b'}})
	orui.text_input(orui.id(id), &text, {})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "ab")

	input := orui.Input_Frame {
		key_events = []orui.Key_Event {
			{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
		},
		modifiers  = orui.SHORTCUT_MODIFIER,
	}
	orui.begin_with_input(ctx, 200, 40, 0, input)
	orui.text_input(orui.id(id), &text, {})
	testing.expect(t, !orui.shortcut_pressed({key = .Z, modifiers = {.Primary}}, focus = id))
	orui.end()

	testing.expect_value(t, strings.to_string(text), "a")
}

@(test)
focused_text_input_redoes_the_last_undo_with_primary_shift_z :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("redo input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {text_events = []rune{'b'}})
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "a")

	redo_modifiers := orui.SHORTCUT_MODIFIER + orui.Key_Modifiers{.Shift}
	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event{{key = .Z, modifiers = redo_modifiers, kind = .Pressed}},
			modifiers = redo_modifiers,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	testing.expect(
		t,
		!orui.shortcut_pressed({key = .Z, modifiers = {.Primary, .Shift}}, focus = id),
	)
	orui.end()

	testing.expect_value(t, strings.to_string(text), "ab")
}

@(test)
focused_text_input_redoes_the_last_undo_with_primary_y :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("alternate redo input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {text_events = []rune{'b'}})
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Y, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	testing.expect(t, !orui.shortcut_pressed({key = .Y, modifiers = {.Primary}}, focus = id))
	orui.end()

	testing.expect_value(t, strings.to_string(text), "ab")
}

@(test)
focused_text_input_undo_restores_deleted_text :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello")
	id := orui.to_id("undo deletion input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{key_events = []orui.Key_Event{{key = .BACKSPACE, kind = .Pressed}}},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "hell")

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "hello")
}

@(test)
focused_text_input_undo_restores_forward_deleted_text :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello")
	id := orui.to_id("undo forward deletion input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .HOME, kind = .Pressed},
				{key = .DELETE, kind = .Pressed},
			},
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "ello")

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "hello")
}

@(test)
focused_multiline_text_input_undo_removes_inserted_newline :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "a")
	id := orui.to_id("undo newline input")

	orui.begin_with_input(ctx, 200, 100, 0, {})
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		100,
		0,
		{key_events = []orui.Key_Event{{key = .ENTER, kind = .Pressed}}},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "a\n")

	orui.begin_with_input(
		ctx,
		200,
		100,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {overflow = .Wrap})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "a")
}

@(test)
focused_text_input_replaces_a_selection_and_undo_restores_it :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello")
	id := orui.to_id("replace selection input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .A, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {})
	orui.end()
	testing.expect_value(t, strings.to_string(text), "X")

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .Z, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "hello")
}

@(test)
focused_text_input_left_collapses_the_selection_to_its_start :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "hello")
	id := orui.to_id("collapse selection input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{
			key_events = []orui.Key_Event {
				{key = .A, modifiers = orui.SHORTCUT_MODIFIER, kind = .Pressed},
			},
			modifiers = orui.SHORTCUT_MODIFIER,
		},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(
		ctx,
		200,
		40,
		0,
		{key_events = []orui.Key_Event{{key = .LEFT, kind = .Pressed}}},
	)
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {text_events = []rune{'X'}})
	orui.text_input(orui.id(id), &text, {})
	orui.end()

	testing.expect_value(t, strings.to_string(text), "Xhello")
}

@(test)
pointer_press_in_unfocused_text_area_places_caret_without_selecting_prefix :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	strings.write_string(&text, "first line\nsecond line")
	id := orui.to_id("pointer text area")
	config := orui.ElementConfig {
		width     = orui.fixed(300),
		height    = orui.fixed(150),
		padding   = orui.padding(8),
		font_size = 16,
		overflow  = .Wrap,
	}

	orui.begin_with_input(ctx, 300, 150, 0, {})
	orui.text_input(orui.id(id), &text, config)
	orui.end()

	orui.begin_with_input(
		ctx,
		300,
		150,
		0,
		{
			pointer_position = {70, 20},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	orui.text_input(orui.id(id), &text, config)
	orui.end()
	pressed_caret := ctx.caret_index

	// The next frame still has the button held, as it does in the live demo.
	orui.begin_with_input(ctx, 300, 150, 0, {pointer_position = {70, 20}})
	orui.text_input(orui.id(id), &text, config)
	orui.end()

	testing.expect(t, orui.focused(id))
	testing.expect(t, pressed_caret > 0)
	testing.expect_value(t, ctx.caret_index, pressed_caret)
	testing.expect_value(t, ctx.text_selection.start, ctx.text_selection.end)
}

@(test)
request_focus_accepts_marked_noneditable_element_only :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	focusable_id := orui.to_id("focusable")
	decorative_id := orui.to_id("decorative")
	orui.begin(ctx, 200, 120, 0)
	{orui.container(
			orui.id(focusable_id),
			{width = orui.fixed(80), height = orui.fixed(40), focus = {.Pointer}},
		)}
	{orui.container(orui.id(decorative_id), {width = orui.fixed(80), height = orui.fixed(40)})}

	orui.request_focus(focusable_id)
	testing.expect(t, orui.focused(focusable_id))
	orui.request_focus(decorative_id)
	testing.expect(t, orui.focused(focusable_id))
	orui.end()
}

@(test)
focused_editable_reports_current_and_previous_frame_owner :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	text_id := orui.to_id("text input")
	button_id := orui.to_id("button")

	orui.begin(ctx, 200, 100, 0)
	orui.text_input(orui.id(text_id), &text, {})
	orui.request_focus(text_id)
	testing.expect(t, orui.focus_is_editable())
	orui.end()

	orui.begin(ctx, 200, 100, 0)
	testing.expect(t, orui.focus_is_editable())
	orui.text_input(orui.id(text_id), &text, {})
	{orui.container(
			orui.id(button_id),
			{width = orui.fixed(80), height = orui.fixed(40), focus = {.Navigation}},
		)}
	orui.request_focus(button_id)
	testing.expect(t, !orui.focus_is_editable())
	orui.end()

	orui.begin(ctx, 200, 100, 0)
	testing.expect(t, !orui.focus_is_editable())
	orui.end()
}

@(test)
focused_noneditable_text_does_not_render_caret :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	label_id := orui.to_id("focused label")
	orui.begin(ctx, 200, 100, 0)
	orui.label(
		orui.id(label_id),
		"Button",
		{width = orui.fixed(100), height = orui.fixed(40), focus = {.Navigation}},
	)
	orui.request_focus(label_id)
	commands := orui.end()

	for command in commands {
		if command.type == .Rectangle && command.source.id == label_id {
			testing.expect(t, false, "focused noneditable label rendered a text caret")
		}
	}
}

@(test)
pointer_focus_requires_pointer_policy :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	focus_test_frame(ctx, {})
	focus_test_frame(
		ctx,
		{
			pointer_position = {50, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, orui.focused(orui.to_id("pointer focus")))

	orui.clear_focus()
	focus_test_frame(
		ctx,
		{
			pointer_position = {150, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	focus_test_frame(
		ctx,
		{
			pointer_position = {150, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, !orui.focused(orui.to_id("tab focus")))

	orui.clear_focus()
	focus_test_frame(
		ctx,
		{
			pointer_position = {250, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Released}},
		},
	)
	focus_test_frame(
		ctx,
		{
			pointer_position = {250, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	)
	testing.expect(t, !orui.focused(orui.to_id("decorative")))
}

@(test)
pointer_focus_resolves_focusable_composite_ancestor :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	parent_id := orui.to_id("focusable parent")
	child_id := orui.to_id("blocking child")
	inputs := [2]orui.Input_Frame {
		{},
		{
			pointer_position = {50, 50},
			pointer_events = []orui.Pointer_Event{{button = .LEFT, kind = .Pressed}},
		},
	}
	for input in inputs {
		orui.begin_with_input(ctx, 100, 100, 0, input)
		{orui.container(
				orui.id(parent_id),
				{
					width = orui.fixed(100),
					height = orui.fixed(100),
					focus = {.Pointer, .Navigation},
				},
			)
			orui.container(orui.id(child_id), {width = orui.grow(), height = orui.grow()})
		}
		orui.end()
	}

	testing.expect(t, orui.focused(parent_id))
}

@(test)
tab_focus_follows_declaration_order_and_wraps :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	tab_focus_test_frame(ctx)
	tab_focus_test_frame(ctx, true)
	testing.expect(t, orui.focused(orui.to_id("first")))

	tab_focus_test_frame(ctx, true)
	testing.expect(t, orui.focused(orui.to_id("last")))

	tab_focus_test_frame(ctx, true)
	testing.expect(t, orui.focused(orui.to_id("first")))

	orui.clear_focus()
	tab_focus_test_frame(ctx, true, .Backward)
	testing.expect(t, orui.focused(orui.to_id("last")))
}

@(test)
plain_tab_and_shift_tab_move_focus_automatically :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	tab_focus_test_frame(ctx)
	tab_focus_test_frame(
		ctx,
		input = {key_events = []orui.Key_Event{{key = .TAB, kind = .Pressed}}},
	)
	testing.expect(t, orui.focused(orui.to_id("first")))

	tab_focus_test_frame(
		ctx,
		input = {key_events = []orui.Key_Event{{key = .TAB, kind = .Pressed}}},
	)
	testing.expect(t, orui.focused(orui.to_id("last")))

	tab_focus_test_frame(
		ctx,
		input = {
			key_events = []orui.Key_Event{{key = .TAB, modifiers = {.Shift}, kind = .Pressed}},
			modifiers = {.Shift},
		},
	)
	testing.expect(t, orui.focused(orui.to_id("first")))
}

@(test)
rebind_focus_to_element :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	ctx.frame = 1

	focused_id := orui.to_id("id")
	ctx.focus = 7
	ctx.focus_id = focused_id
	ctx.element_count[orui.previous_buffer(ctx)] = 4
	ctx.elements[orui.previous_buffer(ctx)][3].id = focused_id
	ctx.elements[orui.previous_buffer(ctx)][3].focus = {.Pointer, .Navigation}
	ctx.elements[orui.previous_buffer(ctx)][3].editable = true

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 3)
	testing.expect_value(t, ctx.focus_id, focused_id)
}

@(test)
clear_focus_when_element_is_missing :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	ctx.frame = 1

	ctx.focus = 7
	ctx.focus_id = orui.to_id("id")

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 0)
	testing.expect_value(t, ctx.focus_id, orui.Id(0))
}

@(test)
clear_focus_when_element_becomes_disabled_or_nonfocusable :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	ctx.frame = 1

	focused_id := orui.to_id("id")
	ctx.focus_id = focused_id
	ctx.element_count[orui.previous_buffer(ctx)] = 2
	ctx.elements[orui.previous_buffer(ctx)][1] = {
		id       = focused_id,
		focus    = {.Navigation},
		disabled = .True,
	}
	orui.sync_focus_element(ctx)
	testing.expect_value(t, ctx.focus_id, orui.Id(0))

	ctx.focus_id = focused_id
	ctx.elements[orui.previous_buffer(ctx)][1].disabled = .False
	ctx.elements[orui.previous_buffer(ctx)][1].focus = {}
	orui.sync_focus_element(ctx)
	testing.expect_value(t, ctx.focus_id, orui.Id(0))
}

@(test)
clamp_caret_position :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)

	builder: strings.Builder
	strings.builder_init(&builder, context.allocator)
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "1")

	focused_id := orui.to_id("id")
	ctx.frame = 1
	ctx.focus_id = focused_id
	ctx.caret_index = 2
	ctx.text_selection = {2, 2}
	ctx.element_count[orui.previous_buffer(ctx)] = 4
	ctx.elements[orui.previous_buffer(ctx)][3].id = focused_id
	ctx.elements[orui.previous_buffer(ctx)][3].focus = {.Pointer, .Navigation}
	ctx.elements[orui.previous_buffer(ctx)][3].editable = true
	ctx.elements[orui.previous_buffer(ctx)][3].text_input = &builder

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 3)
	testing.expect_value(t, ctx.caret_index, 1)
	testing.expect_value(t, ctx.text_selection.start, 1)
	testing.expect_value(t, ctx.text_selection.end, 1)
}

@(test)
nonpointer_focus_starts_editable_caret_at_end :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	first := strings.builder_make()
	defer strings.builder_destroy(&first)
	strings.write_string(&first, "long")
	second := strings.builder_make()
	defer strings.builder_destroy(&second)
	strings.write_string(&second, "x")
	first_id := orui.to_id("first input")
	second_id := orui.to_id("second input")

	orui.begin_with_input(ctx, 200, 100, 0, {})
	orui.text_input(orui.id(first_id), &first, {})
	orui.text_input(orui.id(second_id), &second, {})
	orui.request_focus(first_id)
	orui.end()
	testing.expect_value(t, ctx.caret_index, len(first.buf))

	orui.begin_with_input(ctx, 200, 100, 0, {})
	orui.move_focus(.Forward)
	orui.text_input(orui.id(first_id), &first, {})
	orui.text_input(orui.id(second_id), &second, {})
	orui.end()
	testing.expect(t, orui.focused(second_id))
	testing.expect_value(t, ctx.caret_index, len(second.buf))
}

@(test)
text_input_reports_focus_lost_when_it_becomes_disabled :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	text := strings.builder_make()
	defer strings.builder_destroy(&text)
	id := orui.to_id("disabled input")

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {})
	orui.request_focus(id)
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {})
	orui.text_input(orui.id(id), &text, {disabled = .True})
	orui.end()

	orui.begin_with_input(ctx, 200, 40, 0, {})
	lost := orui.text_input(orui.id(id), &text, {disabled = .True})
	orui.end()
	testing.expect(t, lost)
}
