package orui

import "core:math/linalg"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

TEXT_MULTI_CLICK_TIME: f64 : 0.5
TEXT_MULTI_CLICK_DISTANCE: f32 : 6
POINTER_BUTTON_COUNT :: int(rl.MouseButton.BACK) + 1

Pointer_Event_Kind :: enum {
	Pressed,
	Released,
}

Pointer_Event :: struct {
	button: rl.MouseButton,
	kind:   Pointer_Event_Kind,
}

Key_Modifier :: enum {
	Control,
	Command,
	Shift,
	Alt,
	Super,
}

Key_Modifiers :: bit_set[Key_Modifier;u8]
TEXT_KEY_MODIFIERS: Key_Modifiers : {.Control, .Command, .Shift, .Alt, .Super}

Key_Event_Kind :: enum {
	Pressed,
	Released,
}

Key_Event :: struct {
	key:       rl.KeyboardKey,
	modifiers: Key_Modifiers,
	kind:      Key_Event_Kind,
	repeat:    bool,
}

// Queue a normalized key event produced outside Raylib's polling path.
queue_key_event :: proc(ctx: ^Context, event: Key_Event) {
	assert(ctx != nil)
	if ctx.pending_key_event_count >= len(ctx.pending_key_events) do return

	ctx.pending_key_events[ctx.pending_key_event_count] = event
	ctx.pending_key_event_count += 1
}

has_pending_input :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.pending_key_event_count > 0
}

Input_Frame :: struct {
	pointer_position: rl.Vector2,
	scroll:           rl.Vector2,
	pointer_events:   []Pointer_Event,
	key_events:       []Key_Event,
	text_events:      []rune,
	modifiers:        Key_Modifiers,
}

@(private)
handle_input_state :: proc(ctx: ^Context) {
	pointer_events: [POINTER_BUTTON_COUNT * 2]Pointer_Event
	pointer_event_count := 0
	for button in rl.MouseButton {
		if rl.IsMouseButtonPressed(button) {
			pointer_events[pointer_event_count] = {
				button = button,
				kind   = .Pressed,
			}
			pointer_event_count += 1
		}
		button_index := int(button)
		if rl.IsMouseButtonReleased(button) ||
		   (ctx.pointer_buttons_down[button_index] && !rl.IsMouseButtonDown(button)) {
			pointer_events[pointer_event_count] = {
				button = button,
				kind   = .Released,
			}
			pointer_event_count += 1
		}
	}

	modifiers := current_key_modifiers()
	key_events: [MAX_KEY_EVENTS]Key_Event
	key_event_count := 0
	for key in rl.KeyboardKey {
		pressed := rl.IsKeyPressed(key)
		repeated := rl.IsKeyPressedRepeat(key)
		if (pressed || repeated) && key_event_count < len(key_events) {
			key_events[key_event_count] = {
				key       = key,
				modifiers = modifiers,
				kind      = .Pressed,
				repeat    = repeated,
			}
			key_event_count += 1
		}
		if rl.IsKeyReleased(key) && key_event_count < len(key_events) {
			key_events[key_event_count] = {
				key       = key,
				modifiers = modifiers,
				kind      = .Released,
			}
			key_event_count += 1
		}
	}

	text_events: [MAX_TEXT_EVENTS]rune
	text_event_count := 0
	for char := rl.GetCharPressed(); char != 0; char = rl.GetCharPressed() {
		if text_event_count >= len(text_events) do continue
		text_events[text_event_count] = char
		text_event_count += 1
	}

	handle_input_frame(
		ctx,
		{
			pointer_position = rl.GetMousePosition(),
			scroll = rl.GetMouseWheelMoveV(),
			pointer_events = pointer_events[:pointer_event_count],
			key_events = key_events[:key_event_count],
			text_events = text_events[:text_event_count],
			modifiers = modifiers,
		},
	)
}

