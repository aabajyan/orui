package orui_test

import orui "../src"
import "core:testing"

@(test)
virtual_axis_uses_viewport_and_scroll_offset :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	id := orui.to_id("virtual")
	for frame in 0 ..< 2 {
		orui.begin(ctx, 100, 50, 0)
		{range := orui.virtual_axis(
				id,
				100,
				20,
				0,
				.TopToBottom,
				{width = orui.fixed(100), height = orui.fixed(50)},
			)
			if frame == 1 {
				testing.expect_value(t, range.first, 1)
				testing.expect_value(t, range.last, 6)
				testing.expect_value(t, range.offset, 40)
				testing.expect(t, range.can_scroll_before)
				testing.expect(t, range.can_scroll_after)
			}
		}
		orui.end()
		orui.set_scroll_offset(id, {0, 40})
	}
}
