package orui

import "core:math/linalg"
import "core:strings"
import text_edit "core:text/edit"
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

Shortcut_Modifier :: enum {
	Primary,
	Control,
	Alt,
	Shift,
	Super,
}

Shortcut_Modifiers :: bit_set[Shortcut_Modifier;u8]

Shortcut :: struct {
	key:       rl.KeyboardKey,
	modifiers: Shortcut_Modifiers,
}

Key_Chord :: struct {
	key:       rl.KeyboardKey,
	modifiers: Key_Modifiers,
}

@(private, rodata)
SHORTCUT_KEY_LABELS := #sparse[rl.KeyboardKey]string {
	.KEY_NULL      = "None",
	.APOSTROPHE    = "'",
	.COMMA         = ",",
	.MINUS         = "-",
	.PERIOD        = ".",
	.SLASH         = "/",
	.ZERO          = "0",
	.ONE           = "1",
	.TWO           = "2",
	.THREE         = "3",
	.FOUR          = "4",
	.FIVE          = "5",
	.SIX           = "6",
	.SEVEN         = "7",
	.EIGHT         = "8",
	.NINE          = "9",
	.SEMICOLON     = ";",
	.EQUAL         = "=",
	.A             = "A",
	.B             = "B",
	.C             = "C",
	.D             = "D",
	.E             = "E",
	.F             = "F",
	.G             = "G",
	.H             = "H",
	.I             = "I",
	.J             = "J",
	.K             = "K",
	.L             = "L",
	.M             = "M",
	.N             = "N",
	.O             = "O",
	.P             = "P",
	.Q             = "Q",
	.R             = "R",
	.S             = "S",
	.T             = "T",
	.U             = "U",
	.V             = "V",
	.W             = "W",
	.X             = "X",
	.Y             = "Y",
	.Z             = "Z",
	.LEFT_BRACKET  = "[",
	.BACKSLASH     = "\\",
	.RIGHT_BRACKET = "]",
	.GRAVE         = "`",
	.SPACE         = "Space",
	.ESCAPE        = "Esc",
	.ENTER         = "Enter",
	.TAB           = "Tab",
	.BACKSPACE     = "Backspace",
	.INSERT        = "Insert",
	.DELETE        = "Delete",
	.RIGHT         = "Right",
	.LEFT          = "Left",
	.DOWN          = "Down",
	.UP            = "Up",
	.PAGE_UP       = "Page Up",
	.PAGE_DOWN     = "Page Down",
	.HOME          = "Home",
	.END           = "End",
	.CAPS_LOCK     = "Caps Lock",
	.SCROLL_LOCK   = "Scroll Lock",
	.NUM_LOCK      = "Num Lock",
	.PRINT_SCREEN  = "Print Screen",
	.PAUSE         = "Pause",
	.F1            = "F1",
	.F2            = "F2",
	.F3            = "F3",
	.F4            = "F4",
	.F5            = "F5",
	.F6            = "F6",
	.F7            = "F7",
	.F8            = "F8",
	.F9            = "F9",
	.F10           = "F10",
	.F11           = "F11",
	.F12           = "F12",
	.LEFT_SHIFT    = "Left Shift",
	.LEFT_CONTROL  = "Left Control",
	.LEFT_ALT      = "Left Alt",
	.LEFT_SUPER    = "Left Super",
	.RIGHT_SHIFT   = "Right Shift",
	.RIGHT_CONTROL = "Right Control",
	.RIGHT_ALT     = "Right Alt",
	.RIGHT_SUPER   = "Right Super",
	.KB_MENU       = "Menu",
	.KP_0          = "Numpad 0",
	.KP_1          = "Numpad 1",
	.KP_2          = "Numpad 2",
	.KP_3          = "Numpad 3",
	.KP_4          = "Numpad 4",
	.KP_5          = "Numpad 5",
	.KP_6          = "Numpad 6",
	.KP_7          = "Numpad 7",
	.KP_8          = "Numpad 8",
	.KP_9          = "Numpad 9",
	.KP_DECIMAL    = "Numpad .",
	.KP_DIVIDE     = "Numpad /",
	.KP_MULTIPLY   = "Numpad *",
	.KP_SUBTRACT   = "Numpad -",
	.KP_ADD        = "Numpad +",
	.KP_ENTER      = "Numpad Enter",
	.KP_EQUAL      = "Numpad =",
	.BACK          = "Back",
	.MENU          = "Menu",
	.VOLUME_UP     = "Volume Up",
	.VOLUME_DOWN   = "Volume Down",
}

