-- Tooltip.lua

GSPlus = GSPlus or {}
GSPlus.Tooltip = GSPlus.Tooltip or {}

local Tooltip = GSPlus.Tooltip

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

    HEALTH = "Health",
    MANA = "Mana",
    SPELL_PENETRATION = "Spell Penetration",
    ARMOR_PENETRATION = "Armor Penetration",
    MASTERY = "Mastery Rating",
    SCHOOL_SPELLPOWER = "Spell Damage (one school)",

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

local function GetStatDisplayName(statType, profileKey)
    -- For casters and healers, hit / crit / haste are the spell versions, so
    -- label them accordingly (don't show "Haste Rating" for spell haste).
    if profileKey and GSPlus.Calculator then
        local group = GSPlus.Calculator:GetProfileColorCapGroup(profileKey)

        if group == "CASTER_DPS" or group == "HEALER" then
            if statType == "HASTE" then return "Spell Haste Rating" end
            if statType == "HIT" then return "Spell Hit Rating" end
            if statType == "CRITICAL" then return "Spell Critical Strike Rating" end
        end
    end

    return Tooltip.STAT_DISPLAY_NAMES[statType] or statType or "Unknown"
end

function Tooltip:HasAnyStats(stats)
    for _, value in pairs(stats or {}) do
        if value and value > 0 then
            return true
        end
    end

    return false
end

function Tooltip:BuildStatContributionRows(stats, profileKey)
    local rows = {}
    local weightedStatScore = 0

    -- Cap-neutral on purpose: this breakdown explains the displayed score,
    -- which must be identical for everyone with the same gear. Since the
    -- weighted score is a linear sum, the rows add up to it exactly.
    for statType, value in pairs(stats or {}) do
        if GSPlus.Calculator:IsScoringStat(statType) then
            local budgetCost = GSPlus.Calculator:GetStatBudgetCost(statType)
            local roleWeight = GSPlus.Weights:GetWeight(profileKey, statType)
            local budgetValue = GSPlus.Calculator:CalculateBudgetAdjustedStatValue(statType, value)
            local weightedBudgetValue = budgetValue * roleWeight

            if weightedBudgetValue > 0 then
                weightedStatScore = weightedStatScore + weightedBudgetValue

                rows[#rows + 1] = {
                    statType = statType,
                    statName = GetStatDisplayName(statType, profileKey),
                    rawValue = value,
                    budgetCost = budgetCost,
                    roleWeight = roleWeight,
                    budgetValue = budgetValue,
                    weightedBudgetValue = weightedBudgetValue,
                    finalContribution = weightedBudgetValue,
                }
            end
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

    local dpsWeightKey, damageWeightKey = GSPlus.Calculator:GetWeaponWeightKeys(slotKey, itemLink)

    local dpsWeight = GSPlus.Weights:GetWeight(profileKey, dpsWeightKey)
    local damageWeight = GSPlus.Weights:GetWeight(profileKey, damageWeightKey)

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

-- Maps an item's equip location to the character slots it could replace.
Tooltip.EQUIPLOC_TO_SLOTS = {
    INVTYPE_HEAD = { "HeadSlot" },
    INVTYPE_NECK = { "NeckSlot" },
    INVTYPE_SHOULDER = { "ShoulderSlot" },
    INVTYPE_CLOAK = { "BackSlot" },
    INVTYPE_CHEST = { "ChestSlot" },
    INVTYPE_ROBE = { "ChestSlot" },
    INVTYPE_WRIST = { "WristSlot" },
    INVTYPE_HAND = { "HandsSlot" },
    INVTYPE_WAIST = { "WaistSlot" },
    INVTYPE_LEGS = { "LegsSlot" },
    INVTYPE_FEET = { "FeetSlot" },
    INVTYPE_FINGER = { "Finger0Slot", "Finger1Slot" },
    INVTYPE_TRINKET = { "Trinket0Slot", "Trinket1Slot" },
    INVTYPE_WEAPON = { "MainHandSlot", "SecondaryHandSlot" },
    INVTYPE_WEAPONMAINHAND = { "MainHandSlot" },
    INVTYPE_2HWEAPON = { "MainHandSlot" },
    INVTYPE_WEAPONOFFHAND = { "SecondaryHandSlot" },
    INVTYPE_HOLDABLE = { "SecondaryHandSlot" },
    INVTYPE_SHIELD = { "SecondaryHandSlot" },
    INVTYPE_RANGED = { "RangedSlot" },
    INVTYPE_RANGEDRIGHT = { "RangedSlot" },
    INVTYPE_THROWN = { "RangedSlot" },
    INVTYPE_RELIC = { "RangedSlot" },
}

-- Used only by the personal upgrade comparison, so it IS cap-adjusted (both
-- sides of the comparison consistently). Displayed scores never are.
function Tooltip:GetItemOnlyWeightedScore(itemLink, profileKey, slotKey)
    local stats = GSPlus.ItemParser:ParseItemStats(itemLink)

    return GSPlus.Calculator:CalculateWeightedScore(stats, profileKey, slotKey, itemLink, true)
end

-- Compares the hovered item against what the player has equipped in the
-- slot(s) it would occupy. Set bonuses are excluded from both sides so the
-- comparison is item vs item. Returns nil when no comparison makes sense.
function Tooltip:GetUpgradeComparison(itemLink, profileKey)
    local equipLoc = select(9, GetItemInfo(itemLink))
    local slots = equipLoc and self.EQUIPLOC_TO_SLOTS[equipLoc]

    if not slots then
        return nil
    end

    local hoveredScore = self:GetItemOnlyWeightedScore(itemLink, profileKey, slots[1])

    -- A two-hander displaces both hands, so it competes with their sum.
    if equipLoc == "INVTYPE_2HWEAPON" then
        local equippedScore = 0

        for _, slotKey in ipairs({ "MainHandSlot", "SecondaryHandSlot" }) do
            local slotId = GetInventorySlotInfo(slotKey)
            local equippedLink = slotId and GetInventoryItemLink("player", slotId)

            if equippedLink then
                if equippedLink == itemLink then
                    return { isEquipped = true }
                end

                equippedScore = equippedScore + self:GetItemOnlyWeightedScore(equippedLink, profileKey, slotKey)
            end
        end

        return { delta = hoveredScore - equippedScore }
    end

    local worstScore = nil

    for _, slotKey in ipairs(slots) do
        local slotId = GetInventorySlotInfo(slotKey)
        local equippedLink = slotId and GetInventoryItemLink("player", slotId)

        if equippedLink == itemLink then
            return { isEquipped = true }
        end

        local equippedScore = 0

        if equippedLink then
            equippedScore = self:GetItemOnlyWeightedScore(equippedLink, profileKey, slotKey)
        end

        if not worstScore or equippedScore < worstScore then
            worstScore = equippedScore
        end
    end

    if not worstScore then
        return nil
    end

    return { delta = hoveredScore - worstScore }
end

function Tooltip:AddUpgradeComparison(tooltip, itemLink, profileKey)
    if not GSPlus.Options:Get("showUpgradeDelta") then
        return
    end

    local comparison = self:GetUpgradeComparison(itemLink, profileKey)

    if not comparison then
        return
    end

    if comparison.isEquipped then
        tooltip:AddDoubleLine("For You vs Equipped", "|cff888888currently equipped|r", 1, 1, 1, 1, 1, 1)
        return
    end

    local delta = comparison.delta or 0
    local text

    if delta >= 0.05 then
        text = "|cff00ff00+" .. FormatNumber(delta, 1) .. "|r"
    elseif delta <= -0.05 then
        text = "|cffff4040" .. FormatNumber(delta, 1) .. "|r"
    else
        text = "|cff888888+0.0|r"
    end

    tooltip:AddDoubleLine("For You vs Equipped", text, 1, 1, 1, 1, 1, 1)

    -- The comparison is personal: stats the player has capped count for
    -- less in it (but never in the displayed scores). Say so when relevant.
    local stats = GSPlus.ItemParser:ParseItemStats(itemLink)
    local cappedNames = GSPlus.StatCaps:GetCappedStatNames(stats, profileKey)

    if #cappedNames > 0 then
        tooltip:AddLine(
            "|cffff8800You are at/near your " .. table.concat(cappedNames, ", ")
            .. " cap; it counts for less in this comparison.|r",
            1, 0.53, 0, true
        )
    end
end

function Tooltip:AddCompactGearScore(tooltip, profileKey, rawScore, weightedScore, maxBudgetScore, setBonusWeightedScore, itemLink, inspectUnit)
    local coloredWeightedScore = GSPlus.Calculator:ColorizeScore(weightedScore or 0, maxBudgetScore or 0)
    local profileName = GSPlus.Profiles:GetProfileDisplayName(profileKey)

    tooltip:AddLine(" ")
    -- A single headline: the green "gs+" label on the left, the colored score
    -- and the role on the right. (Previously the label appeared twice - once
    -- in a "gs+ - Role" header and again on the score line.)
    tooltip:AddDoubleLine(
        "|cff00ff00gs+|r",
        coloredWeightedScore .. "  |cff808080(" .. profileName .. ")|r",
        1, 1, 1, 1, 1, 1
    )
    if GSPlus.Options:Get("showBudgetScore") then
        tooltip:AddDoubleLine("Budget Score", math.floor(rawScore or 0), 1, 1, 1, 0.8, 0.8, 0.8)
    end

    if itemLink and GSPlus.Options:Get("showLegacyGearScore") then
        local _, classFileName = UnitClass(inspectUnit or "player")
        local legacyScore = GSPlus.LegacyGearScore:GetItemScore(itemLink, classFileName)

        if legacyScore > 0 then
            tooltip:AddDoubleLine("GearScore (legacy)", legacyScore, 1, 1, 1, 0.6, 0.6, 0.6)
        end
    end

    -- "For You vs Equipped" is personal to the viewer's own gear, so it is
    -- omitted on inspected players' items.
    if itemLink and not inspectUnit then
        self:AddUpgradeComparison(tooltip, itemLink, profileKey)
    end

end

function Tooltip:AddDetailedBreakdown(tooltip, stats, profileKey, slotKey, itemLink, setBonusShare, setBonusPieces)
    if not GSPlus.Options:Get("showTooltipBreakdown") then
        return
    end

    if not IsShiftKeyDown() then
        return
    end

    local statRows = self:BuildStatContributionRows(stats, profileKey)
    local weaponRows = self:BuildWeaponContributionRows(stats, profileKey, slotKey, itemLink)

    tooltip:AddLine(" ")
    tooltip:AddLine("|cffffff00Stat Contribution Breakdown|r")
    tooltip:AddLine("|cffaaaaaaValue × Budget Cost × Role Weight = Score|r")

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

    if (setBonusShare or 0) > 0 then
        anyRows = true

        tooltip:AddDoubleLine(
            string.format("Set bonus effect (1/%d)", setBonusPieces or 1),
            "|cff00ff00" .. FormatNumber(setBonusShare, 1) .. "|r",
            0.65, 0.85, 1.0, 0.8, 0.8, 0.8
        )
    end

    if not anyRows then
        tooltip:AddLine("No weighted stats found for this profile.", 0.8, 0.8, 0.8)
    end

    -- Transparency: disclose effects the parser recognized but cannot value.
    if (stats.UNSCORED_EQUIP_EFFECT or 0) > 0 or (stats.UNSCORED_USE_EFFECT or 0) > 0 then
        tooltip:AddLine("Special equip/use effects are not included in the score.", 0.6, 0.6, 0.6)
    end
end

-- When an item tooltip is shown for a slot on the Blizzard inspect window it
-- should be scored for the inspected player, not the viewer. The inspect slot
-- buttons are named "Inspect<Slot>" (InspectHeadSlot, InspectMainHandSlot,
-- ...), so the tooltip's owner reveals the context. Returns unit, profileKey
-- when inspecting, otherwise nil.
function Tooltip:GetInspectContext(tooltip)
    if not (InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()) then
        return nil
    end

    if not tooltip or not tooltip.GetOwner then
        return nil
    end

    local owner = tooltip:GetOwner()
    local ownerName = owner and owner.GetName and owner:GetName()

    if not ownerName or not string.find(ownerName, "^Inspect") then
        return nil
    end

    local unit = (InspectFrame and InspectFrame.unit) or "target"

    if not UnitExists or not UnitExists(unit) then
        return nil
    end

    local profileKey, roleConfident

    if GSPlus.Inspect and GSPlus.Inspect.GetUnitProfile then
        profileKey, roleConfident = GSPlus.Inspect:GetUnitProfile(unit)
    end

    if not profileKey then
        return nil
    end

    -- Role known only when talents are readable; until then the inspected item
    -- is scored as "inspecting..." rather than under a guessed role.
    local complete = roleConfident ~= false

    if complete and GSPlus.Inspect.IsUnitGearComplete then
        complete = GSPlus.Inspect:IsUnitGearComplete(unit)
    end

    return unit, profileKey, complete
end

function Tooltip:AddGearScoreToTooltip(tooltip)
    if not GSPlus.Options:Get("showItemTooltip") then
        return
    end

    -- OnTooltipSetItem can fire more than once for the same tooltip (e.g.
    -- recipes); the flag is cleared in OnTooltipCleared.
    if tooltip.bgsScoreAdded then
        return
    end

    local itemLink = GetTooltipItemLink(tooltip)

    if not itemLink then
        return
    end

    -- Items shown on the Blizzard inspect window are scored for the inspected
    -- player's spec, not the viewer's (a feral druid inspecting a paladin tank
    -- must see the paladin's tank score, not feral weights).
    local inspectUnit, inspectProfile, inspectComplete = self:GetInspectContext(tooltip)

    -- Inspecting someone whose gear has not fully loaded: their role is not
    -- reliably known yet (a half-loaded tank looks like DPS), so don't score
    -- this item under a guessed role. Show a loading line and queue an
    -- inspect; a later hover shows the real score once their gear is in.
    if inspectUnit and not inspectComplete then
        tooltip.bgsScoreAdded = true
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff00ff00gs+|r - inspecting " .. (UnitName(inspectUnit) or "player") .. "...",
            0.65, 0.65, 0.65)

        if GSPlus.Inspect and GSPlus.Inspect.QueueUnitInspect then
            GSPlus.Inspect:QueueUnitInspect(inspectUnit)
        end

        tooltip:Show()
        return
    end

    local profileKey = inspectProfile or GSPlus.Profiles:GetSelectedProfile()

    -- Score the ITEM ONLY. Merging active set bonuses into a single item's
    -- score inflates it against a per-slot color reference (a set bonus is
    -- not part of any one item) - set bonuses are shown as their own line
    -- and scored as their own entry in the total.
    local stats = GSPlus.ItemParser:ParseItemStats(itemLink)
    local setBonusStats = {}

    -- Score the set bonus from the relevant player's own equipped pieces:
    -- the inspected unit when inspecting, otherwise the viewer.
    if GSPlus.SetBonuses then
        if inspectUnit and GSPlus.SetBonuses.GetUnitActiveSetBonusStatsForItem then
            setBonusStats = GSPlus.SetBonuses:GetUnitActiveSetBonusStatsForItem(inspectUnit, itemLink)
        elseif not inspectUnit and GSPlus.SetBonuses.GetActiveSetBonusStatsForItem then
            setBonusStats = GSPlus.SetBonuses:GetActiveSetBonusStatsForItem(itemLink)
        end
    end

    local statBudgetScore = GSPlus.Calculator:CalculateRawStatBudget(stats)
    local weaponBudgetScore = GSPlus.Calculator:CalculateWeaponBudgetScore(stats)
    local rawScore = statBudgetScore + weaponBudgetScore
    local weightedScore = GSPlus.Calculator:CalculateWeightedScore(stats, profileKey, nil, itemLink)
    local maxBudgetScore = GSPlus.Calculator:GetWeightedColorReferenceForItem(profileKey, nil, itemLink)

    -- Nothing scoreable (e.g. a relic whose only effect is a spell-specific
    -- bonus): fall back to an item-level estimate instead of showing nothing.
    local usedLevelFallback = false

    if (rawScore or 0) <= GSPlus.Calculator.MIN_SCOREABLE
        and (weightedScore or 0) <= GSPlus.Calculator.MIN_SCOREABLE then
        local classFileName = select(2, UnitClass(inspectUnit or "player"))
        local fallback = GSPlus.Calculator:GetItemLevelFallbackScore(itemLink, classFileName)

        if fallback <= 0 then
            return
        end

        weightedScore = fallback
        rawScore = fallback
        -- keep maxBudgetScore (the slot's color reference) so the fallback
        -- score is colored like a normal item instead of plain white.
        usedLevelFallback = true
    end

    local setBonusWeightedScore = 0

    if self:HasAnyStats(setBonusStats) then
        setBonusWeightedScore = GSPlus.Calculator:CalculateWeightedStatScore(setBonusStats, profileKey)
    end

    -- Amortize the set bonus evenly across the equipped set pieces (so it is
    -- counted once for the whole set) and fold each piece's share into this
    -- item's score and its breakdown row, rather than a separate summary line.
    local setBonusShare, setBonusPieces = 0, 0

    if setBonusWeightedScore > 0 and GSPlus.SetBonuses and GSPlus.SetBonuses.GetSetNameForItem then
        local setName = GSPlus.SetBonuses:GetSetNameForItem(itemLink)

        if setName then
            local counts = GSPlus.SetBonuses:GetUnitSetCounts(inspectUnit or "player")
            setBonusPieces = math.max(1, counts[setName] or 1)
            setBonusShare = setBonusWeightedScore / setBonusPieces
            weightedScore = (weightedScore or 0) + setBonusShare
        end
    end

    tooltip.bgsScoreAdded = true

    self:AddCompactGearScore(tooltip, profileKey, rawScore, weightedScore, maxBudgetScore, 0, itemLink, inspectUnit)

    if usedLevelFallback then
        if GSPlus.Options:Get("showTooltipBreakdown") and IsShiftKeyDown() then
            tooltip:AddLine("Estimated from item level (special effect not scoreable).", 0.6, 0.6, 0.6)
        end
    else
        self:AddDetailedBreakdown(tooltip, stats, profileKey, nil, itemLink, setBonusShare, setBonusPieces)
    end

    tooltip:Show()
end

function Tooltip:HookTooltip(tooltipFrame)
    if not tooltipFrame or not tooltipFrame.HookScript then
        return
    end

    tooltipFrame:HookScript("OnTooltipSetItem", function(tooltip)
        GSPlus.Tooltip:AddGearScoreToTooltip(tooltip)
    end)

    tooltipFrame:HookScript("OnTooltipCleared", function(tooltip)
        tooltip.bgsScoreAdded = nil
    end)
end

function Tooltip:HookTooltips()
    if self.hooked then
        return
    end

    self:HookTooltip(GameTooltip)
    self:HookTooltip(ItemRefTooltip)
    self:HookTooltip(ShoppingTooltip1)
    self:HookTooltip(ShoppingTooltip2)

    self.hooked = true
end

Tooltip:HookTooltips()