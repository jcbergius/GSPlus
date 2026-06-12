-- Profiles.lua

local Profiles = GSPlus.Profiles

Profiles.DEFAULT_PROFILE_BY_CLASS = {
    WARRIOR = "WARRIOR_DPS",
    PALADIN = "PALADIN_DPS",
    HUNTER = "HUNTER_DPS",
    ROGUE = "ROGUE_DPS",
    PRIEST = "PRIEST_HEALER",
    SHAMAN = "SHAMAN_ELEMENTAL",
    MAGE = "MAGE_DPS",
    WARLOCK = "WARLOCK_DPS",
    DRUID = "DRUID_FERAL",
    DEATHKNIGHT = "DEATHKNIGHT_DPS",
}

Profiles.PROFILE_NAMES = {
    WARRIOR_DPS = "Warrior DPS",
    WARRIOR_TANK = "Warrior Tank",

    PALADIN_DPS = "Paladin DPS",
    PALADIN_TANK = "Paladin Tank",
    PALADIN_HEALER = "Paladin Healer",

    HUNTER_DPS = "Hunter DPS",
    ROGUE_DPS = "Rogue DPS",

    PRIEST_HEALER = "Priest Healer",
    PRIEST_DPS = "Priest DPS",

    SHAMAN_ELEMENTAL = "Shaman Elemental",
    SHAMAN_ENHANCEMENT = "Shaman Enhancement",
    SHAMAN_HEALER = "Shaman Healer",

    MAGE_DPS = "Mage DPS",
    WARLOCK_DPS = "Warlock DPS",

    DRUID_FERAL = "Druid Feral",
    DRUID_BALANCE = "Druid Balance",
    DRUID_RESTO = "Druid Restoration",
    DRUID_TANK = "Druid Tank",

    DEATHKNIGHT_DPS = "Death Knight DPS",
    DEATHKNIGHT_TANK = "Death Knight Tank",
}

function Profiles:NormalizeProfileKey(profileKey)
    if not profileKey then
        return nil
    end

    profileKey = string.upper(profileKey)
    profileKey = string.gsub(profileKey, "%s+", "_")
    profileKey = string.gsub(profileKey, "-", "_")

    return profileKey
end

function Profiles:GetDefaultProfileForClass(className)
    return self.DEFAULT_PROFILE_BY_CLASS[className] or "MAGE_DPS"
end

function Profiles:GetSelectedProfile()
    GSPlusSavedVars = GSPlusSavedVars or {}

    if GSPlusSavedVars.useManualProfile and GSPlusSavedVars.selectedProfile then
        local manualProfile = self:NormalizeProfileKey(GSPlusSavedVars.selectedProfile)

        if manualProfile and GSPlus.Weights.PROFILE_WEIGHTS[manualProfile] then
            return manualProfile
        end
    end

    if GSPlus.TalentDetector then
        local detectedProfile = GSPlus.TalentDetector:GetDetectedProfile()

        if detectedProfile and GSPlus.Weights.PROFILE_WEIGHTS[detectedProfile] then
            return detectedProfile
        end
    end

    local className = GSPlus.Calculator:GetPlayerClass()
    local defaultProfile = self:GetDefaultProfileForClass(className)

    if GSPlus.Weights.PROFILE_WEIGHTS[defaultProfile] then
        return defaultProfile
    end

    return "MAGE_DPS"
end

function Profiles:SetSelectedProfile(profileKey)
    profileKey = self:NormalizeProfileKey(profileKey)

    if not profileKey or not GSPlus.Weights.PROFILE_WEIGHTS[profileKey] then
        return false
    end

    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.useManualProfile = true
    GSPlusSavedVars.selectedProfile = profileKey

    GSPlus:RefreshUI()

    return true
end

function Profiles:UseAutomaticProfileDetection()
    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.useManualProfile = false
    GSPlusSavedVars.selectedProfile = nil

    GSPlus:RefreshUI()
end

function Profiles:GetProfileDisplayName(profileKey)
    profileKey = self:NormalizeProfileKey(profileKey)

    return self.PROFILE_NAMES[profileKey] or profileKey or "Unknown"
end

Profiles.SORTED_PROFILE_KEYS = {
    "WARRIOR_DPS",
    "WARRIOR_TANK",

    "PALADIN_DPS",
    "PALADIN_TANK",
    "PALADIN_HEALER",

    "HUNTER_DPS",
    "ROGUE_DPS",

    "PRIEST_HEALER",
    "PRIEST_DPS",

    "SHAMAN_ELEMENTAL",
    "SHAMAN_ENHANCEMENT",
    "SHAMAN_HEALER",

    "MAGE_DPS",
    "WARLOCK_DPS",

    "DRUID_FERAL",
    "DRUID_TANK",
    "DRUID_BALANCE",
    "DRUID_RESTO",

    "DEATHKNIGHT_DPS",
    "DEATHKNIGHT_TANK",
}

function Profiles:IsUsingManualProfile()
    GSPlusSavedVars = GSPlusSavedVars or {}

    return GSPlusSavedVars.useManualProfile == true
end

