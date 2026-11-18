-- Gear Set Colors: bag items that belong to an Equipment Manager set get that set's
-- colour (border, tint and/or corner tags), so they are recognisable at a glance.
--
-- Colours are stored by set name, account-wide, so two characters with a "DPS" set
-- share its colour. Items are matched by their bag position, as reported by the
-- Equipment Manager, so two identical rings in different sets are told apart.

local ADDON, ns = ...
local GSC = {}
ns.GSC = GSC

-- Default colours, picked in order for new sets. Green, blue and purple are left
-- out because they look like the item quality borders.
local PALETTE = {
	{ 1.00, 0.20, 0.20 }, -- red
	{ 0.15, 0.95, 0.95 }, -- cyan
	{ 1.00, 0.90, 0.10 }, -- yellow
	{ 1.00, 0.40, 0.85 }, -- pink
	{ 1.00, 0.55, 0.05 }, -- orange
	{ 0.60, 1.00, 0.20 }, -- lime
	{ 1.00, 1.00, 1.00 }, -- white
	{ 0.55, 0.35, 0.20 }, -- brown
}

local BORDER_SIZE = 2
local TINT_ALPHA = 0.30
local TAG_SIZE = 8
local MAX_TAGS = 4

function GSC.Print(msg)
	print("|cff66ccffGear Set Colors|r: " .. tostring(msg))
end

local function DB()
	return GearSetColorsDB
end
GSC.DB = DB

local function InitDB()
	if type(GearSetColorsDB) ~= "table" then GearSetColorsDB = {} end
	local db = GearSetColorsDB
	if type(db.style) ~= "table" then db.style = { border = true, tint = true, corner = false } end
	if type(db.sets) ~= "table" then db.sets = {} end
end

local function SameColor(entry, c)
	return math.abs(entry.r - c[1]) < 0.01 and math.abs(entry.g - c[2]) < 0.01 and math.abs(entry.b - c[3]) < 0.01
end

