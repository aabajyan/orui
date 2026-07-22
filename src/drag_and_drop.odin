package orui

import rl "vendor:raylib"

DRAG_DEFAULT_THRESHOLD: f32 : 6

Drag_Response_Flag :: enum {
	Started,
	Dragged,
	Stopped,
	Cancelled,
}

Drag_Response_Flags :: bit_set[Drag_Response_Flag;u8]

Drag_Response :: struct {
	flags:       Drag_Response_Flags,
	source:      Id,
	origin:      rl.Vector2,
	position:    rl.Vector2,
	delta:       rl.Vector2,
	total_delta: rl.Vector2,
	grab_offset: rl.Vector2,
}

Drop_Response_Flag :: enum {
	Hovered,
	Dropped,
}

Drop_Response_Flags :: bit_set[Drop_Response_Flag;u8]

Drop_Response :: struct {
	flags:  Drop_Response_Flags,
	source: Id,
}

@(private = "package")
Drag_Drop_Session :: struct {
	source:            Id,
	pointer_owner:     Id,
	button:            rl.MouseButton,
	threshold:         f32,
	origin:            rl.Vector2,
	previous_position: rl.Vector2,
	position:          rl.Vector2,
	grab_offset:       rl.Vector2,
	active:            bool,
	started:           bool,
	stopped:           bool,
	cancelled:         bool,
}

// Register id as a drag source. The gesture starts after the pointer travels
// farther than threshold from its press origin. Call every frame the source is
// declared; drag_response keeps an active gesture observable if it disappears.
drag_source :: proc(
	id: Id,
	threshold: f32 = DRAG_DEFAULT_THRESHOLD,
	button: rl.MouseButton = .LEFT,
) -> Drag_Response {
	return drag_source_owned(id, 0, threshold, button)
}

@(private = "package")
drag_source_owned :: proc(
	id, required_owner: Id,
	threshold: f32 = DRAG_DEFAULT_THRESHOLD,
	button: rl.MouseButton = .LEFT,
) -> Drag_Response {
	ctx := current_context
	session := &ctx.drag_drop_session
	pressed := .Pressed in pointer_response(id, button)
	if required_owner != 0 {
		pressed = ctx.pointer_pressed_id == required_owner && ctx.pointer_pressed_button == button
	}
	if session.source == 0 && pressed {
		position := pointer_position()
		rect := bounding_rect(id)
		session^ = {
			source            = id,
			pointer_owner     = ctx.pointer_pressed_id,
			button            = button,
			threshold         = max(0, threshold),
			origin            = position,
			previous_position = position,
			position          = position,
			grab_offset       = position - rl.Vector2{rect.x, rect.y},
		}
	}

	return drag_response(id)
}

// Read a source's current gesture without requiring its element to be declared.
drag_response :: proc(id: Id) -> Drag_Response {
	session := &current_context.drag_drop_session
	if session.source != id do return {}

	flags: Drag_Response_Flags
	if session.started do flags += {.Started}
	if session.active do flags += {.Dragged}
	if session.stopped do flags += {.Stopped}
	if session.cancelled do flags += {.Cancelled}
	return {
		flags = flags,
		source = session.source,
		origin = session.origin,
		position = session.position,
		delta = session.position - session.previous_position,
		total_delta = session.position - session.origin,
		grab_offset = session.grab_offset,
	}
}

// Test a target geometrically while pointer capture suppresses normal hover.
// source is explicit so application payloads can remain caller-owned and typed.
drop_target :: proc(id, source: Id) -> Drop_Response {
	session := &current_context.drag_drop_session
	if source == 0 || session.source != source || id == source do return {}
	if !(session.active || session.stopped) || !pointer_contains(id) do return {}

	flags: Drop_Response_Flags
	if session.active do flags += {.Hovered}
	if session.stopped do flags += {.Dropped}
	return {flags = flags, source = source}
}

// Whether the pointer is inside id's clipped interaction rectangle, independent
// of pointer ownership and normal hover routing.
pointer_contains :: proc(id: Id) -> bool {
	ctx := current_context
	buffer := previous_buffer(ctx)
	index, ok := element_index_by_id(ctx, buffer, id)
	if !ok do return false
	return point_in_element(ctx, buffer, ctx.pointer_position, index)
}

@(private = "package")
end_drag_drop_session :: proc(ctx: ^Context) {
	session := &ctx.drag_drop_session
	if session.source != 0 {
		button := int(session.button)
		if session.stopped ||
		   session.cancelled ||
		   button < 0 ||
		   button >= len(ctx.pointer_buttons_down) ||
		   !ctx.pointer_buttons_down[button] {
			session^ = {}
		}
	}
	if session.source == 0 {
		ctx.sortable_axis_session = {}
	}
}

@(private = "package")
update_drag_drop_session :: proc(ctx: ^Context) {
	session := &ctx.drag_drop_session
	if session.source == 0 do return

	session.started = false
	session.stopped = false
	session.cancelled = false
	session.previous_position = session.position
	session.position = ctx.pointer_position

	if session.active && key_pressed(.ESCAPE, repeat = false) {
		session.cancelled = true
		session.active = false
		return
	}

	released :=
		ctx.pointer_released_id == session.pointer_owner &&
		ctx.pointer_released_button == session.button
	if released {
		session.stopped = session.active
		session.active = false
		return
	}

	button := int(session.button)
	if button < 0 || button >= len(ctx.pointer_buttons_down) || !ctx.pointer_buttons_down[button] {
		session.cancelled = session.active
		session.active = false
		return
	}

	if !session.active {
		delta := session.position - session.origin
		if delta.x * delta.x + delta.y * delta.y > session.threshold * session.threshold {
			session.active = true
			session.started = true
		}
	}
}
