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

-- NotifyInspect on a unit just outside inspect range can throw Blizzard's red
-- "Out of range" UI error. We gate on CheckInteractDistance, but as a belt-and-
-- suspenders we also swallow that one error for a brief window after each
-- inspect attempt (never other errors, never outside the window).
function Inspect:InstallErrorFilter()
    if self.errorFilterInstalled then
        return
    end

    self.errorFilterInstalled = true

    -- CanInspect(unit) (with no/false showError) and NotifyInspect throw a red
    -- "Out of range" UI error for far units. We set skipInspectError around our
    -- own inspect calls and swallow ONLY the inspect-related errors fired while
    -- it's set - the player's own ability "out of range" errors pass through.
    if CanInspect then
        local originalCanInspect = CanInspect

        CanInspect = function(unit, showError, ...)
            local previous = GSPlus.Inspect.skipInspectError

            if showError ~= true then
                GSPlus.Inspect.skipInspectError = true
            end

            local result = originalCanInspect(unit, showError, ...)
            GSPlus.Inspect.skipInspectError = previous

            return result
        end
    end

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        local originalAddMessage = UIErrorsFrame.AddMessage

        UIErrorsFrame.AddMessage = function(frame, message, ...)
            if GSPlus.Inspect.skipInspectError and type(message) == "string"
                and (message == (ERR_OUT_OF_RANGE or "Out of range.")
                    or message == ERR_UNIT_NOT_FOUND
                    or message == ERR_INVALID_INSPECT_TARGET) then
                return
            end

            return originalAddMessage(frame, message, ...)
        end
    end
end

function Inspect:RegisterEvents()
    if self.eventFrame then
        return
    end

    self:InstallErrorFilter()

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

-- Feral druids share one talent tree for cat (DPS) and bear (tank). The
-- player's own detection resolves this from gear; inspected units must too,
-- or every bear tank reads as cat DPS. (Blood DK is gear-resolved separately
-- via the DEATHKNIGHT_RESOLVE marker, which has no weights and so falls to the
-- general gear fallback.)
function Inspect:DisambiguateUnitProfileByGear(unit, profileKey)
    if profileKey ~= "DRUID_FERAL" then
        return profileKey
    end

    if GSPlus.Options and GSPlus.Options.Get
        and not GSPlus.Options:Get("autoDetectFeralRole") then
        return profileKey
    end

    local dps = self:CalculateUnitScore(unit, "DRUID_FERAL")
    local tank = self:CalculateUnitScore(unit, "DRUID_TANK")

    local dpsRatio = 0
    local tankRatio = 0

    if dps.totalMaxScore and dps.totalMaxScore > 0 then
        dpsRatio = dps.totalWeightedScore / dps.totalMaxScore
    end

    if tank.totalMaxScore and tank.totalMaxScore > 0 then
        tankRatio = tank.totalWeightedScore / tank.totalMaxScore
    end

    local bias = (GSPlus.TalentDetector and GSPlus.TalentDetector.GEAR_ROLE_TANK_BIAS) or 1.05

    if tankRatio > dpsRatio * bias then
        return "DRUID_TANK"
    end

    return "DRUID_FERAL"
end

