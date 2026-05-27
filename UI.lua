-- UI Panel for displaying Gear Score

GearScoreUI = {}
GearScoreUI.WINDOW_WIDTH = 400
GearScoreUI.WINDOW_HEIGHT = 600

-- Create the main UI window
function GearScoreUI:CreateWindow()
    if self.frame then
        return self.frame
    end
    
    local frame = CreateFrame("Frame", "GearScoreMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    
    frame:SetTitle("Gear Score Calculator")
    
    -- Create close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- Total score display area
    local totalScoreFrame = CreateFrame("Frame", nil, frame)
    totalScoreFrame:SetSize(self.WINDOW_WIDTH - 30, 80)
    totalScoreFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -30)
    totalScoreFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 5, right = 5, top = 5, bottom = 5}
    })
    totalScoreFrame:SetBackdropColor(0.1, 0.1, 0.15, 0.8)
    
    -- Total gear score text
    local totalScoreText = totalScoreFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    totalScoreText:SetPoint("TOPLEFT", totalScoreFrame, "TOPLEFT", 10, -10)
    totalScoreText:SetText("Total Gear Score: 0")
    self.totalScoreText = totalScoreText
    
    -- Raw vs Weighted info
    local infoText = totalScoreFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", totalScoreText, "BOTTOMLEFT", 0, -10)
    infoText:SetText("Raw: 0  |  Weighted: 0")
    self.infoText = infoText
    
    -- Scrollable item list
    local scrollFrame = CreateFrame("ScrollFrame", "GearScoreScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", totalScoreFrame, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetSize(self.WINDOW_WIDTH - 40, self.WINDOW_HEIGHT - 130)
    
    local listFrame = CreateFrame("Frame", "GearScoreListFrame", scrollFrame)
    listFrame:SetSize(self.WINDOW_WIDTH - 50, 1)  -- Height will be adjusted
    scrollFrame:SetScrollChild(listFrame)
    
    self.listFrame = listFrame
    self.scrollFrame = scrollFrame
    self.frame = frame
    
    return frame
end

-- Update the UI with current gear score
function GearScoreUI:Update()
    if not self.frame then
        self:CreateWindow()
    end
    
    local gearScoreData = GearScoreCalculator:GetPlayerGearScore()
    
    -- Update total score display
    self.totalScoreText:SetText("Total Gear Score: " .. math.floor(gearScoreData.totalWeightedScore))
    self.infoText:SetText("Raw: " .. math.floor(gearScoreData.totalRawScore) .. "  |  Weighted: " .. math.floor(gearScoreData.totalWeightedScore))
    
    -- Clear old item entries
    for i = 1, #self.itemEntries or 0 do
        self.itemEntries[i]:Hide()
        self.itemEntries[i] = nil
    end
    self.itemEntries = {}
    
    -- Add item entries
    local yOffset = -10
    local itemCount = 0
    
    for slot, itemScore in pairs(gearScoreData.itemScores) do
        local itemName = GearScoreItemParser:GetItemName(itemScore.link)
        local slotName = GearScoreItemParser:GetSlotName(slot)
        
        local itemButton = self:CreateItemEntry(itemName, slotName, itemScore.rawScore, itemScore.weightedScore, itemScore.link)
        itemButton:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        
        self.itemEntries[#self.itemEntries + 1] = itemButton
        
        yOffset = yOffset - 40
        itemCount = itemCount + 1
    end
    
    -- Adjust list frame height
    self.listFrame:SetHeight(itemCount * 40 + 20)
end

-- Create a single item entry
function GearScoreUI:CreateItemEntry(itemName, slotName, rawScore, weightedScore, itemLink)
    local frame = CreateFrame("Button", nil, self.listFrame)
    frame:SetSize(self.WINDOW_WIDTH - 50, 35)
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = {left = 3, right = 3, top = 3, bottom = 3}
    })
    frame:SetBackdropColor(0.15, 0.15, 0.2, 0.6)
    
    -- Item name
    local nameText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    nameText:SetText(slotName .. ": " .. itemName)
    nameText:SetWidth(self.WINDOW_WIDTH - 120)
    nameText:SetJustifyH("LEFT")
    
    -- Score display
    local scoreText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    scoreText:SetText(math.floor(weightedScore))
    
    -- Hover effect
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

-- Show the window
function GearScoreUI:Show()
    if not self.frame then
        self:CreateWindow()
    end
    self:Update()
    self.frame:Show()
end

-- Hide the window
function GearScoreUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Toggle the window
function GearScoreUI:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
