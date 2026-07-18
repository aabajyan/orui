package orui

import rl "vendor:raylib"

Pointer_Response_Flag :: enum {
	Hovered,
	Pressed,
	Held,
	Released,
	Clicked,
}

Pointer_Response :: bit_set[Pointer_Response_Flag;u8]

pointer_response :: proc(id: Id, button: rl.MouseButton = .LEFT) -> Pointer_Response {
	ctx := current_context
	response: Pointer_Response
	owner_routes_to_id :=
		ctx.pointer_owner_id != 0 && element_is_in_subtree(ctx, ctx.pointer_owner_id, id)
	hover_routes_to_id :=
		ctx.pointer_hover_id != 0 && element_is_in_subtree(ctx, ctx.pointer_hover_id, id)
	if hover_routes_to_id && (ctx.pointer_owner_id == 0 || owner_routes_to_id) {
		response += {.Hovered}
	}

	if ctx.pointer_pressed_id != 0 &&
	   ctx.pointer_pressed_button == button &&
	   element_is_in_subtree(ctx, ctx.pointer_pressed_id, id) {
		response += {.Pressed}
	}

	if owner_routes_to_id && ctx.pointer_owner_button == button {
		response += {.Held}
	}

	if ctx.pointer_released_id != 0 &&
	   ctx.pointer_released_button == button &&
	   element_is_in_subtree(ctx, ctx.pointer_released_id, id) {
		response += {.Released}
	}

	if ctx.pointer_clicked_id != 0 &&
	   ctx.pointer_released_button == button &&
	   element_is_in_subtree(ctx, ctx.pointer_clicked_id, id) {
		response += {.Clicked}
	}

	return response
}

pointer_position :: proc() -> rl.Vector2 {
	return current_context.pointer_position
}

// Request a cursor for an element on the current pointer hover/owner path.
// Requests from unrelated or covered elements are ignored.
request_cursor :: proc(id: Id, kind: rl.MouseCursor) {
	ctx := current_context
	target := ctx.pointer_owner_id != 0 ? ctx.pointer_owner_id : ctx.pointer_hover_id
	if target == 0 || !element_is_in_subtree(ctx, target, id) do return
	if ctx.cursor_request_id != 0 &&
	   ctx.cursor_request_id != id &&
	   element_is_in_subtree(ctx, ctx.cursor_request_id, id) {
		return
	}

	ctx.cursor_request_id = id
	ctx.cursor_requested_kind = kind
}

bounding_rect :: proc {
	_bounding_rect,
	_bounding_rect_string,
	_bounding_rect_id,
}

@(private)
_bounding_rect :: proc() -> rl.Rectangle {
	ctx := current_context
	return _bounding_rect_id(ctx.current_id)
}

@(private)
_bounding_rect_string :: proc(id: string) -> rl.Rectangle {
	return _bounding_rect_id(to_id(id))
}

@(private)
_bounding_rect_id :: proc(id: Id) -> rl.Rectangle {
	ctx := current_context
	prev_buf := previous_buffer(ctx)

	elem_id, ok := element_index_by_id(ctx, prev_buf, id)
	if !ok do return {}

	element := &ctx.elements[prev_buf][elem_id]
	return rl.Rectangle {
		x = element._position.x,
		y = element._position.y,
		width = element._size.x,
		height = element._size.y,
	}
}

@(private)
element_is_in_subtree :: proc(ctx: ^Context, target, ancestor: Id, buffer := -1) -> bool {
	element_buffer := buffer >= 0 ? buffer : previous_buffer(ctx)
	index, ok := element_index_by_id(ctx, element_buffer, target)
	if !ok do return false

	elements := &ctx.elements[element_buffer]
	for {
		if elements[index].id == ancestor do return true
		if index == 0 do return false
		index = elements[index].parent
	}
}

focused :: proc {
	_focused,
	_focused_string,
	_focused_id,
}

@(private)
// Whether the current element owns keyboard focus.
// Only one element can be focused at a time.
_focused :: proc() -> bool {
	ctx := current_context
	return ctx.focus_id == ctx.current_id
}

@(private)
// Whether the specified element owns keyboard focus.
// Only one element can be focused at a time.
_focused_string :: proc(id: string) -> bool {
	ctx := current_context
	id := to_id(id)
	return ctx.focus_id == id
}

@(private)
_focused_id :: proc(id: Id) -> bool {
	ctx := current_context
	return ctx.focus_id == id
}

// Whether the keyboard focus owner accepts text input.
focus_is_editable :: proc() -> bool {
	ctx := current_context
	if ctx.focus_id == 0 do return false

	index, ok := element_index_by_id(ctx, current_buffer(ctx), ctx.focus_id)
	if !ok {
		index, ok = element_index_by_id(ctx, previous_buffer(ctx), ctx.focus_id)
		if !ok do return false
		return ctx.elements[previous_buffer(ctx)][index].editable
	}

	return ctx.elements[current_buffer(ctx)][index].editable
}

