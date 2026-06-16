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

-- A freshly inspected score is shown as "..." (provisional) until a re-scan
-- confirms it has stopped climbing - item tooltips / set bonuses can resolve a
-- beat after INSPECT_READY even when the client reports the item cached, so the
-- first scan can be an undercount. Scores only ever rise as data finishes
-- loading, so once a re-scan no longer beats the best seen, the number is final
-- and revealed. The user therefore never sees a wrong FIRST number. An already-
-- confirmed number is never flickered back to "..." on a later re-inspect; it is
-- swapped in place once the new reading converges.
Inspect.VERIFY_DELAY = 0.5
Inspect.VERIFY_MAX_PASSES = 4
Inspect.VERIFY_EPSILON = 0.5
Inspect.verifyState = Inspect.verifyState or {}

Inspect.queue = Inspect.queue or {}
-- Resolved role per player GUID, captured at that unit's INSPECT_READY (when the
-- no-unit inspect talent API is current for them). Reused by the verification/
-- tooltip passes so they never re-read talents for the wrong unit, and so item
-- hovers on the inspect window stay cheap.
Inspect.roleByGuid = Inspect.roleByGuid or {}
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
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "INSPECT_READY" then
            GSPlus.Inspect:OnInspectReady(arg1)
        elseif event == "PLAYER_TARGET_CHANGED" then
            -- Targeting a player is the reliable way to inspect them: the
            -- "target" token is stable, unlike a transient "mouseover", so the
            -- inspect completes and a hover shows a real score, not "Loading...".
            GSPlus.Inspect:QueueUnitInspect("target")
        end
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

-- Reads the inspected unit's talent spec NOW and maps it to a profile. Must be
-- called while that unit's inspect data is current (right after its
-- INSPECT_READY), because the inspect talent API takes no unit argument.
-- Returns nil when the talents aren't readable.
function Inspect:ReadTalentProfile(unit)
    local _, classFileName = UnitClass(unit)
    local detector = GSPlus.TalentDetector
    local bestIndex, totalPoints, bestName = detector:GetInspectDominantTree()

    if not bestIndex or totalPoints == 0 then
        return nil
    end

    -- Map by the dominant tree's NAME (order-independent), falling back to the
    -- index only when the name isn't recognized (non-English clients).
    local classProfiles = detector.CLASS_TREE_PROFILES[classFileName]
    local profileKey = detector:ProfileForTreeName(classFileName, bestName)
        or (classProfiles and classProfiles[bestIndex])

    if profileKey and GSPlus.Weights.PROFILE_WEIGHTS[profileKey] then
        -- Role comes from the talent spec. Gear is consulted only to split feral
        -- cat (DPS) vs bear (tank), which share one talent tree.
        return self:DisambiguateUnitProfileByGear(unit, profileKey)
    end

    return nil
end

-- Role for an inspected unit. Prefers the spec captured at that unit's own
-- INSPECT_READY (Inspect.roleByGuid); otherwise reads talents fresh. The second
-- return is confidence: false means the talents weren't readable, so the caller
-- keeps the entry provisional ("...") and retries rather than guess from gear.
function Inspect:GetUnitProfile(unit)
    local guid = UnitGUID and UnitGUID(unit) or nil
    local profile, confident

    if guid and self.roleByGuid[guid] then
        profile, confident = self.roleByGuid[guid], true
    else
        local p = self:ReadTalentProfile(unit)

        if p then
            profile, confident = p, true
        else
            profile, confident = GSPlus.Profiles:GetDefaultProfileForClass(select(2, UnitClass(unit))), false
        end
    end

    -- Gear has the FINAL say on the tank axis. The inspect talent API returns
    -- the wrong/stale player under contention and nothing cross-faction, but
    -- defense rating is unit-bound, reliable, and a tank-only stat.
    return self:ApplyGearRoleOverride(unit, profile, confident)
end

-- A plate class carrying real defense rating IS tanking, whatever the talent
-- read claims; one with none is NOT, so a talent read that says "tank" with no
-- defense gear (a leaked spec) is resolved back to the real role from gear.
function Inspect:ApplyGearRoleOverride(unit, profile, confident)
    if not self:IsUnitGearComplete(unit) then
        return profile, confident
    end

    local _, classFileName = UnitClass(unit)

    if classFileName ~= "WARRIOR" and classFileName ~= "PALADIN" then
        return profile, confident
    end

    local tankKey = (classFileName == "WARRIOR") and "WARRIOR_TANK" or "PALADIN_TANK"
    local defense = GSPlus.ItemParser:GetDefenseRatingTotal(unit)

    if defense >= GSPlus.ItemParser.TANK_DEFENSE_RATING_MIN then
        return tankKey, true
    elseif profile == tankKey then
        local gearProfile = self:ResolveUnitProfileByGear(unit, classFileName)

        if gearProfile then
            return gearProfile, true
        end
    end

    return profile, confident
