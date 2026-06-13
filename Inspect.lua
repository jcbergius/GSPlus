-- Inspect.lua
-- Throttled inspect queue that scores other players' visible gear and feeds
-- the player cache used by unit tooltips and the group window.

GSPlus = GSPlus or {}
GSPlus.Inspect = GSPlus.Inspect or {}

local Inspect = GSPlus.Inspect

Inspect.INSPECT_TIMEOUT = 2.5
Inspect.RETRY_COOLDOWN = 10
Inspect.QUEUE_STEP_DELAY = 0.3
-- The client allows only one inspect in flight and throttles NotifyInspect
-- to roughly 1.5s; fire no faster than this so requests aren't dropped.
Inspect.MIN_NOTIFY_INTERVAL = 1.5

Inspect.queue = Inspect.queue or {}
Inspect.lastAttempt = Inspect.lastAttempt or {}
Inspect.lastNotify = Inspect.lastNotify or 0

-- Background inspects must never fight the player's own inspecting. Skip
-- queueing while the Blizzard inspect window is open (its NotifyInspect and
-- ours collide and one is dropped) or while in combat (inspect is
-- unreliable then). The inspect window's own unit is still captured
-- opportunistically from Blizzard's INSPECT_READY in HandleInspectReady.
function Inspect:IsBackgroundInspectBlocked()
    if InspectFrame and InspectFrame:IsShown() then
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        return true
    end

    return false
end

function Inspect:RegisterEvents()
    if self.eventFrame then
        return
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("INSPECT_READY")

    eventFrame:SetScript("OnEvent", function(_, _, guid)
        GSPlus.Inspect:OnInspectReady(guid)
    end)

    self.eventFrame = eventFrame
end

-- Builds a cache entry for the player themselves (used by comms broadcasts
-- and the player's own tooltip line).
function Inspect:BuildPlayerEntry()
    local data = GSPlus.Calculator:GetPlayerGSPlus()
    local _, classFileName = UnitClass("player")

    return {
        weighted = data.totalWeightedScore or 0,
        max = data.totalMaxBudgetScore or 0,
        raw = data.totalRawScore or 0,
        legacy = GSPlus.LegacyGearScore:GetPlayerScore(),
        profileKey = data.profileKey,
        class = classFileName,
        source = "self",
        time = time(),
    }
end

-- Picks a profile for the inspected unit from their talents when the client
-- exposes inspect talents, otherwise falls back to their class default.
function Inspect:GetUnitProfile(unit)
    local _, classFileName = UnitClass(unit)
    local detector = GSPlus.TalentDetector

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

        if profileKey and GSPlus.Weights.PROFILE_WEIGHTS[profileKey] then
            return profileKey
        end
    end

    -- Inspect talents unreadable: infer the role from their gear instead of
    -- defaulting (which would score e.g. a Resto Shaman as Elemental).
    local gearProfile = self:ResolveUnitProfileByGear(unit, classFileName)

    return gearProfile or GSPlus.Profiles:GetDefaultProfileForClass(classFileName)
end

function Inspect:ResolveUnitProfileByGear(unit, classFileName)
    local profileKeys = GSPlus.TalentDetector:GetClassProfiles(classFileName)

    if #profileKeys == 0 then
        return nil
    end

    if #profileKeys == 1 then
        return profileKeys[1]
    end

    local bestKey = nil
    local bestRatio = -1

    for _, profileKey in ipairs(profileKeys) do
        local result = self:CalculateUnitScore(unit, profileKey)

        if result.itemCount > 0 and result.totalMaxScore > 0 then
            local ratio = result.totalWeightedScore / result.totalMaxScore

            if ratio > bestRatio then
                bestRatio = ratio
                bestKey = profileKey
            end
        end
    end

    return bestKey
end

function Inspect:CalculateUnitScore(unit, profileKey)
    local Calculator = GSPlus.Calculator
    local ItemParser = GSPlus.ItemParser

    local totalRawScore = 0
    local totalWeightedScore = 0
    local totalMaxScore = 0
    local itemCount = 0
    local missingItems = 0
    local emptySockets = 0

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
            emptySockets = emptySockets + (stats.EMPTY_SOCKETS or 0)

            -- INCOMPLETE_SCAN: server hadn't sent the item's tooltip data,
            -- so green equip effects (spell power, attack power, weapon
            -- lines) are missing and the score is an undercount.
            if stats.INCOMPLETE_SCAN or (statBudgetScore <= 0 and weaponBudgetScore <= 0) then
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
        emptySockets = emptySockets,
    }
