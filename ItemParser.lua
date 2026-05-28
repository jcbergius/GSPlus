-- ItemParser.lua

BetterGearScore = BetterGearScore or {}
BetterGearScore.ItemParser = BetterGearScore.ItemParser or {}

local ItemParser = BetterGearScore.ItemParser

ItemParser.SPELL_SPECIFIC_EFFECT_SCALE = 0.35

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

function ItemParser:ParseItemStats(itemLink)
    if not itemLink then
        return {}
    end

    local itemName = GetItemInfo(itemLink)

    if not itemName then
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

function ItemParser:ParseTooltipLine(text, stats)
    text = self:CleanTooltipText(text)

    if not text or text == "" then
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

    for value, statName in string.gmatch(text, "%+(%d+)%s+([^%+]+)") do
        statName = string.gsub(statName, "%s+and%s*$", "")
        statName = string.gsub(statName, "%s*$", "")

        if self:AddTextStat(stats, statName, value, stacking) then
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

    if string.sub(text, 1, 1) == "+" and self:CountPlusSigns(text) == 1 then
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

    return self:ParseEffectText(equipText, stats, true)
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

    local oldHitPercent = string.match(text, "Improves your chance to hit by (%d+)%%")

    if oldHitPercent then
        self:AddStackingStat(stats, "HIT", tonumber(oldHitPercent) * 15.8)
        return true
    end

    local oldCritPercent = string.match(text, "Improves your chance to get a critical strike by (%d+)%%")

    if oldCritPercent then
        self:AddStackingStat(stats, "CRITICAL", tonumber(oldCritPercent) * 22.1)
        return true
    end

    local oldDodgePercent = string.match(text, "Increases your chance to dodge an attack by (%d+)%%")

    if oldDodgePercent then
        self:AddStackingStat(stats, "DODGE", tonumber(oldDodgePercent) * 18.9)
        return true
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