-- Tooltip.lua

BetterGearScore = BetterGearScore or {}
BetterGearScore.Tooltip = BetterGearScore.Tooltip or {}

local Tooltip = BetterGearScore.Tooltip

Tooltip.STAT_DISPLAY_NAMES = {
    STRENGTH = "Strength",
    AGILITY = "Agility",
    INTELLECT = "Intellect",
    STAMINA = "Stamina",
    SPIRIT = "Spirit",

    ARMOR = "Armor",
    ATTACKPOWER = "Attack Power",
    RANGED_ATTACKPOWER = "Ranged Attack Power",
    FERAL_ATTACKPOWER = "Feral Attack Power",

    SPELLPOWER = "Spell Power",
    HEALING = "Healing",

    DEFENSE = "Defense Rating",
    DODGE = "Dodge Rating",
    PARRY = "Parry Rating",
    BLOCK = "Block Rating",
    BLOCK_VALUE = "Block Value",
    CRITICAL = "Critical Strike Rating",
    HIT = "Hit Rating",
    HASTE = "Haste Rating",
    EXPERTISE = "Expertise Rating",
    RESILIENCE = "Resilience Rating",
    WEAPON_SKILL = "Weapon Skill",

    MP5 = "Mana per 5 sec",
    HP5 = "Health per 5 sec",

    ARCANE_RESISTANCE = "Arcane Resistance",
    FIRE_RESISTANCE = "Fire Resistance",
    FROST_RESISTANCE = "Frost Resistance",
    NATURE_RESISTANCE = "Nature Resistance",
    SHADOW_RESISTANCE = "Shadow Resistance",
}

local function GetTooltipItemLink(tooltip)
    local _, itemLink = tooltip:GetItem()
    return itemLink
end

local function FormatNumber(value, decimals)
    value = value or 0

    if decimals and decimals > 0 then
        return string.format("%." .. decimals .. "f", value)
    end

    return tostring(math.floor(value + 0.5))
end

local function GetStatDisplayName(statType)
    return Tooltip.STAT_DISPLAY_NAMES[statType] or statType or "Unknown"
end

function Tooltip:CopyStats(stats)
    local copy = {}

    for statType, value in pairs(stats or {}) do
        copy[statType] = value
    end

    return copy
end

function Tooltip:MergeStats(target, source)
    for statType, value in pairs(source or {}) do
        value = tonumber(value)

        if value and value > 0 then
            target[statType] = (target[statType] or 0) + value
        end
    end
end

function Tooltip:HasAnyStats(stats)
    for _, value in pairs(stats or {}) do
        if value and value > 0 then
            return true
        end
    end

    return false
end

function Tooltip:GetTooltipStatsWithActiveSetBonuses(itemLink)
    local itemStats = BetterGearScore.ItemParser:ParseItemStats(itemLink)
    local combinedStats = self:CopyStats(itemStats)
    local setBonusStats = {}

    if BetterGearScore.SetBonuses and BetterGearScore.SetBonuses.GetActiveSetBonusStatsForItem then
        setBonusStats = BetterGearScore.SetBonuses:GetActiveSetBonusStatsForItem(itemLink)
        self:MergeStats(combinedStats, setBonusStats)
    end

    return combinedStats, itemStats, setBonusStats
end

function Tooltip:BuildStatContributionRows(stats, profileKey)
    local rows = {}
    local exponent = BetterGearScore.Calculator.ITEM_BUDGET_EXPONENT or 1.7095
    local totalPower = 0

    for statType, value in pairs(stats or {}) do
        if not BetterGearScore.Calculator:IsWeaponStat(statType) then
            local budgetCost = BetterGearScore.Calculator:GetStatBudgetCost(statType)
            local roleWeight = BetterGearScore.Weights:GetWeight(profileKey, statType)
            local budgetValue = BetterGearScore.Calculator:CalculateBudgetAdjustedStatValue(statType, value)
            local weightedBudgetValue = budgetValue * roleWeight

            if weightedBudgetValue > 0 then
                local powerValue = math.pow(weightedBudgetValue, exponent)

                totalPower = totalPower + powerValue

                rows[#rows + 1] = {
                    statType = statType,
                    statName = GetStatDisplayName(statType),
                    rawValue = value,
                    budgetCost = budgetCost,
                    roleWeight = roleWeight,
                    budgetValue = budgetValue,
                    weightedBudgetValue = weightedBudgetValue,
                    powerValue = powerValue,
                    finalContribution = 0,
                }
            end
        end
    end

    local weightedStatScore = 0

    if totalPower > 0 then
        weightedStatScore = math.pow(totalPower, 1 / exponent)

        for _, row in ipairs(rows) do
            row.finalContribution = weightedStatScore * (row.powerValue / totalPower)
        end
    end

    table.sort(rows, function(a, b)
        return (a.finalContribution or 0) > (b.finalContribution or 0)
    end)

    return rows, weightedStatScore
end

