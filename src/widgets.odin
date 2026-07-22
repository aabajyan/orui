package orui

import "core:strings"
import rl "vendor:raylib"

@(deferred_none = end_element)
// An element that can contain children.
// Must have its own scope.
container :: proc(
	id: Id,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	for modifier in modifiers {
		modifier(element)
	}
	return true
}

// A text element that can be use to display text.
// This element cannot have children.
label :: proc(
	id: Id,
	text: string,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	element.layout = .None
	element.has_text = true
	element.text = text

	for modifier in modifiers {
		modifier(element)
	}

	if element.font == nil && current_context.default_font != {} {
		element.font = &current_context.default_font
	}

	end_element()

	return .Clicked in pointer_response(id)
}

// A text element that displays text and allows the user to edit it.
// This element cannot have children.
text_input :: proc(
	id: Id,
	text: ^strings.Builder,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	element.layout = .None
	element.has_text = true
	element.text_input = text
	element.text = string(text.buf[:])
	element.editable = true
	element.focus = {.Pointer, .Navigation}
	element.whitespace = .Preserve

	for modifier in modifiers {
		modifier(element)
	}

	if element.font == nil && current_context.default_font != {} {
		element.font = &current_context.default_font
	}

	end_element()

	return current_context.prev_focus_id == id && current_context.focus_id != id
}

// An element that displays a texture.
// This element cannot have children.
image :: proc(
	id: Id,
	texture: ^rl.Texture2D,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	element.layout = .None
	element.texture = texture

	for modifier in modifiers {
		modifier(element)
	}

	end_element()

	return .Clicked in pointer_response(id)
}

Scroll_Axis :: enum {
	Vertical,
	Horizontal,
}

Scroll_Bar_Track_Click :: enum {
	None,
	Jump,
	Page,
}

Scroll_Bar_Visibility :: enum {
	When_Needed,
	Always,
	Hidden,
}

Scroll_Bar_Options :: struct {
	axis:             Scroll_Axis,
	visibility:       Scroll_Bar_Visibility,
	track_click:      Scroll_Bar_Track_Click,
	min_thumb_extent: f32,
	hit_extent:       f32,
}

SCROLL_BAR_DEFAULT_MIN_THUMB_EXTENT: f32 : 24

@(private = "file")
SCROLL_BAR_PAGE_REPEAT_DELAY: f32 : 0.5
@(private = "file")
SCROLL_BAR_PAGE_REPEAT_INTERVAL: f32 : 0.1

@(private = "file")
Scroll_Bar_Session_Action :: enum {
	Drag,
	Page,
}

@(private = "package")
Scroll_Bar_Session :: struct {
	active:           bool,
	id:               Id,
	axis:             Scroll_Axis,
	action:           Scroll_Bar_Session_Action,
	grab_offset:      f32,
	held_time:        f32,
	next_repeat_time: f32,
}

@(private = "file")
Scroll_Bar_Part :: enum {
	Track_Vertical,
	Thumb_Vertical,
	Track_Horizontal,
	Thumb_Horizontal,
}