end

function Inspect:BuildUnitEntry(unit, source)
    local profileKey = self:GetUnitProfile(unit)
    local result = self:CalculateUnitScore(unit, profileKey)

    if result.itemCount == 0 then
        return nil
    end

    local _, classFileName = UnitClass(unit)

    return {
        weighted = result.totalWeightedScore,
        max = result.totalMaxScore,
        raw = result.totalRawScore,
        legacy = GSPlus.LegacyGearScore:GetUnitScore(unit),
        profileKey = profileKey,
        class = classFileName,
        source = source or "inspect",
        time = time(),
        itemCount = result.itemCount,
        missingItems = result.missingItems,
        -- Partial entries are shown (better than nothing) but flagged so
        -- tooltips/group rows trigger a fresh inspect once data arrives.
        partial = result.missingItems > 0,
        missingEnchants = GSPlus.ItemParser:CountMissingEnchants(unit),
        emptySockets = result.emptySockets,
    }
end

-- Public entry point used by unit tooltips, the group window, and the
-- inspect pane. Always silent; results land in the player cache.
function Inspect:QueueUnitInspect(unit)
    unit = unit or "target"

    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        return false
    end

    if CanInspect and not CanInspect(unit) then
        return false
    end

    if self:IsBackgroundInspectBlocked() then
        return false
    end

    local guid = UnitGUID and UnitGUID(unit) or nil

    if guid then
        -- Per-player cooldown so tooltip spam doesn't hammer the inspect API.
        local last = self.lastAttempt[guid]

        if last and (time() - last) < self.RETRY_COOLDOWN then
            return false
        end

        for _, request in ipairs(self.queue) do
            if request.guid == guid then
                return true
            end
        end

        if self.current and self.current.guid == guid then
            return true
        end
    end

    self:RegisterEvents()

    self.queue[#self.queue + 1] = {
        unit = unit,
        guid = guid,
        name = UnitName(unit),
    }

    self:ProcessQueue()

    return true
end

-- Schedules a single deferred ProcessQueue. Guarded so repeated callers
-- (rapid hovers, several queued units while blocked/throttled) can't stack
-- overlapping retry timers.
function Inspect:ScheduleDrain(delay)
    if self.drainScheduled then
        return
    end

    if not (C_Timer and C_Timer.After) then
        return
    end

    self.drainScheduled = true

    C_Timer.After(delay, function()
        GSPlus.Inspect.drainScheduled = false
        GSPlus.Inspect:ProcessQueue()
    end)
end

function Inspect:ProcessQueue()
    if self.current then
        return
    end

    if #self.queue == 0 then
        return
    end

    -- Gate before consuming the queue so a blocked/throttled state doesn't
    -- churn the head in and out; defer with a single guarded timer instead.
    if self:IsBackgroundInspectBlocked() then
        self:ScheduleDrain(1.0)
        return
    end

    local sinceLast = time() - (self.lastNotify or 0)

    if sinceLast < self.MIN_NOTIFY_INTERVAL then
        self:ScheduleDrain(self.MIN_NOTIFY_INTERVAL - sinceLast)
        return
    end

    local request = table.remove(self.queue, 1)

    -- Unit tokens can change meaning (target switched, raid roster moved);
    -- only proceed if the token still points at the same player. Skip
    -- invalid/uninspectable requests and move to the next without recursing.
    while request do
        if request.guid and UnitGUID and UnitGUID(request.unit) ~= request.guid then
            request.unit = self:FindUnitByGuid(request.guid)
        end

        local unit = request.unit

        if unit and (not CanInspect or CanInspect(unit)) then
            break
        end

        request = table.remove(self.queue, 1)
    end

    if not request then
        return
    end

    self.current = request
    self.lastNotify = time()

    if request.guid then
        self.lastAttempt[request.guid] = time()
    end

    NotifyInspect(request.unit)

    if C_Timer and C_Timer.After then
        local token = request

        C_Timer.After(self.INSPECT_TIMEOUT, function()
            GSPlus.Inspect:OnInspectTimeout(token)
        end)
    end
