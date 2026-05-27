-- Class-specific stat weights for Gear Score calculation
-- Higher weight = stat is more valuable for that class

GearScoreWeights = {}

-- Base stat weights for reference
GearScoreWeights.BASE_STATS = {
    "STRENGTH",
    "AGILITY", 
    "INTELLECT",
    "STAMINA",
    "SPIRIT",
}

-- Other stats
GearScoreWeights.OTHER_STATS = {
    "ARMOR",
    "ATTACKPOWER",
    "SPELLPOWER",
    "DEFENSE",
    "DODGE",
    "PARRY",
    "BLOCK",
    "CRITICAL",
    "HASTE",
}

-- Class-specific weight multipliers
-- Format: ClassName -> StatType -> Weight (1.0 = neutral value)
GearScoreWeights.CLASS_WEIGHTS = {
    -- Warrior: Melee DPS/Tank - values Strength, Stamina, and Armor
    WARRIOR = {
        STRENGTH = 1.2,
        AGILITY = 0.7,
        INTELLECT = 0.2,
        STAMINA = 1.1,
        SPIRIT = 0.3,
        ARMOR = 0.8,
        ATTACKPOWER = 1.0,
        SPELLPOWER = 0.0,
        DEFENSE = 1.0,
        DODGE = 0.8,
        PARRY = 0.8,
        BLOCK = 0.9,
        CRITICAL = 0.9,
        HASTE = 0.8,
    },
    
    -- Paladin: Hybrid - values Strength, Stamina, Intellect for healing/tanking
    PALADIN = {
        STRENGTH = 1.0,
        AGILITY = 0.6,
        INTELLECT = 1.1,
        STAMINA = 1.0,
        SPIRIT = 0.9,
        ARMOR = 0.7,
        ATTACKPOWER = 0.9,
        SPELLPOWER = 0.9,
        DEFENSE = 1.0,
        DODGE = 0.7,
        PARRY = 0.7,
        BLOCK = 1.0,
        CRITICAL = 0.7,
        HASTE = 0.6,
    },
    
    -- Hunter: Ranged DPS - values Agility and Attack Power
    HUNTER = {
        STRENGTH = 0.7,
        AGILITY = 1.3,
        INTELLECT = 0.6,
        STAMINA = 1.0,
        SPIRIT = 0.4,
        ARMOR = 0.6,
        ATTACKPOWER = 1.1,
        SPELLPOWER = 0.0,
        DEFENSE = 0.6,
        DODGE = 0.9,
        PARRY = 0.5,
        BLOCK = 0.4,
        CRITICAL = 1.0,
        HASTE = 0.9,
    },
    
    -- Rogue: Melee DPS - heavily values Agility and Attack Power
    ROGUE = {
        STRENGTH = 0.8,
        AGILITY = 1.4,
        INTELLECT = 0.2,
        STAMINA = 0.9,
        SPIRIT = 0.2,
        ARMOR = 0.5,
        ATTACKPOWER = 1.2,
        SPELLPOWER = 0.0,
        DEFENSE = 0.4,
        DODGE = 1.0,
        PARRY = 0.3,
        BLOCK = 0.2,
        CRITICAL = 1.1,
        HASTE = 1.0,
    },
    
    -- Priest: Caster - values Intellect and Spirit
    PRIEST = {
        STRENGTH = 0.2,
        AGILITY = 0.5,
        INTELLECT = 1.4,
        STAMINA = 0.8,
        SPIRIT = 1.2,
        ARMOR = 0.3,
        ATTACKPOWER = 0.0,
        SPELLPOWER = 1.3,
        DEFENSE = 0.3,
        DODGE = 0.6,
        PARRY = 0.2,
        BLOCK = 0.3,
        CRITICAL = 0.7,
        HASTE = 0.9,
    },
    
    -- Death Knight: Melee DPS/Tank - values Strength and Stamina
    DEATHKNIGHT = {
        STRENGTH = 1.3,
        AGILITY = 0.6,
        INTELLECT = 0.3,
        STAMINA = 1.2,
        SPIRIT = 0.2,
        ARMOR = 0.7,
        ATTACKPOWER = 1.1,
        SPELLPOWER = 0.2,
        DEFENSE = 0.9,
        DODGE = 0.7,
        PARRY = 0.8,
        BLOCK = 0.8,
        CRITICAL = 0.8,
        HASTE = 0.7,
    },
    
    -- Shaman: Hybrid - values Intellect, Strength/Agility depending on spec
    SHAMAN = {
        STRENGTH = 0.9,
        AGILITY = 0.9,
        INTELLECT = 1.2,
        STAMINA = 1.0,
        SPIRIT = 1.0,
        ARMOR = 0.6,
        ATTACKPOWER = 0.9,
        SPELLPOWER = 1.0,
        DEFENSE = 0.6,
        DODGE = 0.7,
        PARRY = 0.6,
        BLOCK = 0.7,
        CRITICAL = 0.8,
        HASTE = 0.8,
    },
    
    -- Mage: Caster - values Intellect and Spell Power highly
    MAGE = {
        STRENGTH = 0.1,
        AGILITY = 0.4,
        INTELLECT = 1.5,
        STAMINA = 0.7,
        SPIRIT = 0.8,
        ARMOR = 0.2,
        ATTACKPOWER = 0.0,
        SPELLPOWER = 1.4,
        DEFENSE = 0.2,
        DODGE = 0.5,
        PARRY = 0.1,
        BLOCK = 0.2,
        CRITICAL = 0.8,
        HASTE = 1.0,
    },
    
    -- Warlock: Caster - values Intellect and Spell Power
    WARLOCK = {
        STRENGTH = 0.1,
        AGILITY = 0.4,
        INTELLECT = 1.4,
        STAMINA = 0.8,
        SPIRIT = 0.7,
        ARMOR = 0.2,
        ATTACKPOWER = 0.0,
        SPELLPOWER = 1.3,
        DEFENSE = 0.2,
        DODGE = 0.5,
        PARRY = 0.1,
        BLOCK = 0.2,
        CRITICAL = 0.7,
        HASTE = 0.8,
    },
    
    -- Druid: Hybrid - varies greatly by spec (balance/resto/feral)
    DRUID = {
        STRENGTH = 0.8,
        AGILITY = 1.0,
        INTELLECT = 1.1,
        STAMINA = 1.0,
        SPIRIT = 1.0,
        ARMOR = 0.8,
        ATTACKPOWER = 1.0,
        SPELLPOWER = 1.0,
        DEFENSE = 0.6,
        DODGE = 0.9,
        PARRY = 0.6,
        BLOCK = 0.6,
        CRITICAL = 0.8,
        HASTE = 0.8,
    },
}

-- Get weight for a specific stat and class
function GearScoreWeights:GetWeight(className, statType)
    if not self.CLASS_WEIGHTS[className] then
        return 1.0  -- Default neutral weight
    end
    return self.CLASS_WEIGHTS[className][statType] or 1.0
end

-- Get all weights for a class
function GearScoreWeights:GetClassWeights(className)
    return self.CLASS_WEIGHTS[className] or {}
end
