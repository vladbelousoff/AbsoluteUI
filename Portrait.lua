-- AbsoluteUI: unit portraits (3D model, 2D portrait or class icon).

local _, NS = ...

local IsSecret = NS.IsSecret

local Portrait = {}

function NS:CreatePortrait(parent, region)
	local p = CreateFrame("Frame", nil, parent)
	Mixin(p, Portrait)
	p:SetAllPoints(region)

	p.top = CreateFrame("Frame", nil, p)
	p.top:SetAllPoints()

	p.box = NS:CreateBox(p, p.top, p, NS.color.tile)

	p.model = CreateFrame("PlayerModel", nil, p)
	p.model:SetAllPoints()
	p.model:Hide()

	p.flat = p:CreateTexture(nil, "ARTWORK")
	p.flat:SetAllPoints()

	-- Darkens the lower half to ground the model.
	p.shade = NS:CreateTexture(p.top, "ARTWORK", 0)
	p.shade:SetPoint("BOTTOMLEFT")
	p.shade:SetPoint("BOTTOMRIGHT")
	p.shade:SetPoint("TOP", p, "CENTER")
	if p.shade.SetGradient and CreateColor then
		p.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))
	else
		p.shade:SetVertexColor(0, 0, 0, 0.25)
	end

	-- Dead and offline units.
	p.dim = NS:CreateTexture(p.top, "ARTWORK", 1, { 0, 0, 0, 0.6 })
	p.dim:SetAllPoints()
	p.dim:Hide()

	-- "Elite", "Rare", ...
	p.label = NS:CreateText(p.top, 9, "CENTER", true)
	p.label:SetPoint("TOP", p, "TOP", 0, -2)
	p.label:Hide()

	-- The model resets its camera when hidden; re-apply on show.
	p.model:SetScript("OnShow", function() p:ApplyModelCamera() end)

	return p
end

function Portrait:ApplyModelCamera()
	self.model:SetPortraitZoom(1)
	self.model:SetPosition(0, 0, 0)
end

function Portrait:SetUnit(unit)
	self.unit = unit
	self:Update(true)
end

local function ShowClassIcon(texture, unit)
	local _, classFile = UnitClass(unit)
	local coords = classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
	if not coords then return false end
	texture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
	local inset = 0.015
	texture:SetTexCoord(coords[1] + inset, coords[2] - inset, coords[3] + inset, coords[4] - inset)
	return true
end

-- `force` reloads the model even if the unit didn't change.
function Portrait:Update(force)
	local unit = self.unit
	if not unit or not UnitExists(unit) then return end

	local connected = UnitIsConnected(unit)
	self.dim:SetShown(not connected or UnitIsDeadOrGhost(unit))

	local mode = NS.db.portrait
	if mode == "3d" and connected and UnitIsVisible(unit) then
		local guid = UnitGUID(unit)
		local known = not IsSecret(guid)
		if force or not self.model:IsShown() or (known and guid ~= self.guid) then
			self.guid = known and guid or nil
			self.flat:Hide()
			self.model:Show()
			self.model:ClearModel()
			self.model:SetUnit(unit)
			self:ApplyModelCamera()
		end
		return
	end

	self.guid = nil
	self.model:Hide()
	self.flat:Show()
	if not (mode == "class" and UnitIsPlayer(unit) and ShowClassIcon(self.flat, unit)) then
		SetPortraitTexture(self.flat, unit)
		self.flat:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	end
end

-- `info` is an NS.rarity entry, or nil for none.
function Portrait:SetRarity(info)
	if info then
		local c = info.color
		self.box.border:SetColor(c[1], c[2], c[3], 1)
		self.label:SetText(info.label)
		self.label:SetTextColor(c[1], c[2], c[3])
		self.label:Show()
	else
		self.box.border:SetColor(unpack(NS.color.border))
		self.label:Hide()
	end
end
