package orui

// Semantic mouse cursors emitted by ORUI.
//
// The built-in renderer uses native cursor shapes where the platform exposes
// them and falls back to the closest Raylib cursor otherwise.
Cursor :: enum {
	Default,
	Text,
	TextVertical,
	Crosshair,
	PointingHand,
	Grab,
	Grabbing,
	ResizeLeft,
	ResizeRight,
	ResizeLeftRight,
	ResizeUp,
	ResizeDown,
	ResizeUpDown,
	ResizeEW,
	ResizeNS,
	ResizeNWSE,
	ResizeNESW,
	ResizeAll,
	DisappearingItem,
	NotAllowed,
	DragLink,
	DragCopy,
	ContextualMenu,
}

// Request a cursor for an element on the current pointer hover/owner path.
// Requests from unrelated or covered elements are ignored.
request_cursor :: proc(id: Id, kind: Cursor) {
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
