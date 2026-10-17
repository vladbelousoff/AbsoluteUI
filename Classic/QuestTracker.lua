-- AbsoluteUI: classic quest tracker (QuestWatchFrame).
--
-- A plain list of text lines ("QuestWatchLine1"...) that Blizzard sizes the
-- frame around. It gets a dark panel and our font; Blizzard keeps coloring
-- the lines (titles gold, finished objectives white).

local _, NS = ...

local M = NS:NewModule("QuestTracker", { setting = "questTracker", flavor = "classic" })

local MAX_LINES = 30 -- MAX_QUESTWATCH_LINES
local TEXT_SIZE = 12 -- Blizzard sizes the frame for 13 units per line

function M:Init()
	local frame = QuestWatchFrame
	if not frame then
		NS:Missing("QuestWatchFrame")
		return
	end

	-- Reaches a margin past the lines, which start at the frame's edge.
	local margin = NS.panelStyle.margin
	NS:CreateTile(frame, -margin, -margin, NS.color.panel)

	for i = 1, MAX_QUESTWATCH_LINES or MAX_LINES do
		local line = _G["QuestWatchLine" .. i]
		if not line then break end
		NS:RestyleFont(line, TEXT_SIZE, "LEFT")
	end
end
