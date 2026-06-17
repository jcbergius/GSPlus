-- GSPlusCalculator.lua

local Calculator = GSPlus.Calculator

Calculator.ITEMIZATION_MODE = "TBC"
-- Blizzard's itemization combines stat costs non-linearly: the documented rule
-- is Budget^1.5 = SUM( (StatValue * StatMod)^1.5 ), i.e. the 3/2 power (see the
-- Hyzenthlei/BlizzCon stat-budget table; STAT_BUDGET_ANALYSIS.md). We match that
-- 3/2 exponent so the raw Budget Score mirrors true itemization rather than
-- over-rewarding stat concentration. (The displayed gs+ is a separate LINEAR
-- sum - see CalculateWeightedStatScore - so this only shapes the Budget Score.)
Calculator.ITEM_BUDGET_EXPONENT = 1.5

-- Weapon DPS is the dominant source of a melee/hunter's power but, unlike every
-- other stat, was scored at face value (1 DPS = 1 point) with a role weight
-- capped at 1.0 - under-crediting the weapon for specs built around it (a
-- hunter's bow most of all). This StatMod scales raw weapon DPS up to a
-- stat-equivalent magnitude, exactly as STAT_BUDGET_COST does for other stats.
Calculator.WEAPON_DPS_BUDGET_COST = 2.0

-- Headroom applied to every color reference so RED means true best-in-slot,
-- not merely "as good as a representative endgame piece". The reference items
-- (ReferenceGear.lua / the static fallback caps) approximate strong raid gear
-- that solid raiders already match; without this, good-but-not-BiS gear
-- saturates at red. Raising the bar by this factor reserves red for fully
-- gemmed/enchanted Sunwell-tier BiS. It scales all references uniformly, so
-- gear-based role detection (which compares ratios across profiles) is
-- unaffected. Tunable - validate the exact value in-game.
Calculator.COLOR_REFERENCE_HEADROOM = 1.66

-- Weighted scores at or below this are treated as "nothing we can value", so
-- the item falls back to an item-level estimate (e.g. a relic whose only
-- effect is a spell-specific bonus).
Calculator.MIN_SCOREABLE = 1

-- Cross-role calibration target. Each profile's score is scaled so that a full
-- reference build (the same per-slot reference items the color references use)
-- totals this number. Equally-geared characters of any spec therefore land on
-- the same gs+, so the number is a fair shared currency across roles. The scale
-- multiplies BOTH the weighted score and its color reference, so item colors and
-- the gear-based role-detection ratios are unchanged - only the number is
-- calibrated. Chosen near the pre-calibration cross-role average so existing
-- numbers barely move.
Calculator.CALIBRATION_TARGET = 1700

-- Canonical full-build slots used to measure a profile's reference total (must
-- match the role-balance test in tests/harness.lua so the band collapses to ~0).
Calculator.CALIBRATION_SLOTS = {
    { "HeadSlot", "INVTYPE_HEAD" }, { "NeckSlot", "INVTYPE_NECK" },
    { "ShoulderSlot", "INVTYPE_SHOULDER" }, { "BackSlot", "INVTYPE_CLOAK" },
    { "ChestSlot", "INVTYPE_CHEST" }, { "WristSlot", "INVTYPE_WRIST" },
    { "HandsSlot", "INVTYPE_HAND" }, { "WaistSlot", "INVTYPE_WAIST" },
    { "LegsSlot", "INVTYPE_LEGS" }, { "FeetSlot", "INVTYPE_FEET" },
    { "Finger0Slot", "INVTYPE_FINGER" }, { "Finger1Slot", "INVTYPE_FINGER" },
    { "Trinket0Slot", "INVTYPE_TRINKET" }, { "Trinket1Slot", "INVTYPE_TRINKET" },
    { "MainHandSlot", "INVTYPE_WEAPONMAINHAND" }, { "SecondaryHandSlot", "INVTYPE_SHIELD" },
    { "RangedSlot", "INVTYPE_RELIC" },
}

Calculator.SET_BONUS_COLOR_REFERENCE = {
    HEALER = 45,
    CASTER_DPS = 45,
    PHYSICAL_DPS = 45,
    RANGED = 45,
    TANK = 45,
    FALLBACK = 45,
}