scrollbar :: proc(
	parent: Id,
	options: Scroll_Bar_Options,
	track_config: ElementConfig,
	thumb_config: ElementConfig,
	loc := #caller_location,
) {
	ctx := current_context
	track_id := scroll_bar_part_id(parent, options.axis, false)
	thumb_id := scroll_bar_part_id(parent, options.axis, true)

	track_element, track_parent := begin_element(id(track_id), loc)
	configure_element(ctx, track_element, track_parent^, track_config)
	track_element.clip = {.None, {}}
	set_hit_slop(track_id, scroll_bar_hit_slop(options, track_config, track_id))

	metrics := scroll_bar_metrics(parent, track_id, options)
	shown :=
		options.visibility == .Always ||
		(options.visibility == .When_Needed && (!metrics.known || metrics.can_scroll))
	interactive := shown && metrics.can_scroll
	if !shown {
		scroll_bar_hide_element(track_element)
	}

	thumb_element, thumb_parent := begin_element(id(thumb_id), loc)
	configure_element(ctx, thumb_element, thumb_parent^, thumb_config)
	thumb_element.layout = .None
	cross_position := scroll_bar_thumb_cross_position(
		options.axis,
		track_config,
		thumb_config,
		metrics.track_size,
		thumb_id,
	)
	if options.axis == .Vertical {
		thumb_element.height = fixed(metrics.thumb_extent)
		thumb_element.position = {
			.Relative,
			{cross_position + thumb_config.position.value.x, metrics.thumb_position},
		}
	} else {
		thumb_element.width = fixed(metrics.thumb_extent)
		thumb_element.position = {
			.Relative,
			{metrics.thumb_position, cross_position + thumb_config.position.value.y},
		}
	}
	thumb_element.block = .False
	if !shown {
		scroll_bar_hide_element(thumb_element)
	}
	end_element()

	response: Pointer_Response
	if interactive {
		response = pointer_response(track_id)
	}
	session := &ctx.scrollbar_session
	if session.active && session.id == track_id && !interactive {
		session^ = {}
	}
	if !session.active && .Pressed in response {
		pointer := scroll_bar_axis_value(pointer_position(), options.axis)
		thumb_start := metrics.track_position + metrics.thumb_position
		if pointer >= thumb_start && pointer <= thumb_start + metrics.thumb_extent {
			session^ = {
				active      = true,
				id          = track_id,
				axis        = options.axis,
				grab_offset = pointer - thumb_start,
			}
		} else if options.track_click == .Jump {
			session^ = {
				active      = true,
				id          = track_id,
				axis        = options.axis,
				grab_offset = metrics.thumb_extent * 0.5,
			}
		} else if options.track_click == .Page {
			scroll_bar_page(parent, metrics, options.axis, pointer, thumb_start)
			session^ = {
				active           = true,
				id               = track_id,
				axis             = options.axis,
				action           = .Page,
				next_repeat_time = SCROLL_BAR_PAGE_REPEAT_DELAY,
			}
		}
	}

	if session.active && session.id == track_id {
		switch session.action {
		case .Drag:
			scroll_bar_drag(parent, metrics, session^)
		case .Page:
			scroll_bar_repeat_page(parent, metrics, session)
		}
		if .Released in response {
			ctx.scrollbar_session = {}
		}
	}

	end_element()
}

@(private = "file")
scroll_bar_repeat_page :: proc(
	parent_id: Id,
	metrics: Scroll_Bar_Metrics,
	session: ^Scroll_Bar_Session,
) {
	session.held_time += current_context.dt
	if session.held_time < session.next_repeat_time do return

	pointer := scroll_bar_axis_value(pointer_position(), session.axis)
	thumb_start := metrics.track_position + metrics.thumb_position
	if pointer >= thumb_start && pointer <= thumb_start + metrics.thumb_extent do return

	scroll_bar_page(parent_id, metrics, session.axis, pointer, thumb_start)
	session.next_repeat_time += SCROLL_BAR_PAGE_REPEAT_INTERVAL
}

@(private = "file")
scroll_bar_hide_element :: proc(element: ^Element) {
	element.background_color = {}
	element.border_color = {}
	element.block = .False
	element.custom_event = nil
}

@(private = "file")
Scroll_Bar_Metrics :: struct {
	known:           bool,
	can_scroll:      bool,
	parent:          ^Element,
	max_scroll:      f32,
	viewport_extent: f32,
	track_position:  f32,
	track_extent:    f32,
	track_size:      rl.Vector2,
	thumb_extent:    f32,
	thumb_position:  f32,
}

@(private = "file")
scroll_bar_part_id :: proc(parent: Id, axis: Scroll_Axis, thumb: bool) -> Id {
	namespace := to_id(to_id("orui scrollbar"), int(parent))
	part := Scroll_Bar_Part.Track_Vertical
	if axis == .Vertical {
		part = thumb ? .Thumb_Vertical : .Track_Vertical
	} else {
		part = thumb ? .Thumb_Horizontal : .Track_Horizontal
	}
	return to_id(namespace, int(part))
}

