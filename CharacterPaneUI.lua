-- CharacterPaneUI.lua

GSPlus = GSPlus or {}
GSPlus.CharacterPaneUI = GSPlus.CharacterPaneUI or {}

local CharacterPaneUI = GSPlus.CharacterPaneUI

CharacterPaneUI.frame = CharacterPaneUI.frame or nil
CharacterPaneUI.labelText = CharacterPaneUI.labelText or nil
CharacterPaneUI.scoreText = CharacterPaneUI.scoreText or nil
CharacterPaneUI.eventFrame = CharacterPaneUI.eventFrame or nil
CharacterPaneUI.hooked = CharacterPaneUI.hooked or false

function CharacterPaneUI:GetParentFrame()
    if PaperDollFrame then
        return PaperDollFrame
    end

    if CharacterFrame then
        return CharacterFrame
    end

    return UIParent
end

function CharacterPaneUI:Create()
    if self.frame then
        return self.frame
    end

    local parent = self:GetParentFrame()

    if not parent then
        return nil
    end

    local frame = CreateFrame("Frame", "GSPlusCharacterPaneFrame", parent)
    frame:SetSize(135, 22)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(999)
    frame:EnableMouse(true)

    frame:ClearAllPoints()

    if PaperDollFrame then
        frame:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT", 73, 254)
    elseif CharacterFrame then
        frame:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 73, 254)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local labelText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("LEFT", frame, "LEFT", 0, 0)
    labelText:SetText("|cffffffffgs+|r")

    local scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    scoreText:SetText("|cffffffff0|r")

    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

        local data = GSPlus.Calculator:GetPlayerGSPlus()
        local coloredScore = GSPlus.Calculator:ColorizeScore(
            data.totalWeightedScore or 0,
            data.totalMaxBudgetScore or 0
        )

        GameTooltip:AddLine("|cff00ff00gs+|r")
        GameTooltip:AddLine("Profile: " .. (data.profileName or "Unknown"), 1, 1, 1)
        GameTooltip:AddDoubleLine("Weighted Score", coloredScore, 1, 1, 1, 1, 1, 1)

        if GSPlus.Options:Get("showBudgetScore") then
            GameTooltip:AddLine("Budget Score: " .. math.floor(data.totalRawScore or 0), 0.8, 0.8, 0.8)
        end

        if GSPlus.Options:Get("showLegacyGearScore") then
            local legacyScore = GSPlus.LegacyGearScore:GetPlayerScore()

            if legacyScore > 0 then
                GameTooltip:AddLine("GearScore (legacy): " .. legacyScore, 0.6, 0.6, 0.6)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click: item-by-item details", 0.65, 0.65, 0.65)
        GameTooltip:AddLine("Right-click: group gear scores", 0.65, 0.65, 0.65)

        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            GSPlus.GroupFrame:Toggle()
        else
            GSPlus.UI:Toggle()
        end
    end)

    self.frame = frame
    self.labelText = labelText
    self.scoreText = scoreText

    self:Update()

    if CharacterFrame and not CharacterFrame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end

    return frame
end

function CharacterPaneUI:Reanchor()
    if not self.frame then
        return
    end

    local parent = self:GetParentFrame()

    if parent then
        self.frame:SetParent(parent)
    end

    self.frame:ClearAllPoints()
    self.frame:SetFrameStrata("DIALOG")
    self.frame:SetFrameLevel(999)

    if PaperDollFrame then
        self.frame:SetPoint("BOTTOMLEFT", PaperDollFrame, "BOTTOMLEFT", 73, 254)
    elseif CharacterFrame then
        self.frame:SetPoint("BOTTOMLEFT", CharacterFrame, "BOTTOMLEFT", 73, 254)
    else
        self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function CharacterPaneUI:Update()
    if not GSPlus.Options:Get("showCharacterPane") then
        if self.frame then
            self.frame:Hide()
        end
        return
    end

    if not self.frame then
        self:Create()
    end

    if not self.frame or not self.scoreText then
        return
    end

    if CharacterFrame and CharacterFrame:IsShown() and not self.frame:IsShown() then
        self.frame:Show()
    end

    local data = GSPlus.Calculator:GetPlayerGSPlus()
    local coloredScore = GSPlus.Calculator:ColorizeScore(
        data.totalWeightedScore or 0,
        data.totalMaxBudgetScore or 0
    )

    self.scoreText:SetText(coloredScore)
end

function CharacterPaneUI:Show()
    if not GSPlus.Options:Get("showCharacterPane") then
        self:Hide()
        return
    end

    local frame = self:Create()

    if not frame then
        return
    end

    self:Reanchor()
    self:Update()
    frame:Show()
end

function CharacterPaneUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function CharacterPaneUI:HookCharacterFrame()
    if self.hooked then
        return
    end

    self.hooked = true

    if CharacterFrame then
        CharacterFrame:HookScript("OnShow", function()
            GSPlus.CharacterPaneUI:Show()
        end)

        CharacterFrame:HookScript("OnHide", function()
            GSPlus.CharacterPaneUI:Hide()
        end)
    end

    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            GSPlus.CharacterPaneUI:Show()
        end)

        PaperDollFrame:HookScript("OnHide", function()
            GSPlus.CharacterPaneUI:Hide()
        end)
    end
end

-- Equipment and talent changes are handled by Core's debounced RefreshUI,
-- which calls CharacterPaneUI:Update(). This frame only ensures the character
-- frame hooks exist once the relevant frames have been created.
function CharacterPaneUI:CreateEventFrame()
    if self.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function()
        GSPlus.CharacterPaneUI:HookCharacterFrame()
        GSPlus.CharacterPaneUI:Update()

        if CharacterFrame and CharacterFrame:IsShown() then
            GSPlus.CharacterPaneUI:Show()
        end
    end)

    self.eventFrame = eventFrame
end

function CharacterPaneUI:Initialize()
    self:CreateEventFrame()
    self:HookCharacterFrame()
    self:Create()

    if CharacterFrame and CharacterFrame:IsShown() then
        self:Show()
    end
end

CharacterPaneUI:Initialize()