-- Per-point budget cost of each stat (its "StatMod"), normalized so a primary
-- stat = 1.0. These are the documented WoW itemization values (the Hyzenthlei
-- cost table Blizzard confirmed at BlizzCon); see STAT_BUDGET_ANALYSIS.md for the
-- per-stat sourcing. A stat's contribution = StatValue * StatMod * role weight,
-- so these double as the universal stat->budget normalization that the role
-- weights (StatWeights.lua) are tuned against.
Calculator.STAT_BUDGET_COST = {
    STRENGTH = 1.00,
    AGILITY = 1.00,
    INTELLECT = 1.00,
    SPIRIT = 1.00,

    -- Stamina was repriced to 2/3 in TBC (was 1.0 in vanilla).
    STAMINA = 0.67,

    -- Bonus armor: 0.10 in TBC, 1/14 ~ 0.071 from patch 3.2; 0.07 splits the two.
    ARMOR = 0.07,
    ATTACKPOWER = 0.50,
    RANGED_ATTACKPOWER = 0.40,
    FERAL_ATTACKPOWER = 0.50,

    SPELLPOWER = 0.86,
    -- Single-school spell damage costs 0.70, less than all-school 0.86.
    SCHOOL_SPELLPOWER = 0.70,
    HEALING = 0.45,

    -- All combat ratings cost 1.0 per point.
    DEFENSE = 1.00,
    DODGE = 1.00,
    PARRY = 1.00,
    BLOCK = 1.00,
    BLOCK_VALUE = 0.65,
    CRITICAL = 1.00,
    HIT = 1.00,
    HASTE = 1.00,
    EXPERTISE = 1.00,
    RESILIENCE = 1.00,
    WEAPON_SKILL = 1.00,
    MASTERY = 1.00,
    -- Armor penetration RATING is a combat rating (1.0). Flat "ignore N armor"
    -- (TBC) is priced like bonus armor (see ARMOR_PENETRATION below).
    ARMOR_PENETRATION_RATING = 1.00,

    -- MP5 is the most expensive common stat at 2.5; HP5 is priced alongside it.
    MP5 = 2.50,
    HP5 = 2.50,

    -- 10 health ~ 1 stamina (x0.67), 15 mana ~ 1 intellect
    HEALTH = 0.067,
    MANA = 0.067,
    -- Magic/spell penetration ~ 0.9 per point.
    SPELL_PENETRATION = 0.90,
    -- Flat armor-ignore (TBC), priced like bonus armor; the RATING is above.
    ARMOR_PENETRATION = 0.10,

    -- A single resistance school costs 1.0 per point (only the all-schools
    -- bundle is 2.5; this addon adds an "all resistances" value to each school,
    -- so each school is priced individually at the single-school rate).
    ARCANE_RESISTANCE = 1.00,
    FIRE_RESISTANCE = 1.00,
    FROST_RESISTANCE = 1.00,
    NATURE_RESISTANCE = 1.00,
    SHADOW_RESISTANCE = 1.00,
}

Calculator.WEAPON_STAT_KEYS = {
    WEAPON_MIN_DAMAGE = true,
    WEAPON_MAX_DAMAGE = true,
    WEAPON_AVERAGE_DAMAGE = true,
    WEAPON_SPEED = true,
    WEAPON_DPS = true,
}

-- Bookkeeping markers stored alongside stats; they must never contribute to
-- budget or weighted scores.
Calculator.NON_SCORING_STAT_KEYS = {
    UNSCORED_USE_EFFECT = true,
    UNSCORED_EQUIP_EFFECT = true,
    UNSCORED_SET_BONUS_EFFECT = true,
    EMPTY_SOCKETS = true,
    INCOMPLETE_SCAN = true,
}