-- True only when every equipped item on the unit has fully loaded (no
-- incomplete scans). Role resolution and the displayed score both wait for
-- this, so nothing derived from half-loaded gear is ever shown.
function Inspect:IsUnitGearComplete(unit)
    local ItemParser = GSPlus.ItemParser
    local sawItem = false

    for _, slotInfo in ipairs(ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink then
            sawItem = true

            if ItemParser:ParseItemStats(itemLink).INCOMPLETE_SCAN then
                return false
            end
        end
    end

    return sawItem
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
            return self:DisambiguateUnitProfileByGear(unit, profileKey)
        end
    end

    -- Inspect talents unreadable: infer the role from their gear instead of
    -- defaulting (which would score e.g. a Resto Shaman as Elemental) - but
    -- ONLY when the gear has fully loaded. A role guessed from half-loaded
    -- gear is unreliable (DPS plate looks like a tank before its crit/hit/
    -- weapon load in), so while items are still arriving we return the class
    -- default and let a later, complete inspect set the real role. The entry
    -- is flagged partial meanwhile, so no number or role is shown yet.
    if self:IsUnitGearComplete(unit) then
        local gearProfile = self:ResolveUnitProfileByGear(unit, classFileName)

        if gearProfile then
            return gearProfile
        end
    end

    return GSPlus.Profiles:GetDefaultProfileForClass(classFileName)
end

function Inspect:ResolveUnitProfileByGear(unit, classFileName)
    local profileKeys = GSPlus.TalentDetector:GetClassProfiles(classFileName)

    if #profileKeys == 0 then
        return nil
    end

    if #profileKeys == 1 then
        return profileKeys[1]
    end

    local bestTankKey, bestTankRatio = nil, -1
    local bestNonTankKey, bestNonTankRatio = nil, -1

    for _, profileKey in ipairs(profileKeys) do
        local result = self:CalculateUnitScore(unit, profileKey)

        if result.itemCount > 0 and result.totalMaxScore > 0 then
            local ratio = result.totalWeightedScore / result.totalMaxScore

            if GSPlus.Calculator:GetProfileColorCapGroup(profileKey) == "TANK" then
                if ratio > bestTankRatio then
                    bestTankRatio = ratio
                    bestTankKey = profileKey
                end
            elseif ratio > bestNonTankRatio then
                bestNonTankRatio = ratio
                bestNonTankKey = profileKey
            end
        end
    end

    -- Tank is decided by whether the gear carries defense / avoidance (the
    -- stats only tanks itemize), in BOTH directions: tank gear -> the tank
    -- profile, anything else -> the best non-tank fit. DPS and tank plate
    -- share strength/stamina/armor, so a weighted ratio alone confuses them.
    if bestTankKey
        and GSPlus.ItemParser:GetTankStatTotal(unit) >= GSPlus.ItemParser.TANK_GEAR_DEFENSE_MIN then
        return bestTankKey
    end

    return bestNonTankKey or bestTankKey
end

function Inspect:CalculateUnitScore(unit, profileKey)
    local Calculator = GSPlus.Calculator
    local ItemParser = GSPlus.ItemParser
    local _, unitClass = UnitClass(unit)

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
            local rawScore = statBudgetScore + weaponBudgetScore
            local weightedScore = Calculator:CalculateWeightedScore(stats, profileKey, slotInfo.key, itemLink)

            -- Item-level fallback for items with nothing scoreable. This MUST
            -- match Calculator:CalculateTotalGSPlus exactly, or a player's
            -- comms/self score and their inspected score differ for the same
            -- gear (the "first hover vs after inspect" mismatch).
            if rawScore <= Calculator.MIN_SCOREABLE and weightedScore <= Calculator.MIN_SCOREABLE then
                local fallback = Calculator:GetItemLevelFallbackScore(itemLink, unitClass)

                if fallback > 0 then
                    rawScore = fallback
                    weightedScore = fallback
                end
            end

            totalRawScore = totalRawScore + rawScore
            totalWeightedScore = totalWeightedScore + weightedScore
            totalMaxScore = totalMaxScore + Calculator:GetWeightedColorReferenceForItem(profileKey, slotInfo.key, itemLink)
            itemCount = itemCount + 1
            emptySockets = emptySockets + (stats.EMPTY_SOCKETS or 0)

            -- INCOMPLETE_SCAN: the client hadn't sent the item's full data,
            -- so green equip effects (spell power, attack power, weapon lines)
            -- are missing and the score is an undercount. Only that counts as
            -- "missing". A fully loaded item that simply has no budget stats -
            -- a libram, totem, idol, sigil or other stat-less relic - must NOT
            -- count, or every paladin / shaman / druid / death knight would
            -- read as partial ("score may rise") forever even when fully
            -- inspected.
            if stats.INCOMPLETE_SCAN then
                missingItems = missingItems + 1
            end
        end
    end

    -- Add the inspected unit's own active set bonuses (scored once), so a
    -- tank's Kill Command armor-ignore etc. counts toward their total.
    if GSPlus.SetBonuses and GSPlus.SetBonuses.GetUnitActiveSetBonusStats then
        local setStats = GSPlus.SetBonuses:GetUnitActiveSetBonusStats(unit)
        local setWeighted = Calculator:CalculateWeightedStatScore(setStats, profileKey)

        if setWeighted > 0 then
            totalRawScore = totalRawScore + Calculator:CalculateRawStatBudget(setStats)
            totalWeightedScore = totalWeightedScore + setWeighted
            totalMaxScore = totalMaxScore + Calculator:GetSetBonusColorReference(profileKey)
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

    -- Out of inspect range: skip rather than fire NotifyInspect, which throws
    -- a red "Out of range" UI error. A later hover retries when in range.
    if not self:IsUnitInInspectRange(unit) then
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

-- Inspect range is interact-distance index 1 (~28 yds). When the API is
-- missing we assume in range (older clients).
function Inspect:IsUnitInInspectRange(unit)
    if not unit then
        return false
    end

    if CheckInteractDistance then
        return CheckInteractDistance(unit, 1) and true or false
    end

    return true
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

        if unit and (not CanInspect or CanInspect(unit))
            and self:IsUnitInInspectRange(unit) then
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

    self.skipInspectError = true
    NotifyInspect(request.unit)
    self.skipInspectError = false

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

    -- Never downgrade a complete score to a partial one. A quick re-scan of a
    -- player whose item data briefly fell out of the client cache must not
    -- replace a good total with an undercount - the root of the "mouseover
    -- shows a different number than inspect" inconsistency. The partial scan
    -- still clears the retry cooldown so a later COMPLETE scan refreshes the
    -- entry. (This mirrors TacoTip's all-or-nothing approach: only a fully
    -- loaded scan is allowed to set the displayed number.)
    if entry.partial then
        local existing = GSPlus.PlayerCache:GetByUnit(unit)

        if existing and not existing.partial then
            if guid then
                self.lastAttempt[guid] = nil
            end

            return
        end
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
