-- TalentDetector.lua

GSPlus.TalentDetector = GSPlus.TalentDetector or {}

local TalentDetector = GSPlus.TalentDetector

TalentDetector.CLASS_TREE_PROFILES = {
    WARRIOR = {
        [1] = "WARRIOR_DPS",  -- Arms
        [2] = "WARRIOR_DPS",  -- Fury
        [3] = "WARRIOR_TANK", -- Protection
    },

    PALADIN = {
        [1] = "PALADIN_HEALER", -- Holy
        [2] = "PALADIN_TANK",   -- Protection
        [3] = "PALADIN_DPS",    -- Retribution
    },

    HUNTER = {
        [1] = "HUNTER_DPS", -- Beast Mastery
        [2] = "HUNTER_DPS", -- Marksmanship
        [3] = "HUNTER_DPS", -- Survival
    },

    ROGUE = {
        [1] = "ROGUE_DPS", -- Assassination
        [2] = "ROGUE_DPS", -- Combat
        [3] = "ROGUE_DPS", -- Subtlety
    },

    PRIEST = {
        [1] = "PRIEST_HEALER", -- Discipline
        [2] = "PRIEST_HEALER", -- Holy
        [3] = "PRIEST_DPS",    -- Shadow
    },

    SHAMAN = {
        [1] = "SHAMAN_ELEMENTAL",   -- Elemental
        [2] = "SHAMAN_ENHANCEMENT", -- Enhancement
        [3] = "SHAMAN_HEALER",      -- Restoration
    },

    MAGE = {
        [1] = "MAGE_DPS", -- Arcane
        [2] = "MAGE_DPS", -- Fire
        [3] = "MAGE_DPS", -- Frost
    },

    WARLOCK = {
        [1] = "WARLOCK_DPS", -- Affliction
        [2] = "WARLOCK_DPS", -- Demonology
        [3] = "WARLOCK_DPS", -- Destruction
    },

    DRUID = {
        [1] = "DRUID_BALANCE", -- Balance
        [2] = "DRUID_FERAL",   -- Feral Combat
        [3] = "DRUID_RESTO",   -- Restoration
    },

    -- Wrath/Cata only; the class simply never appears on earlier clients.
    -- Blood is gear-resolved because it tanked in Cata but DPSed for most
    -- of Wrath.
    DEATHKNIGHT = {
        [1] = "DEATHKNIGHT_RESOLVE", -- Blood
        [2] = "DEATHKNIGHT_DPS",     -- Frost
        [3] = "DEATHKNIGHT_DPS",     -- Unholy
    },
}

-- English talent-tree names per class, in the standard tab order, parallel to
-- CLASS_TREE_PROFILES. The inspect talent API can return tabs in a different
-- ORDER than this (a 45/11/5 holy paladin can read its 45 Holy points at tab
-- index 3), so role resolution maps by the dominant tree's NAME, which is
-- order-independent, and only falls back to the index when the name is unknown
-- (non-English clients).
TalentDetector.CLASS_TREE_NAMES = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE = { "Assassination", "Combat", "Subtlety" },
    PRIEST = { "Discipline", "Holy", "Shadow" },
    SHAMAN = { "Elemental", "Enhancement", "Restoration" },
    MAGE = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID = { "Balance", "Feral Combat", "Restoration" },
    DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
}

-- Profile for a talent tree identified by NAME (order-independent).
function TalentDetector:ProfileForTreeName(className, treeName)
    if not treeName or treeName == "" then
        return nil
    end

    local names = self.CLASS_TREE_NAMES[className]
    local profiles = self.CLASS_TREE_PROFILES[className]

    if not names or not profiles then
        return nil
    end

    for i, n in ipairs(names) do
        if n == treeName then
            return profiles[i]
        end
    end

    return nil
end

-- GetTalentTabInfo's returns vary by client:
--   A: (name, texture, pointsSpent, fileName)            - Classic-style
--   B: (id, name, description, texture, pointsSpent)     - Wrath-style
--   C: (id, name, texture, pointsSpent)                  - seen on some builds
-- Detect by type, validate that the result is a plausible pointsSpent
-- (texture fileIDs are huge numbers and must never be mistaken for points).
TalentDetector.MAX_PLAUSIBLE_POINTS = 100

function TalentDetector:IsPlausiblePoints(value)
    return type(value) == "number"
        and value >= 0
        and value <= self.MAX_PLAUSIBLE_POINTS
        and value == math.floor(value)
end

