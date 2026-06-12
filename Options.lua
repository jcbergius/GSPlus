-- Options.lua
-- Saved settings with defaults plus an Interface Options panel.

BetterGearScore = BetterGearScore or {}
BetterGearScore.Options = BetterGearScore.Options or {}

local Options = BetterGearScore.Options

Options.DEFAULTS = {
    showItemTooltip = true,
    showTooltipBreakdown = true,
    showUpgradeDelta = true,
    showLegacyGearScore = true,
    showCharacterPane = true,
    showUnitTooltip = true,
    enableComms = true,
    autoDetectFeralRole = true,
}

-- Order and labels for the options panel.
Options.PANEL_OPTIONS = {
    { key = "showItemTooltip",     label = "Show gear score on item tooltips" },
    { key = "showTooltipBreakdown", label = "Show stat breakdown on item tooltips (hold Shift)" },
    { key = "showUpgradeDelta",    label = "Show upgrade comparison vs equipped items" },
    { key = "showLegacyGearScore", label = "Show legacy GearScore value" },
    { key = "showUnitTooltip",     label = "Show gear scores when mousing over players" },
    { key = "showCharacterPane",   label = "Show gear score on the character pane" },
    { key = "enableComms",         label = "Share scores with group members (addon channel)" },
    { key = "autoDetectFeralRole", label = "Detect Feral Druid tank vs DPS from equipped gear" },
}

function Options:GetStore()
    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}
    BetterGearScoreSavedVars.options = BetterGearScoreSavedVars.options or {}

    return BetterGearScoreSavedVars.options
end

function Options:Get(key)
    local value = self:GetStore()[key]

    if value == nil then
        return self.DEFAULTS[key]
    end

    return value
end

function Options:Set(key, value)
    self:GetStore()[key] = value and true or false

    if BetterGearScore.TalentDetector then
        BetterGearScore.TalentDetector.roleCache = nil
    end

    if BetterGearScore.Calculator and BetterGearScore.Calculator.InvalidateCache then
        BetterGearScore.Calculator:InvalidateCache()
    end

    BetterGearScore:RefreshUI()
end

function Options:CreatePanel()
    if self.panel then
        return self.panel
    end

    local panel = CreateFrame("Frame", "BetterGearScoreOptionsPanel", UIParent)
    panel.name = "BetterGearScore"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("BetterGearScore")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("v" .. (BetterGearScore.VERSION or "?") .. " - Role-aware gear scoring")

    local checkboxes = {}
    local anchor = subtitle
    local anchorOffset = -16

    for index, optionInfo in ipairs(self.PANEL_OPTIONS) do
        local name = "BetterGearScoreOptionsCheck" .. index
        local checkbox = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, anchorOffset)

        local label = _G[name .. "Text"]

        if label then
            label:SetText(optionInfo.label)
        end

        checkbox.bgsOptionKey = optionInfo.key
        checkbox:SetChecked(self:Get(optionInfo.key))
        checkbox:SetScript("OnClick", function(button)
            Options:Set(button.bgsOptionKey, button:GetChecked() and true or false)
        end)

        checkboxes[#checkboxes + 1] = checkbox
        anchor = checkbox
        anchorOffset = -4
    end

    panel.refresh = function()
        for _, checkbox in ipairs(checkboxes) do
            checkbox:SetChecked(Options:Get(checkbox.bgsOptionKey))
        end
    end

    self.panel = panel
    self.checkboxes = checkboxes

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        self.settingsCategory = category
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    return panel
end

function Options:OpenPanel()
    self:CreatePanel()

    if self.panel and self.panel.refresh then
        self.panel.refresh()
    end

    if Settings and Settings.OpenToCategory and self.settingsCategory then
        Settings.OpenToCategory(self.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and self.panel then
        -- Called twice to work around the classic client bug where the first
        -- call opens the options frame without selecting the category.
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    else
        print("|cff00ff00BetterGearScore:|r Options panel is not available on this client. Use /bgs help.")
    end
end

function Options:Initialize()
    self:CreatePanel()
end
