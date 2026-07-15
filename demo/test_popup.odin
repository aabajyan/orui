package demo

import orui "../src"
import "core:fmt"
import rl "vendor:raylib"

popup_demo_underlying_clicks: int

render_test_popup :: proc() {
	open_id := orui.to_id("popup demo open")
	underlying_id := orui.to_id("popup demo underlying")
	popup_id := orui.to_id("popup demo popup")
	nested_open_id := orui.to_id("popup demo nested open")
	nested_id := orui.to_id("popup demo nested")

	{orui.container(
			orui.id("container"),
			{
				direction = .TopToBottom,
				width = orui.grow(),
				height = orui.grow(),
				padding = {16, 24, 16, 16},
				gap = 16,
				background_color = rl.BEIGE,
			},
		)
		orui.label(
			orui.id("title"),
			"Popup routing",
			{
				width = orui.grow(),
				font_size = 24,
				color = rl.BLACK,
				align = {.Center, .Center},
				block = .False,
			},
		)
		orui.label(
			orui.id("popup demo instructions"),
			"Outside clicks close one popup level without activating controls underneath.",
			{
				width = orui.grow(),
				height = orui.fit(),
				font_size = 16,
				color = rl.BLACK,
				overflow = .Wrap,
				clip = {.Self, {}},
				align = {.Center, .Center},
				block = .False,
			},
		)

		{orui.container(
				orui.id("popup demo surface"),
				{
					position = {.Relative, {}},
					width = orui.grow(),
					height = orui.fixed(420),
					direction = .TopToBottom,
					gap = 16,
					padding = orui.padding(24),
					background_color = rl.LIGHTGRAY,
					border = orui.border(1),
					border_color = rl.GRAY,
					clip = {.Self, {}},
				},
			)
			if popup_demo_button(
				orui.id(open_id),
				"Open popup",
				{position = {.Absolute, {24, 24}}, width = orui.fixed(200)},
			) {
				orui.open_popup(popup_id)
			}

			if popup_demo_button(
				orui.id(underlying_id),
				fmt.tprintf("Underlying clicks: %d", popup_demo_underlying_clicks),
				{position = {.Absolute, {24, 88}}, width = orui.fixed(240)},
			) {
				popup_demo_underlying_clicks += 1
			}

			if orui.begin_popup(
				orui.id(popup_id),
				{
					position = {.Absolute, {300, 24}},
					placement = orui.placement(.TopLeft, .TopLeft),
					bounds = {.Window, .Shift, 16},
					width = orui.fixed(320),
					height = orui.fixed(220),
					direction = .TopToBottom,
					gap = 12,
					padding = orui.padding(16),
					background_color = rl.WHITE,
					border = orui.border(2),
					border_color = rl.DARKGRAY,
					clip = {.None, {}},
				},
			) {
				orui.label(
					orui.id("popup demo popup title"),
					"Top-level popup",
					{
						width = orui.grow(),
						font_size = 20,
						color = rl.BLACK,
						clip = {.Self, {}},
						block = .False,
					},
				)
				orui.label(
					orui.id("popup demo popup description"),
					"Outside presses are consumed. A nested popup closes first.",
					{
						width = orui.grow(),
						height = orui.fixed(40),
						font_size = 14,
						color = rl.DARKGRAY,
						overflow = .Wrap,
						clip = {.Self, {}},
						block = .False,
					},
				)
				if popup_demo_button(
					orui.id(nested_open_id),
					"Open nested popup",
					{width = orui.fixed(220)},
				) {
					orui.open_popup(nested_id)
				}
				if popup_demo_button(
					orui.id("popup demo close"),
					"Close popup",
					{width = orui.fixed(220)},
				) {
					orui.close_popup(popup_id)
				}

				if orui.begin_popup(
					orui.id(nested_id),
					{
						position = {.Absolute, {12, 0}},
						placement = orui.placement(.Right, .Left),
						bounds = {.Window, .Shift, 16},
						width = orui.fixed(260),
						height = orui.fixed(116),
						direction = .TopToBottom,
						gap = 12,
						padding = orui.padding(16),
						background_color = {232, 240, 250, 255},
						border = orui.border(2),
						border_color = rl.DARKBLUE,
						clip = {.None, {}},
					},
				) {
					orui.label(
						orui.id("popup demo nested title"),
						"Nested popup",
						{
							width = orui.grow(),
							font_size = 18,
							color = rl.BLACK,
							clip = {.Self, {}},
							block = .False,
						},
					)
					if popup_demo_button(
						orui.id("popup demo nested close"),
						"Close nested popup",
						{width = orui.fixed(220)},
					) {
						orui.close_popup(nested_id)
					}
					orui.end_popup()
				}
				orui.end_popup()
			}
		}
	}
}

popup_demo_button :: proc(id: orui.Id, text: string, config: orui.ElementConfig) -> bool {
	response := orui.pointer_response(id)
	background := rl.Color{245, 245, 245, 255}
	border := rl.Color{170, 170, 170, 255}
	if .Hovered in response || orui.focused(id) {
		background = {230, 238, 250, 255}
		border = {65, 125, 210, 255}
	}
	if .Held in response {
		background = {210, 225, 245, 255}
	}

	config := config
	config.height = orui.fixed(40)
	config.padding = orui.padding(12, 8)
	config.background_color = background
	config.border = orui.border(1)
	config.border_color = border
	config.corner_radius = orui.corner(4)
	config.focus = {.Pointer, .Navigation}
	config.clip = {.Self, {}}
	{orui.container(id, config)
		orui.label(
			orui.id(id, 1),
			text,
			{
				width = orui.grow(),
				font_size = 16,
				color = rl.BLACK,
				clip = {.Self, {}},
				align = {.Center, .Center},
				block = .False,
			},
		)
	}
	return .Clicked in response
}
