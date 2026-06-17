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

-- A stable identifier for the logged-in character. The manual profile is stored
-- per character: profiles are class-specific, so one account-wide setting (the
-- old design) made a pick on one character apply to ALL of them - the cause of
-- "logged in as a Druid, scored as Shaman Healer".
function Profiles:GetCharacterKey()
    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()

    if not name or name == "" then
        return "__local__"
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

-- The class a profile belongs to, derived from its key ("CLASS_ROLE", e.g.
-- DRUID_FERAL -> DRUID). Returns nil for an unrecognized key.
function Profiles:GetProfileClass(profileKey)
    profileKey = self:NormalizeProfileKey(profileKey)

    if not profileKey then
        return nil
    end

    for className in pairs(self.DEFAULT_PROFILE_BY_CLASS) do
        if string.sub(profileKey, 1, #className + 1) == className .. "_" then
            return className
        end
    end

    return nil
end

function Profiles:IsProfileForClass(profileKey, className)
    if not className then
        return false
    end

    return self:GetProfileClass(profileKey) == className
end

-- The manually-selected profile for the CURRENT character, or nil for automatic
-- detection. A selection is honored ONLY when it is a valid profile for this
-- character's class, so a pick stored under one character can never apply to a
-- different class.
function Profiles:GetManualProfile()
    GSPlusSavedVars = GSPlusSavedVars or {}

    -- One-time cleanup: older versions stored a single account-wide manual pick
    -- (useManualProfile/selectedProfile) that leaked to EVERY character - the
    -- cause of a Druid showing "Shaman Healer" and a Resto Shaman showing
    -- "Shaman Enhancement". We can't know which character it belonged to, so we
    -- discard it and let each character auto-detect (or pick again per character).
    if GSPlusSavedVars.useManualProfile ~= nil or GSPlusSavedVars.selectedProfile ~= nil then
        GSPlusSavedVars.useManualProfile = nil
        GSPlusSavedVars.selectedProfile = nil
    end

    local className = GSPlus.Calculator:GetPlayerClass()
    local byChar = GSPlusSavedVars.manualProfileByChar
    local stored = self:NormalizeProfileKey(byChar and byChar[self:GetCharacterKey()])

    if stored
        and GSPlus.Weights.PROFILE_WEIGHTS[stored]
        and self:IsProfileForClass(stored, className) then
        return stored
    end

    return nil
end

function Profiles:GetSelectedProfile()
    GSPlusSavedVars = GSPlusSavedVars or {}

    local manualProfile = self:GetManualProfile()

    if manualProfile then
        return manualProfile
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

    -- Refuse a profile that doesn't belong to this character's class; it could
    -- never be scored sensibly and is the kind of value that used to leak
    -- across characters.
    if not self:IsProfileForClass(profileKey, GSPlus.Calculator:GetPlayerClass()) then
        return false
    end

    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.manualProfileByChar = GSPlusSavedVars.manualProfileByChar or {}
    GSPlusSavedVars.manualProfileByChar[self:GetCharacterKey()] = profileKey

    -- Drop the legacy account-wide fields so an old global pick can't leak to
    -- other characters once any new selection is made.
    GSPlusSavedVars.useManualProfile = nil
    GSPlusSavedVars.selectedProfile = nil

    GSPlus:RefreshUI()

    return true
end

function Profiles:UseAutomaticProfileDetection()
    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.manualProfileByChar = GSPlusSavedVars.manualProfileByChar or {}
    GSPlusSavedVars.manualProfileByChar[self:GetCharacterKey()] = nil

    GSPlusSavedVars.useManualProfile = nil
    GSPlusSavedVars.selectedProfile = nil

    -- Drop cached detection/scores so switching to Automatic re-evaluates from
    -- scratch (talents + gear). Without this, a role cached before a respec is
    -- simply re-displayed and "Auto" appears to do nothing.
    if GSPlus.InvalidateCaches then
        GSPlus:InvalidateCaches()
    end

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
    return self:GetManualProfile() ~= nil
end