function TalentDetector:GetTalentTabNameAndPoints(tabIndex, isInspect)
    if not GetTalentTabInfo then
        return nil, 0
    end

    local r1, r2, r3, r4, r5 = GetTalentTabInfo(tabIndex, isInspect)
    local name, points

    if type(r1) == "string" then
        name = r1
        points = tonumber(r3)
    else
        name = type(r2) == "string" and r2 or nil
        points = tonumber(r5)

        if points == nil then
            points = tonumber(r4)
        end
    end

    if not self:IsPlausiblePoints(points) then
        points = 0
    end

    return name, points
end

-- Reads the inspected unit's dominant talent tree. On TBC/Classic the inspect
-- points from GetTalentTabInfo(tab, true) are unreliable (they can echo the
-- VIEWER's own talents), so - like LibClassicInspector - we sum each tab's
-- talent ranks via GetTalentInfo(tab, talent, true). The inspect APIs take no
-- unit argument: they read the LAST inspected unit, so the caller must invoke
-- this only right after that unit's INSPECT_READY. Falls back to the tab-info
-- points when the per-talent API is unavailable (older clients / tests).
function TalentDetector:GetInspectDominantTree()
    local numTabs = (GetNumTalentTabs and GetNumTalentTabs(true)) or 3
    local haveRankApi = GetTalentInfo and GetNumTalents
    local bestIndex, bestPoints, totalPoints = nil, -1, 0

    for tabIndex = 1, numTabs do
        local tabPoints = 0

        if haveRankApi then
            local count = GetNumTalents(tabIndex, true, false) or 0

            for talentIndex = 1, count do
                local rank = select(5, GetTalentInfo(tabIndex, talentIndex, true, false, 1))
                tabPoints = tabPoints + (tonumber(rank) or 0)
            end
        else
            local _, points = self:GetTalentTabNameAndPoints(tabIndex, true)
            tabPoints = points or 0
        end

        totalPoints = totalPoints + tabPoints

        if tabPoints > bestPoints then
            bestPoints = tabPoints
            bestIndex = tabIndex
        end
    end

    if not bestIndex or totalPoints == 0 then
        return nil, 0
    end

    local bestName = (self:GetTalentTabNameAndPoints(bestIndex, true))

    return bestIndex, totalPoints, bestName
end

function TalentDetector:GetTalentPoints(isInspect)
    local points = {}

    if not GetNumTalentTabs or not GetTalentTabInfo then
        return points
    end

    local numTabs = GetNumTalentTabs(isInspect) or 0

    for tabIndex = 1, numTabs do
        local name, pointsSpent = self:GetTalentTabNameAndPoints(tabIndex, isInspect)
        points[tabIndex] = {
            name = name,
            points = pointsSpent or 0,
        }
    end

    return points
end

function TalentDetector:GetDominantTreeIndex()
    local points = self:GetTalentPoints()

    local bestIndex = nil
    local bestPoints = -1
    local totalPoints = 0

    for tabIndex, data in pairs(points) do
        totalPoints = totalPoints + (data.points or 0)

        if data.points and data.points > bestPoints then
            bestIndex = tabIndex
            bestPoints = data.points
        end
    end

    if not bestIndex or totalPoints == 0 then
        return nil, points, totalPoints
    end

    return bestIndex, points, totalPoints
end

-- Some talent trees can't distinguish DPS from tank (Feral Druid, Blood
-- Death Knight), so compare how the equipped gear performs under each
-- profile (normalized against that profile's slot caps) and pick the better
-- fit. Cached until gear changes.
TalentDetector.GEAR_ROLE_TANK_BIAS = 1.05

function TalentDetector:ResolveRoleByGear(dpsProfile, tankProfile)
    self.roleCache = self.roleCache or {}

    local cacheKey = dpsProfile .. ":" .. tankProfile

    if self.roleCache[cacheKey] then
        return self.roleCache[cacheKey]
    end

    -- Tank vs DPS is decided by whether the gear carries defense / avoidance -
    -- the stats only tanks itemize. DPS and tank gear share
    -- strength/stamina/armor, so a weighted-ratio comparison is unreliable and
    -- must not depend on how armor happens to be weighted for scoring.
    local tankStat = GSPlus.ItemParser:GetTankStatTotal("player")
    local resolved = dpsProfile

    if tankStat >= GSPlus.ItemParser.TANK_GEAR_DEFENSE_MIN then
        resolved = tankProfile
    end

    self.roleCache[cacheKey] = resolved

    return resolved
end

function TalentDetector:ResolveFeralProfile()
    if not GSPlus.Options:Get("autoDetectFeralRole") then
        return "DRUID_FERAL"
    end

    return self:ResolveRoleByGear("DRUID_FERAL", "DRUID_TANK")
end

-- All concrete profiles a class could be playing (ambiguous tree markers
-- expanded into their possible resolutions).
function TalentDetector:GetClassProfiles(className)
    local classProfiles = self.CLASS_TREE_PROFILES[className]
    local seen = {}
    local list = {}

    if not classProfiles then
        return list
    end

    for _, key in pairs(classProfiles) do
        local expanded

        if key == "DEATHKNIGHT_RESOLVE" then
            expanded = { "DEATHKNIGHT_DPS", "DEATHKNIGHT_TANK" }
        elseif key == "DRUID_FERAL" then
            expanded = { "DRUID_FERAL", "DRUID_TANK" }
        else
            expanded = { key }
        end

        for _, profileKey in ipairs(expanded) do
            if not seen[profileKey] and GSPlus.Weights.PROFILE_WEIGHTS[profileKey] then
                seen[profileKey] = true
                list[#list + 1] = profileKey
            end
        end
    end

    return list
end

-- Safety net when talents are unreadable (unknown client API signature) or
-- unspent: pick whichever of the class's profiles the equipped gear fits
-- best, instead of silently falling back to a possibly-wrong class default.
-- This is what keeps a Resto Shaman from being scored as Elemental.
function TalentDetector:ResolveProfileByGear(profileKeys, cacheKey)
    if not profileKeys or #profileKeys == 0 then
        return nil
    end

    if #profileKeys == 1 then
        return profileKeys[1]
    end

    self.roleCache = self.roleCache or {}
    cacheKey = cacheKey or table.concat(profileKeys, ":")

    if self.roleCache[cacheKey] then
        return self.roleCache[cacheKey]
    end

    local Calculator = GSPlus.Calculator
    local bestTankKey, bestTankRatio = nil, -1
    local bestNonTankKey, bestNonTankRatio = nil, -1

    for _, profileKey in ipairs(profileKeys) do
        local data = Calculator:CalculateTotalGSPlus(profileKey)
        local ratio = 0

        if data.totalMaxBudgetScore and data.totalMaxBudgetScore > 0 then
            ratio = data.totalWeightedScore / data.totalMaxBudgetScore
        end

        if Calculator:GetProfileColorCapGroup(profileKey) == "TANK" then
            if ratio > bestTankRatio then
                bestTankRatio = ratio
                bestTankKey = profileKey
            end
        elseif ratio > bestNonTankRatio then
            bestNonTankRatio = ratio
            bestNonTankKey = profileKey
        end
    end

    Calculator:InvalidateCache()

    -- Tank is decided by gear defense/avoidance in both directions (see
    -- ItemParser:GetTankStatTotal), otherwise the best non-tank fit.
    local resolved
    if bestTankKey
        and GSPlus.ItemParser:GetTankStatTotal("player") >= GSPlus.ItemParser.TANK_GEAR_DEFENSE_MIN then
        resolved = bestTankKey
    else
        resolved = bestNonTankKey or bestTankKey or profileKeys[1]
    end

    self.roleCache[cacheKey] = resolved

    return resolved
end

function TalentDetector:GetDetectedProfile()
    local className = GSPlus.Calculator:GetPlayerClass()
    local bestTreeIndex, points, totalPoints = self:GetDominantTreeIndex()
    local defaultProfile = GSPlus.Profiles:GetDefaultProfileForClass(className)
    local profileKey

    if bestTreeIndex and (totalPoints or 0) > 0 then
        local classProfiles = self.CLASS_TREE_PROFILES[className]
        profileKey = (classProfiles and classProfiles[bestTreeIndex]) or defaultProfile

        if profileKey == "DRUID_FERAL" then
            profileKey = self:ResolveFeralProfile()
        elseif profileKey == "DEATHKNIGHT_RESOLVE" then
            profileKey = self:ResolveRoleByGear("DEATHKNIGHT_DPS", "DEATHKNIGHT_TANK")
        end
    else
        -- No readable talent points: infer the role from equipped gear.
        profileKey = self:ResolveProfileByGear(
            self:GetClassProfiles(className),
            "CLASS_FALLBACK:" .. tostring(className)
        ) or defaultProfile
    end

    return profileKey, points, totalPoints
end