-- Per-slot, per-role weighted score references used ONLY for coloring
-- (never for the score itself). The intent: an item's color reflects how
-- close it is to the best realistically obtainable item for that slot at
-- the expansion's endgame - so red ~= Sunwell-tier BiS in TBC.
-- Color scale (see GetScoreColorHex): 0% white -> 25% green -> 50% blue
-- -> 75% purple -> 90% orange -> 100% red of the slot reference.
Calculator.WEIGHTED_COLOR_CAPS = {
    HEALER = {
        INVTYPE_HEAD = 105,
        INVTYPE_NECK = 58,
        INVTYPE_SHOULDER = 85,
        INVTYPE_CHEST = 95,
        INVTYPE_ROBE = 95,
        INVTYPE_WAIST = 82,
        INVTYPE_LEGS = 105,
        INVTYPE_FEET = 82,
        INVTYPE_WRIST = 65,
        INVTYPE_HAND = 82,
        INVTYPE_FINGER = 54,
        INVTYPE_TRINKET = 85,
        INVTYPE_CLOAK = 62,

        INVTYPE_WEAPON = 300,
        INVTYPE_WEAPONMAINHAND = 300,
        INVTYPE_WEAPONOFFHAND = 100,
        INVTYPE_2HWEAPON = 360,
        INVTYPE_HOLDABLE = 110,
        INVTYPE_SHIELD = 110,
        INVTYPE_RELIC = 45,
    },

    CASTER_DPS = {
        INVTYPE_HEAD = 105,
        INVTYPE_NECK = 62,
        INVTYPE_SHOULDER = 85,
        INVTYPE_CHEST = 100,
        INVTYPE_ROBE = 100,
        INVTYPE_WAIST = 82,
        INVTYPE_LEGS = 105,
        INVTYPE_FEET = 82,
        INVTYPE_WRIST = 65,
        INVTYPE_HAND = 82,
        INVTYPE_FINGER = 65,
        INVTYPE_TRINKET = 90,
        INVTYPE_CLOAK = 65,

        INVTYPE_WEAPON = 280,
        INVTYPE_WEAPONMAINHAND = 280,
        INVTYPE_WEAPONOFFHAND = 110,
        INVTYPE_2HWEAPON = 360,
        INVTYPE_HOLDABLE = 110,
        INVTYPE_SHIELD = 110,
        INVTYPE_RELIC = 45,
        INVTYPE_RANGED = 45,
        INVTYPE_RANGEDRIGHT = 45,
    },

    PHYSICAL_DPS = {
        INVTYPE_HEAD = 110,
        INVTYPE_NECK = 68,
        INVTYPE_SHOULDER = 90,
        INVTYPE_CHEST = 115,
        INVTYPE_ROBE = 115,
        INVTYPE_WAIST = 90,
        INVTYPE_LEGS = 115,
        INVTYPE_FEET = 90,
        INVTYPE_WRIST = 68,
        INVTYPE_HAND = 90,
        INVTYPE_FINGER = 68,
        INVTYPE_TRINKET = 100,
        INVTYPE_CLOAK = 68,

        INVTYPE_WEAPON = 210,
        INVTYPE_WEAPONMAINHAND = 210,
        INVTYPE_WEAPONOFFHAND = 170,
        INVTYPE_2HWEAPON = 320,
        INVTYPE_RANGED = 210,
        INVTYPE_RANGEDRIGHT = 210,
        INVTYPE_THROWN = 95,
        INVTYPE_RELIC = 45,
    },

    TANK = {
        INVTYPE_HEAD = 120,
        INVTYPE_NECK = 75,
        INVTYPE_SHOULDER = 100,
        INVTYPE_CHEST = 130,
        INVTYPE_ROBE = 130,
        INVTYPE_WAIST = 100,
        INVTYPE_LEGS = 130,
        INVTYPE_FEET = 100,
        INVTYPE_WRIST = 75,
        INVTYPE_HAND = 100,
        INVTYPE_FINGER = 75,
        INVTYPE_TRINKET = 110,
        INVTYPE_CLOAK = 75,

        INVTYPE_WEAPON = 130,
        INVTYPE_WEAPONMAINHAND = 130,
        INVTYPE_WEAPONOFFHAND = 100,
        INVTYPE_SHIELD = 140,
        INVTYPE_2HWEAPON = 200,
        INVTYPE_RANGED = 75,
        INVTYPE_RANGEDRIGHT = 75,
        INVTYPE_THROWN = 75,
        INVTYPE_RELIC = 45,
    },

    FALLBACK = {
        INVTYPE_HEAD = 105,
        INVTYPE_NECK = 60,
        INVTYPE_SHOULDER = 85,
        INVTYPE_CHEST = 100,
        INVTYPE_ROBE = 100,
        INVTYPE_WAIST = 82,
        INVTYPE_LEGS = 105,
        INVTYPE_FEET = 82,
        INVTYPE_WRIST = 65,
        INVTYPE_HAND = 82,
        INVTYPE_FINGER = 60,
        INVTYPE_TRINKET = 85,
        INVTYPE_CLOAK = 62,

        INVTYPE_WEAPON = 220,
        INVTYPE_WEAPONMAINHAND = 220,
        INVTYPE_WEAPONOFFHAND = 150,
        INVTYPE_2HWEAPON = 320,
        INVTYPE_HOLDABLE = 110,
        INVTYPE_SHIELD = 120,
        INVTYPE_RELIC = 45,
        INVTYPE_RANGED = 120,
        INVTYPE_RANGEDRIGHT = 120,
        INVTYPE_THROWN = 75,
    },
}

