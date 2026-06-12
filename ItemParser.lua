-- ItemParser.lua

BetterGearScore = BetterGearScore or {}
BetterGearScore.ItemParser = BetterGearScore.ItemParser or {}

local ItemParser = BetterGearScore.ItemParser

ItemParser.SPELL_SPECIFIC_EFFECT_SCALE = 0.35

-- Effects that only apply against one creature type (e.g. "+81 Attack Power
-- when fighting Undead") count at a fraction of their face value.
ItemParser.CONDITIONAL_EFFECT_SCALE = 0.25

-- "Allows X% of your Mana regeneration to continue while casting": rough
-- MP5 equivalent per percent for a typical caster's spirit regen.
ItemParser.REGEN_WHILE_CASTING_MP5_PER_PERCENT = 0.5

-- Rating-per-1% conversions for vanilla-style percent effects, per client
-- flavor. Vanilla has no ratings at all, so percents are stored as TBC-scale
-- pseudo-ratings to keep the weight tables uniform across flavors.
-- WRATH (level 80) and CATA (level 85) values are the documented combat
-- rating system conversions, as confirmed throughout Wrath/Cata Classic.
-- (CATA BLOCK is retained only for old-world items; block rating itself was
-- removed in patch 4.0.1.)
ItemParser.RATING_PER_PERCENT_BY_FLAVOR = {
    VANILLA = {
        HIT = 15.77, SPELL_HIT = 12.62, CRIT = 22.08, SPELL_CRIT = 22.08,
        DODGE = 18.94, PARRY = 23.65, BLOCK = 7.88, HASTE = 15.77,
    },
    TBC = {
        HIT = 15.77, SPELL_HIT = 12.62, CRIT = 22.08, SPELL_CRIT = 22.08,
        DODGE = 18.94, PARRY = 23.65, BLOCK = 7.88, HASTE = 15.77,
    },
    -- PARRY is the post-3.2 value (the 3.0 cost of 49.18 was reduced by 8%);
    -- Wrath Classic ran on the final 3.4 rules.
    WRATH = {
        HIT = 32.79, SPELL_HIT = 26.23, CRIT = 45.91, SPELL_CRIT = 45.91,
        DODGE = 39.35, PARRY = 45.25, BLOCK = 16.39, HASTE = 32.79,
    },
    CATA = {
        HIT = 120.11, SPELL_HIT = 102.45, CRIT = 179.28, SPELL_CRIT = 179.28,
        DODGE = 176.72, PARRY = 176.72, BLOCK = 88.36, HASTE = 128.06,
    },
}
ItemParser.RATING_PER_PERCENT_BY_FLAVOR.DEFAULT = ItemParser.RATING_PER_PERCENT_BY_FLAVOR.TBC

function ItemParser:GetRatingPerPercent(ratingKey)
    local ratings = BetterGearScore.GameVersion:Select(self.RATING_PER_PERCENT_BY_FLAVOR)

    return (ratings and ratings[ratingKey]) or 15.77
end

ItemParser.SPELL_SCHOOLS = {
    Arcane = true,
    Fire = true,
    Frost = true,
    Holy = true,
    Nature = true,
    Shadow = true,
}

ItemParser.RESISTANCE_SCHOOLS = {
    Arcane = "ARCANE_RESISTANCE",
    Fire = "FIRE_RESISTANCE",
    Frost = "FROST_RESISTANCE",
    Nature = "NATURE_RESISTANCE",
    Shadow = "SHADOW_RESISTANCE",
}

-- Vanilla-style percent effects. Order matters: "with spells" variants
-- before their generic counterparts.
ItemParser.PERCENT_EFFECT_PATTERNS = {
    { pattern = "Improves your chance to hit with spells by (%d+%.?%d*)%%", stat = "HIT", ratingKey = "SPELL_HIT" },
    { pattern = "Improves your chance to hit by (%d+%.?%d*)%%", stat = "HIT", ratingKey = "HIT" },
    { pattern = "Improves your chance to get a critical strike with spells by (%d+%.?%d*)%%", stat = "CRITICAL", ratingKey = "SPELL_CRIT" },
    { pattern = "Improves your chance to get a critical strike by (%d+%.?%d*)%%", stat = "CRITICAL", ratingKey = "CRIT" },
    { pattern = "Increases your chance to dodge an attack by (%d+%.?%d*)%%", stat = "DODGE", ratingKey = "DODGE" },
    { pattern = "Increases your chance to parry an attack by (%d+%.?%d*)%%", stat = "PARRY", ratingKey = "PARRY" },
    { pattern = "Increases your chance to block attacks with a shield by (%d+%.?%d*)%%", stat = "BLOCK", ratingKey = "BLOCK" },
    { pattern = "Increases your attack speed by (%d+%.?%d*)%%", stat = "HASTE", ratingKey = "HASTE" },
    { pattern = "Increases your casting speed by (%d+%.?%d*)%%", stat = "HASTE", ratingKey = "HASTE" },
}

ItemParser.EQUIPMENT_SLOTS = {
    { key = "HeadSlot",          name = "Head" },
    { key = "NeckSlot",          name = "Neck" },
    { key = "ShoulderSlot",      name = "Shoulder" },
    { key = "BackSlot",          name = "Back" },
    { key = "ChestSlot",         name = "Chest" },
    { key = "WristSlot",         name = "Wrist" },
    { key = "HandsSlot",         name = "Hands" },
    { key = "WaistSlot",         name = "Waist" },
    { key = "LegsSlot",          name = "Legs" },
    { key = "FeetSlot",          name = "Feet" },
    { key = "Finger0Slot",       name = "Finger 1" },
    { key = "Finger1Slot",       name = "Finger 2" },
    { key = "Trinket0Slot",      name = "Trinket 1" },
    { key = "Trinket1Slot",      name = "Trinket 2" },
    { key = "MainHandSlot",      name = "Main Hand" },
    { key = "SecondaryHandSlot", name = "Off Hand" },
    { key = "RangedSlot",        name = "Ranged" },
}

ItemParser.STAT_MAPPING = {
    ITEM_MOD_STRENGTH_SHORT = "STRENGTH",
    ITEM_MOD_AGILITY_SHORT = "AGILITY",
    ITEM_MOD_INTELLECT_SHORT = "INTELLECT",
    ITEM_MOD_STAMINA_SHORT = "STAMINA",
    ITEM_MOD_SPIRIT_SHORT = "SPIRIT",

    ITEM_MOD_ARMOR = "ARMOR",
    ITEM_MOD_EXTRA_ARMOR_SHORT = "ARMOR",
    ITEM_MOD_ATTACK_POWER_SHORT = "ATTACKPOWER",
    ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "RANGED_ATTACKPOWER",

    ITEM_MOD_SPELL_POWER_SHORT = "SPELLPOWER",
    ITEM_MOD_HEALING_DONE_SHORT = "HEALING",

    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "DEFENSE",
    ITEM_MOD_DODGE_RATING_SHORT = "DODGE",
    ITEM_MOD_PARRY_RATING_SHORT = "PARRY",
    ITEM_MOD_BLOCK_RATING_SHORT = "BLOCK",
    ITEM_MOD_BLOCK_VALUE_SHORT = "BLOCK_VALUE",
    ITEM_MOD_CRIT_RATING_SHORT = "CRITICAL",
    ITEM_MOD_SPELL_CRIT_RATING_SHORT = "CRITICAL",
    ITEM_MOD_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_SPELL_HIT_RATING_SHORT = "HIT",
    ITEM_MOD_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_SPELL_HASTE_RATING_SHORT = "HASTE",
    ITEM_MOD_EXPERTISE_RATING_SHORT = "EXPERTISE",
    ITEM_MOD_RESILIENCE_RATING_SHORT = "RESILIENCE",

    ITEM_MOD_MANA_REGENERATION_SHORT = "MP5",
    ITEM_MOD_MP5_SHORT = "MP5",
    ITEM_MOD_HEALTH_REGEN_SHORT = "HP5",

    -- Wrath/Cata stats; harmless on earlier clients where they never appear.
    ITEM_MOD_MASTERY_RATING_SHORT = "MASTERY",
    ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "ARMOR_PENETRATION",
    ITEM_MOD_SPELL_PENETRATION_SHORT = "SPELL_PENETRATION",
}

ItemParser.TEXT_STAT_MAPPING = {
    ["Strength"] = "STRENGTH",
    ["Agility"] = "AGILITY",
    ["Intellect"] = "INTELLECT",
    ["Stamina"] = "STAMINA",
    ["Spirit"] = "SPIRIT",
    ["Armor"] = "ARMOR",

    ["Attack Power"] = "ATTACKPOWER",
    ["Ranged Attack Power"] = "RANGED_ATTACKPOWER",

    ["Healing"] = "HEALING",
    ["Spell Healing"] = "HEALING",
    ["Healing Spells"] = "HEALING",
    ["Healing Done"] = "HEALING",

    ["Spell Damage"] = "SPELLPOWER",
    ["Spell Power"] = "SPELLPOWER",
    ["Damage Spells"] = "SPELLPOWER",
    ["Spell Damage and Healing"] = "SPELLPOWER",

    ["Defense Rating"] = "DEFENSE",
    ["Defense"] = "DEFENSE",
    ["Dodge Rating"] = "DODGE",
    ["Parry Rating"] = "PARRY",
    ["Block Rating"] = "BLOCK",
    ["Shield Block Rating"] = "BLOCK",
    ["Block Value"] = "BLOCK_VALUE",
    ["Shield Block Value"] = "BLOCK_VALUE",
    ["Resilience Rating"] = "RESILIENCE",

    ["Critical Strike Rating"] = "CRITICAL",
    ["Crit Rating"] = "CRITICAL",
    ["Spell Critical Strike Rating"] = "CRITICAL",
    ["Spell Crit Rating"] = "CRITICAL",

    ["Hit Rating"] = "HIT",
    ["Spell Hit Rating"] = "HIT",
    ["Haste Rating"] = "HASTE",
    ["Spell Haste Rating"] = "HASTE",
    ["Melee Haste Rating"] = "HASTE",
    ["Expertise Rating"] = "EXPERTISE",

    ["Health"] = "HEALTH",
    ["health"] = "HEALTH",
    ["Mana"] = "MANA",
    ["mana"] = "MANA",
    ["Spell Penetration"] = "SPELL_PENETRATION",
    ["Armor Penetration"] = "ARMOR_PENETRATION",
    ["Armor Penetration Rating"] = "ARMOR_PENETRATION",
    ["Mastery Rating"] = "MASTERY",

    ["Mana per 5 sec"] = "MP5",
    ["mana per 5 sec"] = "MP5",
    ["Mana every 5 seconds"] = "MP5",
    ["mana every 5 seconds"] = "MP5",
    ["MP5"] = "MP5",

    ["Health per 5 sec"] = "HP5",
    ["health per 5 sec"] = "HP5",
    ["Health every 5 seconds"] = "HP5",
    ["health every 5 seconds"] = "HP5",
    ["HP5"] = "HP5",

    ["Arcane Resistance"] = "ARCANE_RESISTANCE",
    ["Fire Resistance"] = "FIRE_RESISTANCE",
    ["Frost Resistance"] = "FROST_RESISTANCE",
    ["Nature Resistance"] = "NATURE_RESISTANCE",
    ["Shadow Resistance"] = "SHADOW_RESISTANCE",
    ["All Resistances"] = "ALL_RESISTANCE",
    ["Resistance"] = "ALL_RESISTANCE",
}

ItemParser.WEAPON_SKILL_MAPPING = {
    ["Axe"] = "WEAPON_SKILL",
    ["Axes"] = "WEAPON_SKILL",
    ["Bow"] = "WEAPON_SKILL",
    ["Bows"] = "WEAPON_SKILL",
    ["Crossbow"] = "WEAPON_SKILL",
    ["Crossbows"] = "WEAPON_SKILL",
    ["Dagger"] = "WEAPON_SKILL",
    ["Daggers"] = "WEAPON_SKILL",
    ["Fist Weapon"] = "WEAPON_SKILL",
    ["Fist Weapons"] = "WEAPON_SKILL",
    ["Gun"] = "WEAPON_SKILL",
    ["Guns"] = "WEAPON_SKILL",
    ["Mace"] = "WEAPON_SKILL",
    ["Maces"] = "WEAPON_SKILL",
    ["Polearm"] = "WEAPON_SKILL",
    ["Polearms"] = "WEAPON_SKILL",
    ["Staff"] = "WEAPON_SKILL",
    ["Staves"] = "WEAPON_SKILL",
    ["Sword"] = "WEAPON_SKILL",
    ["Swords"] = "WEAPON_SKILL",
    ["Two-Handed Axes"] = "WEAPON_SKILL",
    ["Two-Handed Maces"] = "WEAPON_SKILL",
    ["Two-Handed Swords"] = "WEAPON_SKILL",
}

-- Parsed stats are cached by item link (links include enchants and gems, so
-- the mapping is stable). Treat returned tables as read-only.
ItemParser.statsCache = ItemParser.statsCache or {}
ItemParser.statsCacheCount = ItemParser.statsCacheCount or 0
ItemParser.STATS_CACHE_LIMIT = 500

function ItemParser:ParseItemStats(itemLink)
    if not itemLink then
        return {}
    end

    local cached = self.statsCache[itemLink]

    if cached then
        return cached
    end

    local itemName = GetItemInfo(itemLink)

    if not itemName then
        -- Item data not yet available from the server. Do not cache the empty
        -- result; Core retries after GET_ITEM_INFO_RECEIVED.
        self.sawUncachedItem = true
        return {}
    end

    local stats = {}

    self:ScanTooltipStats(itemLink, stats)

    local itemStats = GetItemStats(itemLink)

    if itemStats then
        for apiStatKey, value in pairs(itemStats) do
            local internalStat = self.STAT_MAPPING[apiStatKey]

            if internalStat and value and value > 0 then
                self:AddStat(stats, internalStat, value)
            end
        end
    end

    if self.statsCacheCount >= self.STATS_CACHE_LIMIT then
        self.statsCache = {}
        self.statsCacheCount = 0
    end

    self.statsCache[itemLink] = stats
    self.statsCacheCount = self.statsCacheCount + 1

    return stats
end

function ItemParser:AddStat(stats, statName, value)
    value = tonumber(value)

    if not value or value <= 0 then
        return
    end

    stats[statName] = math.max(stats[statName] or 0, value)
end

function ItemParser:AddStackingStat(stats, statName, value)
    value = tonumber(value)

    if not value or value <= 0 then
        return
    end

    stats[statName] = (stats[statName] or 0) + value
end

-- For negative stats ("-10 Stamina" on some vanilla items). Totals can go
-- negative; scoring treats non-positive values as zero.
function ItemParser:AddSignedStackingStat(stats, statName, value)
    value = tonumber(value)

    if not value or value == 0 then
        return
    end

    stats[statName] = (stats[statName] or 0) + value
end

function ItemParser:AddScaledStackingStat(stats, statName, value, scale)
    value = tonumber(value)
    scale = tonumber(scale) or 1

    if not value or value <= 0 then
        return
    end

    self:AddStackingStat(stats, statName, value * scale)
end

function ItemParser:CleanTooltipText(text)
    if not text then
        return nil
    end

    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    return text
end

function ItemParser:ScanTooltipStats(itemLink, stats)
    if not itemLink then
        return
    end

    local scannerName = "BetterGearScoreTooltipScanner"
    local scanner = _G[scannerName]

    if not scanner then
        scanner = CreateFrame("GameTooltip", scannerName, nil, "GameTooltipTemplate")
    end

    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)

    for i = 1, scanner:NumLines() do
        local leftLine = _G[scannerName .. "TextLeft" .. i]
        local rightLine = _G[scannerName .. "TextRight" .. i]

        local leftText = leftLine and leftLine:GetText()
        local rightText = rightLine and rightLine:GetText()

        if leftText then
            self:ParseTooltipLine(leftText, stats)
        end

        if rightText then
            self:ParseTooltipLine(rightText, stats)
        end
    end

    self:FinalizeWeaponStats(stats)

    scanner:Hide()
