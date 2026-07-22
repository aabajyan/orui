package orui

import rl "vendor:raylib"

SORTABLE_AXIS_DEFAULT_EDGE_SCROLL_ZONE: f32 : 32
SORTABLE_AXIS_DEFAULT_EDGE_SCROLL_ITEMS_PER_SECOND: f32 : 8

Sortable_Axis_Release_Policy :: enum {
	Require_Inside,
	Clamp_To_Axis,
}

Sortable_Axis_Options :: struct {
	count:                        int,
	item_extent:                  f32,
	gap:                          f32,
	direction:                    LayoutDirection,
	release:                      Sortable_Axis_Release_Policy,
	edge_scroll_zone:             f32,
	edge_scroll_items_per_second: f32,
}

Sortable_Axis_Response :: struct {
	drag:              Drag_Response,
	source_index:      int,
	insertion_index:   int,
	destination_index: int,
	marker_offset:     f32,
	ghost_rect:        rl.Rectangle,
	dropped:           bool,
}

@(private = "package")
Sortable_Axis_Session :: struct {
	axis:         Id,
	source:       Id,
	source_index: int,
	source_rect:  rl.Rectangle,
}

// Register an item as a direct sortable source. When handle is non-zero, only
// that element may own the initiating press; otherwise the item itself must own
// it. Interactive descendants therefore do not accidentally begin sorting.
sortable_item :: proc(
	axis, item: Id,
	index: int,
	handle: Id = 0,
	threshold: f32 = DRAG_DEFAULT_THRESHOLD,
	button: rl.MouseButton = .LEFT,
) -> Drag_Response {
	owner := handle
	if owner == 0 do owner = item
	drag := drag_source_owned(item, owner, threshold, button)

	ctx := current_context
	if ctx.drag_drop_session.source == item {
		session := &ctx.sortable_axis_session
		if session.source == 0 {
			session^ = {
				axis         = axis,
				source       = item,
				source_index = index,
				source_rect  = bounding_rect(item),
			}
		}
	}
	return drag
}

// Resolve fixed-pitch sortable geometry independently of how the axis items
// were declared. Call after registering the visible items for this frame.
sortable_axis :: proc(axis: Id, options: Sortable_Axis_Options) -> Sortable_Axis_Response {
	ctx := current_context
	session := &ctx.sortable_axis_session
	if session.source == 0 || session.axis != axis do return {}

	drag := drag_response(session.source)
	response := Sortable_Axis_Response {
		drag              = drag,
		source_index      = session.source_index,
		insertion_index   = session.source_index,
		destination_index = session.source_index,
		ghost_rect        = session.source_rect,
	}
	if options.count <= 0 || options.item_extent <= 0 do return response

	pitch := max(1, options.item_extent + max(0, options.gap))
	axis_rect := bounding_rect(axis)
	scroll := scroll_offset(axis)
	if .Dragged in drag.flags {
		scroll = sortable_axis_auto_scroll(axis, axis_rect, options, scroll)
	}
	position := drag.position
	content_position: f32
	if options.direction == .LeftToRight {
		content_position = position.x - axis_rect.x + scroll.x
		response.ghost_rect.x = position.x - drag.grab_offset.x
	} else {
		content_position = position.y - axis_rect.y + scroll.y
		response.ghost_rect.y = position.y - drag.grab_offset.y
	}

	response.insertion_index = clamp(
		int((content_position + pitch * 0.5) / pitch),
		0,
		options.count,
	)
	response.destination_index = response.insertion_index
	if response.destination_index > session.source_index {
		response.destination_index -= 1
	}
	response.destination_index = clamp(response.destination_index, 0, options.count - 1)

	if response.insertion_index == options.count {
		response.marker_offset =
			f32(options.count) * options.item_extent +
			f32(max(0, options.count - 1)) * max(0, options.gap)
	} else {
		response.marker_offset = f32(response.insertion_index) * pitch
	}

	if .Stopped in drag.flags {
		switch options.release {
		case .Require_Inside:
			response.dropped = pointer_contains(axis)
		case .Clamp_To_Axis:
			response.dropped = true
		}
	}
	return response
}

@(private = "file")
sortable_axis_auto_scroll :: proc(
	axis: Id,
	axis_rect: rl.Rectangle,
	options: Sortable_Axis_Options,
	offset: rl.Vector2,
) -> rl.Vector2 {
	if options.edge_scroll_zone <= 0 || options.edge_scroll_items_per_second <= 0 {
		return offset
	}

	position := pointer_position()
	main_position, viewport_start, viewport_extent: f32
	if options.direction == .LeftToRight {
		main_position = position.x
		viewport_start = axis_rect.x
		viewport_extent = axis_rect.width
	} else {
		main_position = position.y
		viewport_start = axis_rect.y
		viewport_extent = axis_rect.height
	}
	if viewport_extent <= 0 do return offset

	zone := min(options.edge_scroll_zone, viewport_extent * 0.5)
	direction: f32
	if main_position < viewport_start + zone {
		direction = -1
	} else if main_position > viewport_start + viewport_extent - zone {
		direction = 1
	} else {
		return offset
	}

	total_extent :=
		f32(options.count) * options.item_extent +
		f32(max(0, options.count - 1)) * max(0, options.gap)
	max_offset := max(0, total_extent - viewport_extent)
	delta :=
		direction * options.item_extent * options.edge_scroll_items_per_second * current_context.dt
	new_offset := offset
	if options.direction == .LeftToRight {
		new_offset.x = clamp(offset.x + delta, 0, max_offset)
	} else {
		new_offset.y = clamp(offset.y + delta, 0, max_offset)
	}
	set_scroll_offset(axis, new_offset)
	return new_offset
}