-- The slot caps above are tuned for TBC endgame item budgets. Other flavors
-- scale them so score colors stay meaningful. Scales are derived from the
-- epic item budget curve ((ilvl - 91.45) / 0.65 above ilvl 120, the same
-- curve the wrath-era GearScore formula encodes) at each expansion's
-- endgame, relative to TBC's ~ilvl 150 (budget ~90):
--   VANILLA ~ilvl 90: (90-26)/1.2 = 53   -> 53/90  = 0.60
--   WRATH  ~ilvl 264: (264-91.45)/0.65 = 265 -> 265/90 = 2.95
--   CATA   ~ilvl 410: (410-91.45)/0.65 = 490 -> 490/90 = 5.45
Calculator.COLOR_REFERENCE_SCALE_BY_FLAVOR = {
    VANILLA = 0.60,
    TBC = 1.00,
    WRATH = 2.95,
    CATA = 5.45,
    DEFAULT = 1.00,
}

function Calculator:GetColorReferenceScale()
    return GSPlus.GameVersion:Select(self.COLOR_REFERENCE_SCALE_BY_FLAVOR) or 1.0
end

Calculator.PROFILE_COLOR_CAP_GROUP = {
    WARRIOR_DPS = "PHYSICAL_DPS",
    WARRIOR_TANK = "TANK",

    PALADIN_DPS = "PHYSICAL_DPS",
    PALADIN_TANK = "TANK",
    PALADIN_HEALER = "HEALER",

    HUNTER_DPS = "RANGED",

    ROGUE_DPS = "PHYSICAL_DPS",

    PRIEST_HEALER = "HEALER",
    PRIEST_DPS = "CASTER_DPS",

    SHAMAN_ELEMENTAL = "CASTER_DPS",
    SHAMAN_ENHANCEMENT = "PHYSICAL_DPS",
    SHAMAN_HEALER = "HEALER",

    MAGE_DPS = "CASTER_DPS",

    WARLOCK_DPS = "CASTER_DPS",

    DRUID_FERAL = "PHYSICAL_DPS",
    DRUID_TANK = "TANK",
    DRUID_BALANCE = "CASTER_DPS",
    DRUID_RESTO = "HEALER",

    DEATHKNIGHT_DPS = "PHYSICAL_DPS",
    DEATHKNIGHT_TANK = "TANK",
}

function Calculator:IsWeaponStat(statType)
    return self.WEAPON_STAT_KEYS[statType] == true
end

function Calculator:IsScoringStat(statType)
    return not self.WEAPON_STAT_KEYS[statType] and not self.NON_SCORING_STAT_KEYS[statType]
end

function Calculator:GetStatBudgetCost(statType)
    return self.STAT_BUDGET_COST[statType] or 1.0
end

function Calculator:CalculateBudgetAdjustedStatValue(statType, value)
    return (value or 0) * self:GetStatBudgetCost(statType)
end

function Calculator:CalculateRawStatBudget(stats)
    local exponent = self.ITEM_BUDGET_EXPONENT or 1.5
    local total = 0

    for statType, value in pairs(stats or {}) do
        if self:IsScoringStat(statType) then
            local budgetValue = self:CalculateBudgetAdjustedStatValue(statType, value)

            if budgetValue > 0 then
                total = total + math.pow(budgetValue, exponent)
            end
        end
    end

    if total <= 0 then
        return 0
    end

    return math.pow(total, 1 / exponent)
end

-- Role weight, optionally adjusted for the player's own stat caps (hit,
-- expertise, defense).
--
-- IMPORTANT: gear scores are a shared currency - the same gear must produce
-- the same number for everyone, so NO displayed or broadcast score may use
-- cap adjustments. applyCaps exists solely for the personal "vs Equipped"
-- upgrade comparison, which is advice for this player, not a score.
function Calculator:GetEffectiveWeight(profileKey, statType, applyCaps)
    local roleWeight = GSPlus.Weights:GetWeight(profileKey, statType)

    if applyCaps and roleWeight > 0 and GSPlus.StatCaps then
        roleWeight = roleWeight * GSPlus.StatCaps:GetWeightMultiplier(profileKey, statType)
    end

    -- Per-profile cross-role calibration. Skipped while measuring the reference
    -- build itself (computingReferenceScale), which would otherwise recurse.
    if roleWeight ~= 0 and not self.computingReferenceScale then
        roleWeight = roleWeight * self:GetProfileScoreScale(profileKey)
    end

    return roleWeight
