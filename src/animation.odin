package orui

import "core:hash"
import "core:math"
import "core:math/ease"
import rl "vendor:raylib"

AnimationId :: distinct u32

DEFAULT_ANIMATION_TIME: f32 : 0.12
DEFAULT_ANIMATION_EASING: ease.Ease : .Quadratic_Out

AnimationFactorData :: struct {
	value:   f32,
	start:   f32,
	target:  f32,
	trigger: bool,
}

AnimationFloatData :: struct {
	value:  f32,
	start:  f32,
	target: f32,
}

AnimationVector2Data :: struct {
	value:  rl.Vector2,
	start:  rl.Vector2,
	target: rl.Vector2,
}

AnimationColorData :: struct {
	value:  rl.Color,
	start:  rl.Color,
	target: rl.Color,
}

AnimationEdgesData :: struct {
	value:  Edges,
	start:  Edges,
	target: Edges,
}

AnimationCornersData :: struct {
	value:  Corners,
	start:  Corners,
	target: Corners,
}

AnimationSizeData :: struct {
	value:  Size,
	start:  Size,
	target: Size,
}

AnimationData :: union {
	AnimationFactorData,
	AnimationFloatData,
	AnimationVector2Data,
	AnimationColorData,
	AnimationEdgesData,
	AnimationCornersData,
	AnimationSizeData,
}

AnimationState :: struct {
	elapsed:  f32,
	duration: f32,
	easing:   ease.Ease,
	active:   bool,
	data:     AnimationData,
}

transition :: proc {
	transition_factor_string,
	transition_factor_string_index,
	transition_float_string,
	transition_float_string_index,
	transition_vector2_string,
	transition_vector2_string_index,
	transition_color_string,
	transition_color_string_index,
	transition_edges_string,
	transition_edges_string_index,
	transition_corners_string,
	transition_corners_string_index,
	transition_size_string,
	transition_size_string_index,
}

animate :: proc {
	animate_float_string,
	animate_float_string_index,
	animate_vector2_string,
	animate_vector2_string_index,
	animate_color_string,
	animate_color_string_index,
	animate_edges_string,
	animate_edges_string_index,
	animate_corners_string,
	animate_corners_string_index,
	animate_size_string,
	animate_size_string_index,
}

lerp :: proc {
	lerp_float,
	lerp_vector2,
	lerp_color,
	lerp_edges,
	lerp_corners,
	lerp_size,
}

lerp_float :: proc(a, b, t: f32) -> f32 {
	return math.lerp(a, b, t)
}

lerp_vector2 :: proc(a, b: rl.Vector2, t: f32) -> rl.Vector2 {
	return math.lerp(a, b, t)
}

lerp_color :: proc(a, b: rl.Color, t: f32) -> rl.Color {
	return {
		lerp_color_channel(a[0], b[0], t),
		lerp_color_channel(a[1], b[1], t),
		lerp_color_channel(a[2], b[2], t),
		lerp_color_channel(a[3], b[3], t),
	}
}

@(private)
lerp_color_channel :: #force_inline proc(a, b: u8, t: f32) -> u8 {
	return u8(clamp(math.lerp(f32(a), f32(b), t), 0, 255))
}

lerp_edges :: proc(a, b: Edges, t: f32) -> Edges {
	return Edges {
		top = lerp_float(a.top, b.top, t),
		right = lerp_float(a.right, b.right, t),
		bottom = lerp_float(a.bottom, b.bottom, t),
		left = lerp_float(a.left, b.left, t),
	}
}

lerp_corners :: proc(a, b: Corners, t: f32) -> Corners {
	return Corners {
		top_left = lerp_float(a.top_left, b.top_left, t),
		top_right = lerp_float(a.top_right, b.top_right, t),
		bottom_right = lerp_float(a.bottom_right, b.bottom_right, t),
		bottom_left = lerp_float(a.bottom_left, b.bottom_left, t),
	}
}

lerp_size :: proc(a, b: Size, t: f32) -> Size {
	if a.type != b.type do return b

	return Size {
		type = a.type,
		value = lerp_float(a.value, b.value, t),
		min = lerp_float(a.min, b.min, t),
		max = lerp_float(a.max, b.max, t),
	}
}

@(private)
transition_factor_string :: proc(
	id: string,
	trigger: bool,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return transition_factor(animation_id(id), trigger, duration, easing)
}

@(private)
transition_factor_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return transition_factor(animation_id(id, index), trigger, duration, easing)
}

