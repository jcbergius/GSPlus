-- BetterGearScore Core Module

BetterGearScore = BetterGearScore or {}

BetterGearScore.VERSION = "1.3.0"
BetterGearScore.ItemParser = BetterGearScore.ItemParser or {}
BetterGearScore.Calculator = BetterGearScore.Calculator or {}
BetterGearScore.Weights = BetterGearScore.Weights or {}
BetterGearScore.UI = BetterGearScore.UI or {}
BetterGearScore.Commands = BetterGearScore.Commands or {}
BetterGearScore.Tooltip = BetterGearScore.Tooltip or {}
BetterGearScore.TalentDetector = BetterGearScore.TalentDetector or {}
BetterGearScore.Profiles = BetterGearScore.Profiles or {}
BetterGearScore.CharacterPaneUI = BetterGearScore.CharacterPaneUI or {}
BetterGearScore.SetBonuses = BetterGearScore.SetBonuses or {}
BetterGearScore.Inspect = BetterGearScore.Inspect or {}
BetterGearScore.Options = BetterGearScore.Options or {}
BetterGearScore.LegacyGearScore = BetterGearScore.LegacyGearScore or {}
BetterGearScore.PlayerCache = BetterGearScore.PlayerCache or {}
BetterGearScore.Comms = BetterGearScore.Comms or {}
BetterGearScore.UnitTooltip = BetterGearScore.UnitTooltip or {}
BetterGearScore.GroupFrame = BetterGearScore.GroupFrame or {}
BetterGearScore.InspectPaneUI = BetterGearScore.InspectPaneUI or {}
BetterGearScore.StatCaps = BetterGearScore.StatCaps or {}

function BetterGearScore:Initialize()
    BetterGearScoreSavedVars = BetterGearScoreSavedVars or {}

    -- Zero-config philosophy: silent on login, one short orientation message
    -- on first install only.
    if not BetterGearScoreSavedVars.welcomed then
        BetterGearScoreSavedVars.welcomed = true
        print("|cff00ff00BetterGearScore|r is ready. Your score is on your character pane"
            .. " (click it for details, right-click for group scores)."
            .. " Display settings: Interface Options or |cff00ff00/bgs|r.")
    end

    if self.CharacterPaneUI and self.CharacterPaneUI.Initialize then
        self.CharacterPaneUI:Initialize()
    end

    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_InspectUI")
        and self.InspectPaneUI and self.InspectPaneUI.Initialize then
        self.InspectPaneUI:Initialize()
    end

    if self.Options and self.Options.Initialize then
        self.Options:Initialize()
    end

    if self.Comms and self.Comms.Initialize then
        self.Comms:Initialize()
    end
end

function BetterGearScore:InvalidateCaches()
    if self.SetBonuses and self.SetBonuses.InvalidateCache then
        self.SetBonuses:InvalidateCache()
    end

    if self.Calculator and self.Calculator.InvalidateCache then
        self.Calculator:InvalidateCache()
    end

    if self.TalentDetector then
        self.TalentDetector.feralRoleCache = nil
    end

    if self.StatCaps and self.StatCaps.InvalidateCache then
        self.StatCaps:InvalidateCache()
    end
end

function BetterGearScore:RegisterEvents()
    if self.frame then
        return
    end

    self.frame = CreateFrame("Frame", "BetterGearScoreFrame")
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    self.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    self.frame:SetScript("OnEvent", function(_, event, ...)
        BetterGearScore:OnEvent(event, ...)
    end)
end

function BetterGearScore:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...

        if addonName == "BetterGearScore" then
            self:Initialize()
        elseif addonName == "Blizzard_InspectUI" then
            -- The inspect UI is load-on-demand; hook it as soon as it exists.
            if self.InspectPaneUI and self.InspectPaneUI.Initialize then
                self.InspectPaneUI:Initialize()
            end
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        self:InvalidateCaches()
        self:RequestRefresh()
    elseif event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then
        self:InvalidateCaches()
        self:RequestRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Only refresh if we previously failed to parse an item because the
        -- server had not sent its data yet. Otherwise this event is noise.
        if self.ItemParser and self.ItemParser.sawUncachedItem then
            self.ItemParser.sawUncachedItem = nil
            self:InvalidateCaches()
            self:RequestRefresh()
        end
    end
end

-- Equipment swaps fire one event per slot; collapse bursts into one refresh.
function BetterGearScore:RequestRefresh()
    if not (C_Timer and C_Timer.After) then
        self:RefreshUI()
        return
    end

    if self.refreshPending then
        return
    end

    self.refreshPending = true

    C_Timer.After(0.1, function()
        BetterGearScore.refreshPending = false
        BetterGearScore:RefreshUI()
    end)
end

function BetterGearScore:RefreshUI()
    if self.UI and self.UI:IsVisible() then
        self.UI:Update()
    end

    if self.CharacterPaneUI and self.CharacterPaneUI.Update then
        self.CharacterPaneUI:Update()
    end
end

BetterGearScore:RegisterEvents()