end

-- Weighted score of a full reference build for a profile, computed with UNSCALED
-- weights (the guard stops GetEffectiveWeight/CalculateWeaponScore recursing back
-- through GetProfileScoreScale). Cached; cleared with the reference cache.
function Calculator:GetReferenceBuildScore(profileKey)
    self.refBuildCache = self.refBuildCache or {}

    if self.refBuildCache[profileKey] ~= nil then
        return self.refBuildCache[profileKey]
    end

    local total = 0

    if GSPlus.ReferenceGear and GSPlus.ReferenceGear.GetStats then
        local group = self:GetProfileColorCapGroup(profileKey)
        local wasComputing = self.computingReferenceScale
        self.computingReferenceScale = true

        for _, slot in ipairs(self.CALIBRATION_SLOTS) do
            local refStats = GSPlus.ReferenceGear:GetStats(group, slot[2])

            if refStats then
                local w = self:CalculateWeightedStatScore(refStats, profileKey)

                if refStats.WEAPON_DPS and refStats.WEAPON_DPS > 0 then
                    w = w + self:CalculateWeaponScore(refStats, profileKey, slot[1], nil)
                end

                total = total + w
            end
        end

        self.computingReferenceScale = wasComputing
    end

    self.refBuildCache[profileKey] = total

    return total
end

-- Per-profile multiplier mapping the reference build to CALIBRATION_TARGET.
-- 1.0 when the flavor has no reference data yet (no calibration applied).
function Calculator:GetProfileScoreScale(profileKey)
    self.scoreScaleCache = self.scoreScaleCache or {}

    local cached = self.scoreScaleCache[profileKey]
    if cached ~= nil then
        return cached
    end

    local refTotal = self:GetReferenceBuildScore(profileKey)
    local scale = 1.0

    if refTotal and refTotal > 0 then
        scale = self.CALIBRATION_TARGET / refTotal
    end

    self.scoreScaleCache[profileKey] = scale

    return scale
end

-- The weighted score is a LINEAR sum: stat value contributes to throughput
-- roughly independently per point, so concentration must not be rewarded.
-- The budget exponent belongs only to the budget score, where it models
-- Blizzard's itemization cost curve (concentrated stats cost more budget).
function Calculator:CalculateWeightedStatScore(stats, profileKey, applyCaps)
    local total = 0

    for statType, value in pairs(stats or {}) do
        if self:IsScoringStat(statType) then
            local budgetValue = self:CalculateBudgetAdjustedStatValue(statType, value)
            local roleWeight = self:GetEffectiveWeight(profileKey, statType, applyCaps)
            local weightedBudgetValue = budgetValue * roleWeight

            if weightedBudgetValue > 0 then
                total = total + weightedBudgetValue
            end
        end
    end

    return total
end

function Calculator:GetWeaponWeightKeys(slotKey, itemLink)
    if slotKey == "RangedSlot" then
        return "RANGED_WEAPON_DPS", "RANGED_WEAPON_DAMAGE"
    end

    if slotKey == "MainHandSlot" or slotKey == "SecondaryHandSlot" then
        return "MELEE_WEAPON_DPS", "MELEE_WEAPON_DAMAGE"
    end

    local equipLoc = nil

    if itemLink then
        equipLoc = select(9, GetItemInfo(itemLink))
    end

    if equipLoc == "INVTYPE_RANGED"
        or equipLoc == "INVTYPE_RANGEDRIGHT"
        or equipLoc == "INVTYPE_THROWN"
        or equipLoc == "INVTYPE_RELIC" then
        return "RANGED_WEAPON_DPS", "RANGED_WEAPON_DAMAGE"
    end

    return "MELEE_WEAPON_DPS", "MELEE_WEAPON_DAMAGE"
end

function Calculator:CalculateWeaponBudgetScore(stats)
    local weaponDps = stats and stats.WEAPON_DPS or 0
    local averageDamage = stats and stats.WEAPON_AVERAGE_DAMAGE or 0

    if not weaponDps or weaponDps <= 0 then
        return 0
    end

    return weaponDps + ((averageDamage or 0) * 0.15)
end

function Calculator:CalculateWeaponScore(stats, profileKey, slotKey, itemLink)
    if not stats then
        return 0
    end

    local weaponDps = stats.WEAPON_DPS or 0
    local averageDamage = stats.WEAPON_AVERAGE_DAMAGE or 0

    if weaponDps <= 0 then
        return 0
    end

    local dpsWeightKey, damageWeightKey = self:GetWeaponWeightKeys(slotKey, itemLink)

    local dpsWeight = self:GetEffectiveWeight(profileKey, dpsWeightKey, false)
    local damageWeight = self:GetEffectiveWeight(profileKey, damageWeightKey, false)

    return (weaponDps * self.WEAPON_DPS_BUDGET_COST * dpsWeight) + (averageDamage * damageWeight)
