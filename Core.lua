-- GearScore Core Module
GearScore = {}
GearScore.VERSION = "1.0.0"

-- Initialize the addon
function GearScore:Initialize()
    self:RegisterEvents()
    print("|cff00ff00GearScore|r v" .. self.VERSION .. " loaded. Use |cff00ff00/gearscore|r or |cff00ff00/gs|r for help.")
end

function GearScore:RegisterEvents()
    self.frame = CreateFrame("Frame", "GearScoreFrame")
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:RegisterEvent("EQUIPMENT_SETS_CHANGED")
    self.frame:RegisterEvent("ITEM_LOCK_CHANGED")
    self.frame:SetScript("OnEvent", function(frame, event, ...)
        GearScore:OnEvent(event, ...)
    end)
end

function GearScore:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "GearScore" then
            GearScore:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        GearScore:OnPlayerLogin()
    elseif event == "EQUIPMENT_SETS_CHANGED" or event == "ITEM_LOCK_CHANGED" then
        GearScore:RefreshUI()
    end
end

function GearScore:OnPlayerLogin()
    GearScoreSavedVars = GearScoreSavedVars or {}
    self:RefreshUI()
end

function GearScore:RefreshUI()
    if GearScoreUI and GearScoreUI:IsVisible() then
        GearScoreUI:Update()
    end
end

-- Initialize when loaded
if GearScore.frame == nil then
    GearScore:RegisterEvents()
end
