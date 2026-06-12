-- GroupFrame.lua
-- Party/raid gear score overview (/bgs group): scores from comms or inspect,
-- with missing enchant/socket callouts for raid leaders.

BetterGearScore = BetterGearScore or {}
BetterGearScore.GroupFrame = BetterGearScore.GroupFrame or {}

local GroupFrame = BetterGearScore.GroupFrame

GroupFrame.WINDOW_WIDTH = 440
GroupFrame.WINDOW_HEIGHT = 480
GroupFrame.ROW_HEIGHT = 32
GroupFrame.rows = GroupFrame.rows or {}

function GroupFrame:GetGroupUnits()
    local units = {}

    if IsInRaid and IsInRaid() then
        local count = (GetNumGroupMembers and GetNumGroupMembers()) or 0

        for i = 1, count do
            units[#units + 1] = "raid" .. i
        end
    else
        units[#units + 1] = "player"

        if IsInGroup and IsInGroup() then
            for i = 1, 4 do
                if UnitExists("party" .. i) then
                    units[#units + 1] = "party" .. i
                end
            end
        end
    end

    return units
end

function GroupFrame:CollectRows()
    local rows = {}

    for _, unit in ipairs(self:GetGroupUnits()) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local name = UnitName(unit)
            local _, classFileName = UnitClass(unit)
            local entry

            if UnitIsUnit(unit, "player") then
                entry = BetterGearScore.Inspect:BuildPlayerEntry()
            else
                entry = BetterGearScore.PlayerCache:GetByUnit(unit)
            end

            rows[#rows + 1] = {
                unit = unit,
                name = name or "Unknown",
                class = classFileName or (entry and entry.class),
                entry = entry,
            }
        end
    end

    table.sort(rows, function(a, b)
        local aScore = a.entry and a.entry.weighted or -1
        local bScore = b.entry and b.entry.weighted or -1

        if aScore ~= bScore then
            return aScore > bScore
        end

        return a.name < b.name
    end)

    return rows
end

function GroupFrame:CreateWindow()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "BetterGearScoreGroupWindow", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(self.WINDOW_WIDTH, self.WINDOW_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 50, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.TitleText then
        frame.TitleText:SetText("Group Gear Scores")
    end

    local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshButton:SetSize(100, 22)
    refreshButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -28)
    refreshButton:SetText("Refresh")
    refreshButton:SetScript("OnClick", function()
        BetterGearScore.GroupFrame:RequestMissingScores()
    end)

    local hintText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    hintText:SetPoint("LEFT", refreshButton, "RIGHT", 10, 0)
    hintText:SetText("|cff888888Asks group members and inspects players in range.|r")

    local scrollFrame = CreateFrame("ScrollFrame", "BetterGearScoreGroupScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", refreshButton, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetSize(self.WINDOW_WIDTH - 55, self.WINDOW_HEIGHT - 100)

    local listFrame = CreateFrame("Frame", "BetterGearScoreGroupListFrame", scrollFrame)
    listFrame:SetSize(self.WINDOW_WIDTH - 70, 1)
    scrollFrame:SetScrollChild(listFrame)

    self.frame = frame
    self.listFrame = listFrame

    self:RegisterEvents()

    return frame
end

function GroupFrame:RegisterEvents()
    if self.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

    eventFrame:SetScript("OnEvent", function()
        if BetterGearScore.GroupFrame:IsVisible() then
            BetterGearScore.GroupFrame:Update()
        end
    end)

    self.eventFrame = eventFrame
end

function GroupFrame:AcquireRow(index)
    local row = self.rows[index]

    if row then
        return row
    end

    row = CreateFrame("Button", nil, self.listFrame, "BackdropTemplate")
    row:SetSize(self.WINDOW_WIDTH - 70, self.ROW_HEIGHT - 4)
    row:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 8,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    row:SetBackdropColor(0.15, 0.15, 0.2, 0.6)

    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    nameText:SetJustifyH("LEFT")
    row.nameText = nameText

    local detailText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 3)
    detailText:SetJustifyH("LEFT")
    row.detailText = detailText

    local scoreText = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    scoreText:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.scoreText = scoreText

    self.rows[index] = row

    return row
end

function GroupFrame:GetClassColoredName(name, classFileName)
    local color = classFileName and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]

    if color then
        return string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
    end

    return name
end

function GroupFrame:SetRow(row, data)
    row.nameText:SetText(self:GetClassColoredName(data.name, data.class))

    local entry = data.entry

    if entry then
        row.scoreText:SetText(BetterGearScore.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0))

        local details = BetterGearScore.Profiles:GetProfileDisplayName(entry.profileKey)

        if BetterGearScore.Options:Get("showLegacyGearScore") and entry.legacy and entry.legacy > 0 then
            details = details .. "  |cff888888GS " .. math.floor(entry.legacy) .. "|r"
        end

        local warnings = {}

        if (entry.missingEnchants or 0) > 0 then
            warnings[#warnings + 1] = entry.missingEnchants .. " unenchanted"
        end

        if (entry.emptySockets or 0) > 0 then
            warnings[#warnings + 1] = entry.emptySockets .. " empty sockets"
        end

        if #warnings > 0 then
            details = details .. "  |cffff8800" .. table.concat(warnings, ", ") .. "|r"
        end

        if entry.source and entry.source ~= "self" then
            details = details .. "  |cff666666(" .. BetterGearScore.PlayerCache:FormatSource(entry)
                .. ", " .. BetterGearScore.PlayerCache:FormatAge(entry) .. ")|r"
        end

        row.detailText:SetText(details)
    else
        row.scoreText:SetText("|cff888888?|r")
        row.detailText:SetText("|cff888888No data - press Refresh or mouse over them.|r")
    end
end

function GroupFrame:Update()
    if not self.frame then
        self:CreateWindow()
    end

    local rows = self:CollectRows()
    local yOffset = -5

    for index, data in ipairs(rows) do
        local row = self:AcquireRow(index)

        self:SetRow(row, data)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.listFrame, "TOPLEFT", 0, yOffset)
        row:Show()

        yOffset = yOffset - self.ROW_HEIGHT
    end

    for i = #rows + 1, #self.rows do
        self.rows[i]:Hide()
    end

    self.listFrame:SetHeight(math.max(1, #rows) * self.ROW_HEIGHT + 20)
end

function GroupFrame:RequestMissingScores()
    BetterGearScore.Comms:RequestScores()

    for _, unit in ipairs(self:GetGroupUnits()) do
        if not UnitIsUnit(unit, "player")
            and not BetterGearScore.PlayerCache:GetByUnit(unit)
            and (not CanInspect or CanInspect(unit)) then
            BetterGearScore.Inspect:QueueUnitInspect(unit)
        end
    end

    self:Update()
end

function GroupFrame:OnScoreUpdated()
    if self:IsVisible() then
        self:Update()
    end
end

function GroupFrame:Show()
    self:CreateWindow()
    -- Zero-config: opening the window automatically asks the group over
    -- comms and inspects anyone in range (also updates the rows).
    self:RequestMissingScores()
    self.frame:Show()
end

function GroupFrame:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function GroupFrame:Toggle()
    if self:IsVisible() then
        self:Hide()
    else
        self:Show()
    end
end

function GroupFrame:IsVisible()
    return self.frame ~= nil and self.frame:IsShown()
end