end

-- A shield rules out the 2H DPS specs for plate classes; drop them so a
-- shield-wearing paladin/warrior is never gear-resolved to DPS.
function Inspect:FilterProfilesByWeaponType(profileKeys, classFileName, unit)
    if classFileName ~= "PALADIN" and classFileName ~= "WARRIOR" then
        return profileKeys
    end

    if not (GSPlus.ItemParser and GSPlus.ItemParser.HasShieldEquipped
        and GSPlus.ItemParser:HasShieldEquipped(unit)) then
        return profileKeys
    end

    local filtered = {}

    for _, key in ipairs(profileKeys) do
        if GSPlus.Calculator:GetProfileColorCapGroup(key) ~= "PHYSICAL_DPS" then
            filtered[#filtered + 1] = key
        end
    end

    if #filtered > 0 then
        return filtered
    end

    return profileKeys
end

-- Best-fit profile from the equipped gear's stat budget (used to resolve the
-- non-tank role, and as the whole signal when talents are unreadable).
function Inspect:ResolveUnitProfileByGear(unit, classFileName)
    local profileKeys = self:FilterProfilesByWeaponType(
        GSPlus.TalentDetector:GetClassProfiles(classFileName), classFileName, unit)

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

    if bestTankKey
        and GSPlus.ItemParser:GetDefenseRatingTotal(unit) >= GSPlus.ItemParser.TANK_DEFENSE_RATING_MIN then
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
    local profileKey, roleConfident = self:GetUnitProfile(unit)
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
        partial = result.missingItems > 0 or not roleConfident,
        -- Inspected scores start unconfirmed; the verification pass reveals the
        -- number once it stops rising. (Self/comms entries omit this and show
        -- immediately.)
        confirmed = false,
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

    -- A timed-out inspect produced no score, so don't let the per-player cooldown
    -- (intended for SUCCESSFUL inspects) block a prompt retry on the next hover.
    if token and token.guid then
        self.lastAttempt[token.guid] = nil
    end

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
    -- CRITICAL: read the inspected unit's talents RIGHT NOW, synchronously,
    -- inside the event. The inspect talent API has no unit argument and is
    -- overwritten by the very next NotifyInspect from anyone - our own queue,
    -- the Blizzard inspect frame, or another inspect addon (TacoTip). The
    -- scoring is deferred a frame (below) to avoid competing with tooltip
    -- rendering, but by then the talent slot may already hold a DIFFERENT
    -- player. Capturing the role here, the instant the server delivered THIS
    -- guid's data, is the only point it is reliably theirs.
    if guid then
        local unit = self:FindUnitByGuid(guid)

        if unit and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local role = self:ReadTalentProfile(unit)

            if role then
                self.roleByGuid[guid] = role
            end
        end
    end

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
            -- Role was captured synchronously in OnInspectReady (above); here we
            -- only score, reusing the cached role.
            self:CommitInspectEntry(unit, guid, self:BuildUnitEntry(unit, "inspect"))
        end

        return
    end

    self.current = nil

    local unit = request.unit

    if request.guid and UnitGUID and UnitGUID(unit) ~= request.guid then
        unit = self:FindUnitByGuid(request.guid)
    end

    if unit and UnitExists(unit) and UnitIsPlayer(unit) then
        -- Role was captured synchronously in OnInspectReady; here we only score.
        self:CommitInspectEntry(unit, request.guid, self:BuildUnitEntry(unit, "inspect"))
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

-- Re-score every already-tracked player we can currently resolve, overwriting
-- their cached entry with a freshly computed one. Called after newly arrived
-- item data invalidates the stats cache, so a score captured from half-loaded
-- gear converges to the correct number on its own - no /reload. Only reads
-- inspect data already resident (no new NotifyInspect), and StoreUnitEntry's
-- no-downgrade keeps the better entry if a re-scan is still partial.
function Inspect:RescoreResolvableUnits()
    local seen = {}

    local function rescore(unit)
        if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
            return
        end

        if UnitIsUnit(unit, "player") then
            return
        end

        local guid = UnitGUID and UnitGUID(unit) or nil

        if guid then
            if seen[guid] then
                return
            end

            seen[guid] = true
        end

        -- Only refresh players we already track AND whose score isn't final
        -- yet. A confirmed score's items are already fully loaded, so re-scoring
        -- it on every item-load event is wasted work that caused hover lag.
        local existing = GSPlus.PlayerCache:GetByUnit(unit)

        if not existing or GSPlus.PlayerCache:IsScoreFinal(existing) then
            return
        end

        self:CommitInspectEntry(unit, guid, self:BuildUnitEntry(unit, "inspect"))
    end

    rescore("mouseover")
    rescore("target")
    rescore("focus")

    if InspectFrame and InspectFrame.unit then
        rescore(InspectFrame.unit)
    end

    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            rescore("raid" .. i)
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            rescore("party" .. i)
        end
    end