@(private)
handle_input_frame :: proc(ctx: ^Context, input: Input_Frame) {
	pending_count := min(ctx.pending_key_event_count, len(ctx.key_events))
	input_count := min(len(input.key_events), len(ctx.key_events) - pending_count)
	ctx.key_event_count = pending_count + input_count
	ctx.key_modifiers = input.modifiers
	for event, index in ctx.pending_key_events[:pending_count] {
		ctx.key_events[index] = event
		ctx.key_event_consumed[index] = false
	}
	ctx.pending_key_event_count = 0
	for event, index in input.key_events[:input_count] {
		event_index := pending_count + index
		ctx.key_events[event_index] = event
		ctx.key_event_consumed[event_index] = false
	}

	left_released := false
	for event in input.pointer_events {
		button := int(event.button)
		assert(button >= 0 && button < len(ctx.pointer_buttons_down))
		switch event.kind {
		case .Pressed:
			ctx.pointer_buttons_down[button] = true
		case .Released:
			ctx.pointer_buttons_down[button] = false
			if event.button == .LEFT do left_released = true
		}
	}

	handle_input_state_with(
		ctx,
		position = input.pointer_position,
		mouse_down = ctx.pointer_buttons_down[int(rl.MouseButton.LEFT)],
		released = left_released,
		scroll = input.scroll,
	)
	update_pointer_response(ctx, input)
	if ctx.pointer_pressed_id != 0 && ctx.pointer_pressed_button == .LEFT {
		handle_pointer_focus(ctx, input.pointer_position)
	}
	if key_pressed(.TAB, required = {.Shift}, repeat = false) {
		move_focus(.Backward)
	} else if key_pressed(.TAB, repeat = false) {
		move_focus(.Forward)
	}
	handle_keyboard_input(ctx, input.text_events)
}

SHORTCUT_MODIFIER :: Key_Modifiers{.Command} when ODIN_OS == .Darwin else Key_Modifiers{.Control}

// Consume a matching press. Set focus to restrict the match to that focus owner.
// Required modifiers must be down; optional modifiers may also be down.
key_pressed :: proc(
	key: rl.KeyboardKey,
	focus: Id = 0,
	required: Key_Modifiers = {},
	optional: Key_Modifiers = {},
	repeat := true,
) -> bool {
	ctx := current_context
	if focus != 0 {
		if ctx.focus_id != focus do return false
		if ctx.popup_count > 0 &&
		   !element_is_in_subtree(ctx, focus, ctx.popups[ctx.popup_count - 1].id) {
			return false
		}
	}
	for index in 0 ..< ctx.key_event_count {
		if ctx.key_event_consumed[index] do continue
		event := &ctx.key_events[index]
		if event.kind != .Pressed || event.key != key do continue
		if event.repeat && !repeat do continue
		if !key_modifiers_match(event.modifiers, required, optional) do continue

		ctx.key_event_consumed[index] = true
		return true
	}
	return false
}

@(private)
key_modifiers_match :: proc(actual, required, optional: Key_Modifiers) -> bool {
	for modifier in Key_Modifier {
		if modifier in required && modifier not_in actual do return false
		if modifier in actual && modifier not_in required && modifier not_in optional do return false
	}
	return true
}

@(private)
current_key_modifiers :: proc() -> Key_Modifiers {
	modifiers: Key_Modifiers
	if rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) do modifiers += {.Control}
	if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) do modifiers += {.Shift}
	if rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT) do modifiers += {.Alt}
	if rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER) do modifiers += {.Command} when ODIN_OS == .Darwin else {.Super}

	return modifiers
}

@(private)
update_pointer_response :: proc(ctx: ^Context, input: Input_Frame) {
	ctx.pointer_position = input.pointer_position
	ctx.pointer_pressed_id = 0
	ctx.pointer_released_id = 0
	ctx.pointer_clicked_id = 0

	for event in input.pointer_events {
		switch event.kind {
		case .Pressed:
			if ctx.pointer_owner_id != 0 do continue
			if close_top_popup_on_outside_press(ctx) do continue
			if ctx.pointer_hover_id != 0 {
				ctx.pointer_owner_id = ctx.pointer_hover_id
				ctx.pointer_owner_button = event.button
				ctx.pointer_pressed_id = ctx.pointer_owner_id
				ctx.pointer_pressed_button = event.button
			}
		case .Released:
			if ctx.pointer_owner_id != 0 && ctx.pointer_owner_button == event.button {
				ctx.pointer_released_id = ctx.pointer_owner_id
				ctx.pointer_released_button = event.button
				if ctx.pointer_hover_id != 0 &&
				   element_is_in_subtree(ctx, ctx.pointer_hover_id, ctx.pointer_owner_id) {
					ctx.pointer_clicked_id = ctx.pointer_owner_id
				}
				ctx.pointer_owner_id = 0
			}
		}
	}
}