// Resolve semantic shortcut modifiers to the platform's input modifiers.
shortcut_chord :: proc(shortcut: Shortcut) -> Key_Chord {
	modifiers: Key_Modifiers
	for modifier in Shortcut_Modifier {
		if modifier not_in shortcut.modifiers do continue
		switch modifier {
		case .Primary:
			modifiers += {.Command} when ODIN_OS == .Darwin else {.Control}
		case .Control:
			modifiers += {.Control}
		case .Alt:
			modifiers += {.Alt}
		case .Shift:
			modifiers += {.Shift}
		case .Super:
			modifiers += {.Command} when ODIN_OS == .Darwin else {.Super}
		}
	}
	return {key = shortcut.key, modifiers = modifiers}
}

// Return a platform-aware label allocated with allocator. The caller owns it.
shortcut_label :: proc(shortcut: Shortcut, allocator := context.allocator) -> string {
	chord := shortcut_chord(shortcut)
	builder := strings.builder_make(context.temp_allocator)
	defer strings.builder_destroy(&builder)

	when ODIN_OS == .Darwin {
		if .Control in chord.modifiers do strings.write_string(&builder, "Ctrl+")
		if .Alt in chord.modifiers do strings.write_string(&builder, "Alt+")
		if .Shift in chord.modifiers do strings.write_string(&builder, "Shift+")
		if .Command in chord.modifiers do strings.write_string(&builder, "Cmd+")
	} else {
		if .Control in chord.modifiers do strings.write_string(&builder, "Ctrl+")
		if .Alt in chord.modifiers do strings.write_string(&builder, "Alt+")
		if .Shift in chord.modifiers do strings.write_string(&builder, "Shift+")
		if .Super in chord.modifiers do strings.write_string(&builder, "Super+")
	}

	strings.write_string(&builder, SHORTCUT_KEY_LABELS[chord.key])

	return strings.clone(strings.to_string(builder), allocator)
}

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

is_editing :: proc(ctx: ^Context) -> bool {
	return ctx != nil && ctx.focus != 0 && ctx.caret_index != -1
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
		if !(event.modifiers >= required && event.modifiers <= required + optional) do continue

		ctx.key_event_consumed[index] = true
		return true
	}
	return false
}