// Give keyboard focus to a declared, enabled, focusable element.
// Requests for missing or non-focusable elements are ignored.
request_focus :: proc(id: Id) {
	ctx := current_context
	if ctx.popup_count > 0 {
		popup_id := ctx.popups[ctx.popup_count - 1].id
		if !element_is_in_subtree(ctx, id, popup_id, current_buffer(ctx)) do return
	}

	index, ok := element_index_by_id(ctx, current_buffer(ctx), id)
	if !ok do return

	element := &ctx.elements[current_buffer(ctx)][index]
	if element.disabled == .True || element.focus == {} do return

	set_focus_element(ctx, current_buffer(ctx), index)
}

// Clear the current keyboard focus owner.
clear_focus :: proc() {
	clear_focus_context(current_context)
}

padding :: proc {
	padding_all,
	padding_axis,
}

@(private)
// Equal padding on all sides.
padding_all :: proc(p: f32) -> Edges {
	return {p, p, p, p}
}

@(private)
// Padding on the x and y axis.
padding_axis :: proc(x: f32, y: f32) -> Edges {
	return {y, x, y, x}
}

margin :: proc {
	margin_all,
	margin_axis,
}

@(private)
// Equal margin on all sides.
margin_all :: proc(m: f32) -> Edges {
	return {m, m, m, m}
}

@(private)
// Margin on the x and y axis.
margin_axis :: proc(x: f32, y: f32) -> Edges {
	return {y, x, y, x}
}

// Equal border width on all sides.
border :: proc(b: f32) -> Edges {
	return {b, b, b, b}
}

// Equal corner radius on all sides.
corner :: proc(r: f32) -> Corners {
	return {r, r, r, r}
}

fixed :: proc {
	fixed_f32,
	fixed_int,
}
@(private)
fixed_f32 :: proc(value: f32) -> Size {
	return {.Fixed, value, 0, 0}
}
@(private)
fixed_int :: proc(#any_int value: int) -> Size {
	return {.Fixed, f32(value), 0, 0}
}

percent :: proc(value: f32) -> Size {
	return {.Percent, value, 0, 0}
}

fit :: proc() -> Size {
	return {.Fit, 0, 0, 0}
}

grow :: proc(weight: f32 = 1) -> Size {
	return {.Grow, weight, 0, 0}
}

AnchorPoint :: enum {
	TopLeft,
	TopRight,
	Top,
	Left,
	Right,
	Center,
	BottomLeft,
	BottomRight,
	Bottom,
}

anchor_point :: proc(point: AnchorPoint) -> rl.Vector2 {
	switch point {
	case .TopLeft:
		return {0, 0}
	case .TopRight:
		return {1, 0}
	case .Top:
		return {0.5, 0}
	case .Left:
		return {0, 0.5}
	case .Right:
		return {1, 0.5}
	case .BottomLeft:
		return {0, 1}
	case .BottomRight:
		return {1, 1}
	case .Bottom:
		return {0.5, 1}
	case .Center:
		return {0.5, 0.5}
	}
	return {0, 0}
}

placement :: proc(anchor: AnchorPoint, origin: AnchorPoint) -> Placement {
	return {anchor_point(anchor), anchor_point(origin)}
}

scroll :: proc(direction: ScrollDirection) -> ScrollConfig {
	return {direction, scroll_offset()}
}

scroll_offset :: proc {
	_scroll_offset,
	_scroll_offset_id,
}

@(private)
_scroll_offset :: proc() -> rl.Vector2 {
	return _scroll_offset_id(current_context.current_id)
}

@(private)
_scroll_offset_id :: proc(id: Id) -> rl.Vector2 {
	element := get_element(id)
	if element != nil {
		return element.scroll.offset
	}
	return {}
}

set_scroll_offset :: proc {
	_set_scroll_offset,
	_set_scroll_offset_id,
}

set_hit_slop :: proc(id: Id, hit_slop: Edges) {
	ctx := current_context
	elements := &ctx.elements[current_buffer(ctx)]
	count := ctx.element_count[current_buffer(ctx)]
	for i in 0 ..< count {
		if elements[i].id == id {
			elements[i].hit_slop = hit_slop
			return
		}
	}
}

@(private)
_set_scroll_offset :: proc(offset: rl.Vector2) {
	_set_scroll_offset_id(current_context.current_id, offset)
}

@(private)
_set_scroll_offset_id :: proc(id: Id, offset: rl.Vector2) {
	ctx := current_context
	elements := &ctx.elements[current_buffer(ctx)]
	count := ctx.element_count[current_buffer(ctx)]
	for i in 0 ..< count {
		if elements[i].id == id {
			elements[i].scroll.offset = offset
			return
		}
	}
}

scrollbar_handle_params :: proc(id: Id) -> (percent: [2]f32, size: [2]f32) {
	element := get_element(id)
	if element != nil {
		viewport := rl.Vector2{inner_width(element), inner_height(element)}
		scroll_range := element._content_size - viewport

		scroll_percent: rl.Vector2 = {}
		if scroll_range.x > 0 {
			scroll_percent.x = clamp(element.scroll.offset.x / scroll_range.x, 0, 1)
		}
		if scroll_range.y > 0 {
			scroll_percent.y = clamp(element.scroll.offset.y / scroll_range.y, 0, 1)
		}

		handle_size: rl.Vector2 = {}
		if element._content_size.x > viewport.x {
			handle_size.x = viewport.x / element._content_size.x
		} else {
			handle_size.x = 1
		}
		if element._content_size.y > viewport.y {
			handle_size.y = viewport.y / element._content_size.y
		} else {
			handle_size.y = 1
		}

		return scroll_percent, handle_size
	}
	return {}, {}
}

