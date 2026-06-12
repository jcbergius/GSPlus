-- InspectPaneUI.lua
-- Shows the inspected player's gear score on the Blizzard inspect window.
-- Blizzard_InspectUI is load-on-demand; Core initializes this module when it
-- loads. Opening the inspect window triggers Blizzard's own NotifyInspect,
-- and Inspect.lua's opportunistic INSPECT_READY handler caches the result.

GSPlus = GSPlus or {}
GSPlus.InspectPaneUI = GSPlus.InspectPaneUI or {}

local InspectPaneUI = GSPlus.InspectPaneUI

function InspectPaneUI:GetParentFrame()
    return InspectPaperDollFrame or InspectFrame
end

function InspectPaneUI:GetInspectedUnit()
    if InspectFrame and InspectFrame.unit then
        return InspectFrame.unit
    end

    return "target"
end

function InspectPaneUI:Create()
    if self.frame then
        return self.frame
    end

    local parent = self:GetParentFrame()

    if not parent then
        return nil
    end

    local frame = CreateFrame("Frame", "GSPlusInspectPaneFrame", parent)
    frame:SetSize(135, 22)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(999)
    frame:EnableMouse(true)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 73, 254)

    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", frame, "LEFT", 0, 0)
    labelText:SetText("|cffffffffgs+|r")

    local scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    scoreText:SetText("|cff888888...|r")

    frame:SetScript("OnEnter", function()
        GSPlus.InspectPaneUI:ShowTooltip(frame)
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.frame = frame
    self.scoreText = scoreText

    return frame
end

function InspectPaneUI:ShowTooltip(owner)
    local unit = self:GetInspectedUnit()
    local entry = GSPlus.PlayerCache:GetByUnit(unit)

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("|cff00ff00gs+|r")

    if entry then
        local coloredScore = GSPlus.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0)

        GameTooltip:AddLine("Profile: " .. GSPlus.Profiles:GetProfileDisplayName(entry.profileKey), 1, 1, 1)
        GameTooltip:AddDoubleLine("gs+", coloredScore, 1, 1, 1, 1, 1, 1)

        if GSPlus.Options:Get("showBudgetScore") then
            GameTooltip:AddLine("Budget Score: " .. math.floor(entry.raw or 0), 0.8, 0.8, 0.8)
        end

        if GSPlus.Options:Get("showLegacyGearScore") and entry.legacy and entry.legacy > 0 then
            GameTooltip:AddLine("GearScore (legacy): " .. math.floor(entry.legacy), 0.6, 0.6, 0.6)
        end

        if (entry.missingEnchants or 0) > 0 then
            GameTooltip:AddLine(entry.missingEnchants .. " unenchanted item(s)", 1, 0.53, 0)
        end

        if (entry.emptySockets or 0) > 0 then
            GameTooltip:AddLine(entry.emptySockets .. " empty socket(s)", 1, 0.53, 0)
        end

        if (entry.missingItems or 0) > 0 then
            GameTooltip:AddLine("Some items not cached yet; score may rise shortly.", 0.6, 0.6, 0.6)
        end
    else
        GameTooltip:AddLine("Waiting for inspect data...", 0.8, 0.8, 0.8)
    end

    GameTooltip:Show()
end

function InspectPaneUI:Update()
    if not self.frame or not self.scoreText then
        return
    end

    if not InspectFrame or not InspectFrame:IsShown() then
        self.frame:Hide()
        return
    end

    local unit = self:GetInspectedUnit()
    local entry = GSPlus.PlayerCache:GetByUnit(unit)

    if entry then
        self.scoreText:SetText(GSPlus.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0))
    else
        self.scoreText:SetText("|cff888888...|r")

        -- Blizzard's NotifyInspect usually covers this, but queue our own
        -- request in case its data was claimed before we could read it.
        GSPlus.Inspect:QueueUnitInspect(unit)
    end

    self.frame:Show()
end

function InspectPaneUI:OnScoreUpdated(guid)
    if not self.frame or not self.frame:IsShown() then
        return
    end

    local unit = self:GetInspectedUnit()

    if guid and UnitGUID and UnitGUID(unit) ~= guid then
        return
    end

    self:Update()
end

function InspectPaneUI:Initialize()
    if self.hooked then
        return
    end

    if not InspectFrame then
        return
    end

    self:Create()

    InspectFrame:HookScript("OnShow", function()
        GSPlus.InspectPaneUI:Update()
    end)

    InspectFrame:HookScript("OnHide", function()
        if GSPlus.InspectPaneUI.frame then
            GSPlus.InspectPaneUI.frame:Hide()
        end
    end)

    if InspectFrame:IsShown() then
        self:Update()
    end

    self.hooked = true
end