end

function Inspect:OnInspectTimeout(token)
    if self.current ~= token then
        return
    end

    self.current = nil
    self:ProcessQueue()
end

function Inspect:FindUnitByGuid(guid)
    if not guid or not UnitGUID then
        return nil
    end

    local candidates = { "mouseover", "target", "focus" }

    -- The Blizzard inspect window may target a unit we aren't otherwise
    -- pointing at (inspected via dropdown); include it so we can capture
    -- the data its NotifyInspect produced.
    if InspectFrame and InspectFrame.unit then
        candidates[#candidates + 1] = InspectFrame.unit
    end

    for _, unit in ipairs(candidates) do
        if UnitExists(unit) and UnitGUID(unit) == guid then
            return unit
        end
    end

    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            local unit = "raid" .. i

            if UnitExists(unit) and UnitGUID(unit) == guid then
                return unit
            end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i

            if UnitExists(unit) and UnitGUID(unit) == guid then
                return unit
            end
        end
    end

    return nil
end

-- Defer the actual scoring one frame: scoring scans many item tooltips
-- synchronously, and doing it inside the INSPECT_READY event competes with
-- the Blizzard inspect UI and any open tooltips rendering this frame.
function Inspect:OnInspectReady(guid)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            GSPlus.Inspect:HandleInspectReady(guid)
        end)
    else
        self:HandleInspectReady(guid)
    end
end

-- Stores the unit's entry and, when items weren't fully loaded yet,
-- clears the retry cooldown so the next hover/refresh re-inspects.
function Inspect:StoreUnitEntry(unit, guid, entry)
    if not entry then
        return
    end

    GSPlus.PlayerCache:SetForUnit(unit, entry)

    if entry.partial and guid then
        self.lastAttempt[guid] = nil
    end

    self:NotifyScoreUpdated(guid, UnitName(unit), entry)
end

function Inspect:HandleInspectReady(guid)
    local request = self.current

    if not request or (guid and request.guid and guid ~= request.guid) then
        -- Inspect initiated elsewhere (Blizzard frame, another addon):
        -- opportunistically cache the data if we can resolve the unit.
        local unit = self:FindUnitByGuid(guid)

        if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            self:StoreUnitEntry(unit, guid, self:BuildUnitEntry(unit, "inspect"))
        end

        return
    end

    self.current = nil

    local unit = request.unit

    if request.guid and UnitGUID and UnitGUID(unit) ~= request.guid then
        unit = self:FindUnitByGuid(request.guid)
    end

    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        self:StoreUnitEntry(unit, request.guid, self:BuildUnitEntry(unit, "inspect"))
    end

    -- Intentionally NOT calling ClearInspectPlayer(): it corrupts the
    -- Blizzard inspect UI and collides with other inspect addons. Leaving
    -- the data resident is harmless and far more reliable.

    if C_Timer and C_Timer.After then
        C_Timer.After(self.QUEUE_STEP_DELAY, function()
            GSPlus.Inspect:ProcessQueue()
        end)
    else
        self:ProcessQueue()
    end
end

function Inspect:NotifyScoreUpdated(guid, name, entry)
    if GSPlus.UnitTooltip and GSPlus.UnitTooltip.OnScoreUpdated then
        GSPlus.UnitTooltip:OnScoreUpdated(guid, name, entry)
    end

    if GSPlus.GroupFrame and GSPlus.GroupFrame.OnScoreUpdated then
        GSPlus.GroupFrame:OnScoreUpdated(guid, name, entry)
    end

    if GSPlus.InspectPaneUI and GSPlus.InspectPaneUI.OnScoreUpdated then
        GSPlus.InspectPaneUI:OnScoreUpdated(guid, name, entry)
    end
end
