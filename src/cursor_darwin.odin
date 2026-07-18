#+build darwin

package orui

import "base:intrinsics"
import NS "core:sys/darwin/Foundation"

@(private = "file")
Cursor_Frame_Resize_Position :: enum NS.UInteger {
	Top         = 1 << 0,
	Left        = 1 << 1,
	Bottom      = 1 << 2,
	Right       = 1 << 3,
	TopLeft     = (1 << 0) | (1 << 1),
	TopRight    = (1 << 0) | (1 << 3),
	BottomLeft  = (1 << 2) | (1 << 1),
	BottomRight = (1 << 2) | (1 << 3),
}

@(private = "file")
CURSOR_FRAME_RESIZE_DIRECTIONS_ALL :: NS.UInteger((1 << 0) | (1 << 1))

@(private = "package")
apply_cursor :: proc(kind: Cursor) {
	cursor := cursor_darwin(kind)
	if cursor != nil do NS.Cursor_set(cursor)
}

@(private = "file")
cursor_darwin :: proc(kind: Cursor) -> ^NS.Cursor {
	#partial switch kind {
	case .Default:
		return NS.Cursor_arrowCursor()
	case .Text:
		return NS.Cursor_IBeamCursor()
	case .TextVertical:
		return cursor_i_beam_vertical()
	case .Crosshair:
		return cursor_crosshair()
	case .PointingHand:
		return NS.Cursor_pointingHandCursor()
	case .Grab:
		return cursor_open_hand()
	case .Grabbing:
		return cursor_closed_hand()
	case .ResizeLeft:
		return cursor_resize_left()
	case .ResizeRight:
		return cursor_resize_right()
	case .ResizeLeftRight, .ResizeEW:
		return cursor_resize_left_right()
	case .ResizeUp:
		return cursor_resize_up()
	case .ResizeDown:
		return cursor_resize_down()
	case .ResizeUpDown, .ResizeNS:
		return cursor_resize_up_down()
	case .ResizeNWSE:
		return cursor_frame_resize(.TopLeft)
	case .ResizeNESW:
		return cursor_frame_resize(.TopRight)
	case .ResizeAll:
		// AppKit does not expose a four-way resize cursor.
		return cursor_closed_hand()
	case .DisappearingItem:
		return cursor_disappearing_item()
	case .NotAllowed:
		return cursor_operation_not_allowed()
	case .DragLink:
		return cursor_drag_link()
	case .DragCopy:
		return cursor_drag_copy()
	case .ContextualMenu:
		return cursor_contextual_menu()
	}
	return NS.Cursor_arrowCursor()
}

@(private = "file")
cursor_metaclass :: #force_inline proc() -> NS.Class {
	return cast(NS.Class)NS.objc_getMetaClass("NSCursor")
}

@(private = "file")
cursor_selector_available :: #force_inline proc(name: cstring) -> bool {
	return NS.class_respondsToSelector(cursor_metaclass(), NS.sel_registerName(name))
}

@(private = "file")
cursor_frame_resize :: proc(position: Cursor_Frame_Resize_Position) -> ^NS.Cursor {
	if !cursor_selector_available("frameResizeCursorFromPosition:inDirections:") {
		return cursor_resize_left_right()
	}
	return intrinsics.objc_send(
		^NS.Cursor,
		NS.Cursor,
		"frameResizeCursorFromPosition:inDirections:",
		position,
		CURSOR_FRAME_RESIZE_DIRECTIONS_ALL,
	)
}

@(private = "file")
cursor_crosshair :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("crosshairCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "crosshairCursor")
}

@(private = "file")
cursor_i_beam_vertical :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("IBeamCursorForVerticalLayout") {
		return NS.Cursor_IBeamCursor()
	}
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "IBeamCursorForVerticalLayout")
}

@(private = "file")
cursor_open_hand :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("openHandCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "openHandCursor")
}

@(private = "file")
cursor_closed_hand :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("closedHandCursor") do return cursor_open_hand()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "closedHandCursor")
}

@(private = "file")
cursor_resize_left :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeLeftCursor") do return cursor_resize_left_right()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeLeftCursor")
}

@(private = "file")
cursor_resize_right :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeRightCursor") do return cursor_resize_left_right()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeRightCursor")
}

@(private = "file")
cursor_resize_left_right :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeLeftRightCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeLeftRightCursor")
}

@(private = "file")
cursor_resize_up :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeUpCursor") do return cursor_resize_up_down()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeUpCursor")
}

@(private = "file")
cursor_resize_down :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeDownCursor") do return cursor_resize_up_down()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeDownCursor")
}

@(private = "file")
cursor_resize_up_down :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("resizeUpDownCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "resizeUpDownCursor")
}

@(private = "file")
cursor_disappearing_item :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("disappearingItemCursor") do return cursor_closed_hand()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "disappearingItemCursor")
}

@(private = "file")
cursor_operation_not_allowed :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("operationNotAllowedCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "operationNotAllowedCursor")
}

@(private = "file")
cursor_drag_link :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("dragLinkCursor") do return NS.Cursor_pointingHandCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "dragLinkCursor")
}

@(private = "file")
cursor_drag_copy :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("dragCopyCursor") do return NS.Cursor_pointingHandCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "dragCopyCursor")
}

@(private = "file")
cursor_contextual_menu :: proc() -> ^NS.Cursor {
	if !cursor_selector_available("contextualMenuCursor") do return NS.Cursor_arrowCursor()
	return intrinsics.objc_send(^NS.Cursor, NS.Cursor, "contextualMenuCursor")
}
