-- StatWeights.lua

local Weights = GSPlus.Weights

Weights.BASE_STATS = {
    "STRENGTH",
    "AGILITY",
    "INTELLECT",
    "STAMINA",
    "SPIRIT",
}

Weights.OTHER_STATS = {
    "ARMOR",
    "ATTACKPOWER",
    "RANGED_ATTACKPOWER",
    "FERAL_ATTACKPOWER",

    "SPELLPOWER",
    "HEALING",

    "DEFENSE",
    "DODGE",
    "PARRY",
    "BLOCK",
    "BLOCK_VALUE",
    "CRITICAL",
    "HIT",
    "HASTE",
    "EXPERTISE",
    "RESILIENCE",
    "WEAPON_SKILL",

    "MP5",
    "HP5",

    "ARCANE_RESISTANCE",
    "FIRE_RESISTANCE",
    "FROST_RESISTANCE",
    "NATURE_RESISTANCE",
    "SHADOW_RESISTANCE",

    "MELEE_WEAPON_DPS",
    "MELEE_WEAPON_DAMAGE",
    "RANGED_WEAPON_DPS",
    "RANGED_WEAPON_DAMAGE",
}

Weights.PROFILE_WEIGHTS = {
    -- Hit > Expertise > Crit > Strength/AP > ArmorPen > Haste
    WARRIOR_DPS = {
        STRENGTH = 0.85,
        AGILITY = 0.85,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.85,
        CRITICAL = 0.85,
        HIT = 1,
        HASTE = 0.45,
        EXPERTISE = 0.95,
        ARMOR_PENETRATION = 0.9,
        MELEE_WEAPON_DPS = 1,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    -- Survival: Stamina/Defense/avoidance (uncrittable); Threat: Expertise > Hit > Str/Crit
    WARRIOR_TANK = {
        STRENGTH = 0.4,
        AGILITY = 0.4,
        STAMINA = 1,
        ARMOR = 0.45,
        ATTACKPOWER = 0.4,
        DEFENSE = 0.65,
        DODGE = 0.6,
        PARRY = 0.6,
        BLOCK = 0.4,
        BLOCK_VALUE = 0.4,
        CRITICAL = 0.25,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.55,
        RESILIENCE = 0.55,
        ARMOR_PENETRATION = 0.1,
        MELEE_WEAPON_DPS = 0.4,
        MELEE_WEAPON_DAMAGE = 0.2,
    },

    -- Expertise > Hit > Strength/AP > Crit/Agility
    PALADIN_DPS = {
        STRENGTH = 0.85,
        AGILITY = 0.85,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.85,
        CRITICAL = 0.7,
        HIT = 0.95,
        HASTE = 0.45,
        EXPERTISE = 1,
        ARMOR_PENETRATION = 0.3,
        MELEE_WEAPON_DPS = 1,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    -- Survival: Stamina/Defense/avoidance; Threat: Spell Power/Expertise/Hit
    PALADIN_TANK = {
        STRENGTH = 0.4,
        INTELLECT = 0.4,
        STAMINA = 1,
        ARMOR = 0.45,
        ATTACKPOWER = 0.4,
        SPELLPOWER = 0.55,
        DEFENSE = 0.65,
        DODGE = 0.6,
        PARRY = 0.6,
        BLOCK = 0.5,
        BLOCK_VALUE = 0.45,
        CRITICAL = 0.3,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.55,
        RESILIENCE = 0.55,
        MP5 = 0.1,
        MELEE_WEAPON_DPS = 0.3,
        MELEE_WEAPON_DAMAGE = 0.15,
    },

    -- Healing > Intellect > Spell Crit > MP5 > Stamina
    PALADIN_HEALER = {
        INTELLECT = 0.4,
        STAMINA = 0.2,
        SPIRIT = 0.05,
        SPELLPOWER = 0.1,
        HEALING = 1,
        CRITICAL = 0.35,
        HASTE = 0.25,
        MP5 = 0.1,
    },

    -- Hit > ArmorPen > Haste > Agility > Crit > AP (ranged weapon heavily weighted)
    HUNTER_DPS = {
        AGILITY = 0.8,
        INTELLECT = 0.1,
        STAMINA = 0.2,
        ARMOR = 0.05,
        ATTACKPOWER = 0.5,
        RANGED_ATTACKPOWER = 0.8,
        CRITICAL = 0.7,
        HIT = 1,
        HASTE = 0.85,
        ARMOR_PENETRATION = 0.95,
        RANGED_WEAPON_DPS = 1,
        RANGED_WEAPON_DAMAGE = 0.5,
    },

    -- Expertise > Hit > Haste > Agility > Crit > Str/AP > ArmorPen
    ROGUE_DPS = {
        STRENGTH = 0.35,
        AGILITY = 0.7,
        STAMINA = 0.2,
        ARMOR = 0.05,
        ATTACKPOWER = 0.35,
        CRITICAL = 0.55,
        HIT = 0.9,
        HASTE = 0.75,
        EXPERTISE = 1,
        ARMOR_PENETRATION = 0.85,
        MELEE_WEAPON_DPS = 1,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    -- Spell Haste > Healing > Int/Spirit > Crit > MP5
    PRIEST_HEALER = {
        INTELLECT = 0.4,
        STAMINA = 0.2,
        SPIRIT = 0.4,
        SPELLPOWER = 0.1,
        HEALING = 1,
        CRITICAL = 0.3,
        HASTE = 0.5,
        MP5 = 0.1,
    },

    -- Spell Power > Spell Hit > Crit > Int/Spirit/MP5 (shadow)
    PRIEST_DPS = {
        INTELLECT = 0.4,
        SPIRIT = 0.25,
        SPELLPOWER = 1,
        CRITICAL = 0.7,
        HIT = 0.85,
        HASTE = 0.65,
        MP5 = 0.05,
    },

    -- Spell Hit > Spell Haste > Spell Power > Crit > Int > MP5 > Stamina
    SHAMAN_ELEMENTAL = {
        INTELLECT = 0.45,
        STAMINA = 0.15,
        SPELLPOWER = 1,
        CRITICAL = 0.7,
        HIT = 1,
        HASTE = 0.95,
        MP5 = 0.15,
    },

    -- Expertise > Strength > Hit > Haste > Crit > Agility > AP
    SHAMAN_ENHANCEMENT = {
        STRENGTH = 0.9,
        AGILITY = 0.55,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.9,
        CRITICAL = 0.6,
        HIT = 0.85,
        HASTE = 0.7,
        EXPERTISE = 1,
        ARMOR_PENETRATION = 0.3,
        MELEE_WEAPON_DPS = 1,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    -- Healing > MP5 > Int > Spell Haste > Crit > Stamina
    SHAMAN_HEALER = {
        INTELLECT = 0.35,
        STAMINA = 0.2,
        SPIRIT = 0.1,
        SPELLPOWER = 0.1,
        HEALING = 1,
        CRITICAL = 0.25,
        HASTE = 0.3,
        MP5 = 0.15,
    },

    -- Spell Hit > Spell Haste > Spell Power > Crit > Intellect
    MAGE_DPS = {
        INTELLECT = 0.45,
        SPELLPOWER = 1,
        CRITICAL = 0.7,
        HIT = 1,
        HASTE = 0.95,
    },

    -- Spell Hit > Spell Haste > Spell Power > Crit > Intellect
    WARLOCK_DPS = {
        INTELLECT = 0.4,
        SPIRIT = 0.05,
        SPELLPOWER = 1,
        CRITICAL = 0.7,
        HIT = 1,
        HASTE = 0.95,
    },

    -- Agility > Hit/Expertise > Strength > Crit > Haste > AP/FeralAP > ArmorPen
    DRUID_FERAL = {
        STRENGTH = 0.85,
        AGILITY = 1,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.85,
        FERAL_ATTACKPOWER = 0.85,
        CRITICAL = 0.65,
        HIT = 0.95,
        HASTE = 0.4,
        EXPERTISE = 0.95,
        ARMOR_PENETRATION = 0.85,
    },

    -- Spell Hit > Spell Power > Spell Haste > Crit > Int > Spirit > MP5
    DRUID_BALANCE = {
        INTELLECT = 0.45,
        SPIRIT = 0.2,
        SPELLPOWER = 1,
        CRITICAL = 0.7,
        HIT = 1,
        HASTE = 0.85,
        MP5 = 0.05,
    },

    -- Healing > Spell Haste > Int/Spirit/MP5 > Crit
    DRUID_RESTO = {
        INTELLECT = 0.35,
        STAMINA = 0.2,
        SPIRIT = 0.35,
        SPELLPOWER = 0.1,
        HEALING = 1,
        CRITICAL = 0.25,
        HASTE = 0.4,
        MP5 = 0.15,
    },

    -- Expertise/Agility > Hit > Stamina > Strength > Defense > Crit > Dodge > Haste > AP > Armor
    DRUID_TANK = {
        STRENGTH = 0.65,
        AGILITY = 1,
        STAMINA = 1,
        ARMOR = 0.5,
        ATTACKPOWER = 0.5,
        FERAL_ATTACKPOWER = 0.5,
        DEFENSE = 0.6,
        DODGE = 0.5,
        CRITICAL = 0.55,
        HIT = 0.9,
        HASTE = 0.4,
        EXPERTISE = 1,
        RESILIENCE = 0.45,
    },

    DEATHKNIGHT_DPS = {
        STRENGTH = 1,
        AGILITY = 1,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.9,
        CRITICAL = 0.85,
        HIT = 1,
        HASTE = 0.85,
        EXPERTISE = 1,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.5,
        MELEE_WEAPON_DPS = 1,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    DEATHKNIGHT_TANK = {
        STRENGTH = 0.5,
        AGILITY = 0.5,
        STAMINA = 1,
        ARMOR = 0.35,
        ATTACKPOWER = 0.3,
        DEFENSE = 1,
        DODGE = 0.9,
        PARRY = 0.9,
        CRITICAL = 0.15,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.7,
        RESILIENCE = 0.65,
        HP5 = 0.15,
        MELEE_WEAPON_DPS = 0.35,
        MELEE_WEAPON_DAMAGE = 0.15,
    },

}

-- Stats that derive their role value from another stat, so the 18 profile
-- tables don't need explicit entries for them. The budget cost (see
-- Calculator.STAT_BUDGET_COST) handles the magnitude conversion.
Weights.STAT_WEIGHT_ALIASES = {
    HEALTH = "STAMINA",
    MANA = "INTELLECT",
    ARMOR_PENETRATION = "ATTACKPOWER",
    ARMOR_PENETRATION_RATING = "ATTACKPOWER",
    SPELL_PENETRATION = "SPELLPOWER",
    -- Single-school spell damage counts at the general spell power weight
    -- (BiS lists agree matching-school gear is top-tier for that school).
    SCHOOL_SPELLPOWER = "SPELLPOWER",
    -- Placeholder until proper per-spec values exist (Cata): mastery is a
    -- throughput secondary, so crit is the closest stand-in.
    MASTERY = "CRITICAL",
}

function Weights:ClampWeight(weight)
    weight = tonumber(weight) or 0.0

    if weight < 0 then
        return 0.0
    end

    if weight > 1 then
        return 1.0
    end

    return weight
end

function Weights:GetWeight(profileKey, statType)
    if not profileKey then
        return 0.0
    end

    local profileWeights = self.PROFILE_WEIGHTS[profileKey]

    if not profileWeights then
        return 0.0
    end

    local weight = profileWeights[statType]

    if weight == nil then
        local alias = self.STAT_WEIGHT_ALIASES[statType]

        if alias then
            weight = profileWeights[alias]
        end
    end

    return self:ClampWeight(weight or 0.0)
end

function Weights:GetProfileWeights(profileKey)
    return self.PROFILE_WEIGHTS[profileKey] or {}
end