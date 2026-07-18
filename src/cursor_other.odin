#+build !darwin

package orui

import rl "vendor:raylib"

@(private = "file")
cursor_to_raylib :: proc(cursor: Cursor) -> rl.MouseCursor {
	#partial switch cursor {
	case .Default:
		return .DEFAULT
	case .Text, .TextVertical:
		return .IBEAM
	case .Crosshair:
		return .CROSSHAIR
	case .PointingHand:
		return .POINTING_HAND
	case .Grab, .Grabbing, .ResizeAll, .DisappearingItem:
		return .RESIZE_ALL
	case .ResizeLeft, .ResizeRight, .ResizeLeftRight, .ResizeEW:
		return .RESIZE_EW
	case .ResizeUp, .ResizeDown, .ResizeUpDown, .ResizeNS:
		return .RESIZE_NS
	case .ResizeNWSE:
		return .RESIZE_NWSE
	case .ResizeNESW:
		return .RESIZE_NESW
	case .NotAllowed:
		return .NOT_ALLOWED
	case .DragLink, .DragCopy, .ContextualMenu:
		return .POINTING_HAND
	}
	return .DEFAULT
}

@(private = "package")
apply_cursor :: proc(cursor: Cursor) {
	rl.SetMouseCursor(cursor_to_raylib(cursor))
}
