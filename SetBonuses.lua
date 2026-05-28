-- SetBonuses.lua

BetterGearScore = BetterGearScore or {}
BetterGearScore.SetBonuses = BetterGearScore.SetBonuses or {}

local SetBonuses = BetterGearScore.SetBonuses

SetBonuses.scannerName = "BetterGearScoreSetBonusScanner"

-- Conservative conversions for percent-based set bonuses.
-- These let useful set bonuses contribute without pretending we know exact uptime/simulation value.
SetBonuses.PERCENT_HEALING_TO_HEALING = 5
SetBonuses.PERCENT_DAMAGE_TO_SPELLPOWER = 5
SetBonuses.PERCENT_MANA_COST_TO_MP5 = 0.5
SetBonuses.PERCENT_THREAT_TO_THREAT_VALUE = 0

SetBonuses.TEXT_STAT_MAPPING = {
    ["Strength"] = "STRENGTH",
    ["Agility"] = "AGILITY",
    ["Intellect"] = "INTELLECT",
    ["Stamina"] = "STAMINA",
    ["Spirit"] = "SPIRIT",
    ["Armor"] = "ARMOR",

    ["Attack Power"] = "ATTACKPOWER",
    ["Ranged Attack Power"] = "RANGED_ATTACKPOWER",
    ["Feral Attack Power"] = "FERAL_ATTACKPOWER",

    ["Healing"] = "HEALING",
    ["Healing Done"] = "HEALING",
    ["Healing Spells"] = "HEALING",
    ["Spell Healing"] = "HEALING",

    ["Spell Damage"] = "SPELLPOWER",
    ["Spell Power"] = "SPELLPOWER",
    ["Damage Spells"] = "SPELLPOWER",
    ["Damage and Healing"] = "SPELLPOWER",
    ["Spell Damage and Healing"] = "SPELLPOWER",

    ["Defense Rating"] = "DEFENSE",
    ["Defense"] = "DEFENSE",
    ["Dodge Rating"] = "DODGE",
    ["Parry Rating"] = "PARRY",
    ["Block Rating"] = "BLOCK",
    ["Shield Block Rating"] = "BLOCK",
    ["Block Value"] = "BLOCK_VALUE",
    ["Shield Block Value"] = "BLOCK_VALUE",

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
    ["Resilience Rating"] = "RESILIENCE",

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

function SetBonuses:CleanTooltipText(text)
    if not text then
        return nil
    end

    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    return text
end

function SetBonuses:AddStat(stats, statName, value)
    value = tonumber(value)

    if not value or value <= 0 then
        return
    end

    stats[statName] = (stats[statName] or 0) + value
end

function SetBonuses:AddScaledStat(stats, statName, value, scale)
    value = tonumber(value)
    scale = tonumber(scale) or 1

    if not value or value <= 0 then
        return
    end

    self:AddStat(stats, statName, value * scale)
end

function SetBonuses:NormalizeStatName(statName)
    if not statName then
        return nil
    end

    statName = string.gsub(statName, "^%s+", "")
    statName = string.gsub(statName, "%s+$", "")
    statName = string.gsub(statName, "%.$", "")
    statName = string.gsub(statName, "%s+", " ")

    local mapped = self.TEXT_STAT_MAPPING[statName]

    if mapped then
        return mapped
    end

    local lowerName = string.lower(statName)

    if lowerName == "spell haste rating" then
        return "HASTE"
    elseif lowerName == "haste rating" then
        return "HASTE"
    elseif lowerName == "spell hit rating" then
        return "HIT"
    elseif lowerName == "spell critical strike rating" or lowerName == "spell crit rating" then
        return "CRITICAL"
    elseif lowerName == "critical strike rating" or lowerName == "crit rating" then
        return "CRITICAL"
    elseif lowerName == "mana per 5 sec" or lowerName == "mana every 5 seconds" then
        return "MP5"
    elseif lowerName == "resilience rating" then
        return "RESILIENCE"
    end

    return nil
end

function SetBonuses:AddTextStat(stats, statName, value)
    local internalStat = self:NormalizeStatName(statName)

    if not internalStat then
        return false
    end

    if internalStat == "ALL_RESISTANCE" then
        self:AddStat(stats, "ARCANE_RESISTANCE", value)
        self:AddStat(stats, "FIRE_RESISTANCE", value)
        self:AddStat(stats, "FROST_RESISTANCE", value)
        self:AddStat(stats, "NATURE_RESISTANCE", value)
        self:AddStat(stats, "SHADOW_RESISTANCE", value)
        return true
    end

    self:AddStat(stats, internalStat, value)
    return true
end

function SetBonuses:ParseStatChunks(text, stats)
    local parsedAny = false

    for value, statName in string.gmatch(text, "%+(%d+)%s+([^%+%.]+)") do
        statName = string.gsub(statName, "%s+and%s*$", "")
        statName = string.gsub(statName, "%s*$", "")

        if self:AddTextStat(stats, statName, value) then
            parsedAny = true
        end
    end

    return parsedAny
end

function SetBonuses:GetTooltipLines(itemLink)
    local lines = {}

    if not itemLink then
        return lines
    end

    local scanner = _G[self.scannerName]

    if not scanner then
        scanner = CreateFrame("GameTooltip", self.scannerName, nil, "GameTooltipTemplate")
    end

    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)

    for i = 1, scanner:NumLines() do
        local leftLine = _G[self.scannerName .. "TextLeft" .. i]
        local rightLine = _G[self.scannerName .. "TextRight" .. i]

        local leftText = leftLine and leftLine:GetText()
        local rightText = rightLine and rightLine:GetText()

        leftText = self:CleanTooltipText(leftText)
        rightText = self:CleanTooltipText(rightText)

        if leftText and leftText ~= "" then
            lines[#lines + 1] = leftText
        end

        if rightText and rightText ~= "" then
            lines[#lines + 1] = rightText
        end
    end

    scanner:Hide()

    return lines
end

function SetBonuses:FindSetHeader(lines)
    for _, line in ipairs(lines or {}) do
        local setName, equippedCount, totalCount = string.match(line, "^(.+)%s+%((%d+)/(%d+)%)$")

        if setName and equippedCount and totalCount then
            return setName, tonumber(equippedCount), tonumber(totalCount)
        end
    end

    return nil, 0, 0
end

function SetBonuses:IsSetBonusStartLine(text)
    return string.match(text or "", "^%((%d+)%)%s+Set:") ~= nil
end

function SetBonuses:IsTooltipSectionStopLine(text)
    if not text then
        return true
    end

    if self:IsSetBonusStartLine(text) then
        return true
    end

    if string.match(text, "^Requires ") then
        return true
    end

    if string.match(text, "^Equip:") then
        return true
    end

    if string.match(text, "^Use:") then
        return true
    end

    if string.match(text, "^Socket Bonus:") then
        return true
    end

    if string.match(text, "^Durability ") then
        return true
    end

    if string.match(text, "^Classes:") then
        return true
    end

    if string.match(text, "^Item Level") then
        return true
    end

    return false
end

function SetBonuses:ParseGenericStatEffects(text, stats)
    local parsedAny = false

    if self:ParseStatChunks(text, stats) then
        parsedAny = true
    end

    local value, statName = string.match(text, "[Ii]mproves ([%a%s]+ rating) by (%d+)")

    if value and statName then
        -- Defensive fallback for accidental reversed capture in old Lua patterns.
    end

    statName, value = string.match(text, "[Ii]mproves ([%a%s]+ rating) by (%d+)")

    if statName and value then
        if self:AddTextStat(stats, statName, value) then
            parsedAny = true
        end
    end

    statName, value = string.match(text, "[Ii]ncreases your ([%a%s]+ rating) by (%d+)")

    if statName and value then
        if self:AddTextStat(stats, statName, value) then
            parsedAny = true
        end
    end

    statName, value = string.match(text, "[Ii]ncreases ([%a%s]+ rating) by (%d+)")

    if statName and value then
        if self:AddTextStat(stats, statName, value) then
            parsedAny = true
        end
    end

    value = string.match(text, "[Gg]ain (%d+) mana per 5 sec")
        or string.match(text, "[Gg]ain (%d+) mana per 5 seconds")
        or string.match(text, "[Rr]estore[s]? (%d+) mana per 5 sec")
        or string.match(text, "[Rr]estore[s]? (%d+) mana per 5 seconds")

    if value then
        self:AddStat(stats, "MP5", value)
        parsedAny = true
    end

    value = string.match(text, "[Gg]ain (%d+) health per 5 sec")
        or string.match(text, "[Gg]ain (%d+) health per 5 seconds")
        or string.match(text, "[Rr]estore[s]? (%d+) health per 5 sec")
        or string.match(text, "[Rr]estore[s]? (%d+) health per 5 seconds")

    if value then
        self:AddStat(stats, "HP5", value)
        parsedAny = true
    end

    value = string.match(text, "(%d+) mana per 5 sec")
        or string.match(text, "(%d+) mana per 5 seconds")

    if value then
        self:AddStat(stats, "MP5", value)
        parsedAny = true
    end

    value = string.match(text, "(%d+) spell critical strike rating")
        or string.match(text, "(%d+) spell crit rating")

    if value then
        self:AddStat(stats, "CRITICAL", value)
        parsedAny = true
    end

    value = string.match(text, "(%d+) critical strike rating")
        or string.match(text, "(%d+) crit rating")

    if value then
        self:AddStat(stats, "CRITICAL", value)
        parsedAny = true
    end

    value = string.match(text, "(%d+) spell hit rating")

    if value then
        self:AddStat(stats, "HIT", value)
        parsedAny = true
    end

    value = string.match(text, "(%d+) spell haste rating")
        or string.match(text, "(%d+) haste rating")

    if value then
        self:AddStat(stats, "HASTE", value)
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ParseHealingDamageEffects(text, stats)
    local parsedAny = false

    local healing, spellDamage = string.match(
        text,
        "[Ii]ncreases healing done by up to (%d+) and damage done by up to (%d+) for all magical spells and effects"
    )

    if healing and spellDamage then
        self:AddStat(stats, "HEALING", healing)
        self:AddStat(stats, "SPELLPOWER", spellDamage)
        parsedAny = true
    end

    local both = string.match(
        text,
        "[Ii]ncreases damage and healing done by magical spells and effects by up to (%d+)"
    )

    if both then
        self:AddStat(stats, "SPELLPOWER", both)
        self:AddStat(stats, "HEALING", both)
        parsedAny = true
    end

    both = string.match(text, "[Ii]ncreases spell damage and healing by up to (%d+)")

    if both then
        self:AddStat(stats, "SPELLPOWER", both)
        self:AddStat(stats, "HEALING", both)
        parsedAny = true
    end

    local healingOnly = string.match(text, "[Ii]ncreases healing done by up to (%d+)")
        or string.match(text, "[Ii]ncreases healing by up to (%d+)")
        or string.match(text, "up to (%d+) healing")

    if healingOnly then
        self:AddStat(stats, "HEALING", healingOnly)
        parsedAny = true
    end

    local spellDamage = string.match(text, "[Ii]ncreases spell damage by up to (%d+)")
        or string.match(text, "[Ii]ncreases damage done by magical spells and effects by up to (%d+)")
        or string.match(text, "up to (%d+) spell damage")

    if spellDamage then
        self:AddStat(stats, "SPELLPOWER", spellDamage)
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ParseAttackPowerEffects(text, stats)
    local parsedAny = false

    local value = string.match(text, "[Ii]ncreases attack power by (%d+) in Cat, Bear, Dire Bear, and Moonkin forms only")
        or string.match(text, "[Ii]ncreases attack power by (%d+) in Cat, Bear, Dire Bear and Moonkin forms only")
        or string.match(text, "[Ii]ncreases attack power by (%d+) in feral forms only")

    if value then
        self:AddStat(stats, "FERAL_ATTACKPOWER", value)
        parsedAny = true
    end

    value = string.match(text, "[Ii]ncreases ranged attack power by (%d+)")
        or string.match(text, "[Ii]ncreases your ranged attack power by (%d+)")

    if value then
        self:AddStat(stats, "RANGED_ATTACKPOWER", value)
        parsedAny = true
    end

    value = string.match(text, "[Ii]ncreases attack power by (%d+)")
        or string.match(text, "[Ii]ncreases your attack power by (%d+)")

    if value then
        self:AddStat(stats, "ATTACKPOWER", value)
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ParseDefenseTankEffects(text, stats)
    local parsedAny = false

    local value = string.match(text, "[Ii]ncreases the block value of your shield by (%d+)")

    if value then
        self:AddStat(stats, "BLOCK_VALUE", value)
        parsedAny = true
    end

    value = string.match(text, "[Ii]ncreases armor by (%d+)")
        or string.match(text, "[Ii]ncreases your armor by (%d+)")

    if value then
        self:AddStat(stats, "ARMOR", value)
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ParsePercentEffects(text, stats)
    local parsedAny = false

    local value = string.match(text, "[Ii]ncreases the amount healed by your [%a%s]+ ability by (%d+)%%")
        or string.match(text, "[Ii]ncreases healing done by your [%a%s]+ by (%d+)%%")
        or string.match(text, "[Ii]ncreases your healing by (%d+)%%")
        or string.match(text, "[Ii]ncreases healing done by (%d+)%%")

    if value then
        self:AddScaledStat(stats, "HEALING", value, self.PERCENT_HEALING_TO_HEALING)
        parsedAny = true
    end

    value = string.match(text, "[Ii]ncreases the damage dealt by your [%a%s]+ ability by (%d+)%%")
        or string.match(text, "[Ii]ncreases damage done by your [%a%s]+ by (%d+)%%")
        or string.match(text, "[Ii]ncreases your damage by (%d+)%%")
        or string.match(text, "[Ii]ncreases damage done by (%d+)%%")

    if value then
        self:AddScaledStat(stats, "SPELLPOWER", value, self.PERCENT_DAMAGE_TO_SPELLPOWER)
        parsedAny = true
    end

    value = string.match(text, "[Cc]osts (%d+)%% less mana")
        or string.match(text, "[Rr]educes the mana cost of your [%a%s]+ by (%d+)%%")
        or string.match(text, "[Rr]educes the mana cost of [%a%s]+ by (%d+)%%")

    if value then
        self:AddScaledStat(stats, "MP5", value, self.PERCENT_MANA_COST_TO_MP5)
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ParseProcOrConditionalEffects(text, stats)
    local lowerText = string.lower(text or "")

    if string.find(lowerText, "chance")
        or string.find(lowerText, "whenever")
        or string.find(lowerText, "when you")
        or string.find(lowerText, "after you")
        or string.find(lowerText, "your attacks have")
        or string.find(lowerText, "your spells have") then

        -- Try to still parse simple temporary stat gains.
        local parsedAny = self:ParseGenericStatEffects(text, stats)
        parsedAny = self:ParseHealingDamageEffects(text, stats) or parsedAny
        parsedAny = self:ParseAttackPowerEffects(text, stats) or parsedAny

        if not parsedAny then
            stats.UNSCORED_SET_BONUS_EFFECT = (stats.UNSCORED_SET_BONUS_EFFECT or 0) + 1
        end

        return true
    end

    return false
end

function SetBonuses:ParseSetBonusTextLine(text, stats)
    if not text or text == "" then
        return false
    end

    text = string.gsub(text, "^%(%d+%)%s+Set:%s*", "")
    text = string.gsub(text, "^Set:%s*", "")
    text = self:CleanTooltipText(text)

    if not text or text == "" then
        return false
    end

    local parsedAny = false

    if BetterGearScore.ItemParser and BetterGearScore.ItemParser.ParseEffectText then
        if BetterGearScore.ItemParser:ParseEffectText(text, stats, true) then
            parsedAny = true
        end
    end

    if self:ParseGenericStatEffects(text, stats) then
        parsedAny = true
    end

    if self:ParseHealingDamageEffects(text, stats) then
        parsedAny = true
    end

    if self:ParseAttackPowerEffects(text, stats) then
        parsedAny = true
    end

    if self:ParseDefenseTankEffects(text, stats) then
        parsedAny = true
    end

    if self:ParsePercentEffects(text, stats) then
        parsedAny = true
    end

    if self:ParseProcOrConditionalEffects(text, stats) then
        parsedAny = true
    end

    return parsedAny
end

function SetBonuses:ScanItemSetBonuses(itemLink, processedBonuses)
    local stats = {}

    local lines = self:GetTooltipLines(itemLink)
    local setName, equippedCount = self:FindSetHeader(lines)

    if not setName or not equippedCount or equippedCount <= 0 then
        return stats
    end

    processedBonuses = processedBonuses or {}

    local plainSetBonusIndex = 0

    for i = 1, #lines do
        local line = lines[i]

        -- Normal set bonus format:
        -- (2) Set: ...
        -- (4) Set: ...
        local requiredCount, firstBonusText = string.match(line, "^%((%d+)%)%s+Set:%s*(.*)$")

        if requiredCount then
            requiredCount = tonumber(requiredCount)

            local bonusKey = setName .. ":" .. tostring(requiredCount)
            local isActive = equippedCount >= requiredCount

            if isActive and not processedBonuses[bonusKey] then
                processedBonuses[bonusKey] = true

                if firstBonusText and firstBonusText ~= "" then
                    self:ParseSetBonusTextLine(firstBonusText, stats)
                end

                local j = i + 1

                while j <= #lines do
                    local nextLine = lines[j]

                    if self:IsSetBonusStartLine(nextLine) then
                        break
                    end

                    if string.match(nextLine, "^Set:") then
                        break
                    end

                    if string.match(nextLine, "^Black Temple")
                        or string.match(nextLine, "^Sunwell Plateau")
                        or string.match(nextLine, "^Hyjal Summit")
                        or string.match(nextLine, "^Serpentshrine Cavern")
                        or string.match(nextLine, "^Tempest Keep")
                        or string.match(nextLine, "^Karazhan") then
                        break
                    end

                    self:ParseSetBonusTextLine(nextLine, stats)

                    j = j + 1
                end
            end
        end

        -- PvP / older set bonus format:
        -- Set: +35 Resilience Rating.
        --
        -- In this format, active bonuses can appear as plain "Set:" lines,
        -- while inactive later bonuses still appear as "(4) Set:".
        local plainSetText = string.match(line, "^Set:%s*(.+)$")

        if plainSetText then
            plainSetBonusIndex = plainSetBonusIndex + 1

            -- Most plain "Set:" bonuses represent the first active threshold.
            -- Since the tooltip header already says something like (2/5),
            -- only count these if at least 2 pieces are equipped.
            local inferredRequiredCount = 2
            local bonusKey = setName .. ":plain:" .. tostring(plainSetBonusIndex)

            if equippedCount >= inferredRequiredCount and not processedBonuses[bonusKey] then
                processedBonuses[bonusKey] = true
                self:ParseSetBonusTextLine(plainSetText, stats)
            end
        end
    end

    return stats
end

function SetBonuses:MergeStats(target, source)
    for statName, value in pairs(source or {}) do
        self:AddStat(target, statName, value)
    end
end

function SetBonuses:GetEquippedActiveSetBonusStats()
    local totalStats = {}
    local processedBonuses = {}

    if not BetterGearScore.ItemParser or not BetterGearScore.ItemParser.EQUIPMENT_SLOTS then
        return totalStats
    end

    for _, slotInfo in ipairs(BetterGearScore.ItemParser.EQUIPMENT_SLOTS) do
        local slotId = GetInventorySlotInfo(slotInfo.key)
        local itemLink = slotId and GetInventoryItemLink("player", slotId)

        if itemLink then
            local setStats = self:ScanItemSetBonuses(itemLink, processedBonuses)
            self:MergeStats(totalStats, setStats)
        end
    end

    return totalStats
end

function SetBonuses:GetActiveSetBonusStatsForItem(itemLink)
    local stats = {}

    if not itemLink then
        return stats
    end

    local processedBonuses = {}
    local setStats = self:ScanItemSetBonuses(itemLink, processedBonuses)

    self:MergeStats(stats, setStats)

    return stats
end