end

function Calculator:CalculateWeightedScore(stats, profileKey, slotKey, itemLink, applyCaps)
    local weightedStatScore = self:CalculateWeightedStatScore(stats, profileKey, applyCaps)
    local weaponScore = self:CalculateWeaponScore(stats, profileKey, slotKey, itemLink)

    return weightedStatScore + weaponScore
end

function Calculator:GetProfileColorCapGroup(profileKey)
    return self.PROFILE_COLOR_CAP_GROUP[profileKey] or "FALLBACK"
end

function Calculator:GetEquipLoc(itemLink)
    if not itemLink then
        return nil
    end

    return select(9, GetItemInfo(itemLink))
end

function Calculator:GetFallbackEquipLocFromSlot(slotKey)
    if slotKey == "HeadSlot" then
        return "INVTYPE_HEAD"
    elseif slotKey == "NeckSlot" then
        return "INVTYPE_NECK"
    elseif slotKey == "ShoulderSlot" then
        return "INVTYPE_SHOULDER"
    elseif slotKey == "BackSlot" then
        return "INVTYPE_CLOAK"
    elseif slotKey == "ChestSlot" then
        return "INVTYPE_CHEST"
    elseif slotKey == "WristSlot" then
        return "INVTYPE_WRIST"
    elseif slotKey == "HandsSlot" then
        return "INVTYPE_HAND"
    elseif slotKey == "WaistSlot" then
        return "INVTYPE_WAIST"
    elseif slotKey == "LegsSlot" then
        return "INVTYPE_LEGS"
    elseif slotKey == "FeetSlot" then
        return "INVTYPE_FEET"
    elseif slotKey == "Finger0Slot" or slotKey == "Finger1Slot" then
        return "INVTYPE_FINGER"
    elseif slotKey == "Trinket0Slot" or slotKey == "Trinket1Slot" then
        return "INVTYPE_TRINKET"
    elseif slotKey == "MainHandSlot" then
        return "INVTYPE_WEAPONMAINHAND"
    elseif slotKey == "SecondaryHandSlot" then
        return "INVTYPE_WEAPONOFFHAND"
    elseif slotKey == "RangedSlot" then
        return "INVTYPE_RANGED"
    end

    return nil
end

function Calculator:GetWeightedColorReferenceForItem(profileKey, slotKey, itemLink)
    local equipLoc = self:GetEquipLoc(itemLink) or self:GetFallbackEquipLocFromSlot(slotKey)
    local groupName = self:GetProfileColorCapGroup(profileKey)

    -- Preferred path: derive the reference by scoring an actual endgame
    -- reference item (ReferenceGear.lua) under THIS profile's own weights,
    -- through the same pipeline as real items. Red then means "scores like
    -- endgame BiS" by construction and can never drift from the weights.
    if equipLoc and GSPlus.ReferenceGear and GSPlus.ReferenceGear.GetStats then
        local refStats = GSPlus.ReferenceGear:GetStats(groupName, equipLoc)

        if refStats then
            self.referenceCache = self.referenceCache or {}

            local cacheKey = tostring(profileKey) .. ":" .. equipLoc .. ":" .. tostring(slotKey or "auto")
            local cached = self.referenceCache[cacheKey]

            if cached then
                return cached
            end

            local reference = self:CalculateWeightedScore(refStats, profileKey, slotKey, itemLink)
                * self.COLOR_REFERENCE_HEADROOM

            if reference > 0 then
                self.referenceCache[cacheKey] = reference
                return reference
            end
        end
    end

    -- Fallback for flavors without reference gear data yet: static caps
    -- scaled by the flavor's item budget growth.
    local groupCaps = self.WEIGHTED_COLOR_CAPS[groupName] or self.WEIGHTED_COLOR_CAPS.FALLBACK
    local scale = self:GetColorReferenceScale()

    if equipLoc and groupCaps[equipLoc] then
        return groupCaps[equipLoc] * scale * self.COLOR_REFERENCE_HEADROOM
    end

    if equipLoc and self.WEIGHTED_COLOR_CAPS.FALLBACK[equipLoc] then
        return self.WEIGHTED_COLOR_CAPS.FALLBACK[equipLoc] * scale * self.COLOR_REFERENCE_HEADROOM
    end

    return 100 * scale * self.COLOR_REFERENCE_HEADROOM
