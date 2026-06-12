-- GSPlus Core Module

GSPlus = GSPlus or {}

GSPlus.VERSION = "2.1.1"
GSPlus.ItemParser = GSPlus.ItemParser or {}
GSPlus.Calculator = GSPlus.Calculator or {}
GSPlus.Weights = GSPlus.Weights or {}
GSPlus.UI = GSPlus.UI or {}
GSPlus.Commands = GSPlus.Commands or {}
GSPlus.Tooltip = GSPlus.Tooltip or {}
GSPlus.TalentDetector = GSPlus.TalentDetector or {}
GSPlus.Profiles = GSPlus.Profiles or {}
GSPlus.CharacterPaneUI = GSPlus.CharacterPaneUI or {}
GSPlus.SetBonuses = GSPlus.SetBonuses or {}
GSPlus.Inspect = GSPlus.Inspect or {}
GSPlus.Options = GSPlus.Options or {}
GSPlus.LegacyGearScore = GSPlus.LegacyGearScore or {}
GSPlus.PlayerCache = GSPlus.PlayerCache or {}
GSPlus.Comms = GSPlus.Comms or {}
GSPlus.UnitTooltip = GSPlus.UnitTooltip or {}
GSPlus.GroupFrame = GSPlus.GroupFrame or {}
GSPlus.InspectPaneUI = GSPlus.InspectPaneUI or {}
GSPlus.StatCaps = GSPlus.StatCaps or {}
GSPlus.GameVersion = GSPlus.GameVersion or {}

function GSPlus:Initialize()
    GSPlusSavedVars = GSPlusSavedVars or {}

    -- Zero-config philosophy: silent on login, one short orientation message
    -- on first install only.
    if not GSPlusSavedVars.welcomed then
        GSPlusSavedVars.welcomed = true
        print("|cff00ff00gs+|r is ready. Your score is on your character pane"
            .. " (click it for details, right-click for group scores)."
            .. " Display settings: Interface Options or |cff00ff00/gs|r.")
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

function GSPlus:InvalidateCaches()
    if self.SetBonuses and self.SetBonuses.InvalidateCache then
        self.SetBonuses:InvalidateCache()
    end

    if self.Calculator and self.Calculator.InvalidateCache then
        self.Calculator:InvalidateCache()
    end

    if self.TalentDetector then
        self.TalentDetector.roleCache = nil
    end

    if self.StatCaps and self.StatCaps.InvalidateCache then
        self.StatCaps:InvalidateCache()
    end
end

function GSPlus:RegisterEvents()
    if self.frame then
        return
    end

    self.frame = CreateFrame("Frame", "GSPlusFrame")
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self.frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    self.frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    self.frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    self.frame:SetScript("OnEvent", function(_, event, ...)
        GSPlus:OnEvent(event, ...)
    end)
end

function GSPlus:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...

        if addonName == "GSPlus" then
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
function GSPlus:RequestRefresh()
    if not (C_Timer and C_Timer.After) then
        self:RefreshUI()
        return
    end

    if self.refreshPending then
        return
    end

    self.refreshPending = true

    C_Timer.After(0.1, function()
        GSPlus.refreshPending = false
        GSPlus:RefreshUI()
    end)
end

function GSPlus:RefreshUI()
    if self.UI and self.UI:IsVisible() then
        self.UI:Update()
    end

    if self.CharacterPaneUI and self.CharacterPaneUI.Update then
        self.CharacterPaneUI:Update()
    end
end

GSPlus:RegisterEvents()