end

-- All inspect results funnel through here. Guarantees the user never sees an
-- undercounted FIRST number: a score with nothing trustworthy already on screen
-- is revealed as provisional "..." and then verified upward; a score we have
-- ALREADY confirmed stays on screen and is swapped in place once a re-verify
-- converges (never flickered back to "...").
function Inspect:CommitInspectEntry(unit, guid, entry)
    if not entry then
        return
    end

    if entry.partial then
        -- Missing item data: no-downgrade path shows "..." and retries.
        self:StoreUnitEntry(unit, guid, entry)
        return
    end

    local existing = GSPlus.PlayerCache:GetByUnit(unit)
    local haveConfirmed = existing and existing.confirmed and not existing.partial

    if not haveConfirmed then
        -- Nothing trustworthy on screen yet: show provisional "..." (entry
        -- carries confirmed=false) so the user sees loading, then verify upward.
        entry.confirmed = false
        self:StoreUnitEntry(unit, guid, entry)
        self:NotifyScoreUpdated(guid, UnitName(unit), entry)
    end

    self:BeginVerify(guid, entry)
end

-- Start (or restart) the convergence loop, tracking the best reading so far.
function Inspect:BeginVerify(guid, entry)
    if not guid or not entry then
        return
    end

    self.verifyState[guid] = { passes = 0, best = entry }

    if not (C_Timer and C_Timer.After) then
        -- No scheduler (older client/tests without a timer): accept as final.
        self:FinalizeVerify(guid)
        return
    end

    self:ScheduleVerify(guid)
end

function Inspect:ScheduleVerify(guid)
    if not (C_Timer and C_Timer.After) then
        return
    end

    C_Timer.After(self.VERIFY_DELAY, function()
        GSPlus.Inspect:VerifyRescore(guid)
    end)
end

-- Re-read the unit's gear from scratch (its item tooltips may have finished
-- loading since) and decide whether the score has converged.
function Inspect:VerifyRescore(guid)
    local state = self.verifyState[guid]

    if not state then
        return
    end

    local unit = self:FindUnitByGuid(guid)

    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        -- Can't re-read (gone/out of range): finalize so it isn't stuck on "...".
        self:FinalizeVerify(guid)
        return
    end

    local ItemParser = GSPlus.ItemParser

    for _, slotInfo in ipairs(ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink then
            ItemParser:InvalidateItem(itemLink)
        end
    end

    local entry = self:BuildUnitEntry(unit, "inspect")

    if not entry then
        self:FinalizeVerify(guid)
        return
    end

    if entry.partial then
        -- Gear fell out of cache mid-verify: hand to the no-downgrade path.
        self:StoreUnitEntry(unit, guid, entry)
        self.verifyState[guid] = nil
        return
    end

    state.passes = state.passes + 1

    local rising = (entry.weighted or 0) > (state.best.weighted or 0) + self.VERIFY_EPSILON

    if rising then
        state.best = entry

        -- Keep a provisional "..." entry fresh, but never overwrite an already-
        -- confirmed on-screen number while still climbing.
        local shown = GSPlus.PlayerCache:GetByUnit(unit)

        if not (shown and shown.confirmed) then
            entry.confirmed = false
            GSPlus.PlayerCache:SetForUnit(unit, entry)
        end
    end

    if not rising or state.passes >= self.VERIFY_MAX_PASSES then
        self:FinalizeVerify(guid)
        return
    end

    self:ScheduleVerify(guid)
end

-- Commit the best reading as the confirmed, displayable score.
function Inspect:FinalizeVerify(guid)
    local state = self.verifyState[guid]
    self.verifyState[guid] = nil

    if not state or not state.best then
        return
    end

    local unit = self:FindUnitByGuid(guid)

    if not unit or not UnitExists(unit) then
        return
    end

    local best = state.best
    best.confirmed = true

    GSPlus.PlayerCache:SetForUnit(unit, best)
    self:NotifyScoreUpdated(guid, UnitName(unit), best)
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
