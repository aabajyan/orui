#+build darwin
package orui

// Capture Ctrl-Tab (and Shift-Ctrl-Tab) on macOS, which raylib never delivers.
// The Cocoa keyDown path drops Tab while Control is held — it's a built-in
// keyboard-navigation combination — so a local NSEvent monitor
// (addLocalMonitorForEventsMatchingMask:handler:) on the raylib window
// intercepts the key-down, filters for Ctrl-only + Tab, and enqueues it via
// queue_key_event so the normal input path sees it.
//
// Same root cause as https://github.com/hajimehoshi/ebiten/issues/3467
// (Ctrl+Tab dropped while Control held on macOS).
// The block is hand-built because Odin has no Obj-C block literal;
// _NSConcreteStackBlock + a struct matching libc's BlockLayout is the
// standard way to pass a stack block to an Obj-C API. raylib exposes one
// native window, so there is one darwin input owner at a time.

import "base:intrinsics"
import "base:runtime"
import NS "core:sys/darwin/Foundation"
import rl "vendor:raylib"

@(private = "file")
Darwin_Event_Block_Descriptor :: struct {
	reserved: uint,
	size:     uint,
}

@(private = "file")
Darwin_Event_Block :: struct {
	isa:        ^intrinsics.objc_class,
	flags:      u32,
	reserved:   u32,
	invoke:     rawptr,
	descriptor: ^Darwin_Event_Block_Descriptor,
	ctx:        ^Context,
	window:     ^NS.Window,
}

@(private = "file")
darwin_event_block_descriptor := Darwin_Event_Block_Descriptor {
	size = size_of(Darwin_Event_Block),
}

// Raylib exposes one native window, so ORUI has one native input owner.
@(private = "file")
darwin_input_owner: ^Context

foreign import libSystem "system:System"
foreign libSystem {
	_NSConcreteStackBlock: intrinsics.objc_class
}

@(private = "package")
platform_input_init :: proc(ctx: ^Context) {
	if ctx.platform_input_monitor != nil || !rl.IsWindowReady() do return
	assert(
		darwin_input_owner == nil || darwin_input_owner == ctx,
		"ORUI supports one Darwin input owner at a time",
	)
	window := cast(^NS.Window)rl.GetWindowHandle()
	if window == nil do return

	block := Darwin_Event_Block {
		isa        = &_NSConcreteStackBlock,
		invoke     = auto_cast darwin_monitor_event,
		descriptor = &darwin_event_block_descriptor,
		ctx        = ctx,
		window     = window,
	}
	ctx.platform_input_monitor = intrinsics.objc_send(
		rawptr,
		NS.Event,
		"addLocalMonitorForEventsMatchingMask:handler:",
		NS.EventMask{.KeyDown},
		&block,
	)
	if ctx.platform_input_monitor != nil do darwin_input_owner = ctx
}

@(private = "package")
platform_input_destroy :: proc(ctx: ^Context) {
	if ctx.platform_input_monitor == nil do return
	assert(darwin_input_owner == ctx)

	intrinsics.objc_send(nil, NS.Event, "removeMonitor:", ctx.platform_input_monitor)
	ctx.platform_input_monitor = nil
	darwin_input_owner = nil
}

@(private = "file")
darwin_monitor_event :: proc "c" (block: ^Darwin_Event_Block, event: ^NS.Event) -> ^NS.Event {
	context = runtime.default_context()
	if event == nil || NS.Event_isARepeat(event) do return event
	if NS.Event_window(event) != block.window do return event
	if NS.Event_keyCode(event) != u16(NS.kVK.Tab) do return event

	flags := NS.Event_modifierFlags(event)
	if .Control not_in flags || .Option in flags || .Command in flags do return event
	if block.ctx.pending_key_event_count >= len(block.ctx.pending_key_events) {
		return event
	}

	modifiers: Key_Modifiers = {.Control}
	if .Shift in flags do modifiers += {.Shift}
	queue_key_event(block.ctx, {key = .TAB, modifiers = modifiers, kind = .Pressed})
	return nil
}
