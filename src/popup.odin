package orui

POPUP_LAYER_BASE :: 1 << 30

@(private)
Popup_State :: struct {
	id:               Id,
	restore_focus_id: Id,
}

// Open a popup at the current popup nesting level.
open_popup :: proc(id: Id) {
	ctx := current_context
	depth := ctx.popup_begin_count
	if depth < ctx.popup_count && ctx.popups[depth].id == id do return
	if depth < ctx.popup_count do close_popups_to(ctx, depth, true)

	assert(depth < MAX_POPUPS)
	ctx.popup_count = depth + 1
	ctx.popups[depth] = {
		id               = id,
		restore_focus_id = ctx.focus_id,
	}
	if ctx.focus_id != 0 do clear_focus_context(ctx)
}

// Begin declaring an open popup. Must be paired with end_popup when true.
begin_popup :: proc(id: Id, config: ElementConfig, loc := #caller_location) -> bool {
	ctx := current_context
	depth := ctx.popup_begin_count
	if depth >= ctx.popup_count || ctx.popups[depth].id != id do return false

	config := config
	config.layer = POPUP_LAYER_BASE + depth
	config.block = .True
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	ctx.popup_begin_count += 1
	return true
}

// End the current popup declaration.
end_popup :: proc() {
	ctx := current_context
	assert(ctx.popup_begin_count > 0)
	ctx.popup_begin_count -= 1
	end_element()
}

// Close a popup and its descendants.
close_popup :: proc(id: Id) {
	ctx := current_context
	for popup, index in ctx.popups[:ctx.popup_count] {
		if popup.id == id {
			close_popups_to(ctx, index, ctx.popup_begin_count > 0)
			return
		}
	}
}

@(private)
close_top_popup_on_outside_press :: proc(ctx: ^Context) -> bool {
	if ctx.popup_count == 0 do return false

	top := ctx.popups[ctx.popup_count - 1]
	if ctx.pointer_hover_id != 0 &&
	   element_is_in_subtree(ctx, ctx.pointer_hover_id, top.id) {
		return false
	}

	close_popups_to(ctx, ctx.popup_count - 1, false)
	return true
}

@(private)
close_popups_to :: proc(ctx: ^Context, count: int, current_declared: bool) {
	restore_focus_id := ctx.popups[count].restore_focus_id
	ctx.popup_count = count
	restore_popup_focus(ctx, restore_focus_id, current_declared)
}

@(private)
restore_popup_focus :: proc(ctx: ^Context, id: Id, current_declared: bool) {
	if id == 0 {
		clear_focus_context(ctx)
		return
	}

	buffer := current_buffer(ctx)
	index: i32
	ok: bool
	if current_declared {
		index, ok = element_index_by_id(ctx, buffer, id)
	}
	if !ok {
		buffer = previous_buffer(ctx)
		index, ok = element_index_by_id(ctx, buffer, id)
	}
	if !ok {
		clear_focus_context(ctx)
		return
	}

	element := &ctx.elements[buffer][index]
	if element.disabled == .True || element.focus == {} {
		clear_focus_context(ctx)
		return
	}
	set_focus_element(ctx, buffer, index)
}
