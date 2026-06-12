-- CharacterPaneUI.lua

BetterGearScore = BetterGearScore or {}
BetterGearScore.CharacterPaneUI = BetterGearScore.CharacterPaneUI or {}

local CharacterPaneUI = BetterGearScore.CharacterPaneUI

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

    local frame = CreateFrame("Frame", "BetterGearScoreCharacterPaneFrame", parent)
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
    labelText:SetText("|cffffffffBGS|r")

    local scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    scoreText:SetPoint("LEFT", labelText, "RIGHT", 8, 0)
    scoreText:SetText("|cffffffff0|r")

    frame:SetScript("OnEnter", function()
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")

        local data = BetterGearScore.Calculator:GetPlayerBetterGearScore()
        local coloredScore = BetterGearScore.Calculator:ColorizeScore(
            data.totalWeightedScore or 0,
            data.totalMaxBudgetScore or 0
        )

        GameTooltip:AddLine("|cff00ff00BetterGearScore|r")
        GameTooltip:AddLine("Profile: " .. (data.profileName or "Unknown"), 1, 1, 1)
        GameTooltip:AddDoubleLine("Weighted Score", coloredScore, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine("Budget Score: " .. math.floor(data.totalRawScore or 0), 0.8, 0.8, 0.8)

        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
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
    if not self.frame then
        self:Create()
    end

    if not self.frame or not self.scoreText then
        return
    end

    local data = BetterGearScore.Calculator:GetPlayerBetterGearScore()
    local coloredScore = BetterGearScore.Calculator:ColorizeScore(
        data.totalWeightedScore or 0,
        data.totalMaxBudgetScore or 0
    )

    self.scoreText:SetText(coloredScore)
end

function CharacterPaneUI:Show()
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
            BetterGearScore.CharacterPaneUI:Show()
        end)

        CharacterFrame:HookScript("OnHide", function()
            BetterGearScore.CharacterPaneUI:Hide()
        end)
    end

    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            BetterGearScore.CharacterPaneUI:Show()
        end)

        PaperDollFrame:HookScript("OnHide", function()
            BetterGearScore.CharacterPaneUI:Hide()
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
        BetterGearScore.CharacterPaneUI:HookCharacterFrame()
        BetterGearScore.CharacterPaneUI:Update()

        if CharacterFrame and CharacterFrame:IsShown() then
            BetterGearScore.CharacterPaneUI:Show()
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