// Consume one exact shortcut press through the normal focus and popup routing.
shortcut_pressed :: proc(shortcut: Shortcut, focus: Id = 0, repeat := false) -> bool {
	chord := shortcut_chord(shortcut)
	return key_pressed(chord.key, focus = focus, required = chord.modifiers, repeat = repeat)
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

		if !point_in_element(ctx, previous, position, element_index) {
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
		ctx.text_selection = {ctx.text_selection_anchor.start, end}
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
		   (key_pressed(
					   .ENTER,
					   focus = element.id,
					   optional = TEXT_KEY_MODIFIERS,
					   repeat = false,
				   ) ||
				   key_pressed(
					   .KP_ENTER,
					   focus = element.id,
					   optional = TEXT_KEY_MODIFIERS,
					   repeat = false,
				   )) {
			clear_focus_context(ctx)
		} else {
			ctrl_down := .Control in ctx.key_modifiers
			cmd_down := .Command in ctx.key_modifiers
			shift_down := .Shift in ctx.key_modifiers
			state := text_editor_bind(ctx, element)
			interacted := false

			when ODIN_OS == .Darwin {
				word_modifier := .Alt in ctx.key_modifiers
			} else {
				word_modifier := ctrl_down
			}

			for char in text_events {
				if char == '\r' || char == '\n' {
					continue
				}
				text_edit.input_rune(state, char)
				interacted = true
			}

			if key_pressed(.Z, focus = element.id, required = SHORTCUT_MODIFIER + {.Shift}) {
				text_edit.perform_command(state, .Redo)
				interacted = true
			} else if key_pressed(.Z, focus = element.id, required = SHORTCUT_MODIFIER) {
				text_edit.perform_command(state, .Undo)
				interacted = true
			} else if key_pressed(.Y, focus = element.id, required = SHORTCUT_MODIFIER) {
				text_edit.perform_command(state, .Redo)
				interacted = true
			}

			if key_pressed(.LEFT, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				translation: text_edit.Translation = word_modifier ? .Word_Left : .Left
				when ODIN_OS == .Darwin {
					if cmd_down {
						state.line_start = caret_index_start_of_line(
							ctx,
							element,
							state.selection[0],
						)
						translation = .Soft_Line_Start
					}
				}
				text_editor_move(state, translation, shift_down)
				interacted = true
			}

			if key_pressed(.RIGHT, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				translation: text_edit.Translation = word_modifier ? .Word_Right : .Right
				when ODIN_OS == .Darwin {
					if cmd_down {
						state.line_end = caret_index_end_of_line(ctx, element, state.selection[0])
						translation = .Soft_Line_End
					}
				}
				text_editor_move(state, translation, shift_down)
				interacted = true
			}

			if key_pressed(.HOME, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				translation: text_edit.Translation = .Start
				if ctrl_down || cmd_down || element.overflow == .Visible {
					translation = .Start
				} else {
					state.line_start = caret_index_start_of_line(ctx, element, state.selection[0])
					translation = .Soft_Line_Start
				}
				text_editor_move(state, translation, shift_down)
				interacted = true
			}

			if key_pressed(.END, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				translation: text_edit.Translation = .End
				if ctrl_down || cmd_down || element.overflow == .Visible {
					translation = .End
				} else {
					state.line_end = caret_index_end_of_line(ctx, element, state.selection[0])
					translation = .Soft_Line_End
				}
				text_editor_move(state, translation, shift_down)
				interacted = true
			}

			if element.overflow == .Wrap {
				if key_pressed(.UP, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					translation: text_edit.Translation = .Up
					state.up_index = caret_index_up(ctx, element, ctx.caret_position)
					when ODIN_OS == .Darwin {
						if cmd_down {
							translation = .Start
						}
					}
					text_editor_move(state, translation, shift_down)
					interacted = true
				}

				if key_pressed(.DOWN, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					translation: text_edit.Translation = .Down
					state.down_index = caret_index_down(ctx, element, ctx.caret_position)
					when ODIN_OS == .Darwin {
						if cmd_down {
							translation = .End
						}
					}
					text_editor_move(state, translation, shift_down)
					interacted = true
				}

				if key_pressed(.PAGE_UP, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					state.up_index = caret_index_up(ctx, element, ctx.caret_position, 5)
					text_editor_move(state, .Up, shift_down)
					interacted = true
				}

				if key_pressed(.PAGE_DOWN, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
					state.down_index = caret_index_down(ctx, element, ctx.caret_position, 5)
					text_editor_move(state, .Down, shift_down)
					interacted = true
				}
			}

			if key_pressed(.BACKSPACE, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				command: text_edit.Command = word_modifier ? .Delete_Word_Left : .Backspace
				when ODIN_OS == .Darwin {
					if cmd_down {
						state.line_start = caret_index_start_of_line(
							ctx,
							element,
							state.selection[0],
						)
						text_edit.delete_to(state, .Soft_Line_Start)
					} else {
						text_edit.perform_command(state, command)
					}
				} else {
					text_edit.perform_command(state, command)
				}
				interacted = true
			}

			if key_pressed(.DELETE, focus = element.id, optional = TEXT_KEY_MODIFIERS) {
				command: text_edit.Command = word_modifier ? .Delete_Word_Right : .Delete
				text_edit.perform_command(state, command)
				interacted = true
			}

			if (key_pressed(.ENTER, focus = element.id, optional = TEXT_KEY_MODIFIERS) ||
				   key_pressed(.KP_ENTER, focus = element.id, optional = TEXT_KEY_MODIFIERS)) &&
			   element.overflow == .Wrap {
				text_edit.perform_command(state, .New_Line)
				interacted = true
			}

			if key_pressed(.A, focus = element.id, required = SHORTCUT_MODIFIER) {
				text_edit.perform_command(state, .Select_All)
				interacted = true
			}

			if key_pressed(.C, focus = element.id, required = SHORTCUT_MODIFIER) {
				if text_edit.has_selection(state) {
					text_edit.perform_command(state, .Copy)
				}
			}

			if key_pressed(.X, focus = element.id, required = SHORTCUT_MODIFIER) {
				if text_edit.has_selection(state) {
					text_edit.perform_command(state, .Cut)
					interacted = true
				}
			}

			if key_pressed(.V, focus = element.id, required = SHORTCUT_MODIFIER) {
				text_edit.perform_command(state, .Paste)
				interacted = true
			}

			text_editor_sync(ctx, element, state, interacted)
		}
	}
}

