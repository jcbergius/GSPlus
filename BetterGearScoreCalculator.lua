-- BetterGearScoreCalculator.lua

local Calculator = BetterGearScore.Calculator

Calculator.ITEMIZATION_MODE = "TBC"
Calculator.ITEM_BUDGET_EXPONENT = 1.7095

Calculator.SET_BONUS_COLOR_REFERENCE = {
    HEALER = 45,
    CASTER_DPS = 45,
    PHYSICAL_DPS = 45,
    TANK = 45,
    FALLBACK = 45,
}

Calculator.STAT_BUDGET_COST = {
    STRENGTH = 1.00,
    AGILITY = 1.00,
    INTELLECT = 1.00,
    SPIRIT = 1.00,

    STAMINA = 0.67,

    ARMOR = 0.07,
    ATTACKPOWER = 0.50,
    RANGED_ATTACKPOWER = 0.40,
    FERAL_ATTACKPOWER = 0.50,

    SPELLPOWER = 0.86,
    HEALING = 0.45,

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

    MP5 = 2.00,
    HP5 = 2.50,

    -- 10 health ~ 1 stamina (x0.67), 15 mana ~ 1 intellect
    HEALTH = 0.067,
    MANA = 0.067,
    SPELL_PENETRATION = 0.20,
    ARMOR_PENETRATION = 0.10,
    MASTERY = 1.00,

    ARCANE_RESISTANCE = 2.50,
    FIRE_RESISTANCE = 2.50,
    FROST_RESISTANCE = 2.50,
    NATURE_RESISTANCE = 2.50,
    SHADOW_RESISTANCE = 2.50,
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
}

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
-- scale them so score colors stay meaningful. VANILLA is calibrated against
-- level-60 epics; WRATH/CATA are first-pass estimates to revisit when those
-- clients ship.
Calculator.COLOR_REFERENCE_SCALE_BY_FLAVOR = {
    VANILLA = 0.60,
    TBC = 1.00,
    WRATH = 2.10,
    CATA = 4.20,
    DEFAULT = 1.00,
}

function Calculator:GetColorReferenceScale()
    return BetterGearScore.GameVersion:Select(self.COLOR_REFERENCE_SCALE_BY_FLAVOR) or 1.0
end

Calculator.PROFILE_COLOR_CAP_GROUP = {
    WARRIOR_DPS = "PHYSICAL_DPS",
    WARRIOR_TANK = "TANK",

    PALADIN_DPS = "PHYSICAL_DPS",
    PALADIN_TANK = "TANK",
    PALADIN_HEALER = "HEALER",

    HUNTER_DPS = "PHYSICAL_DPS",

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
    local exponent = self.ITEM_BUDGET_EXPONENT or 1.7095
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
    local roleWeight = BetterGearScore.Weights:GetWeight(profileKey, statType)

    if applyCaps and roleWeight > 0 and BetterGearScore.StatCaps then
        roleWeight = roleWeight * BetterGearScore.StatCaps:GetWeightMultiplier(profileKey, statType)
    end

    return roleWeight
end

function Calculator:CalculateWeightedStatScore(stats, profileKey, applyCaps)
    local exponent = self.ITEM_BUDGET_EXPONENT or 1.7095
    local total = 0

    for statType, value in pairs(stats or {}) do
        if self:IsScoringStat(statType) then
            local budgetValue = self:CalculateBudgetAdjustedStatValue(statType, value)
            local roleWeight = self:GetEffectiveWeight(profileKey, statType, applyCaps)
            local weightedBudgetValue = budgetValue * roleWeight

            if weightedBudgetValue > 0 then
                total = total + math.pow(weightedBudgetValue, exponent)
            end
        end
    end

    if total <= 0 then
        return 0
    end

    return math.pow(total, 1 / exponent)
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

    local dpsWeight = BetterGearScore.Weights:GetWeight(profileKey, dpsWeightKey)
    local damageWeight = BetterGearScore.Weights:GetWeight(profileKey, damageWeightKey)

    return (weaponDps * dpsWeight) + (averageDamage * damageWeight)
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
    local groupCaps = self.WEIGHTED_COLOR_CAPS[groupName] or self.WEIGHTED_COLOR_CAPS.FALLBACK
    local scale = self:GetColorReferenceScale()

    if equipLoc and groupCaps[equipLoc] then
        return groupCaps[equipLoc] * scale
    end

    if equipLoc and self.WEIGHTED_COLOR_CAPS.FALLBACK[equipLoc] then
        return self.WEIGHTED_COLOR_CAPS.FALLBACK[equipLoc] * scale
    end

    return 100 * scale
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

function Calculator:CalculateTotalBetterGearScore(profileKey)
    profileKey = profileKey or BetterGearScore.Profiles:GetSelectedProfile()

    if self.scoreCache and self.scoreCache.profileKey == profileKey then
        return self.scoreCache
    end

    local equippedItems = BetterGearScore.ItemParser:GetEquippedItems()

    local setBonusStats = {}

    if BetterGearScore.SetBonuses and BetterGearScore.SetBonuses.GetEquippedActiveSetBonusStats then
        setBonusStats = BetterGearScore.SetBonuses:GetEquippedActiveSetBonusStats()
    end

    local setBonusRawScore = self:CalculateRawStatBudget(setBonusStats)
    local setBonusWeightedScore = self:CalculateWeightedStatScore(setBonusStats, profileKey)
    local hasSetBonuses = setBonusWeightedScore and setBonusWeightedScore > 0

    local totalRawScore = 0
    local totalWeightedScore = 0
    local totalMaxBudgetScore = self:GetTotalWeightedColorReference(equippedItems, profileKey, hasSetBonuses)
    local itemScores = {}

    for slot, item in pairs(equippedItems) do
        local statBudgetScore = self:CalculateRawStatBudget(item.stats)
        local weaponBudgetScore = self:CalculateWeaponBudgetScore(item.stats)
        local rawScore = statBudgetScore + weaponBudgetScore
        local weightedScore = self:CalculateWeightedScore(item.stats, profileKey, item.slotKey, item.link)
        local maxWeightedScore = self:GetWeightedColorReferenceForItem(profileKey, item.slotKey, item.link)

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
        profileName = BetterGearScore.Profiles:GetProfileDisplayName(profileKey),
        totalRawScore = totalRawScore,
        totalWeightedScore = totalWeightedScore,
        totalMaxBudgetScore = totalMaxBudgetScore,
        itemScores = itemScores,
        setBonusStats = setBonusStats,
        setBonusRawScore = setBonusRawScore,
        setBonusWeightedScore = setBonusWeightedScore,
    }

    self.scoreCache = result

    return result
end

function Calculator:GetPlayerClass()
    local _, classFileName = UnitClass("player")

    return classFileName
end

function Calculator:GetPlayerBetterGearScore()
    local profileKey = BetterGearScore.Profiles:GetSelectedProfile()

    return self:CalculateTotalBetterGearScore(profileKey)
end