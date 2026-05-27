-- Item Parser - Extract stats from equipped items

GearScoreItemParser = {}

-- WoW equipment slot IDs (1-19)
GearScoreItemParser.EQUIPMENT_SLOTS = {
    1,   -- Head
    2,   -- Neck
    3,   -- Shoulder
    4,   -- Chest
    5,   -- Waist
    6,   -- Legs
    7,   -- Feet
    8,   -- Wrist
    9,   -- Hands
    10,  -- Finger 1
    11,  -- Finger 2
    12,  -- Back
    13,  -- Main Hand
    14,  -- Off Hand
    15,  -- Ranged
    16,  -- Tabard
}

-- Map stat names to internal stat types
GearScoreItemParser.STAT_MAPPING = {
    ["Strength"] = "STRENGTH",
    ["Agility"] = "AGILITY",
    ["Intellect"] = "INTELLECT",
    ["Stamina"] = "STAMINA",
    ["Spirit"] = "SPIRIT",
    ["Armor"] = "ARMOR",
    ["Attack Power"] = "ATTACKPOWER",
    ["Spell Power"] = "SPELLPOWER",
    ["Defense"] = "DEFENSE",
    ["Dodge"] = "DODGE",
    ["Parry"] = "PARRY",
    ["Block"] = "BLOCK",
    ["Critical Strike"] = "CRITICAL",
    ["Haste"] = "HASTE",
}

-- Parse an item link and extract stats
function GearScoreItemParser:ParseItemStats(itemLink)
    if not itemLink then
        return {}
    end
    
    local stats = {}
    
    -- Get item info - returns name, link, rarity, level, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice
    local itemName, _, rarity, itemLevel, reqLevel, itemClass, itemSubclass = GetItemInfo(itemLink)
    
    if not itemName then
        return {}
    end
    
    -- Use GetItemStats to extract stats
    -- This is the most reliable way to get item stats
    local itemStats = GetItemStats(itemLink)
    
    if itemStats then
        for statName, value in pairs(itemStats) do
            local internalStat = self.STAT_MAPPING[statName]
            if internalStat then
                stats[internalStat] = (stats[internalStat] or 0) + value
            end
        end
    end
    
    return stats
end

-- Get all equipped items and their stats
function GearScoreItemParser:GetEquippedItems()
    local equippedItems = {}
    
    for _, slot in ipairs(self.EQUIPMENT_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slot)
        if itemLink then
            local stats = self:ParseItemStats(itemLink)
            if next(stats) then  -- If stats table is not empty
                equippedItems[slot] = {
                    link = itemLink,
                    stats = stats,
                }
            end
        end
    end
    
    return equippedItems
end

-- Get stats for a specific equipped slot
function GearScoreItemParser:GetItemStatsInSlot(slot)
    local itemLink = GetInventoryItemLink("player", slot)
    if itemLink then
        return self:ParseItemStats(itemLink)
    end
    return {}
end

-- Get item name from link
function GearScoreItemParser:GetItemName(itemLink)
    if not itemLink then
        return "Unknown"
    end
    local name = GetItemInfo(itemLink)
    return name or "Unknown"
end

-- Get slot name from slot ID
function GearScoreItemParser:GetSlotName(slot)
    local slotNames = {
        [1] = "Head",
        [2] = "Neck",
        [3] = "Shoulder",
        [4] = "Chest",
        [5] = "Waist",
        [6] = "Legs",
        [7] = "Feet",
        [8] = "Wrist",
        [9] = "Hands",
        [10] = "Finger 1",
        [11] = "Finger 2",
        [12] = "Back",
        [13] = "Main Hand",
        [14] = "Off Hand",
        [15] = "Ranged",
        [16] = "Tabard",
    }
    return slotNames[slot] or "Unknown"
end
