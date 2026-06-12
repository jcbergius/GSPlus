-- TalentDetector.lua

BetterGearScore.TalentDetector = BetterGearScore.TalentDetector or {}

local TalentDetector = BetterGearScore.TalentDetector

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

-- Classic/TBC clients return (name, texture, pointsSpent, fileName) while
-- Wrath-style clients return (id, name, description, texture, pointsSpent).
-- Detect the signature by type so role detection works on both.
function TalentDetector:GetTalentTabNameAndPoints(tabIndex, isInspect)
    if not GetTalentTabInfo then
        return nil, 0
    end

    local r1, r2, r3, r4, r5 = GetTalentTabInfo(tabIndex, isInspect)

    if type(r1) == "string" then
        return r1, tonumber(r3) or 0
    end

    return r2, tonumber(r5) or 0
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

    local Calculator = BetterGearScore.Calculator

    local dps = Calculator:CalculateTotalBetterGearScore(dpsProfile)
    local tank = Calculator:CalculateTotalBetterGearScore(tankProfile)

    local dpsRatio = 0
    local tankRatio = 0

    if dps.totalMaxBudgetScore and dps.totalMaxBudgetScore > 0 then
        dpsRatio = dps.totalWeightedScore / dps.totalMaxBudgetScore
    end

    if tank.totalMaxBudgetScore and tank.totalMaxBudgetScore > 0 then
        tankRatio = tank.totalWeightedScore / tank.totalMaxBudgetScore
    end

    -- Comparing two profiles poisons the calculator's single-entry score
    -- cache with the last explicit key; clear it so the real profile's
    -- result is recomputed cleanly.
    Calculator:InvalidateCache()

    local resolved = dpsProfile

    if tankRatio > dpsRatio * self.GEAR_ROLE_TANK_BIAS then
        resolved = tankProfile
    end

    self.roleCache[cacheKey] = resolved

    return resolved
end

function TalentDetector:ResolveFeralProfile()
    if not BetterGearScore.Options:Get("autoDetectFeralRole") then
        return "DRUID_FERAL"
    end

    return self:ResolveRoleByGear("DRUID_FERAL", "DRUID_TANK")
end

function TalentDetector:GetDetectedProfile()
    local className = BetterGearScore.Calculator:GetPlayerClass()
    local bestTreeIndex, points, totalPoints = self:GetDominantTreeIndex()
    local defaultProfile = BetterGearScore.Profiles:GetDefaultProfileForClass(className)
    local profileKey = defaultProfile

    if bestTreeIndex then
        local classProfiles = self.CLASS_TREE_PROFILES[className]
        profileKey = (classProfiles and classProfiles[bestTreeIndex]) or defaultProfile
    end

    if profileKey == "DRUID_FERAL" then
        profileKey = self:ResolveFeralProfile()
    elseif profileKey == "DEATHKNIGHT_RESOLVE" then
        profileKey = self:ResolveRoleByGear("DEATHKNIGHT_DPS", "DEATHKNIGHT_TANK")
    end

    return profileKey, points, totalPoints
end

