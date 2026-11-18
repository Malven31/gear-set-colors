-- Adds a colour square to each set in the Character window's Equipment Manager
-- list. Clicking it opens the colour picker for that set.

local ADDON, ns = ...
local GSC = ns.GSC

local SWATCH_SIZE = 14
local swatches = {}   -- every swatch created, to recolour them after a change
local hookedScrollBox
local warned = false

-- Which set a list button shows: its setID, else its label matched against the sets.
local function SetNameForButton(button, elementData)
	local setID = (type(elementData) == "table" and elementData.setID) or button.setID
	if setID and C_EquipmentSet.GetEquipmentSetInfo then
		local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
		if name then return name end
	end
	local label = button.text or button.Text or button.Name
	local text = label and label.GetText and label:GetText()
	if text then
		for _, set in ipairs(GSC.GetSets()) do
			if set.name == text then return set.name end
		end
	end
end

local function UpdateSwatch(swatch)
	local name = swatch.setName
	if not name then
		swatch:Hide()
		return
	end
	local entry = GSC.Entry(name)
	swatch.color:SetColorTexture(entry.r, entry.g, entry.b, 1)
	swatch.color:SetAlpha(entry.enabled and 1 or 0.35)
	swatch:Show()
end

local function GetSwatch(button)
	local swatch = button.GearSetColorsSwatch
	if swatch then return swatch end

	swatch = CreateFrame("Button", nil, button)
	swatch:SetSize(SWATCH_SIZE, SWATCH_SIZE)
	-- On the top-left corner of the set's icon, the one free spot of the row: the right side holds the
	-- equipped tick (RIGHT -23) and, on hover, the edit and delete buttons, and the spec badge sits on
	-- the icon's bottom-right corner (Forever's GearSetButtonTemplate, PaperDollFrame.xml).
	if button.icon then
		swatch:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -2, 2)
	else
		swatch:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
	end
	swatch:SetFrameLevel(button:GetFrameLevel() + 10)

	local outline = swatch:CreateTexture(nil, "BACKGROUND")
	outline:SetAllPoints()
	outline:SetColorTexture(0, 0, 0, 1)
	swatch.color = swatch:CreateTexture(nil, "ARTWORK")
	swatch.color:SetPoint("TOPLEFT", 1, -1)
	swatch.color:SetPoint("BOTTOMRIGHT", -1, 1)

	swatch:SetScript("OnClick", function(self)
		if self.setName then GSC.OpenColorPicker(GSC.Entry(self.setName)) end
	end)
	swatch:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Gear Set Colors")
		GameTooltip:AddLine("Click to change the colour of this set's items in your bags.", 1, 1, 1, true)
		GameTooltip:AddLine("/gsc for more options.", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

	button.GearSetColorsSwatch = swatch
	swatches[#swatches + 1] = swatch
	return swatch
end

local function DecorateButtonUnsafe(button, elementData)
	local swatch = GetSwatch(button)
	swatch.setName = SetNameForButton(button, elementData)
	UpdateSwatch(swatch)
end

-- Runs inside Blizzard's list code, so an error must never escape into it.
local function DecorateButton(button, elementData)
	local ok, err = pcall(DecorateButtonUnsafe, button, elementData)
	if not ok and not warned then
		warned = true
		GSC.Print("Equipment Manager colours failed: " .. tostring(err))
	end
end

function GSC.RefreshSwatches()
	for _, swatch in ipairs(swatches) do
		local button = swatch:GetParent()
		if button:IsShown() then
			swatch.setName = SetNameForButton(button, button.GetElementData and button:GetElementData())
			UpdateSwatch(swatch)
		end
	end
end

local function FindScrollBox()
	local pane = (PaperDollFrame and PaperDollFrame.EquipmentManagerPane) or _G.PaperDollEquipmentManagerPane
	return pane and pane.ScrollBox, pane
end

local function DecorateExisting(scrollBox)
	if scrollBox.ForEachFrame then
		scrollBox:ForEachFrame(function(button, elementData) DecorateButton(button, elementData) end)
	end
end

local function TryHook()
	if hookedScrollBox then return true end
	local scrollBox, pane = FindScrollBox()
	if not scrollBox then return false end

	if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
		-- Not iterateExisting: it calls the callback as (button, elementData), without the owner that
		-- the later calls get first. DecorateExisting below covers the rows already shown.
		ScrollUtil.AddInitializedFrameCallback(scrollBox, function(_, button, elementData)
			DecorateButton(button, elementData)
		end, GSC, false)
	elseif scrollBox.RegisterCallback and ScrollBoxListMixin and ScrollBoxListMixin.Event then
		scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, button, elementData)
			DecorateButton(button, elementData)
		end, GSC)
	else
		return false
	end
	-- Blizzard rebuilds the list on most changes, but recolour when the pane opens anyway.
	if pane and pane.HookScript then pane:HookScript("OnShow", GSC.RefreshSwatches) end
	hookedScrollBox = scrollBox
	DecorateExisting(scrollBox)
	return true
end

local function TryHookFromCharacterFrame()
	if TryHook() or warned then return end
	warned = true
	GSC.Print("couldn't add colour squares to the Equipment Manager. Use /gsc to change set colours.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		local ok = pcall(TryHook)
		if not (ok and hookedScrollBox) and CharacterFrame then
			-- The pane may only exist once the Character window is first opened.
			CharacterFrame:HookScript("OnShow", function()
				local ok2, err = pcall(TryHookFromCharacterFrame)
				if not ok2 and not warned then
					warned = true
					GSC.Print("Equipment Manager colours failed: " .. tostring(err))
				end
			end)
		end
	else
		C_Timer.After(0, GSC.RefreshSwatches)
	end
end)
