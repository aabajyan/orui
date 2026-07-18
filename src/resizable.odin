package orui

import rl "vendor:raylib"

Resize_Edge :: enum {
	Left,
	Right,
	Top,
	Bottom,
}

Resize_Edges :: bit_set[Resize_Edge;u8]

@(private = "package")
Resize_Drag_Session :: struct {
	active:           bool,
	id:               Id,
	drag_start_mouse: rl.Vector2,
	start_rect:       rl.Rectangle,
	edges:            Resize_Edges,
}

// Turn an existing element into an edge-resize handle for a caller-owned rectangle.
// Call after declaring id. Sizes and limits use ORUI units; max = 0 means unbounded.
resizable :: proc(
	id: Id,
	edges: Resize_Edges,
	rect: ^rl.Rectangle,
	min_width: f32 = 0,
	max_width: f32 = 0,
	min_height: f32 = 0,
	max_height: f32 = 0,
	hit_size: f32 = 10,
	corner_size: f32 = 20,
) -> bool {
	if rect == nil do return false

	set_hit_slop(id, resize_hit_slop(edges, hit_size * 0.5, corner_size * 0.5))

	ctx := current_context
	response := pointer_response(id)
	session := &ctx.resize_drag
	if session.active && session.id == id {
		delta := pointer_position() - session.drag_start_mouse
		if .Left in session.edges {
			right := session.start_rect.x + session.start_rect.width
			rect.width = resize_clamp_size(
				session.start_rect.width - delta.x,
				min_width,
				max_width,
			)
			rect.x = right - rect.width
		}
		if .Top in session.edges {
			bottom := session.start_rect.y + session.start_rect.height
			rect.height = resize_clamp_size(
				session.start_rect.height - delta.y,
				min_height,
				max_height,
			)
			rect.y = bottom - rect.height
		}
		if .Right in session.edges {
			rect.width = resize_clamp_size(
				session.start_rect.width + delta.x,
				min_width,
				max_width,
			)
		}
		if .Bottom in session.edges {
			rect.height = resize_clamp_size(
				session.start_rect.height + delta.y,
				min_height,
				max_height,
			)
		}
		request_cursor(id, resize_cursor(session.edges))
		if .Released in response {
			ctx.resize_drag = {}
		}
		return true
	}

	if session.active || .Hovered not_in response do return false
	hovered := hovered_resize_edges(id, edges, hit_size, corner_size)
	if hovered == {} do return false

	request_cursor(id, resize_cursor(hovered))
	if .Pressed in response {
		session^ = {
			active           = true,
			id               = id,
			drag_start_mouse = pointer_position(),
			start_rect       = rect^,
			edges            = hovered,
		}
	}
	return true
}

@(private = "file")
resize_hit_slop :: proc(edges: Resize_Edges, edge_slop, corner_slop: f32) -> Edges {
	result: Edges
	if .Left in edges do result.left = edge_slop
	if .Right in edges do result.right = edge_slop
	if .Top in edges do result.top = edge_slop
	if .Bottom in edges do result.bottom = edge_slop
	if result.left > 0 && (result.top > 0 || result.bottom > 0) do result.left = corner_slop
	if result.right > 0 && (result.top > 0 || result.bottom > 0) do result.right = corner_slop
	if result.top > 0 && (result.left > 0 || result.right > 0) do result.top = corner_slop
	if result.bottom > 0 && (result.left > 0 || result.right > 0) do result.bottom = corner_slop

	return result
}

@(private = "file")
hovered_resize_edges :: proc(
	id: Id,
	edges: Resize_Edges,
	hit_size, corner_size: f32,
) -> Resize_Edges {
	box := bounding_rect(id)
	if box.width <= 0 || box.height <= 0 do return {}
	mouse := pointer_position()

	// Corners take priority over their overlapping side handles.
	corners := [4]Resize_Edges{{.Left, .Top}, {.Right, .Top}, {.Left, .Bottom}, {.Right, .Bottom}}
	for corner in corners {
		if !resize_edges_supported(edges, corner) do continue
		if rl.CheckCollisionPointRec(mouse, resize_corner_hit_rect(box, corner, corner_size)) {
			return corner
		}
	}

	for edge in Resize_Edge {
		if edge not_in edges do continue
		if rl.CheckCollisionPointRec(mouse, resize_edge_hit_rect(box, edge, hit_size)) {
			return {edge}
		}
	}

	return {}
}

@(private = "file")
resize_edges_supported :: proc(supported, requested: Resize_Edges) -> bool {
	for edge in requested {
		if edge not_in supported do return false
	}
	return true
}

@(private = "file")
resize_corner_hit_rect :: proc(box: rl.Rectangle, edges: Resize_Edges, size: f32) -> rl.Rectangle {
	half := size * 0.5
	x := .Right in edges ? box.x + box.width : box.x
	y := .Bottom in edges ? box.y + box.height : box.y
	return {x - half, y - half, size, size}
}

@(private = "file")
resize_edge_hit_rect :: proc(box: rl.Rectangle, edge: Resize_Edge, hit_size: f32) -> rl.Rectangle {
	half := hit_size * 0.5
	result := box
	switch edge {
	case .Left:
		result.x = box.x - half
		result.width = hit_size
	case .Right:
		result.x = box.x + box.width - half
		result.width = hit_size
	case .Top:
		result.y = box.y - half
		result.height = hit_size
	case .Bottom:
		result.y = box.y + box.height - half
		result.height = hit_size
	}

	return result
}

@(private = "file")
resize_cursor :: proc(edges: Resize_Edges) -> Cursor {
	horizontal := .Left in edges || .Right in edges
	vertical := .Top in edges || .Bottom in edges
	if horizontal && vertical {
		if (.Left in edges && .Top in edges) || (.Right in edges && .Bottom in edges) {
			return .ResizeNWSE
		}

		return .ResizeNESW
	}

	return horizontal ? .ResizeEW : .ResizeNS
}

@(private = "file")
resize_clamp_size :: proc(value, min_value, max_value: f32) -> f32 {
	if max_value == 0 do return max(value, min_value)
	return clamp(value, min_value, max_value)
}
