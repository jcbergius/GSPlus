-- UI Panel for displaying BetterGearScore

local UI = BetterGearScore.UI

UI.WINDOW_WIDTH = 400
UI.WINDOW_HEIGHT = 600
UI.itemEntries = UI.itemEntries or {}

function UI:CreateWindow()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "BetterGearScoreMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText("Better Gear Score")
    end

    local totalScoreFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    totalScoreFrame:SetSize(self.WINDOW_WIDTH - 30, 80)
    totalScoreFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -30)
    totalScoreFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    totalScoreFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.8)

    local totalScoreText = totalScoreFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    totalScoreText:SetPoint("TOPLEFT", totalScoreFrame, "TOPLEFT", 10, -10)
    totalScoreText:SetText("Total Gear Score: 0")
    self.totalScoreText = totalScoreText

    local infoText = totalScoreFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", totalScoreText, "BOTTOMLEFT", 0, -10)
    infoText:SetText("Budget: 0")
    self.infoText = infoText

    local scrollFrame = CreateFrame("ScrollFrame", "BetterGearScoreScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", totalScoreFrame, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetSize(self.WINDOW_WIDTH - 40, self.WINDOW_HEIGHT - 130)

    local listFrame = CreateFrame("Frame", "BetterGearScoreListFrame", scrollFrame)
    listFrame:SetSize(self.WINDOW_WIDTH - 65, 1)
    scrollFrame:SetScrollChild(listFrame)

    self.listFrame = listFrame
    self.scrollFrame = scrollFrame
    self.frame = frame

    return frame
end

function UI:Update()
    if not self.frame then
        self:CreateWindow()
    end

    local data = BetterGearScore.Calculator:GetPlayerBetterGearScore()
    local coloredTotalScore = BetterGearScore.Calculator:ColorizeScore(
        data.totalWeightedScore or 0,
        data.totalMaxBudgetScore or 0
    )

    self.totalScoreText:SetText("Total Gear Score: " .. coloredTotalScore)

    self.infoText:SetText(
        "Profile: " .. (data.profileName or "Unknown")
        .. "  |  Budget: " .. math.floor(data.totalRawScore or 0)
    )

    self.itemEntries = self.itemEntries or {}

    for i = 1, #self.itemEntries do
        self.itemEntries[i]:Hide()
        self.itemEntries[i]:SetParent(nil)
        self.itemEntries[i] = nil
    end

    local yOffset = -5
    local itemCount = 0

    for slot, itemScore in pairs(data.itemScores or {}) do
        local itemName = BetterGearScore.ItemParser:GetItemName(itemScore.link)
        local slotName = itemScore.slotName or BetterGearScore.ItemParser:GetSlotName(slot)

        local itemButton = self:CreateItemEntry(
            itemName,
            slotName,
            itemScore.rawScore or 0,
            itemScore.weightedScore or 0,
            itemScore.maxBudgetScore or 0,
            itemScore.link
        )

        itemButton:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        self.itemEntries[#self.itemEntries + 1] = itemButton

        yOffset = yOffset - 40
        itemCount = itemCount + 1
    end

    if itemCount == 0 then
        local emptyRow = self:CreateItemEntry("No equipped items found", "Info", 0, 0, 0, nil)
        emptyRow:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        self.itemEntries[#self.itemEntries + 1] = emptyRow
        itemCount = 1
    end

    self.listFrame:SetHeight(itemCount * 40 + 20)
end

function UI:CreateItemEntry(itemName, slotName, rawScore, weightedScore, maxBudgetScore, itemLink)
    local frame = CreateFrame("Button", nil, self.listFrame, "BackdropTemplate")
    frame:SetSize(self.WINDOW_WIDTH - 65, 35)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    frame:SetBackdropColor(0.15, 0.15, 0.2, 0.6)

    local nameText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("LEFT", frame, "LEFT", 8, 0)
    nameText:SetWidth(self.WINDOW_WIDTH - 145)
    nameText:SetJustifyH("LEFT")
    nameText:SetText((slotName or "Unknown") .. ": " .. (itemName or "Unknown"))

    local scoreText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    scoreText:SetText(BetterGearScore.Calculator:ColorizeScore(weightedScore or 0, maxBudgetScore or 0))

    frame:SetScript("OnEnter", function()
        frame:SetBackdropColor(0.2, 0.2, 0.3, 0.9)

        if itemLink then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function()
        frame:SetBackdropColor(0.15, 0.15, 0.2, 0.6)
        GameTooltip:Hide()
    end)

    return frame
end

function UI:Show()
    if not self.frame then
        self:CreateWindow()
    end

    self:Update()
    self.frame:Show()
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function UI:IsVisible()
    return self.frame and self.frame:IsShown()
end