@(private)
transition_float_string :: proc(
	id: string,
	trigger: bool,
	from, to: f32,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return lerp_float(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_float_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: f32,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return lerp_float(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_vector2_string :: proc(
	id: string,
	trigger: bool,
	from, to: rl.Vector2,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Vector2 {
	return lerp_vector2(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_vector2_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: rl.Vector2,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Vector2 {
	return lerp_vector2(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_color_string :: proc(
	id: string,
	trigger: bool,
	from, to: rl.Color,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Color {
	return lerp_color(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_color_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: rl.Color,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Color {
	return lerp_color(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_edges_string :: proc(
	id: string,
	trigger: bool,
	from, to: Edges,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Edges {
	return lerp_edges(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_edges_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: Edges,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Edges {
	return lerp_edges(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_corners_string :: proc(
	id: string,
	trigger: bool,
	from, to: Corners,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Corners {
	return lerp_corners(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_corners_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: Corners,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Corners {
	return lerp_corners(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_size_string :: proc(
	id: string,
	trigger: bool,
	from, to: Size,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Size {
	if from.type != to.type do return trigger ? to : from
	return lerp_size(from, to, transition_factor(animation_id(id), trigger, duration, easing))
}

@(private)
transition_size_string_index :: proc(
	id: string,
	index: int,
	trigger: bool,
	from, to: Size,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Size {
	if from.type != to.type do return trigger ? to : from
	return lerp_size(
		from,
		to,
		transition_factor(animation_id(id, index), trigger, duration, easing),
	)
}

@(private)
transition_factor :: proc(
	local_id: AnimationId,
	trigger: bool,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	ctx := current_context
	key := animation_key(local_id)
	target: f32 = trigger ? 1 : 0

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationFactorData); ok {
			assert(
				data.trigger == trigger,
				"same transition id used with conflicting triggers in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return 0
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationFactorData); ok {
			if data.trigger != trigger {
				data.trigger = trigger
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationFactorData {
		value   = target,
		start   = target,
		target  = target,
		trigger = trigger,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_float_string :: proc(
	id: string,
	target: f32,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return animate_float(animation_id(id), target, duration, easing)
}

@(private)
animate_float_string_index :: proc(
	id: string,
	index: int,
	target: f32,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	return animate_float(animation_id(id, index), target, duration, easing)
}

@(private)
animate_vector2_string :: proc(
	id: string,
	target: rl.Vector2,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Vector2 {
	return animate_vector2(animation_id(id), target, duration, easing)
}

@(private)
animate_vector2_string_index :: proc(
	id: string,
	index: int,
	target: rl.Vector2,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Vector2 {
	return animate_vector2(animation_id(id, index), target, duration, easing)
}

@(private)
animate_color_string :: proc(
	id: string,
	target: rl.Color,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Color {
	return animate_color(animation_id(id), target, duration, easing)
}

@(private)
animate_color_string_index :: proc(
	id: string,
	index: int,
	target: rl.Color,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Color {
	return animate_color(animation_id(id, index), target, duration, easing)
}

@(private)
animate_edges_string :: proc(
	id: string,
	target: Edges,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Edges {
	return animate_edges(animation_id(id), target, duration, easing)
}

@(private)
animate_edges_string_index :: proc(
	id: string,
	index: int,
	target: Edges,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Edges {
	return animate_edges(animation_id(id, index), target, duration, easing)
}

@(private)
animate_corners_string :: proc(
	id: string,
	target: Corners,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Corners {
	return animate_corners(animation_id(id), target, duration, easing)
}

@(private)
animate_corners_string_index :: proc(
	id: string,
	index: int,
	target: Corners,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Corners {
	return animate_corners(animation_id(id, index), target, duration, easing)
}

@(private)
animate_size_string :: proc(
	id: string,
	target: Size,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Size {
	return animate_size(animation_id(id), target, duration, easing)
}

@(private)
animate_size_string_index :: proc(
	id: string,
	index: int,
	target: Size,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Size {
	return animate_size(animation_id(id, index), target, duration, easing)
}

@(private)
animate_float :: proc(
	local_id: AnimationId,
	target: f32,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> f32 {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationFloatData); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return 0
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationFloatData); ok {
			if data.target != target {
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationFloatData {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_vector2 :: proc(
	local_id: AnimationId,
	target: rl.Vector2,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Vector2 {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationVector2Data); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return {}
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationVector2Data); ok {
			if data.target != target {
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationVector2Data {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_color :: proc(
	local_id: AnimationId,
	target: rl.Color,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> rl.Color {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationColorData); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return {}
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationColorData); ok {
			if data.target != target {
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationColorData {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_edges :: proc(
	local_id: AnimationId,
	target: Edges,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Edges {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationEdgesData); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return {}
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationEdgesData); ok {
			if data.target != target {
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationEdgesData {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_corners :: proc(
	local_id: AnimationId,
	target: Corners,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Corners {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationCornersData); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return {}
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationCornersData); ok {
			if data.target != target {
				data.start = data.value
				data.target = target
				animation_start(&state, duration, easing, data.start != data.target)
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationCornersData {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animate_size :: proc(
	local_id: AnimationId,
	target: Size,
	duration: f32 = DEFAULT_ANIMATION_TIME,
	easing: ease.Ease = DEFAULT_ANIMATION_EASING,
) -> Size {
	ctx := current_context
	key := animation_key(local_id)

	if state, ok := animation_current(ctx, key); ok {
		if data, ok := state.data.(AnimationSizeData); ok {
			assert(
				data.target == target,
				"same animate id used with conflicting targets in one frame",
			)
			return data.value
		}

		assert(false, "animation id reused with incompatible animation value type")
		return {}
	}

	if state, ok := animation_previous(ctx, key); ok {
		if data, ok := state.data.(AnimationSizeData); ok {
			if data.target != target {
				if data.target.type != target.type {
					data.value = target
					data.start = target
					data.target = target
					state.active = false
					state.elapsed = 0
					state.duration = max(duration, 0)
					state.easing = easing
				} else {
					data.start = data.value
					data.target = target
					animation_start(&state, duration, easing, data.start != data.target)
				}
			}

			animation_update(ctx, &state, &data)
			state.data = data
			animation_store(ctx, key, state)
			return data.value
		}
	}

	data := AnimationSizeData {
		value  = target,
		start  = target,
		target = target,
	}
	state := AnimationState {
		elapsed  = 0,
		duration = max(duration, 0),
		easing   = easing,
		active   = false,
		data     = data,
	}
	animation_store(ctx, key, state)
	return data.value
}

@(private)
animation_start :: #force_inline proc(
	state: ^AnimationState,
	duration: f32,
	easing: ease.Ease,
	changed: bool,
) {
	state.duration = max(duration, 0)
	state.easing = easing
	state.active = changed && state.duration > 0
	state.elapsed = 0
}

@(private)
animation_update :: proc(ctx: ^Context, state: ^AnimationState, data: ^$Data) {
	if state.active {
		state.elapsed += ctx.dt
		raw_t := state.duration <= 0 ? 1 : clamp(state.elapsed / state.duration, 0, 1)
		eased_t := animation_apply_easing(raw_t, state.easing)
		data.value = lerp(data.start, data.target, eased_t)

		if raw_t >= 1 {
			data.value = data.target
			state.active = false
		}
	} else {
		data.value = data.target
	}
}

@(private)
animation_apply_easing :: #force_inline proc(t: f32, easing: ease.Ease) -> f32 {
	return ease.ease(easing, clamp(t, 0, 1))
}

@(private)
animation_current :: #force_inline proc(
	ctx: ^Context,
	key: AnimationId,
) -> (
	AnimationState,
	bool,
) {
	return ctx.animation_states[current_buffer(ctx)][key]
}

@(private)
animation_previous :: #force_inline proc(
	ctx: ^Context,
	key: AnimationId,
) -> (
	AnimationState,
	bool,
) {
	return ctx.animation_states[previous_buffer(ctx)][key]
}

@(private)
animation_store :: #force_inline proc(ctx: ^Context, key: AnimationId, state: AnimationState) {
	ctx.animation_states[current_buffer(ctx)][key] = state
}

animation_id :: proc {
	animation_id_compiled,
	animation_id_compiled_index,
	animation_id_string,
	animation_id_string_index,
}

animation_id_compiled :: proc($S: string) -> AnimationId {
	return AnimationId(#hash(S, "fnv32a"))
}

animation_id_compiled_index :: proc($S: string, #any_int index: int) -> AnimationId {
	return AnimationId(hash.fnv32a(transmute([]u8)S, u32(index)))
}

animation_id_string :: proc(str: string) -> AnimationId {
	return AnimationId(hash.fnv32a(transmute([]u8)str))
}

animation_id_string_index :: proc(str: string, #any_int index: int) -> AnimationId {
	return AnimationId(hash.fnv32a(transmute([]u8)str, u32(index)))
}

animation_key :: #force_inline proc(local_id: AnimationId) -> AnimationId {
	ctx := current_context
	assert(ctx != nil)
	assert(ctx.current_id != 0, "animation functions must be called inside an element declaration")
	local_bytes := transmute([4]u8)local_id
	return AnimationId(hash.fnv32a(local_bytes[:], u32(ctx.current_id)))
}
