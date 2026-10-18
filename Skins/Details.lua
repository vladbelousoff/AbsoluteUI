-- AbsoluteUI: a window skin for Details!, picked in its Skin Selection.
--
-- Built on Details' own "ElvUI Frame Style" layout (same title bar art and
-- anchors) with our colors, bar texture and font. Details resets a window
-- to the skin's properties when the skin is picked; the user can change any
-- of them afterwards, like with Details' own skins.

local _, NS = ...

local M = NS:NewModule("Details", { setting = "skinDetails", addon = "Details", early = true })

local SKIN_ID = "AbsoluteUI"

local function Color(color, alpha)
	return { color[1], color[2], color[3], alpha or color[4] or 1 }
end

-- Details' own, for when no shared media library is around.
local FALLBACK_TEXTURE, FALLBACK_FONT = "Details Flat", "FORCED SQUARE"

local function InstanceProps()
	local texture, font = NS:SharedBarMedia()
	texture, font = texture or FALLBACK_TEXTURE, font or FALLBACK_FONT
	local panel, tile, text = NS.color.panel, NS.color.tile, NS.color.text
	return {
		menu_icons_alpha = 0.92,
		menu_icons_size = 0.9,
		color = { 1, 1, 1, 1 },
		color_buttons = { 1, 1, 1, 1 },
		menu_anchor = { 16, 2, side = 2 },
		menu_anchor_down = { 16, -2 },
		bg_r = panel[1], bg_g = panel[2], bg_b = panel[3], bg_alpha = panel[4],
		backdrop_texture = "Details Ground",
		show_statusbar = false,
		show_sidebars = true,
		hide_icon = true,
		toolbar_side = 1,
		wallpaper = { enabled = false },
		attribute_text = {
			enabled = true, shadow = true, side = 1, text_size = 12,
			custom_text = "{name}", enable_custom_text = false,
			text_face = font,
			anchor = { -19, 5 },
			text_color = Color(text),
		},
		row_info = {
			height = 20,
			space = { left = 1, right = -2, between = 2 },
			alpha = 1,
			texture = texture,
			texture_file = NS:GetBarTexture(),
			texture_class_colors = true,
			texture_background_class_color = false,
			texture_background = "Details Flat",
			texture_background_file = [[Interface\AddOns\Details\images\bar_background]],
			fixed_texture_background_color = Color(tile, 0.9),
			font_face = font,
			font_face_file = NS:GetBarFontFile(),
			font_size = 12,
			textL_outline = true,
			textR_outline = true,
			fixed_text_color = { text[1], text[2], text[3] },
			texts = {
				[1] = { color = { byClass = false } },
				[2] = { color = { byClass = false } },
				[3] = { color = { byClass = false } },
				[4] = { color = { byClass = false } },
			},
			start_after_icon = true,
			no_icon = false,
			use_spec_icons = true,
			backdrop = { enabled = true, size = 1, color = { 0, 0, 0, 1 }, texture = "Details BarBorder 2" },
		},
	}
end

-- A 1px border and our shadow around each window on this skin. They go
-- when the window changes to another skin.
local framed = {} -- [window] = { border, shadow }

local function SyncWindow(instance)
	local window = instance and instance.baseframe
	if not window then return end
	local ours = instance.skin == SKIN_ID
	local frame = framed[window]
	if not frame then
		if not ours then return end
		frame = { NS:CreateBorder(window, window, "OVERLAY"), NS:CreateShadow(window, window) }
		framed[window] = frame
	end
	for _, part in pairs(frame) do part:SetShown(ours) end
end

function M:Init()
	local details = _G.Details
	if not (details and details.InstallSkin) then
		NS:Missing("Details skin API")
		return
	end
	details:InstallSkin(SKIN_ID, {
		file = [[Interface\AddOns\Details\images\skins\elvui.blp]],
		author = "AbsoluteUI",
		version = NS.version,
		site = "",
		desc = "AbsoluteUI's colors, bar texture and font.",
		-- Installed every load; Details mustn't keep a copy of its own.
		no_cache = true,
		can_change_alpha_head = true,
		icon_anchor_main = { -4, -5 },
		icon_anchor_plugins = { -7, -13 },
		icon_plugins_size = { 19, 18 },
		micro_frames = { color = { 1, 1, 1, 0.7 }, size = 10, textymod = 1 },
		icon_point_anchor = { -35, -0.5 },
		left_corner_anchor = { -107, 0 },
		right_corner_anchor = { 96, 0 },
		icon_point_anchor_bottom = { -37, 12 },
		left_corner_anchor_bottom = { -107, 0 },
		right_corner_anchor_bottom = { 96, 0 },
		icon_on_top = true,
		icon_ignore_alpha = true,
		icon_titletext_position = { 2, 5 },
		instance_cprops = InstanceProps(),
	})
	-- Windows already on the skin got it while it was installed.
	NS:Hook(details, "ChangeSkin", SyncWindow)
	if details.ListInstances and type(details.tabela_instancias) == "table" then
		for _, instance in details:ListInstances() do
			SyncWindow(instance)
		end
	end
end
