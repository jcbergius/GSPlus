-- LegacyGearScore.lua
-- Approximates the classic GearScore number (item level + rarity based) so
-- players used to "the" GearScore can read GSPlus output without
-- mental translation.

GSPlus = GSPlus or {}
GSPlus.LegacyGearScore = GSPlus.LegacyGearScore or {}

local LegacyGearScore = GSPlus.LegacyGearScore

LegacyGearScore.SCALE_FACTOR = 1.8618

LegacyGearScore.SLOT_MODIFIERS = {
    INVTYPE_HEAD = 1.0000,
    INVTYPE_NECK = 0.5625,
    INVTYPE_SHOULDER = 0.7500,
    INVTYPE_CHEST = 1.0000,
    INVTYPE_ROBE = 1.0000,
    INVTYPE_WAIST = 0.7500,
    INVTYPE_LEGS = 1.0000,
    INVTYPE_FEET = 0.7500,
    INVTYPE_WRIST = 0.5625,
    INVTYPE_HAND = 0.7500,
    INVTYPE_FINGER = 0.5625,
    INVTYPE_TRINKET = 0.5625,
    INVTYPE_CLOAK = 0.5625,

    INVTYPE_WEAPON = 1.0000,
    INVTYPE_SHIELD = 1.0000,
    INVTYPE_2HWEAPON = 2.0000,
    INVTYPE_WEAPONMAINHAND = 1.0000,
    INVTYPE_WEAPONOFFHAND = 1.0000,
    INVTYPE_HOLDABLE = 1.0000,

    INVTYPE_RANGED = 0.3164,
    INVTYPE_RANGEDRIGHT = 0.3164,
    INVTYPE_THROWN = 0.3164,
    INVTYPE_RELIC = 0.3164,

    INVTYPE_BODY = 0,
    INVTYPE_TABARD = 0,
}

-- Hunters value their ranged weapon as the primary weapon and melee weapons
-- as stat sticks, matching the original GearScore behaviour.
LegacyGearScore.HUNTER_RANGED_SLOTS = {
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
    INVTYPE_THROWN = true,
}

LegacyGearScore.HUNTER_MELEE_SLOTS = {
    INVTYPE_WEAPON = true,
    INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_2HWEAPON = true,
}

LegacyGearScore.HUNTER_RANGED_SCALE = 5.3224
LegacyGearScore.HUNTER_MELEE_SCALE = 0.3164

-- Quality coefficients from the original GearScore formula.
LegacyGearScore.HIGH_LEVEL_FORMULA = {
    [4] = { A = 91.4500, B = 0.6500 },
    [3] = { A = 81.3750, B = 0.8125 },
    [2] = { A = 73.0000, B = 1.0000 },
}

LegacyGearScore.LOW_LEVEL_FORMULA = {
    [4] = { A = 26.0000, B = 1.2000 },
    [3] = { A = 0.7500, B = 1.8000 },
    [2] = { A = 8.0000, B = 2.0000 },
    [1] = { A = 0.0000, B = 2.2500 },
    [0] = { A = 0.0000, B = 2.2500 },
}

function LegacyGearScore:GetItemScore(itemLink, classFileName)
    if not itemLink then
        return 0
    end

    local _, _, rarity, itemLevel, _, _, _, _, equipLoc = GetItemInfo(itemLink)

    if not itemLevel or not equipLoc then
        return 0
    end

    local slotModifier = self.SLOT_MODIFIERS[equipLoc]

    if not slotModifier or slotModifier <= 0 then
        return 0
    end

    rarity = tonumber(rarity) or 0

    -- Legendaries and artifacts are scored as epics, as the original did.
    if rarity > 4 then
        rarity = 4
    end

    local formula

    if itemLevel > 120 then
        formula = self.HIGH_LEVEL_FORMULA[rarity]
    else
        formula = self.LOW_LEVEL_FORMULA[rarity]
    end

    if not formula then
        return 0
    end

    local classScale = 1

    if classFileName == "HUNTER" then
        if self.HUNTER_RANGED_SLOTS[equipLoc] then
            classScale = self.HUNTER_RANGED_SCALE
        elseif self.HUNTER_MELEE_SLOTS[equipLoc] then
            classScale = self.HUNTER_MELEE_SCALE
        end
    end

    local score = math.floor(((itemLevel - formula.A) / formula.B) * slotModifier * self.SCALE_FACTOR * classScale)

    if score < 0 then
        return 0
    end

    return score
end

function LegacyGearScore:GetUnitScore(unit)
    unit = unit or "player"

    local _, classFileName = UnitClass(unit)
    local total = 0

    for _, slotInfo in ipairs(GSPlus.ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink then
            total = total + self:GetItemScore(itemLink, classFileName)
        end
    end

    return total
end

function LegacyGearScore:GetPlayerScore()
    return self:GetUnitScore("player")
end
