-- Profiles.lua

local Profiles = BetterGearScore.Profiles

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
    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}

    if BetterGearScoreSavedVars.useManualProfile and BetterGearScoreSavedVars.selectedProfile then
        local manualProfile = self:NormalizeProfileKey(BetterGearScoreSavedVars.selectedProfile)

        if manualProfile and BetterGearScore.Weights.PROFILE_WEIGHTS[manualProfile] then
            return manualProfile
        end
    end

    if BetterGearScore.TalentDetector then
        local detectedProfile = BetterGearScore.TalentDetector:GetDetectedProfile()

        if detectedProfile and BetterGearScore.Weights.PROFILE_WEIGHTS[detectedProfile] then
            return detectedProfile
        end
    end

    local className = BetterGearScore.Calculator:GetPlayerClass()
    local defaultProfile = self:GetDefaultProfileForClass(className)

    if BetterGearScore.Weights.PROFILE_WEIGHTS[defaultProfile] then
        return defaultProfile
    end

    return "MAGE_DPS"
end

function Profiles:SetSelectedProfile(profileKey)
    profileKey = self:NormalizeProfileKey(profileKey)

    if not profileKey or not BetterGearScore.Weights.PROFILE_WEIGHTS[profileKey] then
        return false
    end

    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}
    BetterGearScoreSavedVars.useManualProfile = true
    BetterGearScoreSavedVars.selectedProfile = profileKey

    BetterGearScore:RefreshUI()

    return true
end

function Profiles:UseAutomaticProfileDetection()
    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}
    BetterGearScoreSavedVars.useManualProfile = false
    BetterGearScoreSavedVars.selectedProfile = nil

    BetterGearScore:RefreshUI()
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
}

function Profiles:IsUsingManualProfile()
    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}

    return BetterGearScoreSavedVars.useManualProfile == true
end