@(private)
handle_input_state_with :: proc(
	ctx: ^Context,
	position: rl.Vector2,
	mouse_down: bool = false,
	released: bool = false,
	scroll: rl.Vector2 = {},
) {
	previous := previous_buffer(ctx)
	// processing previous frame's elements
	// input runs at the start of the frame, before the current frame's elements are declared
	// previous elements are the latest available state of the elements
	elements := &ctx.elements[previous]

	ctx.prev_focus_id = ctx.focus_id
	sync_focus_element(ctx)
	ctx.pointer_hover_id = 0

	if released {
		if ctx.focus != 0 && ctx.caret_index == -1 {
			ctx.caret_index = text_caret_from_point(ctx, &elements[ctx.focus], position)
		}
	}

	scroll_consumed := false
	scroll_blocking_index: i32 = -1
	target_found := false

	for i := ctx.sorted_count - 1; i >= 0; i -= 1 {
		element_index := ctx.sorted[i]
		element := &elements[element_index]

		if element.disabled == .True {
			continue
		}

		if !point_in_element(position, element) {
			continue
		}

		if !scroll_consumed &&
		   (scroll_blocking_index < 0 ||
				   element_is_same_layer_ancestor(
					   elements,
					   scroll_blocking_index,
					   element_index,
				   )) {
			if scroll.x != 0 && scrolls_x(element) {
				scroll_offset := get_scroll_offset(element)
				old := scroll_offset.x
				scroll_offset.x -= scroll.x * SCROLL_FACTOR
				scroll_offset.x = clamp(
					scroll_offset.x,
					0,
					element._content_size.x - inner_width(element),
				)
				// don't consume the scroll if it didn't change
				if scroll_offset.x != old {
					element.scroll.offset = scroll_offset
					if element.block == .True {
						scroll_consumed = true
					}
				}
			}
			if scroll.y != 0 && scrolls_y(element) {
				scroll_offset := get_scroll_offset(element)
				old := scroll_offset.y
				scroll_offset.y -= scroll.y * SCROLL_FACTOR
				scroll_offset.y = clamp(
					scroll_offset.y,
					0,
					element._content_size.y - inner_height(element),
				)
				// don't consume the scroll if it didn't change
				if scroll_offset.y != old {
					element.scroll.offset = scroll_offset
					if element.block == .True {
						scroll_consumed = true
					}
				}
			}
		}

		if !target_found && element.block == .True {
			scroll_blocking_index = element_index
			target_found = true
			ctx.pointer_hover_id = element.id
		}

		if scroll_consumed && target_found {
			break
		}
	}

	if ctx.selecting && mouse_down && ctx.focus != 0 {
		el := &elements[ctx.focus]
		update_text_drag_selection(ctx, el, position)
	}

	if released {
		ctx.selecting = false
	}

}

@(private)
element_is_same_layer_ancestor :: proc(
	elements: ^[MAX_ELEMENTS]Element,
	child_index, candidate_index: i32,
) -> bool {
	layer := elements[child_index]._layer
	for index := child_index;; index = elements[index].parent {
		if elements[index]._layer != layer do return false
		if index == candidate_index do return true
		if index == 0 do return false
	}
}

@(private)
handle_pointer_focus :: proc(ctx: ^Context, position: rl.Vector2) {
	buffer := previous_buffer(ctx)
	target_index, ok := element_index_by_id(ctx, buffer, ctx.pointer_pressed_id)
	if !ok do return

	elements := &ctx.elements[buffer]
	focus_index := target_index
	for focus_index != 0 &&
	    (elements[focus_index].disabled == .True || .Pointer not_in elements[focus_index].focus) {
		focus_index = elements[focus_index].parent
	}

	if focus_index == 0 {
		if ctx.focus != 0 do clear_focus_context(ctx)
		else do clear_text_click_state(ctx)
		return
	}

	element := &elements[focus_index]
	if element.editable {
		if ctx.focus == focus_index && (ctx.selecting || .Shift in ctx.key_modifiers) {
			ctx.text_selection_mode = .Character
			ctx.text_selection.end = text_caret_from_point(ctx, element, position)
			ctx.caret_index = ctx.text_selection.end
			ctx.caret_time = 0
			ensure_caret_visible(ctx, element, ctx.caret_index)
		} else {
			set_focus_element(ctx, buffer, focus_index)
			click_count := next_text_click_count(ctx, element.id, position)
			ctx.selecting = true
			start_text_click_selection(ctx, element, position, click_count)
		}
	} else {
		set_focus_element(ctx, buffer, focus_index)
	}
}

