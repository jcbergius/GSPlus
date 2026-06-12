-- StatCaps.lua
-- Static weights can't capture caps: hit is the best stat in the game until
-- you reach the cap and nearly worthless after. This module reads the
-- player's current ratings and tapers the affected weights automatically,
-- with no configuration. Applied only when scoring for the player (own gear
-- and tooltip comparisons), never to other players whose totals we can't see.

GSPlus = GSPlus or {}
GSPlus.StatCaps = GSPlus.StatCaps or {}

local StatCaps = GSPlus.StatCaps

-- Caps against a boss-level (+3) target, per client flavor. The rating APIs
-- only report bonuses from gear, not talents (e.g. Precision), so these are
-- slightly conservative - gear keeps a little value near the true cap.
-- A nil entry means the cap doesn't exist on that flavor (no taper).
-- WRATH/CATA values are the established caps from Wrath/Cata Classic:
-- 8% melee / 17% spell vs bosses, 540 defense in Wrath, defense removed and
-- crit immunity granted by talents in Cata.
StatCaps.CAPS_BY_FLAVOR = {
    VANILLA = {
        MELEE_HIT = 9.0, RANGED_HIT = 9.0, SPELL_HIT = 16.0,
        EXPERTISE_DODGE = nil, DEFENSE = 440,
    },
    TBC = {
        MELEE_HIT = 9.0, RANGED_HIT = 9.0, SPELL_HIT = 16.0,
        EXPERTISE_DODGE = 26, DEFENSE = 490,
    },
    WRATH = {
        MELEE_HIT = 8.0, RANGED_HIT = 8.0, SPELL_HIT = 17.0,
        EXPERTISE_DODGE = 26, DEFENSE = 540,
    },
    CATA = {
        MELEE_HIT = 8.0, RANGED_HIT = 8.0, SPELL_HIT = 17.0,
        EXPERTISE_DODGE = 26, DEFENSE = nil,
    },
}
StatCaps.CAPS_BY_FLAVOR.DEFAULT = StatCaps.CAPS_BY_FLAVOR.TBC

function StatCaps:GetCaps()
    return GSPlus.GameVersion:Select(self.CAPS_BY_FLAVOR) or self.CAPS_BY_FLAVOR.DEFAULT
end

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
    local group = GSPlus.Calculator:GetProfileColorCapGroup(profileKey)
    local caps = self:GetCaps()

    if group == "CASTER_DPS" or group == "HEALER" then
        return caps.SPELL_HIT, self.CR_HIT_SPELL_INDEX
    end

    if profileKey == "HUNTER_DPS" then
        return caps.RANGED_HIT, self.CR_HIT_RANGED_INDEX
    end

    return caps.MELEE_HIT, self.CR_HIT_MELEE_INDEX
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
    local expertiseCap = self:GetCaps().EXPERTISE_DODGE

    if not expertiseCap then
        return 1
    end

    local group = GSPlus.Calculator:GetProfileColorCapGroup(profileKey)

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

    return self:GetTaperMultiplier(currentExpertise, expertiseCap, self.EXPERTISE_TAPER_WINDOW)
end

function StatCaps:GetDefenseMultiplier(profileKey)
    local defenseCap = self:GetCaps().DEFENSE

    if not defenseCap then
        return 1
    end

    local group = GSPlus.Calculator:GetProfileColorCapGroup(profileKey)

    if group ~= "TANK" then
        return 1
    end

    if not UnitDefense then
        return 1
    end

    local base, modifier = UnitDefense("player")
    local defenseSkill = (base or 0) + (modifier or 0)

    -- Defense past the crit-immunity point still grants avoidance, so the
    -- post-cap floor is higher than for hit.
    local multiplier = self:GetTaperMultiplier(defenseSkill, defenseCap, self.DEFENSE_TAPER_WINDOW)

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

-- Display names of stats on this item that the player has (nearly) capped,
-- for explaining why the personal upgrade comparison discounts them.
function StatCaps:GetCappedStatNames(stats, profileKey)
    local names = {}

    for statType, value in pairs(stats or {}) do
        if value and value > 0
            and GSPlus.Weights:GetWeight(profileKey, statType) > 0
            and self:IsCapped(profileKey, statType) then
            local displayNames = GSPlus.Tooltip and GSPlus.Tooltip.STAT_DISPLAY_NAMES
            names[#names + 1] = (displayNames and displayNames[statType]) or statType
        end
    end

    table.sort(names)

    return names
end