-- Returns the saved colour entry for a set name, creating it with the first palette
-- colour no other set uses yet.
function GSC.Entry(name)
	local sets = DB().sets
	local entry = sets[name]
	if entry then return entry end

	local count, pick = 0, nil
	for _ in pairs(sets) do count = count + 1 end
	for _, c in ipairs(PALETTE) do
		local used = false
		for _, other in pairs(sets) do
			if SameColor(other, c) then used = true break end
		end
		if not used then pick = c break end
	end
	pick = pick or PALETTE[(count % #PALETTE) + 1]
	entry = { r = pick[1], g = pick[2], b = pick[3], enabled = true }
	sets[name] = entry
	return entry
end

-- The current character's sets, in Equipment Manager order: { id, name, icon, entry }.
function GSC.GetSets()
	local out = {}
	if not (C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs) then return out end
	for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
		local name, icon = C_EquipmentSet.GetEquipmentSetInfo(id)
		if name then
			out[#out + 1] = { id = id, name = name, icon = icon, entry = GSC.Entry(name) }
		end
	end
	return out
end

-- Equipment Manager location -> bag, slot (nil if the item isn't in a bag).
local function LocationToBagSlot(location)
	if EquipmentManager_GetLocationData then
		local data = EquipmentManager_GetLocationData(location)
		if data and data.isBags then return data.bag, data.slot end
	elseif EquipmentManager_UnpackLocation then
		-- Retail order: player, bank, bags, voidStorage, slot, bag. Classic has no voidStorage.
		local _, _, bags, a, b, c = EquipmentManager_UnpackLocation(location)
		if bags then
			if c ~= nil then return c, b end
			return b, a
		end
	end
end

local function AddToList(map, key, entry)
	local list = map[key]
	if not list then
		list = {}
		map[key] = list
	end
	for _, e in ipairs(list) do
		if e == entry then return end
	end
	list[#list + 1] = entry
end

-- Builds { ["bag:slot"] = { entry, ... } } for every enabled set. Returns nil when
-- this client has no way to decode set locations (FallbackSets is used instead).
local function BuildMap()
	if not (EquipmentManager_GetLocationData or EquipmentManager_UnpackLocation) then return nil end
	local map = {}
	for _, set in ipairs(GSC.GetSets()) do
		if set.entry.enabled then
			local locations = C_EquipmentSet.GetItemLocations(set.id)
			if locations then
				for _, location in pairs(locations) do
					-- 1 = slot ignored, 0 = slot left empty, -1 = item missing.
					if type(location) == "number" and location > 1 then
						local bag, slot = LocationToBagSlot(location)
						if bag and slot then AddToList(map, bag .. ":" .. slot, set.entry) end
					end
				end
			end
		end
	end
	return map
end

-- Per-slot lookup by set name, for clients without the location helpers.
local function FallbackSets(bag, slot)
	if not (C_Container and C_Container.GetContainerItemEquipmentSetInfo) then return nil end
	local inSet, setList = C_Container.GetContainerItemEquipmentSetInfo(bag, slot)
	if not inSet or type(setList) ~= "string" then return nil end
	local list = {}
	for name in setList:gmatch("[^,]+") do
		name = strtrim(name)
		local entry = GSC.Entry(name)
		if entry.enabled then list[#list + 1] = entry end
	end
	return #list > 0 and list or nil
end

local function GetOverlay(button)
	local o = button.GearSetColorsOverlay
	if o then return o end

	o = CreateFrame("Frame", nil, button)
	o:SetAllPoints(button)
	o:SetFrameLevel(button:GetFrameLevel() + 5)

	o.tint = o:CreateTexture(nil, "ARTWORK")
	o.tint:SetAllPoints(o)

	-- Edges in order: top, right, bottom, left.
	local top = o:CreateTexture(nil, "OVERLAY")
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(BORDER_SIZE)
	local right = o:CreateTexture(nil, "OVERLAY")
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(BORDER_SIZE)
	local bottom = o:CreateTexture(nil, "OVERLAY")
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(BORDER_SIZE)
	local left = o:CreateTexture(nil, "OVERLAY")
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(BORDER_SIZE)
	o.edges = { top, right, bottom, left }

	-- Corner tags: small squares with a dark outline, stacked down the top-right corner.
	o.tags = {}
	for i = 1, MAX_TAGS do
		local back = o:CreateTexture(nil, "OVERLAY", nil, 1)
		back:SetSize(TAG_SIZE + 2, TAG_SIZE + 2)
		back:SetPoint("TOPRIGHT", o, "TOPRIGHT", -2, -2 - (i - 1) * (TAG_SIZE + 1))
		back:SetColorTexture(0, 0, 0, 1)
		local fill = o:CreateTexture(nil, "OVERLAY", nil, 2)
		fill:SetPoint("TOPLEFT", back, "TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMRIGHT", back, "BOTTOMRIGHT", -1, 1)
		o.tags[i] = { back = back, fill = fill }
	end

	button.GearSetColorsOverlay = o
	return o
end

local function Apply(button, list)
	if not list then
		if button.GearSetColorsOverlay then button.GearSetColorsOverlay:Hide() end
		return
	end
	local style = DB().style
	local o = GetOverlay(button)
	local first = list[1]

	o.tint:SetColorTexture(first.r, first.g, first.b, TINT_ALPHA)
	o.tint:SetShown(style.tint and true or false)

	-- With several sets, the edges alternate between their colours.
	for i, edge in ipairs(o.edges) do
		local e = list[((i - 1) % #list) + 1]
		edge:SetColorTexture(e.r, e.g, e.b, 1)
		edge:SetShown(style.border and true or false)
	end

	for i, tag in ipairs(o.tags) do
		local e = style.corner and list[i]
		if e then tag.fill:SetColorTexture(e.r, e.g, e.b, 1) end
		tag.back:SetShown(e and true or false)
		tag.fill:SetShown(e and true or false)
	end

	o:Show()
end

local function ButtonBagSlot(button)
	local bag
	if button.GetBagID then
		bag = button:GetBagID()
	else
		local parent = button:GetParent()
		bag = parent and parent:GetID()
	end
	return bag, button:GetID()
end

local function UpdateButtons(buttons)
	local map = BuildMap()
	for _, button in ipairs(buttons) do
		local bag, slot = ButtonBagSlot(button)
		local list
		if bag and slot then
			if map then
				list = map[bag .. ":" .. slot]
			else
				list = FallbackSets(bag, slot)
			end
		end
		Apply(button, list)
	end
end

-- Modern bags (ContainerFrameMixin): one frame per bag, plus the combined-bags frame.
local function UpdateModernFrame(frame)
	if not frame.EnumerateValidItems then return end
	local buttons = {}
	for _, button in frame:EnumerateValidItems() do
		buttons[#buttons + 1] = button
	end
	UpdateButtons(buttons)
end

-- Older bags: ContainerFrameNItemM buttons.
local function UpdateClassicFrame(frame)
	local prefix = frame:GetName() and (frame:GetName() .. "Item")
	if not prefix or not frame.size then return end
	local buttons = {}
	for i = 1, frame.size do
		local button = _G[prefix .. i]
		if button then buttons[#buttons + 1] = button end
	end
	UpdateButtons(buttons)
end

local bagFrames = {}
local isModern = ContainerFrameMixin ~= nil

local function SafeUpdate(frame)
	local ok, err = pcall(isModern and UpdateModernFrame or UpdateClassicFrame, frame)
	if not ok and not GSC.reportedError then
		GSC.reportedError = true
		GSC.Print("couldn't colour the bags: " .. tostring(err))
	end
end

function GSC.RefreshBags()
	for frame in pairs(bagFrames) do
		if frame:IsShown() then SafeUpdate(frame) end
	end
end

local refreshQueued = false
local function QueueRefresh()
	if refreshQueued then return end
	refreshQueued = true
	C_Timer.After(0, function()
		refreshQueued = false
		GSC.RefreshBags()
	end)
end
GSC.QueueRefresh = QueueRefresh

local function HookBags()
	local count = NUM_TOTAL_BAG_FRAMES or NUM_CONTAINER_FRAMES or 13
	if isModern then
		-- Hooking the mixin doesn't reach frames already created, so hook each frame.
		local frames = { ContainerFrameCombinedBags }
		for i = 1, count do frames[#frames + 1] = _G["ContainerFrame" .. i] end
		for _, frame in ipairs(frames) do
			if frame and frame.UpdateItems and not bagFrames[frame] then
				bagFrames[frame] = true
				hooksecurefunc(frame, "UpdateItems", SafeUpdate)
			end
		end
	elseif ContainerFrame_Update then
		for i = 1, count do
			local frame = _G["ContainerFrame" .. i]
			if frame then bagFrames[frame] = true end
		end
		hooksecurefunc("ContainerFrame_Update", SafeUpdate)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then InitDB() end
	elseif event == "PLAYER_LOGIN" then
		HookBags()
		self:RegisterEvent("EQUIPMENT_SETS_CHANGED")
		self:RegisterEvent("BAG_UPDATE_DELAYED")
		self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
		self:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
	else
		QueueRefresh()
		if event == "EQUIPMENT_SETS_CHANGED" and GSC.OnSetsChanged then GSC.OnSetsChanged() end
	end
end)