@(private)
next_text_click_count :: proc(ctx: ^Context, id: Id, position: rl.Vector2) -> int {
	now := rl.GetTime()
	within_distance :=
		linalg.distance(position, ctx.text_click_position) <= TEXT_MULTI_CLICK_DISTANCE
	within_time := now - ctx.text_click_time <= TEXT_MULTI_CLICK_TIME

	click_count := 1
	if ctx.text_click_id == id && within_time && within_distance {
		click_count = min(ctx.text_click_count + 1, 3)
	}

	ctx.text_click_id = id
	ctx.text_click_time = now
	ctx.text_click_position = position
	ctx.text_click_count = click_count
	return click_count
}

@(private)
clear_text_click_state :: proc(ctx: ^Context) {
	ctx.text_click_id = 0
	ctx.text_click_count = 0
	ctx.text_selection_mode = .Character
	ctx.text_selection_anchor = {}
}

@(private)
set_text_selection :: proc(
	ctx: ^Context,
	element: ^Element,
	selection: TextSelection,
	caret: int,
) {
	ctx.text_selection = selection
	ctx.caret_index = clamp(caret, 0, len(element.text_input.buf))
	ctx.caret_time = 0
	ensure_caret_visible(ctx, element, ctx.caret_index)
}

@(private)
start_text_click_selection :: proc(
	ctx: ^Context,
	element: ^Element,
	position: rl.Vector2,
	click_count: int,
) {
	if click_count <= 1 {
		caret := text_caret_from_point(ctx, element, position)
		selection := TextSelection{caret, caret}
		ctx.text_selection_mode = .Character
		ctx.text_selection_anchor = selection
		set_text_selection(ctx, element, selection, caret)
		return
	}

	index := text_index_from_point(ctx, element, position)
	selection: TextSelection
	if click_count == 2 {
		selection = text_word_range(element.text, index)
		ctx.text_selection_mode = .Word
	} else {
		selection = text_line_range(element.text, index)
		ctx.text_selection_mode = .Line
	}

	ctx.text_selection_anchor = selection
	set_text_selection(ctx, element, selection, selection.end)
}

@(private)
update_text_drag_selection :: proc(ctx: ^Context, element: ^Element, position: rl.Vector2) {
	switch ctx.text_selection_mode {
	case .Word:
		target := text_word_range(element.text, text_index_from_point(ctx, element, position))
		selection, caret := extend_text_selection(ctx.text_selection_anchor, target)
		set_text_selection(ctx, element, selection, caret)
	case .Line:
		target := text_line_range(element.text, text_index_from_point(ctx, element, position))
		selection, caret := extend_text_selection(ctx.text_selection_anchor, target)
		set_text_selection(ctx, element, selection, caret)
	case .Character:
		end := text_caret_from_point(ctx, element, position)
		ctx.text_selection.end = end
		ctx.caret_index = end
		ctx.caret_time = 0
		ensure_caret_visible(ctx, element, ctx.caret_index)
	}
}

