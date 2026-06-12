-- StatCaps.lua
-- Static weights can't capture caps: hit is the best stat in the game until
-- you reach the cap and nearly worthless after. This module reads the
-- player's current ratings and tapers the affected weights automatically,
-- with no configuration. Applied only when scoring for the player (own gear
-- and tooltip comparisons), never to other players whose totals we can't see.

BetterGearScore = BetterGearScore or {}
BetterGearScore.StatCaps = BetterGearScore.StatCaps or {}

local StatCaps = BetterGearScore.StatCaps

-- Caps against a level 73 (boss) target at level 70. The rating APIs only
-- report bonuses from gear, not talents (e.g. Precision), so these are
-- slightly conservative - gear keeps a little value near the true cap.
StatCaps.MELEE_HIT_CAP_PERCENT = 9.0
StatCaps.RANGED_HIT_CAP_PERCENT = 9.0
StatCaps.SPELL_HIT_CAP_PERCENT = 16.0
StatCaps.EXPERTISE_DODGE_CAP = 26
StatCaps.DEFENSE_CRIT_IMMUNITY_SKILL = 490

-- Taper windows: full value until (cap - window), then linear down to the
-- floor at the cap. The floor is non-zero because swapping gear around can
-- put you back under the cap.
StatCaps.HIT_TAPER_WINDOW = 1.0
StatCaps.EXPERTISE_TAPER_WINDOW = 3
StatCaps.DEFENSE_TAPER_WINDOW = 10
StatCaps.TAPER_FLOOR = 0.15

-- Combat rating indices (globals exist in-game; fall back to known values).
StatCaps.CR_HIT_MELEE_INDEX = CR_HIT_MELEE or 6
StatCaps.CR_HIT_RANGED_INDEX = CR_HIT_RANGED or 7
StatCaps.CR_HIT_SPELL_INDEX = CR_HIT_SPELL or 8
StatCaps.CR_EXPERTISE_INDEX = CR_EXPERTISE or 24

StatCaps.cache = StatCaps.cache or {}

function StatCaps:InvalidateCache()
    self.cache = {}
end

function StatCaps:GetTaperMultiplier(current, cap, window)
    if not current or not cap or cap <= 0 then
        return 1
    end

    local taperStart = cap - (window or 0)

    if current <= taperStart then
        return 1
    end

    if current >= cap then
        return self.TAPER_FLOOR
    end

    local progress = (current - taperStart) / (cap - taperStart)

    return 1 + (self.TAPER_FLOOR - 1) * progress
end

function StatCaps:GetHitCapForProfile(profileKey)
    local group = BetterGearScore.Calculator:GetProfileColorCapGroup(profileKey)

    if group == "CASTER_DPS" or group == "HEALER" then
        return self.SPELL_HIT_CAP_PERCENT, self.CR_HIT_SPELL_INDEX
    end

    if profileKey == "HUNTER_DPS" then
        return self.RANGED_HIT_CAP_PERCENT, self.CR_HIT_RANGED_INDEX
    end

    return self.MELEE_HIT_CAP_PERCENT, self.CR_HIT_MELEE_INDEX
end

function StatCaps:GetHitMultiplier(profileKey)
    if not GetCombatRatingBonus then
        return 1
    end

    local cap, ratingIndex = self:GetHitCapForProfile(profileKey)
    local currentPercent = GetCombatRatingBonus(ratingIndex)

    return self:GetTaperMultiplier(currentPercent, cap, self.HIT_TAPER_WINDOW)
end

function StatCaps:GetExpertiseMultiplier(profileKey)
    local group = BetterGearScore.Calculator:GetProfileColorCapGroup(profileKey)

    if group ~= "PHYSICAL_DPS" and group ~= "TANK" then
        return 1
    end

    local currentExpertise

    if GetExpertise then
        currentExpertise = GetExpertise()
    elseif GetCombatRatingBonus then
        currentExpertise = GetCombatRatingBonus(self.CR_EXPERTISE_INDEX)
    end

    -- Tanks benefit from expertise past the dodge cap (parry), so only DPS
    -- tapers at the dodge cap.
    if group == "TANK" then
        return 1
    end

    return self:GetTaperMultiplier(currentExpertise, self.EXPERTISE_DODGE_CAP, self.EXPERTISE_TAPER_WINDOW)
end

function StatCaps:GetDefenseMultiplier(profileKey)
    local group = BetterGearScore.Calculator:GetProfileColorCapGroup(profileKey)

    if group ~= "TANK" then
        return 1
    end

    if not UnitDefense then
        return 1
    end

    local base, modifier = UnitDefense("player")
    local defenseSkill = (base or 0) + (modifier or 0)

    -- Defense past 490 still grants avoidance, just not the crit-immunity
    -- premium, so the post-cap floor is higher than for hit.
    local multiplier = self:GetTaperMultiplier(defenseSkill, self.DEFENSE_CRIT_IMMUNITY_SKILL, self.DEFENSE_TAPER_WINDOW)

    if multiplier < 0.5 then
        return 0.5
    end

    return multiplier
end

-- Returns the multiplier applied to the role weight of statType when scoring
-- the player's own gear. 1.0 means no adjustment.
function StatCaps:GetWeightMultiplier(profileKey, statType)
    if statType ~= "HIT" and statType ~= "EXPERTISE" and statType ~= "DEFENSE" then
        return 1
    end

    local cacheKey = tostring(profileKey) .. ":" .. statType
    local cached = self.cache[cacheKey]

    if cached then
        return cached
    end

    local multiplier = 1

    if statType == "HIT" then
        multiplier = self:GetHitMultiplier(profileKey)
    elseif statType == "EXPERTISE" then
        multiplier = self:GetExpertiseMultiplier(profileKey)
    elseif statType == "DEFENSE" then
        multiplier = self:GetDefenseMultiplier(profileKey)
    end

    self.cache[cacheKey] = multiplier

    return multiplier
end

function StatCaps:IsCapped(profileKey, statType)
    return self:GetWeightMultiplier(profileKey, statType) < 1
end
