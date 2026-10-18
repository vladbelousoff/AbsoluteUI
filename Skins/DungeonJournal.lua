-- AbsoluteUI: Dungeon Journal (ForeverDungeonJournal).
--
-- The journal draws everything with backdrops in brown and per-dungeon
-- tints and re-colors them on every refresh. The backdrops are flattened
-- and their colors kept neutral (NS:FlattenBackdrops), so every refresh
-- comes out in our grey. Dungeon art, boss portraits and the quest text
-- page stay as they are.
--
-- The journal builds its window at login and the side windows on first
-- open; each part is skinned once it exists.

local _, NS = ...

local M = NS:NewModule("DungeonJournal", { setting = "skinDungeonJournal", addon = "ForeverDungeonJournal" })

local MIN_QUALITY = 2 -- like the bags: uncommon and better get a colored border

local PARCHMENTS = {
	"homeParchment", "contentParchment", "headerParchment", "leftParchment",
	"rightParchment", "questLeftParchment", "questRightParchment",
}

-- Side windows, by global name, and the function that creates each.
local WINDOWS = {
	{ "ForeverDungeonJournalFavourites", "ToggleFavouritesWindow" },
	{ "ForeverDungeonJournalLootFilter", "ToggleLootFilterWindow" },
	{ "ForeverDungeonJournalLootFilterResults", "ShowLootFilterList" },
	{ "ForeverDungeonJournalSettings", "ToggleSettingsPanel" },
}

---------------------------------------------------------------------------
-- Generic parts
---------------------------------------------------------------------------

local panels = {}

local function SkinPart(root)
	if not root then return end
	-- The favourites window uses a Blizzard window template where it can.
	if not panels[root] and root.NineSlice and (root.TitleContainer or root.PortraitContainer) then
		panels[root] = true
		NS:SkinPanelPortrait(root, NS:SkinPanelFrame(root))
		if root.Inset and root.Inset.NineSlice then
			root.Inset.NineSlice:SetAlpha(0)
			NS:HideTextures(root.Inset.Bg)
		end
	end
	NS:FlattenBackdrops(root, true)
	NS:SkinDescendants(root)
end

---------------------------------------------------------------------------
-- Item rows: loot, quest rewards, favourites
---------------------------------------------------------------------------

local itemBoxes = {}

local function SyncItemRow(row, itemID)
	local icon = row and (row.icon or row.Icon)
	if not icon or not icon.GetTexture then return end
	local box = itemBoxes[row]
	if not box then
		box = NS:CreateBox(row, row, icon, NS.color.tile)
		itemBoxes[row] = box
	end
	NS:CropIcon(icon)
	local quality = itemID and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(itemID)
	if quality and quality >= MIN_QUALITY then
		box.border:SetColor(NS:QualityColor(quality))
	else
		box.border:SetColor(unpack(NS.color.border))
	end
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------

local function SkinMainFrame(frame)
	for _, key in ipairs(PARCHMENTS) do
		NS:Kill(frame[key])
	end
	-- The quest text keeps its parchment page: it's dark text meant for it.
	NS:FlattenBackdrop(frame.questTextInset, false)

	if frame.topStrip then
		NS:SetColor(frame.topStrip, NS.color.header)
	end
	NS:HideTextures(frame.topStripLine)
	if frame.topStripBottomLine then
		NS:SetColor(frame.topStripBottomLine, NS.color.divider)
	end
	if frame.mainTitle then
		NS:RestyleFont(frame.mainTitle, 15, frame.mainTitle:GetJustifyH())
	end
	SkinPart(frame)

	-- Pages build their rows as they're first opened.
	local function Refresh() SkinPart(frame) end
	frame:HookScript("OnShow", Refresh)
	local fdj = _G.ForeverDungeonJournal_NS
	for _, name in ipairs({ "OpenBossPage", "OpenQuestPage", "RefreshHomeCards", "RefreshLootNow" }) do
		if type(fdj[name]) == "function" then
			NS:Hook(fdj, name, Refresh)
		end
	end
end

function M:Init()
	local fdj = _G.ForeverDungeonJournal_NS
	if not fdj then
		NS:Missing("ForeverDungeonJournal_NS")
		return
	end

	NS:Hook(fdj, "UpdateFavouriteIndicator", SyncItemRow)
	for _, spec in ipairs(WINDOWS) do
		local name, creator = spec[1], spec[2]
		if type(fdj[creator]) == "function" then
			NS:Hook(fdj, creator, function() SkinPart(_G[name]) end)
		end
		SkinPart(_G[name])
	end

	-- The window is created at login, right after we load.
	local function SkinWhenReady()
		local frame = _G.ForeverDungeonJournalFrame
		if frame then
			SkinMainFrame(frame)
		else
			NS:Missing("ForeverDungeonJournalFrame")
		end
	end
	if _G.ForeverDungeonJournalFrame then
		SkinWhenReady()
	else
		C_Timer.After(0, function() NS.SafeCall(SkinWhenReady) end)
	end
end
