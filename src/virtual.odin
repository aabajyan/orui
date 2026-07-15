package orui

import rl "vendor:raylib"

VIRTUAL_AXIS_OVERSCAN :: 1

@(private = "file")
Virtual_Axis_Id :: enum int {
	Content = -1,
}

Virtual_Range :: struct {
	first, last:       int,
	item_extent:       f32,
	gap:               f32,
	pitch:             f32,
	offset:            f32,
	can_scroll_before: bool,
	can_scroll_after:  bool,
	direction:         LayoutDirection,
}

Virtual_Grid :: struct {
	first, last: int,
	rows:        Virtual_Range,
	columns:     int,
	cell_width:  f32,
	cell_height: f32,
	gap:         f32,
}

@(deferred_none = virtual_axis_end)
virtual_axis :: proc(
	element_id: Id,
	count: int,
	item_extent, gap: f32,
	direction: LayoutDirection,
	cfg: ElementConfig,
	overscan := VIRTUAL_AXIS_OVERSCAN,
	loc := #caller_location,
) -> Virtual_Range {
	range := virtual_axis_range(element_id, count, item_extent, gap, direction, overscan)
	virtual_axis_open(
		element_id,
		virtual_axis_total_extent(count, item_extent, gap),
		direction,
		cfg,
		range,
		loc,
	)

	return range
}

@(deferred_none = virtual_axis_end)
virtual_grid :: proc(
	element_id: Id,
	count: int,
	min_cell_width, cell_height, gap: f32,
	cfg: ElementConfig,
	overscan := VIRTUAL_AXIS_OVERSCAN,
	loc := #caller_location,
) -> Virtual_Grid {
	count := max(0, count)
	min_cell_width := max(1, min_cell_width)
	cell_height := max(1, cell_height)
	gap := max(0, gap)

	outer_width := size(element_id).x
	horizontal_padding := cfg.padding.left + cfg.padding.right
	horizontal_border := cfg.border.left + cfg.border.right
	content_width := outer_width - horizontal_padding - horizontal_border
	if content_width <= 0 {
		content_width = min_cell_width
	}

	max_columns_that_fit := int((content_width + gap) / (min_cell_width + gap))
	columns := max(1, max_columns_that_fit)
	width_without_gaps := content_width - gap * f32(columns - 1)
	cell_width := width_without_gaps / f32(columns)
	if columns > 1 do cell_width = max(min_cell_width, cell_width)

	row_count := (count + columns - 1) / columns
	rows := virtual_axis_range(element_id, row_count, cell_height, gap, .TopToBottom, overscan)
	virtual_axis_open(
		element_id,
		virtual_axis_total_extent(row_count, cell_height, gap),
		.TopToBottom,
		cfg,
		rows,
		loc,
	)

	return {
		first = min(count, rows.first * columns),
		last = min(count, rows.last * columns),
		rows = rows,
		columns = columns,
		cell_width = cell_width,
		cell_height = cell_height,
		gap = gap,
	}
}

@(private = "file")
virtual_axis_end :: proc() {
	end_element()
	end_element()
}

virtual_axis_item :: proc(range: Virtual_Range, index: int, cfg: ^ElementConfig) {
	offset := f32(index) * range.pitch
	cfg.position = {.Absolute, {}}
	if range.direction == .LeftToRight {
		cfg.position.value.x = offset
		cfg.position.value.y = 0
		cfg.width = fixed(range.item_extent)
		cfg.height = percent(1)
		return
	}

	cfg.position.value.x = 0
	cfg.position.value.y = offset
	cfg.width = percent(1)
	cfg.height = fixed(range.item_extent)
}

virtual_grid_item :: proc(grid: Virtual_Grid, index: int, cfg: ^ElementConfig) {
	row := index / grid.columns
	col := index % grid.columns
	cfg.position = {
		.Absolute,
		{f32(col) * (grid.cell_width + grid.gap), f32(row) * (grid.cell_height + grid.gap)},
	}
	cfg.width = fixed(grid.cell_width)
	cfg.height = fixed(grid.cell_height)
}

@(private = "file")
virtual_axis_open :: proc(
	element_id: Id,
	total_extent: f32,
	direction: LayoutDirection,
	cfg: ElementConfig,
	range: Virtual_Range,
	loc := #caller_location,
) {
	local_cfg := cfg
	local_cfg.layout = .Flex
	local_cfg.direction = direction
	local_cfg.align_main = .Start
	local_cfg.gap = 0
	local_cfg.clip = {.Self, {}}
	scroll_direction := ScrollDirection.Vertical
	scroll_offset := rl.Vector2{0, range.offset}
	if direction == .LeftToRight {
		scroll_direction = .Horizontal
		scroll_offset = {range.offset, 0}
	}
	local_cfg.scroll = {scroll_direction, scroll_offset}

	element(id(element_id), local_cfg, loc = loc)

	content_cfg := ElementConfig {
		layout   = .None,
		position = {.Relative, {}},
	}
	if direction == .LeftToRight {
		content_cfg.width = fixed(total_extent)
		content_cfg.height = percent(1)
	} else {
		content_cfg.width = percent(1)
		content_cfg.height = fixed(total_extent)
	}

	element(id(element_id, Virtual_Axis_Id.Content), content_cfg, loc = loc)
}

@(private = "file")
virtual_axis_range :: proc(
	element_id: Id,
	count: int,
	item_extent, gap: f32,
	direction: LayoutDirection,
	overscan: int,
) -> Virtual_Range {
	count := max(0, count)
	item_extent := max(0, item_extent)
	gap := max(0, gap)
	overscan := max(0, overscan)
	pitch := max(1, item_extent + gap)
	total_extent := virtual_axis_total_extent(count, item_extent, gap)

	viewport_size := size(element_id)
	viewport := direction == .LeftToRight ? viewport_size.x : viewport_size.y
	if viewport <= 0 {
		viewport = item_extent
	}

	scroll := scroll_offset(element_id)
	offset := direction == .LeftToRight ? scroll.x : scroll.y
	max_offset := max(0, total_extent - viewport)
	offset = clamp(offset, 0, max_offset)

	visible_first := 0
	visible_last := 0
	if count > 0 && item_extent > 0 {
		visible_first = min(count - 1, int(offset / pitch))
		visible_last = min(count, int((offset + viewport) / pitch) + 1)
	}

	first := max(0, visible_first - overscan)
	last := min(count, visible_last + overscan)

	return {
		first = first,
		last = last,
		item_extent = item_extent,
		gap = gap,
		pitch = pitch,
		offset = offset,
		can_scroll_before = offset > 0,
		can_scroll_after = offset < max_offset,
		direction = direction,
	}
}

@(private = "file")
virtual_axis_total_extent :: proc(count: int, item_extent, gap: f32) -> f32 {
	if count <= 0 || item_extent <= 0 {
		return 0
	}

	return f32(count) * item_extent + f32(count - 1) * max(0, gap)
}