size :: proc(id: Id) -> rl.Vector2 {
	element := get_element(id)
	if element != nil {
		return element._size
	}
	return {}
}


@(private)
x_padding :: #force_inline proc(e: ^Element) -> f32 {
	return e.padding.left + e.padding.right
}

@(private)
y_padding :: #force_inline proc(e: ^Element) -> f32 {
	return e.padding.top + e.padding.bottom
}

@(private)
x_margin :: #force_inline proc(e: ^Element) -> f32 {
	return e.margin.left + e.margin.right
}

@(private)
y_margin :: #force_inline proc(e: ^Element) -> f32 {
	return e.margin.top + e.margin.bottom
}

@(private)
x_border :: #force_inline proc(e: ^Element) -> f32 {
	return e.border.left + e.border.right
}

@(private)
y_border :: #force_inline proc(e: ^Element) -> f32 {
	return e.border.top + e.border.bottom
}

@(private)
inner_width :: #force_inline proc(e: ^Element) -> f32 {
	return max(0, e._size.x - x_padding(e) - x_border(e))
}

@(private)
inner_height :: #force_inline proc(e: ^Element) -> f32 {
	return max(0, e._size.y - y_padding(e) - y_border(e))
}

@(private)
scroll_x_enabled :: #force_inline proc(element: ^Element) -> bool {
	return(
		element.scroll.direction == .Auto ||
		element.scroll.direction == .Horizontal ||
		element.scroll.direction == .Manual \
	)
}

@(private)
scroll_y_enabled :: #force_inline proc(element: ^Element) -> bool {
	return(
		element.scroll.direction == .Auto ||
		element.scroll.direction == .Vertical ||
		element.scroll.direction == .Manual \
	)
}

@(private)
parent_inner_width :: proc(ctx: ^Context, e: ^Element) -> (w: f32, definite: bool) {
	elements := &ctx.elements[current_buffer(ctx)]
	if e.parent == 0 {
		root := &elements[0]
		return root._size.x, true
	}

	parent := &elements[e.parent]
	if parent.layout == .Grid {
		return grid_inner_width(ctx, parent, e)
	} else {
		return inner_width(parent), parent._size.x > 0 && !scroll_x_enabled(parent)
	}
}

@(private)
parent_inner_height :: proc(ctx: ^Context, e: ^Element) -> (h: f32, definite: bool) {
	elements := &ctx.elements[current_buffer(ctx)]
	if e.parent == 0 {
		root := &elements[0]
		return root._size.y, true
	}

	parent := &elements[e.parent]
	if parent.layout == .Grid {
		return grid_inner_height(ctx, parent, e)
	} else {
		return inner_height(parent), parent._size.y > 0 && !scroll_y_enabled(parent)
	}
}

@(private)
has_round_corners :: proc(corners: Corners) -> bool {
	return(
		corners.top_left > 0 ||
		corners.top_right > 0 ||
		corners.bottom_right > 0 ||
		corners.bottom_left > 0 \
	)
}

@(private)
scrolls_x :: proc(element: ^Element) -> bool {
	return(
		(element.scroll.direction == .Auto || element.scroll.direction == .Horizontal) &&
		element._content_size.x > inner_width(element) \
	)
}

@(private)
scrolls_y :: proc(element: ^Element) -> bool {
	return(
		(element.scroll.direction == .Auto || element.scroll.direction == .Vertical) &&
		element._content_size.y > inner_height(element) \
	)
}

@(private)
clamp_scroll_offset :: proc(element: ^Element) {
	// TODO: remove this, replace with scroll velocity/gravity/something
	// animate towards the nearest scrollable position instead of snapping
	max_x := max(0, element._content_size.x - inner_width(element))
	max_y := max(0, element._content_size.y - inner_height(element))
	scroll := element.scroll.offset

	switch element.scroll.direction {
	case .None:
		scroll = {}
	case .Auto:
		scroll = {clamp(scroll.x, 0, max_x), clamp(scroll.y, 0, max_y)}
	case .Vertical:
		scroll.y = clamp(scroll.y, 0, max_y)
	case .Horizontal:
		scroll.x = clamp(scroll.x, 0, max_x)
	case .Manual:
	}
	element.scroll.offset = scroll
}

@(private)
get_scroll_offset :: proc(element: ^Element) -> rl.Vector2 {
	scroll := element.scroll.offset
	switch element.scroll.direction {
	case .None:
		return {}
	case .Auto:
		return scroll
	case .Vertical:
		return {0, scroll.y}
	case .Horizontal:
		return {scroll.x, 0}
	case .Manual:
		return scroll
	}
	return {}
}