@(private)
text_editor_bind :: proc(ctx: ^Context, element: ^Element) -> ^text_edit.State {
	state := &ctx.text_edit_state
	id := u64(element.id)
	// `text_edit.begin` clears history, so only initialise when the active editor changes.
	if state.id != id || (state.builder != nil && state.builder != element.text_input) {
		text_edit.setup_once(state, element.text_input)
		state.id = id
		state.last_edit_time = {}
	} else {
		state.builder = element.text_input
	}

	state.selection = {ctx.caret_index, ctx.caret_index}
	if has_text_selection(ctx) {
		state.selection[1] = ctx.text_selection.start
	}
	text_edit.update_time(state)
	return state
}

@(private)
text_editor_move :: proc(
	state: ^text_edit.State,
	translation: text_edit.Translation,
	selecting: bool,
) {
	if selecting {
		text_edit.select_to(state, translation)
	} else {
		text_edit.move_to(state, translation)
	}
}

@(private)
text_editor_sync :: proc(
	ctx: ^Context,
	element: ^Element,
	state: ^text_edit.State,
	interacted: bool,
) {
	ctx.caret_index = state.selection[0]
	if text_edit.has_selection(state) {
		ctx.text_selection = {state.selection[1], state.selection[0]}
	} else {
		ctx.text_selection = {}
	}
	element.text = strings.to_string(element.text_input^)
	if interacted {
		ctx.caret_time = 0
		ensure_caret_visible(ctx, element, ctx.caret_index)
	}
}

@(private)
text_editor_set_clipboard :: proc(user_data: rawptr, text: string) -> bool {
	ctx := cast(^Context)user_data
	rl.SetClipboardText(strings.clone_to_cstring(text, ctx.allocator[current_buffer(ctx)]))
	return true
}

@(private)
text_editor_get_clipboard :: proc(user_data: rawptr) -> (text: string, ok: bool) {
	clipboard_text := rl.GetClipboardText()
	if clipboard_text == nil {
		return "", false
	}
	return string(clipboard_text), true
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
point_in_element :: proc(ctx: ^Context, buffer: int, p: rl.Vector2, index: i32) -> bool {
	elements := &ctx.elements[buffer]
	element := &elements[index]
	position := rl.Vector2 {
		element._position.x - element.hit_slop.left,
		element._position.y - element.hit_slop.top,
	}
	size := rl.Vector2 {
		element._size.x + element.hit_slop.left + element.hit_slop.right,
		element._size.y + element.hit_slop.top + element.hit_slop.bottom,
	}
	if !rl.CheckCollisionPointRec(p, {position.x, position.y, size.x, size.y}) {
		return false
	}

	interaction_clip: ClipRectangle
	switch element.clip.type {
	case .Inherit, .Self, .Manual:
		interaction_clip = element._clip
	case .Intersect:
		interaction_clip = elements[element.parent]._clip
	case .None:
	}
	if interaction_clip.width > 0 || interaction_clip.height > 0 {
		return rl.CheckCollisionPointRec(
			p,
			{
				f32(interaction_clip.x),
				f32(interaction_clip.y),
				f32(interaction_clip.width),
				f32(interaction_clip.height),
			},
		)
	}

	return true
}

@(private)
has_text_selection :: #force_inline proc(ctx: ^Context) -> bool {
	return ctx.text_selection.start != ctx.text_selection.end
}