function Tooltip:BuildWeaponContributionRows(stats, profileKey, slotKey, itemLink)
    local rows = {}

    if not stats then
        return rows, 0
    end

    local weaponDps = stats.WEAPON_DPS or 0
    local averageDamage = stats.WEAPON_AVERAGE_DAMAGE or 0

    if weaponDps <= 0 then
        return rows, 0
    end

    local dpsWeightKey, damageWeightKey = BetterGearScore.Calculator:GetWeaponWeightKeys(slotKey, itemLink)

    local dpsWeight = BetterGearScore.Weights:GetWeight(profileKey, dpsWeightKey)
    local damageWeight = BetterGearScore.Weights:GetWeight(profileKey, damageWeightKey)

    local dpsContribution = weaponDps * dpsWeight
    local damageContribution = averageDamage * damageWeight

    if dpsContribution > 0 then
        rows[#rows + 1] = {
            statName = dpsWeightKey == "RANGED_WEAPON_DPS" and "Ranged Weapon DPS" or "Melee Weapon DPS",
            rawValue = weaponDps,
            budgetCost = 1.0,
            roleWeight = dpsWeight,
            finalContribution = dpsContribution,
        }
    end

    if damageContribution > 0 then
        rows[#rows + 1] = {
            statName = damageWeightKey == "RANGED_WEAPON_DAMAGE" and "Ranged Avg Damage" or "Melee Avg Damage",
            rawValue = averageDamage,
            budgetCost = 1.0,
            roleWeight = damageWeight,
            finalContribution = damageContribution,
        }
    end

    table.sort(rows, function(a, b)
        return (a.finalContribution or 0) > (b.finalContribution or 0)
    end)

    return rows, dpsContribution + damageContribution
end

function Tooltip:AddCompactGearScore(tooltip, profileKey, rawScore, weightedScore, maxBudgetScore, hasActiveSetBonuses)
    local coloredWeightedScore = BetterGearScore.Calculator:ColorizeScore(weightedScore or 0, maxBudgetScore or 0)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ff00BetterGearScore|r - " .. BetterGearScore.Profiles:GetProfileDisplayName(profileKey))
    tooltip:AddDoubleLine("Weighted Score", coloredWeightedScore, 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine("Budget Score", math.floor(rawScore or 0), 1, 1, 1, 0.8, 0.8, 0.8)

    if hasActiveSetBonuses then
        tooltip:AddLine("Includes active set bonuses.", 0.65, 0.85, 1.0)
    end

    if not IsShiftKeyDown() then
        tooltip:AddLine("Hold Shift for stat breakdown.", 0.65, 0.65, 0.65)
    end
end

function Tooltip:AddDetailedBreakdown(tooltip, stats, profileKey, slotKey, itemLink, setBonusStats)
    if not IsShiftKeyDown() then
        return
    end

    local statRows = self:BuildStatContributionRows(stats, profileKey)
    local weaponRows = self:BuildWeaponContributionRows(stats, profileKey, slotKey, itemLink)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cffffff00Stat Contribution Breakdown|r")
    tooltip:AddLine("|cffaaaaaaValue × Budget Cost × Role Weight → Score|r")

    if self:HasAnyStats(setBonusStats) then
        tooltip:AddLine("|cff66ccffActive set bonuses are included in the values below.|r")
    end

    local anyRows = false

    for _, row in ipairs(statRows) do
        anyRows = true

        local leftText = row.statName .. " +" .. FormatNumber(row.rawValue, 0)
        local rightText =
            FormatNumber(row.budgetCost, 2)
            .. " × "
            .. FormatNumber(row.roleWeight, 2)
            .. " = |cff00ff00"
            .. FormatNumber(row.finalContribution, 1)
            .. "|r"

        tooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.8, 0.8, 0.8)
    end

    for _, row in ipairs(weaponRows) do
        anyRows = true

        local leftText = row.statName .. " " .. FormatNumber(row.rawValue, 1)
        local rightText =
            FormatNumber(row.roleWeight, 2)
            .. " = |cff00ff00"
            .. FormatNumber(row.finalContribution, 1)
            .. "|r"

        tooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 0.8, 0.8, 0.8)
    end

    if not anyRows then
        tooltip:AddLine("No weighted stats found for this profile.", 0.8, 0.8, 0.8)
    end
end

function Tooltip:AddGearScoreToTooltip(tooltip)
    local itemLink = GetTooltipItemLink(tooltip)

    if not itemLink then
        return
    end

    local profileKey = BetterGearScore.Profiles:GetSelectedProfile()
    local stats, _, setBonusStats = self:GetTooltipStatsWithActiveSetBonuses(itemLink)

    local statBudgetScore = BetterGearScore.Calculator:CalculateRawStatBudget(stats)
    local weaponBudgetScore = BetterGearScore.Calculator:CalculateWeaponBudgetScore(stats)
    local rawScore = statBudgetScore + weaponBudgetScore
    local weightedScore = BetterGearScore.Calculator:CalculateWeightedScore(stats, profileKey, nil, itemLink)
    local maxBudgetScore = BetterGearScore.Calculator:GetWeightedColorReferenceForItem(profileKey, nil, itemLink)

    if not rawScore or rawScore <= 0 then
        return
    end

    local hasActiveSetBonuses = self:HasAnyStats(setBonusStats)

    self:AddCompactGearScore(tooltip, profileKey, rawScore, weightedScore, maxBudgetScore, hasActiveSetBonuses)
    self:AddDetailedBreakdown(tooltip, stats, profileKey, nil, itemLink, setBonusStats)

    tooltip:Show()
end

function Tooltip:HookTooltips()
    if self.hooked then
        return
    end

    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            BetterGearScore.Tooltip:AddGearScoreToTooltip(tooltip)
        end)
    end

    if ItemRefTooltip then
        ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
            BetterGearScore.Tooltip:AddGearScoreToTooltip(tooltip)
        end)
    end

    self.hooked = true
end

Tooltip:HookTooltips()