@(private)
handle_keyboard_input :: proc(ctx: ^Context, text_events: []rune) {
	elements := &ctx.elements[previous_buffer(ctx)]
	if ctx.focus != 0 {
		element := &elements[ctx.focus]
		if !element.editable {
			return
		} else if element.overflow == .Visible &&
		   key_pressed(.ENTER, focus = element.id, optional = TEXT_KEY_MODIFIERS, repeat = false) {
			clear_focus_context(ctx)
		} else {
			text_input := element.text_input
			ctrl_down := .Control in ctx.key_modifiers
			cmd_down := .Command in ctx.key_modifiers
			shift_down := .Shift in ctx.key_modifiers

			when ODIN_OS == .Darwin {
				word_modifier := .Alt in ctx.key_modifiers
			} else {
				word_modifier := ctrl_down
			}

			for char in text_events {
				if char == '\r' || char == '\n' {
					continue
				}
				if has_text_selection(ctx) {
					ctx.caret_index = delete_text_selection(ctx, element)
				}
				char_bytes, char_len := utf8.encode_rune(char)
				bytes_inserted := insert_bytes(
					text_input,
					ctx.caret_index,
					string(char_bytes[:char_len]),
				)
				element.text = strings.to_string(text_input^)
				set_caret_index(ctx, element, ctx.caret_index + bytes_inserted)

				if bytes_inserted == 0 {
					break
				}
			}

			if key_pressed(.LEFT, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				next :=
					word_modifier ? utf8_prev_word(text_input, ctx.caret_index) : utf8_prev(text_input, ctx.caret_index)
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next)
			}

			if key_pressed(.RIGHT, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				next :=
					word_modifier ? utf8_next_word(text_input, ctx.caret_index) : utf8_next(text_input, ctx.caret_index)
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next)
			}

			if key_pressed(.HOME, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				next_index := 0
				if ctrl_down || cmd_down || element.overflow == .Visible {
					next_index = 0
				} else {
					next_index = caret_index_start_of_line(ctx, element, ctx.caret_index)
				}
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next_index
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next_index)
			}

			if key_pressed(.END, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				next_index := len(text_input.buf)
				if ctrl_down || cmd_down || element.overflow == .Visible {
					next_index = len(text_input.buf)
				} else {
					next_index = caret_index_end_of_line(ctx, element, ctx.caret_index)
				}
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next_index
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next_index)
			}

			if element.overflow == .Wrap {
				if key_pressed(.UP, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					next := caret_index_up(ctx, element, ctx.caret_position)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(.DOWN, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					next := caret_index_down(ctx, element, ctx.caret_position)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(.PAGE_UP, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					next := caret_index_up(ctx, element, ctx.caret_position, 5)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(.PAGE_DOWN, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					next := caret_index_down(ctx, element, ctx.caret_position, 5)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}
			}

			if key_pressed(.BACKSPACE, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				caret := ctx.caret_index
				if has_text_selection(ctx) {
					caret = delete_text_selection(ctx, element)
				} else {
					prev := utf8_prev(text_input, ctx.caret_index)
					delete_range(text_input, prev, ctx.caret_index)
					caret = prev
				}
				element.text = strings.to_string(text_input^)
				set_caret_index(ctx, element, caret)
			}

			if key_pressed(.DELETE, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				if has_text_selection(ctx) {
					caret := delete_text_selection(ctx, element)
					set_caret_index(ctx, element, caret)
				} else {
					next := utf8_next(text_input, ctx.caret_index)
					delete_range(text_input, ctx.caret_index, next)
				}
				element.text = strings.to_string(text_input^)
			}

			if key_pressed(.ENTER, focus = element.id, optional = TEXT_KEY_MODIFIERS) &&
			   element.overflow == .Wrap {
				caret := ctx.caret_index
				if has_text_selection(ctx) {
					caret = delete_text_selection(ctx, element)
				}
				char_bytes, char_len := utf8.encode_rune('\n')
				bytes_inserted := insert_bytes(text_input, caret, string(char_bytes[:char_len]))
				element.text = strings.to_string(text_input^)
				set_caret_index(ctx, element, caret + bytes_inserted)
			}

			if key_pressed(.A, focus = element.id, required = SHORTCUT_MODIFIER) {
				ctx.text_selection.start = 0
				ctx.text_selection.end = len(text_input.buf)
				set_caret_index(ctx, element, len(text_input.buf))
			}

			if key_pressed(.C, focus = element.id, required = SHORTCUT_MODIFIER) {
				if has_text_selection(ctx) {
					a, b := get_text_selection(ctx)
					selected_text := string(text_input.buf[a:b])
					rl.SetClipboardText(
						strings.clone_to_cstring(
							selected_text,
							ctx.allocator[current_buffer(ctx)],
						),
					)
				}
			}

			if key_pressed(.X, focus = element.id, required = SHORTCUT_MODIFIER) {
				if has_text_selection(ctx) {
					a, b := get_text_selection(ctx)
					selected_text := string(text_input.buf[a:b])
					rl.SetClipboardText(
						strings.clone_to_cstring(
							selected_text,
							ctx.allocator[current_buffer(ctx)],
						),
					)
					delete_range(text_input, a, b)
					element.text = strings.to_string(text_input^)
					set_caret_index(ctx, element, a)
					clear_text_selection(ctx)
				}
			}

			if key_pressed(.V, focus = element.id, required = SHORTCUT_MODIFIER) {
				clipboard_text := rl.GetClipboardText()
				if clipboard_text != nil {
					text := string(clipboard_text)
					caret := ctx.caret_index
					if has_text_selection(ctx) {
						caret = delete_text_selection(ctx, element)
					}
					bytes_inserted := insert_bytes(text_input, caret, text)
					element.text = strings.to_string(text_input^)
					set_caret_index(ctx, element, caret + bytes_inserted)
				}
			}
		}
	}
}

