-- UI Panel for displaying GSPlus

local UI = GSPlus.UI

UI.WINDOW_WIDTH = 400
UI.WINDOW_HEIGHT = 600
UI.HEADER_HEIGHT = 110
UI.ENTRY_HEIGHT = 40
UI.itemEntries = UI.itemEntries or {}

function UI:CreateWindow()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "GSPlusMainWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText("gs+")
    end

    local totalScoreFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    totalScoreFrame:SetSize(self.WINDOW_WIDTH - 30, self.HEADER_HEIGHT)
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

    local groupButton = CreateFrame("Button", nil, totalScoreFrame, "UIPanelButtonTemplate")
    groupButton:SetSize(110, 22)
    groupButton:SetPoint("TOPRIGHT", totalScoreFrame, "TOPRIGHT", -10, -8)
    groupButton:SetText("Group Scores")
    groupButton:SetScript("OnClick", function()
        GSPlus.GroupFrame:Toggle()
    end)

    local infoText = totalScoreFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    infoText:SetPoint("TOPLEFT", totalScoreText, "BOTTOMLEFT", 0, -10)
    infoText:SetText("Budget: 0")
    self.infoText = infoText

    self:CreateProfileDropdown(totalScoreFrame)

    local scrollFrame = CreateFrame("ScrollFrame", "GSPlusScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", totalScoreFrame, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetSize(self.WINDOW_WIDTH - 40, self.WINDOW_HEIGHT - self.HEADER_HEIGHT - 50)

    local listFrame = CreateFrame("Frame", "GSPlusListFrame", scrollFrame)
    listFrame:SetSize(self.WINDOW_WIDTH - 65, 1)
    scrollFrame:SetScrollChild(listFrame)

    self.listFrame = listFrame
    self.scrollFrame = scrollFrame
    self.frame = frame

    return frame
end

function UI:CreateProfileDropdown(parent)
    if self.profileDropdown or not CreateFrame then
        return self.profileDropdown
    end

    if not UIDropDownMenu_Initialize or not UIDropDownMenu_CreateInfo then
        return nil
    end

    local dropdown = CreateFrame("Frame", "GSPlusProfileDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", self.infoText, "BOTTOMLEFT", -20, -8)
    UIDropDownMenu_SetWidth(dropdown, 180)

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local Profiles = GSPlus.Profiles
        local manual = Profiles:IsUsingManualProfile()
        local selected = Profiles:GetSelectedProfile()

        local info = UIDropDownMenu_CreateInfo()
        info.text = "Automatic (detect from talents)"
        info.checked = not manual
        info.func = function()
            Profiles:UseAutomaticProfileDetection()
        end
        UIDropDownMenu_AddButton(info, level)

        for _, profileKey in ipairs(Profiles.SORTED_PROFILE_KEYS) do
            if GSPlus.Weights.PROFILE_WEIGHTS[profileKey] then
                local key = profileKey

                info = UIDropDownMenu_CreateInfo()
                info.text = Profiles:GetProfileDisplayName(key)
                info.checked = manual and selected == key
                info.func = function()
                    Profiles:SetSelectedProfile(key)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end)

    self.profileDropdown = dropdown
    self:UpdateProfileDropdown()

    return dropdown
end

function UI:UpdateProfileDropdown()
    if not self.profileDropdown or not UIDropDownMenu_SetText then
        return
    end

    local Profiles = GSPlus.Profiles
    local text = Profiles:GetProfileDisplayName(Profiles:GetSelectedProfile())

    if not Profiles:IsUsingManualProfile() then
        text = "Auto: " .. text
    end

    UIDropDownMenu_SetText(self.profileDropdown, text)
end

-- Returns item score entries in equipment slot order (pairs() iteration order
-- is undefined), with active set bonuses listed last.
function UI:GetOrderedItemScores(itemScores)
    local ordered = {}

    for _, slotInfo in ipairs(GSPlus.ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemScore = slotId and itemScores[slotId]

        if itemScore then
            ordered[#ordered + 1] = itemScore
        end
    end

    if itemScores["SET_BONUSES"] then
        ordered[#ordered + 1] = itemScores["SET_BONUSES"]
    end

    return ordered
end

function UI:AcquireItemEntry(index)
    local frame = self.itemEntries[index]

    if frame then
        return frame
    end

    frame = CreateFrame("Button", nil, self.listFrame, "BackdropTemplate")
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
    frame.nameText = nameText

    local scoreText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    scoreText:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
    frame.scoreText = scoreText

    frame:SetScript("OnEnter", function()
        frame:SetBackdropColor(0.2, 0.2, 0.3, 0.9)

        if frame.itemLink then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(frame.itemLink)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function()
        frame:SetBackdropColor(0.15, 0.15, 0.2, 0.6)
        GameTooltip:Hide()
    end)

    self.itemEntries[index] = frame

    return frame
end

function UI:SetItemEntry(frame, labelText, weightedScore, maxBudgetScore, itemLink)
    frame.itemLink = itemLink
    frame.nameText:SetText(labelText)
    frame.scoreText:SetText(GSPlus.Calculator:ColorizeScore(weightedScore or 0, maxBudgetScore or 0))
end

function UI:Update()
    if not self.frame then
        self:CreateWindow()
    end

    local data = GSPlus.Calculator:GetPlayerGSPlus()
    local coloredTotalScore = GSPlus.Calculator:ColorizeScore(
        data.totalWeightedScore or 0,
        data.totalMaxBudgetScore or 0
    )

    self.totalScoreText:SetText("Total Gear Score: " .. coloredTotalScore)

    self.infoText:SetText(
        "Profile: " .. (data.profileName or "Unknown")
        .. "  |  Budget: " .. math.floor(data.totalRawScore or 0)
    )

    self:UpdateProfileDropdown()

    local ordered = self:GetOrderedItemScores(data.itemScores or {})
    local yOffset = -5
    local entryCount = 0

    for _, itemScore in ipairs(ordered) do
        entryCount = entryCount + 1

        local labelText

        if itemScore.link then
            local itemName = GSPlus.ItemParser:GetItemName(itemScore.link)
            labelText = (itemScore.slotName or "Unknown") .. ": " .. itemName
        else
            labelText = itemScore.slotName or "Unknown"
        end

        local frame = self:AcquireItemEntry(entryCount)

        self:SetItemEntry(frame, labelText, itemScore.weightedScore, itemScore.maxBudgetScore, itemScore.link)

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        frame:Show()

        yOffset = yOffset - self.ENTRY_HEIGHT
    end

    if entryCount == 0 then
        entryCount = 1

        local frame = self:AcquireItemEntry(entryCount)

        self:SetItemEntry(frame, "No equipped items found", 0, 0, nil)

        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        frame:Show()
    end

    for i = entryCount + 1, #self.itemEntries do
        self.itemEntries[i]:Hide()
    end

    self.listFrame:SetHeight(entryCount * self.ENTRY_HEIGHT + 20)
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
