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
    -- Death Knight (Wrath/Cata clients only). Sparse on purpose: stats not
    -- listed default to 0 via GetWeight.
    DEATHKNIGHT_DPS = {
        STRENGTH = 1.0,
        AGILITY = 0.45,
        STAMINA = 0.35,
        ARMOR = 0.05,
        ATTACKPOWER = 0.90,
        CRITICAL = 0.85,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 1.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.50,
        MELEE_WEAPON_DPS = 1.0,
        MELEE_WEAPON_DAMAGE = 0.45,
    },

    DEATHKNIGHT_TANK = {
        STRENGTH = 0.50,
        AGILITY = 0.50,
        STAMINA = 1.0,
        ARMOR = 0.35,
        ATTACKPOWER = 0.30,
        DEFENSE = 1.0,
        DODGE = 0.90,
        PARRY = 0.90,
        CRITICAL = 0.15,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.70,
        RESILIENCE = 0.65,
        HP5 = 0.15,
        MELEE_WEAPON_DPS = 0.35,
        MELEE_WEAPON_DAMAGE = 0.15,
    },

    WARRIOR_DPS = {
        STRENGTH = 1.0,
        AGILITY = 0.55,
        INTELLECT = 0.0,
        STAMINA = 0.35,
        SPIRIT = 0.0,

        ARMOR = 0.05,
        ATTACKPOWER = 0.90,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.05,
        PARRY = 0.05,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.85,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 1.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.85,

        MP5 = 0.0,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 1.0,
        MELEE_WEAPON_DAMAGE = 0.45,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    WARRIOR_TANK = {
        STRENGTH = 0.45,
        AGILITY = 0.45,
        INTELLECT = 0.0,
        STAMINA = 1.0,
        SPIRIT = 0.0,

        ARMOR = 0.35,
        ATTACKPOWER = 0.30,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 1.0,
        DODGE = 0.90,
        PARRY = 0.85,
        BLOCK = 0.70,
        BLOCK_VALUE = 0.65,
        CRITICAL = 0.15,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.70,
        RESILIENCE = 0.65,
        WEAPON_SKILL = 0.50,

        MP5 = 0.0,
        HP5 = 0.15,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.35,
        MELEE_WEAPON_DAMAGE = 0.15,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    PALADIN_DPS = {
        STRENGTH = 1.0,
        AGILITY = 0.30,
        INTELLECT = 0.35,
        STAMINA = 0.35,
        SPIRIT = 0.0,

        ARMOR = 0.05,
        ATTACKPOWER = 0.85,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.30,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.05,
        PARRY = 0.05,
        BLOCK = 0.05,
        BLOCK_VALUE = 0.05,
        CRITICAL = 0.80,
        HIT = 1.0,
        HASTE = 0.75,
        EXPERTISE = 0.85,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.70,

        MP5 = 0.15,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.90,
        MELEE_WEAPON_DAMAGE = 0.35,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    PALADIN_TANK = {
        STRENGTH = 0.40,
        AGILITY = 0.20,
        -- Spell power / intellect / mp5 are real prot-paladin THREAT stats, but
        -- weighting them as high as tank survival stats inflated paladin-tank
        -- gs+ above every other role (their gear carries these where warrior
        -- tanks carry none). Tuned down so a prot paladin's total lines up with
        -- a warrior tank's. Colour is unaffected: the paladin-tank reference
        -- weapon also carries spell power, so the ratio scales with the weight.
        INTELLECT = 0.35,
        STAMINA = 1.0,
        SPIRIT = 0.0,

        ARMOR = 0.35,
        ATTACKPOWER = 0.20,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.50,
        HEALING = 0.0,

        DEFENSE = 1.0,
        DODGE = 0.80,
        PARRY = 0.75,
        BLOCK = 0.85,
        BLOCK_VALUE = 0.75,
        CRITICAL = 0.15,
        HIT = 0.45,
        HASTE = 0.15,
        EXPERTISE = 0.55,
        RESILIENCE = 0.65,
        WEAPON_SKILL = 0.40,

        MP5 = 0.30,
        HP5 = 0.15,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.20,
        MELEE_WEAPON_DAMAGE = 0.10,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    PALADIN_HEALER = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 1.0,
        STAMINA = 0.40,
        SPIRIT = 0.25,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.30,
        HEALING = 1.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.70,
        HIT = 0.0,
        HASTE = 0.80,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.85,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    HUNTER_DPS = {
        STRENGTH = 0.0,
        AGILITY = 1.0,
        INTELLECT = 0.35,
        STAMINA = 0.35,
        SPIRIT = 0.0,

        ARMOR = 0.05,
        ATTACKPOWER = 0.75,
        RANGED_ATTACKPOWER = 1.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.15,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.90,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.35,

        MP5 = 0.20,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.10,
        MELEE_WEAPON_DAMAGE = 0.05,
        RANGED_WEAPON_DPS = 1.0,
        RANGED_WEAPON_DAMAGE = 0.45,
    },

    ROGUE_DPS = {
        STRENGTH = 0.50,
        AGILITY = 1.0,
        INTELLECT = 0.0,
        STAMINA = 0.35,
        SPIRIT = 0.0,

        ARMOR = 0.05,
        ATTACKPOWER = 0.90,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.15,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.90,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 1.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.90,

        MP5 = 0.0,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 1.0,
        MELEE_WEAPON_DAMAGE = 0.35,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    PRIEST_HEALER = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 1.0,
        STAMINA = 0.40,
        SPIRIT = 0.95,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.25,
        HEALING = 1.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.45,
        HIT = 0.0,
        HASTE = 0.75,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.80,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    PRIEST_DPS = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 0.85,
        STAMINA = 0.45,
        SPIRIT = 0.55,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 1.0,
        HEALING = 0.10,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.70,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.25,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    SHAMAN_ELEMENTAL = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 0.85,
        STAMINA = 0.40,
        SPIRIT = 0.20,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 1.0,
        HEALING = 0.10,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.80,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.25,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    SHAMAN_ENHANCEMENT = {
        STRENGTH = 0.65,
        AGILITY = 0.80,
        INTELLECT = 0.35,
        STAMINA = 0.35,
        SPIRIT = 0.0,

        ARMOR = 0.10,
        ATTACKPOWER = 0.90,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.10,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.15,
        PARRY = 0.05,
        BLOCK = 0.05,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.85,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 1.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.75,

        MP5 = 0.15,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 1.0,
        MELEE_WEAPON_DAMAGE = 0.40,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    SHAMAN_HEALER = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 1.0,
        STAMINA = 0.45,
        SPIRIT = 0.20,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.35,
        HEALING = 1.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.45,
        HIT = 0.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.95,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    MAGE_DPS = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 0.85,
        STAMINA = 0.35,
        SPIRIT = 0.35,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 1.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.80,
        HIT = 1.0,
        HASTE = 0.90,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.15,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    WARLOCK_DPS = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 0.80,
        STAMINA = 0.55,
        SPIRIT = 0.20,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 1.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.75,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.15,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    DRUID_FERAL = {
        STRENGTH = 0.65,
        AGILITY = 1.0,
        INTELLECT = 0.10,
        STAMINA = 0.40,
        SPIRIT = 0.0,

        ARMOR = 0.20,
        ATTACKPOWER = 0.90,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 1.0,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 0.0,
        DODGE = 0.35,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.90,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 1.0,
        RESILIENCE = 0.35,
        WEAPON_SKILL = 0.70,

        MP5 = 0.0,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.35,
        MELEE_WEAPON_DAMAGE = 0.15,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    DRUID_TANK = {
        STRENGTH = 0.35,
        AGILITY = 0.80,
        INTELLECT = 0.0,
        STAMINA = 1.0,
        SPIRIT = 0.0,

        ARMOR = 0.55,
        ATTACKPOWER = 0.30,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.70,

        SPELLPOWER = 0.0,
        HEALING = 0.0,

        DEFENSE = 0.80,
        DODGE = 1.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.15,
        HIT = 0.40,
        HASTE = 0.15,
        EXPERTISE = 0.65,
        RESILIENCE = 0.65,
        WEAPON_SKILL = 0.40,

        MP5 = 0.0,
        HP5 = 0.15,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.20,
        MELEE_WEAPON_DAMAGE = 0.05,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    DRUID_BALANCE = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 0.85,
        STAMINA = 0.40,
        SPIRIT = 0.45,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 1.0,
        HEALING = 0.10,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.75,
        HIT = 1.0,
        HASTE = 0.85,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.25,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },

    DRUID_RESTO = {
        STRENGTH = 0.0,
        AGILITY = 0.0,
        INTELLECT = 1.0,
        STAMINA = 0.40,
        SPIRIT = 0.95,

        ARMOR = 0.05,
        ATTACKPOWER = 0.0,
        RANGED_ATTACKPOWER = 0.0,
        FERAL_ATTACKPOWER = 0.0,

        SPELLPOWER = 0.25,
        HEALING = 1.0,

        DEFENSE = 0.0,
        DODGE = 0.0,
        PARRY = 0.0,
        BLOCK = 0.0,
        BLOCK_VALUE = 0.0,
        CRITICAL = 0.40,
        HIT = 0.0,
        HASTE = 0.75,
        EXPERTISE = 0.0,
        RESILIENCE = 0.20,
        WEAPON_SKILL = 0.0,

        MP5 = 0.80,
        HP5 = 0.0,

        ARCANE_RESISTANCE = 0.0,
        FIRE_RESISTANCE = 0.0,
        FROST_RESISTANCE = 0.0,
        NATURE_RESISTANCE = 0.0,
        SHADOW_RESISTANCE = 0.0,

        MELEE_WEAPON_DPS = 0.0,
        MELEE_WEAPON_DAMAGE = 0.0,
        RANGED_WEAPON_DPS = 0.0,
        RANGED_WEAPON_DAMAGE = 0.0,
    },
}

-- Stats that derive their role value from another stat, so the 18 profile
-- tables don't need explicit entries for them. The budget cost (see
-- Calculator.STAT_BUDGET_COST) handles the magnitude conversion.
Weights.STAT_WEIGHT_ALIASES = {
    HEALTH = "STAMINA",
    MANA = "INTELLECT",
    ARMOR_PENETRATION = "ATTACKPOWER",
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