move_focus :: proc(direction: Focus_Direction) {
	ctx := current_context
	buffer := previous_buffer(ctx)
	count := ctx.element_count[buffer]
	if count <= 1 do return
	elements := &ctx.elements[buffer]
	reverse := direction == .Backward

	candidate := ctx.focus
	for _ in 1 ..< count {
		if reverse {
			candidate -= 1
			if candidate <= 0 do candidate = count - 1
		} else {
			candidate += 1
			if candidate >= count do candidate = 1
		}

		element := &elements[candidate]
		if element.disabled == .True || .Navigation not_in element.focus do continue
		if ctx.popup_count > 0 &&
		   !element_is_in_subtree(ctx, element.id, ctx.popups[ctx.popup_count - 1].id) {
			continue
		}

		set_focus_element(ctx, buffer, candidate)
		return
	}
}

@(private)
set_focus_element :: proc(ctx: ^Context, buffer: int, index: i32) {
	element := &ctx.elements[buffer][index]
	ctx.focus = index
	ctx.focus_id = element.id
	ctx.text_selection = {}
	ctx.selecting = false
	ctx.caret_index =
		element.editable && element.text_input != nil ? len(element.text_input.buf) : -1
	ctx.caret_time = 0
	clear_text_click_state(ctx)
}

sync_focus_element :: proc(ctx: ^Context) {
	if ctx.focus_id == 0 {
		ctx.focus = 0
		return
	}

	focus_index, ok := element_index_by_id(ctx, previous_buffer(ctx), ctx.focus_id)
	if !ok {
		clear_focus_context(ctx)
		return
	}

	ctx.focus = focus_index

	element := &ctx.elements[previous_buffer(ctx)][focus_index]
	if element.disabled == .True || element.focus == {} {
		clear_focus_context(ctx)
		return
	}

	if !element.editable || element.text_input == nil {
		return
	}

	max_index := len(element.text_input.buf)
	caret_index := clamp(ctx.caret_index, 0, max_index)
	selection_start := clamp(ctx.text_selection.start, 0, max_index)
	selection_end := clamp(ctx.text_selection.end, 0, max_index)
	if caret_index != ctx.caret_index ||
	   selection_start != ctx.text_selection.start ||
	   selection_end != ctx.text_selection.end {
		ctx.caret_index = caret_index
		ctx.text_selection.start = selection_start
		ctx.text_selection.end = selection_end
		ctx.caret_time = 0
	}
}

@(private)
clear_focus_context :: proc(ctx: ^Context) {
	ctx.focus = 0
	ctx.focus_id = 0
	ctx.text_selection = {}
	ctx.selecting = false
	clear_text_click_state(ctx)
}

@(private)
point_in_rect :: proc(p: rl.Vector2, pos: rl.Vector2, size: rl.Vector2) -> bool {
	return p.x >= pos.x && p.y >= pos.y && p.x < pos.x + size.x && p.y < pos.y + size.y
}

@(private)
point_in_element :: proc(p: rl.Vector2, element: ^Element) -> bool {
	position := rl.Vector2 {
		element._position.x - element.hit_slop.left,
		element._position.y - element.hit_slop.top,
	}
	size := rl.Vector2 {
		element._size.x + element.hit_slop.left + element.hit_slop.right,
		element._size.y + element.hit_slop.top + element.hit_slop.bottom,
	}
	if !point_in_rect(p, position, size) {
		return false
	}

	if element._clip.width > 0 || element._clip.height > 0 {
		return point_in_rect(
			p,
			{f32(element._clip.x), f32(element._clip.y)},
			{f32(element._clip.width), f32(element._clip.height)},
		)
	}

	return true
}

@(private)
set_caret_index :: proc(ctx: ^Context, element: ^Element, index: int) {
	ctx.caret_index = clamp(index, 0, len(element.text_input.buf))
	ctx.caret_time = 0
	ensure_caret_visible(ctx, element, ctx.caret_index)
}

@(private)
has_text_selection :: #force_inline proc(ctx: ^Context) -> bool {
	return ctx.text_selection.start != ctx.text_selection.end
}

@(private)
get_text_selection :: #force_inline proc(ctx: ^Context) -> (int, int) {
	a := min(ctx.text_selection.start, ctx.text_selection.end)
	b := max(ctx.text_selection.start, ctx.text_selection.end)
	return a, b
}

@(private)
clear_text_selection :: #force_inline proc(ctx: ^Context) {
	ctx.text_selection = {}
}

@(private)
delete_text_selection :: #force_inline proc(ctx: ^Context, element: ^Element) -> int {
	a, b := get_text_selection(ctx)
	delete_range(element.text_input, a, b)
	clear_text_selection(ctx)
	return a
}
