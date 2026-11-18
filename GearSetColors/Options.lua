-- Options page (Options > AddOns > Gear Set Colors, or /gsc): how items are marked,
-- and one colour per equipment set of the current character.

local ADDON, ns = ...
local GSC = ns.GSC

local panel, category
local rows = {}
local emptyText, setsAnchor

local function Changed()
	GSC.RefreshBags()
	if GSC.RefreshSwatches then GSC.RefreshSwatches() end
	if panel and panel:IsShown() then panel.Refresh() end
end

local function OpenColorPicker(entry)
	local r, g, b = entry.r, entry.g, entry.b
	local function Set(nr, ng, nb)
		entry.r, entry.g, entry.b = nr, ng, nb
		Changed()
	end
	local function OnColor() Set(ColorPickerFrame:GetColorRGB()) end
	local function OnCancel() Set(r, g, b) end

	if ColorPickerFrame.SetupColorPickerAndShow then
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r, g = g, b = b, hasOpacity = false,
			swatchFunc = OnColor, cancelFunc = OnCancel,
		})
	else
		ColorPickerFrame.hasOpacity = false
		ColorPickerFrame.previousValues = { r = r, g = g, b = b }
		ColorPickerFrame.func = OnColor
		ColorPickerFrame.swatchFunc = OnColor
		ColorPickerFrame.cancelFunc = OnCancel
		ColorPickerFrame:SetColorRGB(r, g, b)
		ColorPickerFrame:Hide()
		ColorPickerFrame:Show()
	end
end
GSC.OpenColorPicker = OpenColorPicker

local function CheckBox(parent, label, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	c.label = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	c.label:SetPoint("LEFT", c, "RIGHT", 4, 0)
	c.label:SetText(label)
	c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
	return c
end

local function GetRow(i)
	if rows[i] then return rows[i] end
	local row = CreateFrame("Frame", nil, panel)
	row:SetSize(420, 28)
	row:SetPoint("TOPLEFT", setsAnchor, "BOTTOMLEFT", 0, -8 - (i - 1) * 32)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(24, 24)
	row.icon:SetPoint("LEFT", 0, 0)

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetWidth(160)
	row.name:SetJustifyH("LEFT")

	-- Colour swatch: click to change the colour.
	row.swatch = CreateFrame("Button", nil, row)
	row.swatch:SetSize(48, 22)
	row.swatch:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
	local outline = row.swatch:CreateTexture(nil, "BACKGROUND")
	outline:SetAllPoints()
	outline:SetColorTexture(0, 0, 0, 1)
	row.swatch.color = row.swatch:CreateTexture(nil, "ARTWORK")
	row.swatch.color:SetPoint("TOPLEFT", 2, -2)
	row.swatch.color:SetPoint("BOTTOMRIGHT", -2, 2)
	row.swatch:SetScript("OnClick", function(self) OpenColorPicker(self.entry) end)
	row.swatch:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Click to change this set's colour")
		GameTooltip:Show()
	end)
	row.swatch:SetScript("OnLeave", function() GameTooltip:Hide() end)

	row.enabled = CheckBox(row, "Mark its items", function(checked)
		row.entry.enabled = checked
		Changed()
	end)
	row.enabled:SetPoint("LEFT", row.swatch, "RIGHT", 16, 0)

	rows[i] = row
	return row
end

local function Refresh()
	local style = GSC.DB().style
	panel.border:SetChecked(style.border)
	panel.tint:SetChecked(style.tint)
	panel.corner:SetChecked(style.corner)

	local sets = GSC.GetSets()
	for i, set in ipairs(sets) do
		local row = GetRow(i)
		row.entry = set.entry
		row.swatch.entry = set.entry
		row.icon:SetTexture(set.icon or 134400)
		row.name:SetText(set.name)
		row.swatch.color:SetColorTexture(set.entry.r, set.entry.g, set.entry.b, 1)
		row.enabled:SetChecked(set.entry.enabled)
		row:Show()
	end
	for i = #sets + 1, #rows do rows[i]:Hide() end
	emptyText:SetShown(#sets == 0)
end

local function SetupOptionsPage()
	panel = CreateFrame("Frame")
	panel.name = "Gear Set Colors"
	panel.Refresh = Refresh

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Gear Set Colors")

	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	text:SetJustifyH("LEFT")
	text:SetText("Items in your bags that belong to an equipment set are marked with that set's colour, "
		.. "so you don't sell them by mistake. Sets come from the Equipment Manager in the Character window. "
		.. "Colours go by set name and are shared by all your characters.")

	local styleTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	styleTitle:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
	styleTitle:SetText("How to mark items")

	local style = function(key)
		return function(checked)
			GSC.DB().style[key] = checked
			Changed()
		end
	end
	panel.border = CheckBox(panel, "Coloured border", style("border"))
	panel.border:SetPoint("TOPLEFT", styleTitle, "BOTTOMLEFT", 0, -6)
	panel.tint = CheckBox(panel, "Coloured tint over the icon", style("tint"))
	panel.tint:SetPoint("TOPLEFT", panel.border, "BOTTOMLEFT", 0, -2)
	panel.corner = CheckBox(panel, "Small square per set in the top-right corner", style("corner"))
	panel.corner:SetPoint("TOPLEFT", panel.tint, "BOTTOMLEFT", 0, -2)

	local note = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", panel.corner, "BOTTOMLEFT", 4, -4)
	note:SetText("An item in several sets gets a border alternating their colours.")

	setsAnchor = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	setsAnchor:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -4, -18)
	setsAnchor:SetText("This character's sets")

	emptyText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	emptyText:SetPoint("TOPLEFT", setsAnchor, "BOTTOMLEFT", 0, -10)
	emptyText:SetText("No equipment sets yet. Create them in the Character window's Equipment Manager.")

	panel:SetScript("OnShow", Refresh)

	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, "Gear Set Colors")
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

function GSC.OpenOptions()
	if category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

function GSC.OnSetsChanged()
	if panel and panel:IsShown() then Refresh() end
end

function GearSetColors_OnAddonCompartmentClick()
	GSC.OpenOptions()
end

SLASH_GEARSETCOLORS1 = "/gsc"
SlashCmdList.GEARSETCOLORS = function() GSC.OpenOptions() end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	local ok, err = pcall(SetupOptionsPage)
	if not ok then GSC.Print("options page failed: " .. tostring(err)) end
end)