@(private = "file")
scroll_bar_metrics :: proc(
	parent_id, track_id: Id,
	options: Scroll_Bar_Options,
) -> Scroll_Bar_Metrics {
	parent := get_element(parent_id)
	track := get_element(track_id)
	if parent == nil || track == nil do return {}

	viewport := options.axis == .Vertical ? inner_height(parent) : inner_width(parent)
	content := options.axis == .Vertical ? parent._content_size.y : parent._content_size.x
	track_extent := options.axis == .Vertical ? track._size.y : track._size.x
	max_scroll := max(0, content - viewport)
	thumb_extent := track_extent
	if content > 0 {
		min_thumb_extent :=
			options.min_thumb_extent > 0 ? options.min_thumb_extent : SCROLL_BAR_DEFAULT_MIN_THUMB_EXTENT
		thumb_extent = clamp(track_extent * viewport / content, min_thumb_extent, track_extent)
	}
	thumb_range := max(0, track_extent - thumb_extent)
	offset := options.axis == .Vertical ? parent.scroll.offset.y : parent.scroll.offset.x
	thumb_position := max_scroll > 0 ? clamp(offset / max_scroll, 0, 1) * thumb_range : 0
	return {
		known = true,
		can_scroll = max_scroll > 0,
		parent = parent,
		max_scroll = max_scroll,
		viewport_extent = viewport,
		track_position = scroll_bar_axis_position(track, options.axis),
		track_extent = track_extent,
		track_size = track._size,
		thumb_extent = thumb_extent,
		thumb_position = thumb_position,
	}
}

@(private = "file")
scroll_bar_page :: proc(
	parent_id: Id,
	metrics: Scroll_Bar_Metrics,
	axis: Scroll_Axis,
	pointer, thumb_start: f32,
) {
	parent := metrics.parent
	if parent == nil do return
	direction: f32 = pointer < thumb_start ? -1 : 1
	offset := parent.scroll.offset
	if axis == .Vertical {
		offset.y = clamp(offset.y + direction * metrics.viewport_extent, 0, metrics.max_scroll)
	} else {
		offset.x = clamp(offset.x + direction * metrics.viewport_extent, 0, metrics.max_scroll)
	}
	set_scroll_offset(parent_id, offset)
}

@(private = "file")
scroll_bar_hit_slop :: proc(
	options: Scroll_Bar_Options,
	config: ElementConfig,
	track_id: Id,
) -> Edges {
	visual_extent: f32
	if options.axis == .Vertical {
		visual_extent = config.width.type == .Fixed ? config.width.value : size(track_id).x
	} else {
		visual_extent = config.height.type == .Fixed ? config.height.value : size(track_id).y
	}
	slop := max(0, (options.hit_extent - visual_extent) * 0.5)
	return(
		options.axis == .Vertical ? Edges{left = slop, right = slop} : Edges{top = slop, bottom = slop} \
	)
}

@(private = "file")
scroll_bar_axis_value :: proc(value: rl.Vector2, axis: Scroll_Axis) -> f32 {
	return axis == .Vertical ? value.y : value.x
}

@(private = "file")
scroll_bar_axis_position :: proc(element: ^Element, axis: Scroll_Axis) -> f32 {
	if element == nil do return 0
	return axis == .Vertical ? element._position.y : element._position.x
}

@(private = "file")
scroll_bar_thumb_cross_position :: proc(
	axis: Scroll_Axis,
	track_config, thumb_config: ElementConfig,
	track_size: rl.Vector2,
	thumb_id: Id,
) -> f32 {
	thumb_size := size(thumb_id)
	track_extent: f32
	thumb_extent: f32
	if axis == .Vertical {
		track_extent = scroll_bar_config_extent(track_config.width, track_size.x, track_size.x)
		thumb_extent = scroll_bar_config_extent(thumb_config.width, thumb_size.x, track_extent)
	} else {
		track_extent = scroll_bar_config_extent(track_config.height, track_size.y, track_size.y)
		thumb_extent = scroll_bar_config_extent(thumb_config.height, thumb_size.y, track_extent)
	}
	return (track_extent - thumb_extent) * 0.5
}

@(private = "file")
scroll_bar_config_extent :: proc(config: Size, measured, parent_extent: f32) -> f32 {
	if config.type == .Fixed do return config.value
	if config.type == .Percent do return parent_extent * config.value
	return measured
}

@(private = "file")
scroll_bar_drag :: proc(parent_id: Id, metrics: Scroll_Bar_Metrics, session: Scroll_Bar_Session) {
	parent := metrics.parent
	if parent == nil do return

	pointer := scroll_bar_axis_value(pointer_position(), session.axis)
	thumb_range := max(0, metrics.track_extent - metrics.thumb_extent)
	thumb_position := clamp(pointer - metrics.track_position - session.grab_offset, 0, thumb_range)
	percent := thumb_range > 0 ? thumb_position / thumb_range : 0
	offset := parent.scroll.offset
	if session.axis == .Vertical {
		offset.y = percent * metrics.max_scroll
	} else {
		offset.x = percent * metrics.max_scroll
	}
	set_scroll_offset(parent_id, offset)
}