end

function Calculator:GetSetBonusColorReference(profileKey)
    local groupName = self:GetProfileColorCapGroup(profileKey)
    local reference = self.SET_BONUS_COLOR_REFERENCE[groupName] or self.SET_BONUS_COLOR_REFERENCE.FALLBACK or 45

    return reference * self:GetColorReferenceScale()
end

function Calculator:GetScoreRatio(score, maxScore)
    score = tonumber(score) or 0
    maxScore = tonumber(maxScore) or 0

    if maxScore <= 0 then
        return 0
    end

    local ratio = score / maxScore

    if ratio < 0 then
        return 0
    end

    if ratio > 1 then
        return 1
    end

    return ratio
end

function Calculator:GetScoreColorHex(score, maxScore)
    local ratio = self:GetScoreRatio(score, maxScore)

    local colorStops = {
        { ratio = 0.00, r = 255, g = 255, b = 255 },
        { ratio = 0.25, r = 30,  g = 255, b = 0   },
        { ratio = 0.50, r = 0,   g = 112, b = 255 },
        { ratio = 0.75, r = 163, g = 53,  b = 238 },
        { ratio = 0.90, r = 255, g = 128, b = 0   },
        { ratio = 1.00, r = 255, g = 0,   b = 0   },
    }

    local lower = colorStops[1]
    local upper = colorStops[#colorStops]

    for i = 1, #colorStops - 1 do
        if ratio >= colorStops[i].ratio and ratio <= colorStops[i + 1].ratio then
            lower = colorStops[i]
            upper = colorStops[i + 1]
            break
        end
    end

    local range = upper.ratio - lower.ratio
    local t = 0

    if range > 0 then
        t = (ratio - lower.ratio) / range
    end

    local red = math.floor(lower.r + ((upper.r - lower.r) * t) + 0.5)
    local green = math.floor(lower.g + ((upper.g - lower.g) * t) + 0.5)
    local blue = math.floor(lower.b + ((upper.b - lower.b) * t) + 0.5)

    return string.format("ff%02x%02x%02x", red, green, blue)
end

function Calculator:ColorizeScore(score, maxScore)
    local color = self:GetScoreColorHex(score, maxScore)

    return "|c" .. color .. math.floor(score or 0) .. "|r"
end

function Calculator:GetTotalWeightedColorReference(equippedItems, profileKey, hasSetBonuses)
    local total = 0

    for _, item in pairs(equippedItems or {}) do
        total = total + self:GetWeightedColorReferenceForItem(profileKey, item.slotKey, item.link)
    end

    if hasSetBonuses then
        total = total + self:GetSetBonusColorReference(profileKey)
    end

    return total
end

-- The total score is cached until equipment or talents change (see Core.lua)
-- so frequent callers like the character pane tooltip stay cheap.
function Calculator:InvalidateCache()
    self.scoreCache = nil
end

-- The per-slot/per-role color references are derived from fixed reference
-- gear and the runtime-constant weight tables, so they never go stale when
-- the player's own gear or talents change - only the score cache does. They
-- are kept across refreshes (a meaningful saving for hybrid specs that score
-- the gear under two profiles to resolve their role on every refresh) and
-- cleared only when the client flavor changes, which is the one thing that
-- can rescale a reference (GameVersion:Detect calls this).
function Calculator:InvalidateReferenceCache()
    self.referenceCache = nil
    -- The calibration scale derives from the (flavor-specific) reference gear,
    -- so it is rebuilt whenever the references are.
    self.refBuildCache = nil
    self.scoreScaleCache = nil
end

-- Some items carry no stats we can value (a relic with only a spell-specific
-- bonus, a pure-utility piece). Rather than score them as zero, estimate from
-- item level using the legacy GearScore value, which is ilvl/rarity based and
-- on a scale comparable to the weighted score.
function Calculator:GetItemLevelFallbackScore(itemLink, classFileName)
    if not itemLink or not GSPlus.LegacyGearScore then
        return 0
    end

    classFileName = classFileName or self:GetPlayerClass()

    return GSPlus.LegacyGearScore:GetItemScore(itemLink, classFileName) or 0
end

function Calculator:CalculateTotalGSPlus(profileKey)
    profileKey = profileKey or GSPlus.Profiles:GetSelectedProfile()

    if self.scoreCache and self.scoreCache.profileKey == profileKey then
        return self.scoreCache
    end

    local equippedItems = GSPlus.ItemParser:GetEquippedItems()
    local playerClass = self:GetPlayerClass()

    local setBonusStats = {}

    if GSPlus.SetBonuses and GSPlus.SetBonuses.GetEquippedActiveSetBonusStats then
        setBonusStats = GSPlus.SetBonuses:GetEquippedActiveSetBonusStats()
    end

    local setBonusRawScore = self:CalculateRawStatBudget(setBonusStats)
    local setBonusWeightedScore = self:CalculateWeightedStatScore(setBonusStats, profileKey)
    local hasSetBonuses = setBonusWeightedScore and setBonusWeightedScore > 0

    local totalRawScore = 0
    local totalWeightedScore = 0
    local totalMaxBudgetScore = self:GetTotalWeightedColorReference(equippedItems, profileKey, hasSetBonuses)
    local itemScores = {}

    -- Any equipped item whose server data had not fully loaded yet (a login-time
    -- scan, or a piece that briefly fell out of the client cache) makes the total
    -- an undercount. Track it so the result can be flagged and, crucially, NOT
    -- cached - otherwise a partial total computed during login freezes in the
    -- score cache and only a /reload clears it (the "wrong gs+ on login" bug).
    local incompleteScan = false

    for slot, item in pairs(equippedItems) do
        if item.stats and item.stats.INCOMPLETE_SCAN then
            incompleteScan = true
        end

        local statBudgetScore = self:CalculateRawStatBudget(item.stats)
        local weaponBudgetScore = self:CalculateWeaponBudgetScore(item.stats)
        local rawScore = statBudgetScore + weaponBudgetScore
        local weightedScore = self:CalculateWeightedScore(item.stats, profileKey, item.slotKey, item.link)
        local maxWeightedScore = self:GetWeightedColorReferenceForItem(profileKey, item.slotKey, item.link)

        -- Nothing scoreable on this item: fall back to an item-level estimate.
        if rawScore <= self.MIN_SCOREABLE and weightedScore <= self.MIN_SCOREABLE then
            local fallback = self:GetItemLevelFallbackScore(item.link, playerClass)

            if fallback > 0 then
                weightedScore = fallback
                rawScore = fallback
            end
        end

        totalRawScore = totalRawScore + rawScore
        totalWeightedScore = totalWeightedScore + weightedScore

        itemScores[slot] = {
            rawScore = rawScore,
            weightedScore = weightedScore,
            maxBudgetScore = maxWeightedScore,
            statBudgetScore = statBudgetScore,
            weaponBudgetScore = weaponBudgetScore,
            stats = item.stats,
            link = item.link,
            slotName = item.slotName,
            slotKey = item.slotKey,
        }
    end

    if hasSetBonuses then
        totalRawScore = totalRawScore + setBonusRawScore
        totalWeightedScore = totalWeightedScore + setBonusWeightedScore

        itemScores["SET_BONUSES"] = {
            rawScore = setBonusRawScore,
            weightedScore = setBonusWeightedScore,
            maxBudgetScore = self:GetSetBonusColorReference(profileKey),
            statBudgetScore = setBonusRawScore,
            weaponBudgetScore = 0,
            stats = setBonusStats,
            link = nil,
            slotName = "Active Set Bonuses",
            slotKey = "SetBonus",
        }
    end

    local result = {
        profileKey = profileKey,
        profileName = GSPlus.Profiles:GetProfileDisplayName(profileKey),
        totalRawScore = totalRawScore,
        totalWeightedScore = totalWeightedScore,
        totalMaxBudgetScore = totalMaxBudgetScore,
        itemScores = itemScores,
        setBonusStats = setBonusStats,
        setBonusRawScore = setBonusRawScore,
        setBonusWeightedScore = setBonusWeightedScore,
        -- True when at least one item was scored from half-loaded data. Callers
        -- (the login convergence pass, the pane) use it to keep retrying.
        incomplete = incompleteScan or nil,
    }

    -- Never cache an undercount built from gear that has not finished loading;
    -- the next call recomputes against the complete data instead of returning a
    -- frozen wrong score. A complete total caches as before.
    if not incompleteScan then
        self.scoreCache = result
    end

    return result
end

function Calculator:GetPlayerClass()
    local _, classFileName = UnitClass("player")

    return classFileName
end

function Calculator:GetPlayerGSPlus()
    local profileKey = GSPlus.Profiles:GetSelectedProfile()

    return self:CalculateTotalGSPlus(profileKey)
end