end

ItemParser.SOCKET_COLOR_NAMES = {
    Red = true,
    Yellow = true,
    Blue = true,
    Meta = true,
}

-- Slots with cheap, expected enchants in TBC. Rings (enchanter-only) and
-- ranged (scopes) are intentionally excluded to avoid false warnings.
ItemParser.ENCHANTABLE_SLOT_KEYS = {
    "HeadSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "WristSlot",
    "HandsSlot",
    "LegsSlot",
    "FeetSlot",
    "MainHandSlot",
}

function ItemParser:GetEnchantId(itemLink)
    local enchantId = string.match(itemLink or "", "item:%-?%d+:(%-?%d*)")

    enchantId = tonumber(enchantId)

    if enchantId and enchantId ~= 0 then
        return enchantId
    end

    return nil
end

function ItemParser:CountMissingEnchants(unit)
    unit = unit or "player"

    local missing = 0

    for _, slotKey in ipairs(self.ENCHANTABLE_SLOT_KEYS) do
        local slotId = GetInventorySlotInfo(slotKey)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink and not self:GetEnchantId(itemLink) then
            missing = missing + 1
        end
    end

    return missing
end

function ItemParser:CountEmptySockets(unit)
    unit = unit or "player"

    local empty = 0

    for _, slotInfo in ipairs(self.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink(unit, slotId)

        if itemLink then
            local stats = self:ParseItemStats(itemLink)
            empty = empty + (stats.EMPTY_SOCKETS or 0)
        end
    end

    return empty
end

function ItemParser:ParseTooltipLine(text, stats)
    text = self:CleanTooltipText(text)

    if not text or text == "" then
        return
    end

    -- Unfilled sockets render as e.g. "Red Socket"; filled ones show the gem
    -- name instead, so this line only appears for empty sockets.
    local socketColor = string.match(text, "^(%a+) Socket$")

    if socketColor and self.SOCKET_COLOR_NAMES[socketColor] then
        self:AddStackingStat(stats, "EMPTY_SOCKETS", 1)
        return
    end

    if self:ParseWeaponTooltipLine(text, stats) then
        return
    end

    if self:ParseSocketBonusTooltipLine(text, stats) then
        return
    end

    if self:ParseEnchantOrGemTooltipLine(text, stats) then
        return
    end

    if self:ParseSetBonusTooltipLine(text, stats) then
        return
    end

    if self:ParseUseTooltipLine(text, stats) then
        return
    end

    if self:ParseEquipTooltipLine(text, stats) then
        return
    end

    self:ParseBaseTooltipStatLine(text, stats)
end

function ItemParser:ParseWeaponTooltipLine(text, stats)
    local minDamage, maxDamage = string.match(text, "^(%d+)%s*%-%s*(%d+)%s+Damage")

    if minDamage and maxDamage then
        self:AddStat(stats, "WEAPON_MIN_DAMAGE", minDamage)
        self:AddStat(stats, "WEAPON_MAX_DAMAGE", maxDamage)
        return true
    end

    local speed = string.match(text, "Speed%s+(%d+%.?%d*)")

    if speed then
        self:AddStat(stats, "WEAPON_SPEED", speed)
        return true
    end

    local dps = string.match(text, "%((%d+%.?%d*) damage per second%)")

    if dps then
        self:AddStat(stats, "WEAPON_DPS", dps)
        return true
    end

    return false
end

function ItemParser:FinalizeWeaponStats(stats)
    local minDamage = stats.WEAPON_MIN_DAMAGE
    local maxDamage = stats.WEAPON_MAX_DAMAGE

    if minDamage and maxDamage then
        stats.WEAPON_AVERAGE_DAMAGE = (minDamage + maxDamage) / 2
    end

    if not stats.WEAPON_DPS and stats.WEAPON_AVERAGE_DAMAGE and stats.WEAPON_SPEED and stats.WEAPON_SPEED > 0 then
        stats.WEAPON_DPS = stats.WEAPON_AVERAGE_DAMAGE / stats.WEAPON_SPEED
    end
end

function ItemParser:NormalizeStatName(statName)
    if not statName then
        return nil
    end

    statName = string.gsub(statName, "^%s+", "")
    statName = string.gsub(statName, "%s+$", "")
    statName = string.gsub(statName, "%s+and$", "")
    statName = string.gsub(statName, "%.$", "")
    statName = string.gsub(statName, "%s+", " ")

    local mapped = self.TEXT_STAT_MAPPING[statName]

    if mapped then
        return mapped
    end

    local lowerName = string.lower(statName)

    if lowerName == "strength" then
        return "STRENGTH"
    elseif lowerName == "agility" then
        return "AGILITY"
    elseif lowerName == "intellect" then
        return "INTELLECT"
    elseif lowerName == "stamina" then
        return "STAMINA"
    elseif lowerName == "spirit" then
        return "SPIRIT"
    elseif lowerName == "armor" then
        return "ARMOR"
    elseif lowerName == "attack power" then
        return "ATTACKPOWER"
    elseif lowerName == "ranged attack power" then
        return "RANGED_ATTACKPOWER"
    elseif lowerName == "healing" or lowerName == "healing done" or lowerName == "healing spells" or lowerName == "spell healing" then
        return "HEALING"
    elseif lowerName == "spell damage" or lowerName == "spell power" or lowerName == "damage spells" or lowerName == "spell damage and healing" then
        return "SPELLPOWER"
    elseif lowerName == "defense rating" or lowerName == "defense" then
        return "DEFENSE"
    elseif lowerName == "dodge rating" then
        return "DODGE"
    elseif lowerName == "parry rating" then
        return "PARRY"
    elseif lowerName == "block rating" or lowerName == "shield block rating" then
        return "BLOCK"
    elseif lowerName == "block value" or lowerName == "shield block value" then
        return "BLOCK_VALUE"
    elseif lowerName == "critical strike rating" or lowerName == "crit rating" then
        return "CRITICAL"
    elseif lowerName == "spell critical strike rating" or lowerName == "spell crit rating" then
        return "CRITICAL"
    elseif lowerName == "hit rating" then
        return "HIT"
    elseif lowerName == "spell hit rating" then
        return "HIT"
    elseif lowerName == "haste rating" then
        return "HASTE"
    elseif lowerName == "spell haste rating" then
        return "HASTE"
    elseif lowerName == "melee haste rating" then
        return "HASTE"
    elseif lowerName == "expertise rating" then
        return "EXPERTISE"
    elseif lowerName == "mastery rating" then
        return "MASTERY"
    elseif lowerName == "armor penetration rating" then
        return "ARMOR_PENETRATION"
    elseif lowerName == "resilience rating" then
        return "RESILIENCE"
    elseif lowerName == "mana per 5 sec" or lowerName == "mana every 5 seconds" or lowerName == "mp5" then
        return "MP5"
    elseif lowerName == "health per 5 sec" or lowerName == "health every 5 seconds" or lowerName == "hp5" then
        return "HP5"
    elseif lowerName == "arcane resistance" then
        return "ARCANE_RESISTANCE"
    elseif lowerName == "fire resistance" then
        return "FIRE_RESISTANCE"
    elseif lowerName == "frost resistance" then
        return "FROST_RESISTANCE"
    elseif lowerName == "nature resistance" then
        return "NATURE_RESISTANCE"
    elseif lowerName == "shadow resistance" then
        return "SHADOW_RESISTANCE"
    elseif lowerName == "all resistances" or lowerName == "resistance" then
        return "ALL_RESISTANCE"
    end

    return nil
end

function ItemParser:AddTextStat(stats, statName, value, stacking)
    local internalStat = self:NormalizeStatName(statName)

    if not internalStat then
        return false
    end

    local numericValue = tonumber(value)

    if numericValue and numericValue < 0 then
        if internalStat == "ALL_RESISTANCE" then
            for _, resistStat in pairs(self.RESISTANCE_SCHOOLS) do
                self:AddSignedStackingStat(stats, resistStat, numericValue)
            end
        else
            self:AddSignedStackingStat(stats, internalStat, numericValue)
        end

        return true
    end

    if internalStat == "ALL_RESISTANCE" then
        if stacking then
            self:AddStackingStat(stats, "ARCANE_RESISTANCE", value)
            self:AddStackingStat(stats, "FIRE_RESISTANCE", value)
            self:AddStackingStat(stats, "FROST_RESISTANCE", value)
            self:AddStackingStat(stats, "NATURE_RESISTANCE", value)
            self:AddStackingStat(stats, "SHADOW_RESISTANCE", value)
        else
            self:AddStat(stats, "ARCANE_RESISTANCE", value)
            self:AddStat(stats, "FIRE_RESISTANCE", value)
            self:AddStat(stats, "FROST_RESISTANCE", value)
            self:AddStat(stats, "NATURE_RESISTANCE", value)
            self:AddStat(stats, "SHADOW_RESISTANCE", value)
        end

        return true
    end

    if stacking then
        self:AddStackingStat(stats, internalStat, value)
    else
        self:AddStat(stats, internalStat, value)
    end

    return true
end

function ItemParser:ParseStatChunks(text, stats, stacking)
    local parsedAny = false

    for sign, value, statName in string.gmatch(text, "([%+%-])(%d+)%s+([^%+%-]+)") do
        statName = string.gsub(statName, "%s+and%s*$", "")
        statName = string.gsub(statName, "%s*$", "")

        if self:AddTextStat(stats, statName, tonumber(sign .. value), stacking) then
            parsedAny = true
        end
    end

    return parsedAny
end

function ItemParser:CountPlusSigns(text)
    local count = 0

    for _ in string.gmatch(text or "", "%+") do
        count = count + 1
    end

    return count
end

function ItemParser:ParseSocketBonusTooltipLine(text, stats)
    local socketBonusText = string.match(text, "^Socket Bonus:%s*(.+)$")

    if not socketBonusText then
        return false
    end

    if self:ParseRegenEffect(socketBonusText, stats, true) then
        return true
    end

    self:ParseAllStatsLine(socketBonusText, stats, true)
    self:ParseAllResistancesLine(socketBonusText, stats, true)
    self:ParseStatChunks(socketBonusText, stats, true)

    return true
end

function ItemParser:ParseAllStatsLine(text, stats, stacking)
    local value = string.match(text, "%+(%d+)%s+All Stats")

    if not value then
        return false
    end

    if stacking then
        self:AddStackingStat(stats, "STRENGTH", value)
        self:AddStackingStat(stats, "AGILITY", value)
        self:AddStackingStat(stats, "INTELLECT", value)
        self:AddStackingStat(stats, "STAMINA", value)
        self:AddStackingStat(stats, "SPIRIT", value)
    else
        self:AddStat(stats, "STRENGTH", value)
        self:AddStat(stats, "AGILITY", value)
        self:AddStat(stats, "INTELLECT", value)
        self:AddStat(stats, "STAMINA", value)
        self:AddStat(stats, "SPIRIT", value)
    end

    return true
end

function ItemParser:ParseAllResistancesLine(text, stats, stacking)
    local value = string.match(text, "%+(%d+)%s+All Resistances")

    if not value then
        return false
    end

    if stacking then
        self:AddStackingStat(stats, "ARCANE_RESISTANCE", value)
        self:AddStackingStat(stats, "FIRE_RESISTANCE", value)
        self:AddStackingStat(stats, "FROST_RESISTANCE", value)
        self:AddStackingStat(stats, "NATURE_RESISTANCE", value)
        self:AddStackingStat(stats, "SHADOW_RESISTANCE", value)
    else
        self:AddStat(stats, "ARCANE_RESISTANCE", value)
        self:AddStat(stats, "FIRE_RESISTANCE", value)
        self:AddStat(stats, "FROST_RESISTANCE", value)
        self:AddStat(stats, "NATURE_RESISTANCE", value)
        self:AddStat(stats, "SHADOW_RESISTANCE", value)
    end

    return true
end

function ItemParser:ParseEnchantOrGemTooltipLine(text, stats)
    local enchantText = string.match(text, "^Enchant:%s*(.+)$")

    if enchantText then
        self:ParseAllStatsLine(enchantText, stats, true)
        self:ParseAllResistancesLine(enchantText, stats, true)
        self:ParseStatChunks(enchantText, stats, true)
        return true
    end

    if string.sub(text, 1, 1) == "+" and self:CountPlusSigns(text) >= 2 then
        self:ParseAllStatsLine(text, stats, true)
        self:ParseAllResistancesLine(text, stats, true)
        self:ParseStatChunks(text, stats, true)
        return true
    end

    return false
end

function ItemParser:ParseBaseTooltipStatLine(text, stats)
    local armor = string.match(text, "^(%d+)%s+Armor$")

    if armor then
        self:AddStat(stats, "ARMOR", armor)
        return true
    end

    if self:ParseAllStatsLine(text, stats, false) then
        return true
    end

    if self:ParseAllResistancesLine(text, stats, false) then
        return true
    end

    local firstChar = string.sub(text, 1, 1)

    if firstChar == "+" and self:CountPlusSigns(text) == 1 then
        return self:ParseStatChunks(text, stats, false)
    end

    -- Negative base stats, e.g. "-10 Stamina" on some vanilla items.
    if firstChar == "-" and self:CountPlusSigns(text) == 0 then
        return self:ParseStatChunks(text, stats, false)
    end

    return false
end

function ItemParser:ParseSetBonusTooltipLine(text, stats)
    -- Set bonuses are shown in item tooltips even when inactive.
    -- Do not score them here. Active set bonuses need a separate equipped-set system.
    return false
end

function ItemParser:ParseUseTooltipLine(text, stats)
    local useText = string.match(text, "^Use:%s*(.+)$")

    if not useText then
        return false
    end

    stats.UNSCORED_USE_EFFECT = 1

    return true
end

function ItemParser:ParseEquipTooltipLine(text, stats)
    local equipText = string.match(text, "^Equip:%s*(.+)$")

    if not equipText then
        return false
    end

    if not self:ParseEffectText(equipText, stats, true) then
        -- Unrecognized equip effect (proc, utility, threat, etc.): flag it
        -- so the tooltip breakdown can disclose that something isn't scored.
        self:AddStackingStat(stats, "UNSCORED_EQUIP_EFFECT", 1)
    end

    return true
end

function ItemParser:ParseEffectText(text, stats, stacking)
    if self:ParseGenericHealingSpellDamageEffect(text, stats, stacking) then
        return true
    end

    if self:ParseSpellSpecificEffect(text, stats) then
        return true
    end

    if self:ParseAttackPowerEffect(text, stats, stacking) then
        return true
    end

    if self:ParseRatingEffect(text, stats, stacking) then
        return true
    end

    if self:ParseRegenEffect(text, stats, stacking) then
        return true
    end

    if self:ParseArmorBlockResistanceEffect(text, stats, stacking) then
        return true
    end

    if self:ParseWeaponSkillEffect(text, stats, stacking) then
        return true
    end

    if self:ParseMiscEquipEffect(text, stats) then
        return true
    end

    return false
end

function ItemParser:ParseGenericHealingSpellDamageEffect(text, stats, stacking)
    local healing, spellDamage = string.match(
        text,
        "Increases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects"
    )

    if healing and spellDamage then
        self:AddStackingStat(stats, "HEALING", healing)
        self:AddStackingStat(stats, "SPELLPOWER", spellDamage)
        return true
    end

    local damageHealing = string.match(
        text,
        "Increases damage and healing done by magical spells and effects by up to (%d+)"
    )

    if damageHealing then
        self:AddStackingStat(stats, "SPELLPOWER", damageHealing)
        self:AddStackingStat(stats, "HEALING", damageHealing)
        return true
    end

    local spellPower = string.match(
        text,
        "Increases spell damage and healing by up to (%d+)"
    )

    if spellPower then
        self:AddStackingStat(stats, "SPELLPOWER", spellPower)
        self:AddStackingStat(stats, "HEALING", spellPower)
        return true
    end

    local healingOnly = string.match(
        text,
        "Increases healing done by up to (%d+) for all magical spells and effects"
    )

    if healingOnly then
        self:AddStackingStat(stats, "HEALING", healingOnly)
        return true
    end

    healingOnly = string.match(
        text,
        "Increases healing done by magical spells and effects by up to (%d+)"
    )

    if healingOnly then
        self:AddStackingStat(stats, "HEALING", healingOnly)
        return true
    end

    local spellDamage = string.match(
        text,
        "Increases damage done by magical spells and effects by up to (%d+)"
    )

    if spellDamage then
        self:AddStackingStat(stats, "SPELLPOWER", spellDamage)
        return true
    end

    spellDamage = string.match(text, "Increases spell damage by up to (%d+)")

    if spellDamage then
        self:AddStackingStat(stats, "SPELLPOWER", spellDamage)
        return true
    end

    -- Vanilla healing wording: "Increases healing done by spells and
    -- effects by up to X."
    healingOnly = string.match(text, "Increases healing done by spells and effects by up to (%d+)")

    if healingOnly then
        self:AddStackingStat(stats, "HEALING", healingOnly)
        return true
    end

    -- Creature-type-conditional caster damage (e.g. Mark of the Champion):
    -- "Increases damage done to Undead by magical spells and effects by up
    -- to X." Counted at a fraction since it only applies sometimes.
    local conditionalSpellDamage = string.match(
        text,
        "Increases damage done to [%a%s]+ by magical spells and effects by up to (%d+)"
    )

    if conditionalSpellDamage then
        self:AddScaledStackingStat(stats, "SPELLPOWER", conditionalSpellDamage, self.CONDITIONAL_EFFECT_SCALE)
        return true
    end

    -- School-specific spell damage (Frozen Shadoweave etc.):
    -- "Increases damage done by Shadow spells and effects by up to X."
    local school, schoolDamage = string.match(text, "Increases damage done by (%a+) spells and effects by up to (%d+)")

    if school and schoolDamage and self.SPELL_SCHOOLS[school] then
        self:AddStackingStat(stats, "SPELLPOWER", schoolDamage)
        return true
    end

    return false
end

function ItemParser:ParseSpellSpecificEffect(text, stats)
    local value = string.match(text, "Increases the periodic healing of your [%a%s]+ by up to (%d+)")

    if value then
        self:AddScaledStackingStat(stats, "HEALING", value, self.SPELL_SPECIFIC_EFFECT_SCALE)
        return true
    end

    value = string.match(text, "Increases the healing done by your [%a%s]+ by up to (%d+)")

    if value then
        self:AddScaledStackingStat(stats, "HEALING", value, self.SPELL_SPECIFIC_EFFECT_SCALE)
        return true
    end

    value = string.match(text, "Increases the healing done by your [%a%s]+ by (%d+)")

    if value then
        self:AddScaledStackingStat(stats, "HEALING", value, self.SPELL_SPECIFIC_EFFECT_SCALE)
        return true
    end

    value = string.match(text, "Increases the damage done by your [%a%s]+ by up to (%d+)")

    if value then
        self:AddScaledStackingStat(stats, "SPELLPOWER", value, self.SPELL_SPECIFIC_EFFECT_SCALE)
        return true
    end

    value = string.match(text, "Increases the damage done by your [%a%s]+ by (%d+)")

    if value then
        self:AddScaledStackingStat(stats, "SPELLPOWER", value, self.SPELL_SPECIFIC_EFFECT_SCALE)
        return true
    end

    return false
end

function ItemParser:ParseAttackPowerEffect(text, stats, stacking)
    -- Creature-type-conditional AP must be checked before the generic
    -- pattern, which would otherwise match the same line at full value.
    local conditionalAttackPower = string.match(text, "Increases attack power by (%d+) when fighting")
        or string.match(text, "^%+(%d+) Attack Power when fighting")

    if conditionalAttackPower then
        self:AddScaledStackingStat(stats, "ATTACKPOWER", conditionalAttackPower, self.CONDITIONAL_EFFECT_SCALE)
        return true
    end

    local feralAttackPower = string.match(
        text,
        "Increases attack power by (%d+) in Cat, Bear, Dire Bear, and Moonkin forms only"
    )

    if feralAttackPower then
        self:AddStackingStat(stats, "FERAL_ATTACKPOWER", feralAttackPower)
        return true
    end

    feralAttackPower = string.match(
        text,
        "Increases attack power by (%d+) in Cat, Bear, Dire Bear and Moonkin forms only"
    )

    if feralAttackPower then
        self:AddStackingStat(stats, "FERAL_ATTACKPOWER", feralAttackPower)
        return true
    end

    feralAttackPower = string.match(text, "Increases attack power by (%d+) in feral forms only")

    if feralAttackPower then
        self:AddStackingStat(stats, "FERAL_ATTACKPOWER", feralAttackPower)
        return true
    end

    local rangedAttackPower = string.match(text, "Increases ranged attack power by (%d+)")

    if rangedAttackPower then
        self:AddStackingStat(stats, "RANGED_ATTACKPOWER", rangedAttackPower)
        return true
    end

    rangedAttackPower = string.match(text, "Increases your ranged attack power by (%d+)")

    if rangedAttackPower then
        self:AddStackingStat(stats, "RANGED_ATTACKPOWER", rangedAttackPower)
        return true
    end

    local attackPower = string.match(text, "Increases attack power by (%d+)")

    if attackPower then
        self:AddStackingStat(stats, "ATTACKPOWER", attackPower)
        return true
    end

    attackPower = string.match(text, "Increases your attack power by (%d+)")

    if attackPower then
        self:AddStackingStat(stats, "ATTACKPOWER", attackPower)
        return true
    end

    -- Old plain formats: "Equip: +28 Attack Power." / "+14 ranged Attack Power."
    rangedAttackPower = string.match(text, "^%+(%d+) [Rr]anged Attack Power%.?$")

    if rangedAttackPower then
        self:AddStackingStat(stats, "RANGED_ATTACKPOWER", rangedAttackPower)
        return true
    end

    attackPower = string.match(text, "^%+(%d+) Attack Power%.?$")

    if attackPower then
        self:AddStackingStat(stats, "ATTACKPOWER", attackPower)
        return true
    end

    return false
end

function ItemParser:ParseRatingEffect(text, stats, stacking)
    local ratingName, value = string.match(text, "Improves your ([%a%s]+ rating) by (%d+)")

    if ratingName and value then
        if self:AddTextStat(stats, ratingName, value, true) then
            return true
        end
    end

    ratingName, value = string.match(text, "Improves ([%a%s]+ rating) by (%d+)")

    if ratingName and value then
        if self:AddTextStat(stats, ratingName, value, true) then
            return true
        end
    end

    ratingName, value = string.match(text, "Increases your ([%a%s]+ rating) by (%d+)")

    if ratingName and value then
        if self:AddTextStat(stats, ratingName, value, true) then
            return true
        end
    end

    ratingName, value = string.match(text, "Increases ([%a%s]+ rating) by (%d+)")

    if ratingName and value then
        if self:AddTextStat(stats, ratingName, value, true) then
            return true
        end
    end

    -- Vanilla-style percent effects, converted to level-70 rating
    -- equivalents. "with spells" variants are listed before their generic
    -- counterparts so they match first.
    for _, percentInfo in ipairs(self.PERCENT_EFFECT_PATTERNS) do
        local percent = string.match(text, percentInfo.pattern)

        if percent then
            local rating = tonumber(percent) * self:GetRatingPerPercent(percentInfo.ratingKey)
            self:AddStackingStat(stats, percentInfo.stat, rating)
            return true
        end
    end

    return false
end

function ItemParser:ParseRegenEffect(text, stats, stacking)
    local mp5 = string.match(text, "Restores (%d+) mana per 5 sec")

    if mp5 then
        self:AddStackingStat(stats, "MP5", mp5)
        return true
    end

    mp5 = string.match(text, "Restores (%d+) mana per 5 seconds")

    if mp5 then
        self:AddStackingStat(stats, "MP5", mp5)
        return true
    end

    mp5 = string.match(text, "%+?(%d+) Mana every 5 seconds")

    if mp5 then
        self:AddStackingStat(stats, "MP5", mp5)
        return true
    end

    mp5 = string.match(text, "%+?(%d+) mana per 5 sec")

    if mp5 then
        self:AddStackingStat(stats, "MP5", mp5)
        return true
    end

    local hp5 = string.match(text, "Restores (%d+) health per 5 sec")

    if hp5 then
        self:AddStackingStat(stats, "HP5", hp5)
        return true
    end

    hp5 = string.match(text, "Restores (%d+) health per 5 seconds")

    if hp5 then
        self:AddStackingStat(stats, "HP5", hp5)
        return true
    end

    hp5 = string.match(text, "%+?(%d+) Health every 5 seconds")

    if hp5 then
        self:AddStackingStat(stats, "HP5", hp5)
        return true
    end

    return false
end

function ItemParser:ParseArmorBlockResistanceEffect(text, stats, stacking)
    local armor = string.match(text, "Increases armor by (%d+)")

    if armor then
        self:AddStackingStat(stats, "ARMOR", armor)
        return true
    end

    armor = string.match(text, "Increases your armor by (%d+)")

    if armor then
        self:AddStackingStat(stats, "ARMOR", armor)
        return true
    end

    local blockValue = string.match(text, "Increases the block value of your shield by (%d+)")

    if blockValue then
        self:AddStackingStat(stats, "BLOCK_VALUE", blockValue)
        return true
    end

    local allResist = string.match(text, "Increases all resistances by (%d+)")

    if allResist then
        self:AddStackingStat(stats, "ARCANE_RESISTANCE", allResist)
        self:AddStackingStat(stats, "FIRE_RESISTANCE", allResist)
        self:AddStackingStat(stats, "FROST_RESISTANCE", allResist)
        self:AddStackingStat(stats, "NATURE_RESISTANCE", allResist)
        self:AddStackingStat(stats, "SHADOW_RESISTANCE", allResist)
        return true
    end

    return false
end

function ItemParser:ParseWeaponSkillEffect(text, stats, stacking)
    local weaponName, value = string.match(text, "Increased ([%a%s%-]+) %+(%d+)")

    if weaponName and value then
        weaponName = string.gsub(weaponName, "^%s+", "")
        weaponName = string.gsub(weaponName, "%s+$", "")

        if self.WEAPON_SKILL_MAPPING[weaponName] then
            self:AddStackingStat(stats, "WEAPON_SKILL", value)
            return true
        end
    end

    value, weaponName = string.match(text, "%+(%d+) ([%a%s%-]+) Skill")

    if weaponName and value then
        weaponName = string.gsub(weaponName, "^%s+", "")
        weaponName = string.gsub(weaponName, "%s+$", "")

        if self.WEAPON_SKILL_MAPPING[weaponName] then
            self:AddStackingStat(stats, "WEAPON_SKILL", value)
            return true
        end
    end

    return false
end

function ItemParser:ParseMiscEquipEffect(text, stats)
    -- Old-style defense: "Increased Defense +7."
    local defense = string.match(text, "Increased Defense %+(%d+)")

    if defense then
        self:AddStackingStat(stats, "DEFENSE", defense)
        return true
    end

    -- Armor penetration (TBC): "Your attacks ignore X of your opponent's armor."
    local armorPenetration = string.match(text, "Your attacks ignore (%d+) of your opponent's armor")

    if armorPenetration then
        self:AddStackingStat(stats, "ARMOR_PENETRATION", armorPenetration)
        return true
    end

    -- Spell penetration: "Decreases the magical resistances of your spell
    -- targets by X."
    local spellPenetration = string.match(text, "Decreases the magical resistances of your spell targets by (%d+)")

    if spellPenetration then
        self:AddStackingStat(stats, "SPELL_PENETRATION", spellPenetration)
        return true
    end

    -- Vanilla casting regen: "Allows 15% of your Mana regeneration to
    -- continue while casting." Converted to a rough MP5 equivalent.
    local regenPercent = string.match(text, "Allows (%d+)%% of your [Mm]ana regeneration to continue while casting")

    if regenPercent then
        self:AddScaledStackingStat(stats, "MP5", regenPercent, self.REGEN_WHILE_CASTING_MP5_PER_PERCENT)
        return true
    end

    -- Single-school resistance equip lines: "Increases Fire Resistance by 10."
    local resistSchool, resistValue = string.match(text, "Increases (%a+) [Rr]esistance by (%d+)")

    if resistSchool and resistValue and self.RESISTANCE_SCHOOLS[resistSchool] then
        self:AddStackingStat(stats, self.RESISTANCE_SCHOOLS[resistSchool], resistValue)
        return true
    end

    return false
end

function ItemParser:GetEquippedItems()
    local equippedItems = {}

    for _, slotInfo in ipairs(self.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink("player", slotId)

        if itemLink then
            local stats = self:ParseItemStats(itemLink)

            equippedItems[slotId] = {
                link = itemLink,
                stats = stats,
                slotName = slotInfo.name,
                slotKey = slotInfo.key,
            }
        end
    end

    return equippedItems
end

function ItemParser:GetItemStatsInSlot(slotId)
    local itemLink = GetInventoryItemLink("player", slotId)

    if itemLink then
        return self:ParseItemStats(itemLink)
    end

    return {}
end

function ItemParser:GetItemName(itemLink)
    if not itemLink then
        return "Unknown"
    end

    local name = GetItemInfo(itemLink)

    return name or "Unknown"
end

function ItemParser:GetSlotName(slotId)
    for _, slotInfo in ipairs(self.EQUIPMENT_SLOTS) do
        local id = GetInventorySlotInfo(slotInfo.key)

        if id == slotId then
            return slotInfo.name
        end
    end

    return "Unknown"
end

function ItemParser:GetSlotKey(slotId)
    for _, slotInfo in ipairs(self.EQUIPMENT_SLOTS) do
        local id = GetInventorySlotInfo(slotInfo.key)

        if id == slotId then
            return slotInfo.key
        end
    end

    return nil
end