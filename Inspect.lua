-- Inspect.lua
-- Scores another player's visible gear via the inspect API (/bgs target).

BetterGearScore = BetterGearScore or {}
BetterGearScore.Inspect = BetterGearScore.Inspect or {}

local Inspect = BetterGearScore.Inspect

function Inspect:RegisterEvents()
    if self.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSPECT_READY")

    eventFrame:SetScript("OnEvent", function(_, _, guid)
        BetterGearScore.Inspect:OnInspectReady(guid)
    end)

    self.eventFrame = eventFrame
end

function Inspect:RequestInspect(unit)
    unit = unit or "target"

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        print("|cffff0000BetterGearScore:|r Target a player to inspect their gear score.")
        return
    end

    if UnitIsUnit(unit, "player") then
        BetterGearScore.Commands:PrintScore()
        return
    end

    if CanInspect and not CanInspect(unit) then
        print("|cffff0000BetterGearScore:|r That player cannot be inspected right now (out of range?).")
        return
    end

    self:RegisterEvents()

    self.pendingUnit = unit
    self.pendingGUID = UnitGUID and UnitGUID(unit) or nil

    NotifyInspect(unit)
end

function Inspect:OnInspectReady(guid)
    if not self.pendingUnit then
        return
    end

    if guid and self.pendingGUID and guid ~= self.pendingGUID then
        return
    end

    local unit = self.pendingUnit

    self.pendingUnit = nil
    self.pendingGUID = nil

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        return
    end

    self:PrintUnitScore(unit)

    -- Only release inspect data if the Blizzard inspect window isn't using it.
    if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then
        ClearInspectPlayer()
    end
end

-- Picks a profile for the inspected unit from their talents when the client
-- exposes inspect talents, otherwise falls back to their class default.
function Inspect:GetUnitProfile(unit)
    local _, classFileName = UnitClass(unit)
    local detector = BetterGearScore.TalentDetector

    local bestIndex = nil
    local bestPoints = -1
    local totalPoints = 0

    if GetNumTalentTabs and GetTalentTabInfo then
        local numTabs = GetNumTalentTabs(true) or 0

        for tabIndex = 1, numTabs do
            local _, points = detector:GetTalentTabNameAndPoints(tabIndex, true)

            totalPoints = totalPoints + (points or 0)

            if points and points > bestPoints then
                bestIndex = tabIndex
                bestPoints = points
            end
        end
    end

    if bestIndex and totalPoints > 0 then
        local classProfiles = detector.CLASS_TREE_PROFILES[classFileName]
        local profileKey = classProfiles and classProfiles[bestIndex]

        if profileKey and BetterGearScore.Weights.PROFILE_WEIGHTS[profileKey] then
            return profileKey
        end
    end

    return BetterGearScore.Profiles:GetDefaultProfileForClass(classFileName)
end

function Inspect:CalculateUnitScore(unit, profileKey)
    local Calculator = BetterGearScore.Calculator
    local ItemParser = BetterGearScore.ItemParser

    local totalRawScore = 0
    local totalWeightedScore = 0
    local totalMaxScore = 0
    local itemCount = 0
    local missingItems = 0

    for _, slotInfo in ipairs(ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink then
            local stats = ItemParser:ParseItemStats(itemLink)
            local statBudgetScore = Calculator:CalculateRawStatBudget(stats)
            local weaponBudgetScore = Calculator:CalculateWeaponBudgetScore(stats)
            local weightedScore = Calculator:CalculateWeightedScore(stats, profileKey, slotInfo.key, itemLink)

            totalRawScore = totalRawScore + statBudgetScore + weaponBudgetScore
            totalWeightedScore = totalWeightedScore + weightedScore
            totalMaxScore = totalMaxScore + Calculator:GetWeightedColorReferenceForItem(profileKey, slotInfo.key, itemLink)
            itemCount = itemCount + 1

            if statBudgetScore <= 0 and weaponBudgetScore <= 0 then
                missingItems = missingItems + 1
            end
        end
    end

    return {
        totalRawScore = totalRawScore,
        totalWeightedScore = totalWeightedScore,
        totalMaxScore = totalMaxScore,
        itemCount = itemCount,
        missingItems = missingItems,
    }
end

function Inspect:PrintUnitScore(unit)
    local profileKey = self:GetUnitProfile(unit)
    local result = self:CalculateUnitScore(unit, profileKey)
    local unitName = UnitName(unit) or "Unknown"

    if result.itemCount == 0 then
        print("|cffff0000BetterGearScore:|r No inspectable items found on " .. unitName .. ". Try again in range.")
        return
    end

    local coloredScore = BetterGearScore.Calculator:ColorizeScore(result.totalWeightedScore, result.totalMaxScore)

    print("|cff00ff00BetterGearScore for|r " .. unitName
        .. " |cff888888(" .. BetterGearScore.Profiles:GetProfileDisplayName(profileKey) .. ")|r")
    print("Weighted Score: " .. coloredScore
        .. "  |cff888888|||r  Budget Score: " .. math.floor(result.totalRawScore)
        .. "  |cff888888|||r  Items: " .. result.itemCount)

    if result.missingItems > 0 then
        print("|cff888888" .. result.missingItems .. " item(s) had no cached data yet; score may rise on a second inspect.|r")
    end
end
