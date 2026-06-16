-- GSPlus Core Module

GSPlus = GSPlus or {}

GSPlus.VERSION = "2.4.7"
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
GSPlus.ReferenceGear = GSPlus.ReferenceGear or {}
GSPlus.KnownProcs = GSPlus.KnownProcs or {}
GSPlus.KnownEnchants = GSPlus.KnownEnchants or {}

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

    -- Register the INSPECT_READY listener up front so the inspect window
    -- score works even if no background inspect (mouseover/group) ever runs
    -- to lazily register it - e.g. when unit tooltips are disabled.
    if self.Inspect and self.Inspect.RegisterEvents then
        self.Inspect:RegisterEvents()
    end

    if self.CharacterPaneUI and self.CharacterPaneUI.Initialize then
        self.CharacterPaneUI:Initialize()
    end

    local isAddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded

    if isAddOnLoaded and isAddOnLoaded("Blizzard_InspectUI")
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
        -- Equipped item data often arrives a beat AFTER login. Relying only on
        -- GET_ITEM_INFO_RECEIVED to recompute is racy: if the data lands before
        -- our first scan (so sawUncachedItem was never set when the events
        -- fired) or a first scan reads an item as "complete" while its green
        -- Equip lines are still a beat behind, the score sticks at a wrong value
        -- until a /reload. This bounded pass re-scores the player's own gear
        -- until it has fully loaded and the number stops rising.
        self:ConvergePlayerScore()
    elseif event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then
        self:InvalidateCaches()
        self:RequestRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Only react if we previously failed to parse an item because the
        -- server had not sent its data yet - and batch the reaction: this
        -- event fires once per arriving item (a fresh inspect triggers a
        -- storm of them), and invalidating/recomputing per event causes
        -- visible frame hitches.
        if self.ItemParser and self.ItemParser.sawUncachedItem and not self.itemInfoFlushPending then
            self.itemInfoFlushPending = true

            local function flush()
                GSPlus.itemInfoFlushPending = false

                if GSPlus.ItemParser then
                    GSPlus.ItemParser.sawUncachedItem = nil

                    -- Drop item scans taken before this data arrived so they
                    -- recompute fresh; keeps mouseover and inspect scores
                    -- converging to the same final number.
                    if GSPlus.ItemParser.InvalidateStatsCache then
                        GSPlus.ItemParser:InvalidateStatsCache()
                    end
                end

                GSPlus:InvalidateCaches()

                -- Newly-loaded item data: actively re-score the players we
                -- already track so a score captured from half-loaded gear
                -- converges to the right number without a /reload. Re-rendering
                -- alone (RefreshUI) would keep showing the stale cached entry.
                if GSPlus.Inspect and GSPlus.Inspect.RescoreResolvableUnits then
                    GSPlus.Inspect:RescoreResolvableUnits()
                end

                GSPlus:RefreshUI()

                -- Newly-loaded items may belong to a player whose score we
                -- captured partially; refresh those surfaces too.
                if GSPlus.GroupFrame and GSPlus.GroupFrame.IsVisible
                    and GSPlus.GroupFrame:IsVisible() then
                    GSPlus.GroupFrame:Update()
                end

                if GSPlus.InspectPaneUI and GSPlus.InspectPaneUI.Update then
                    GSPlus.InspectPaneUI:Update()
                end
            end

            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, flush)
            else
                flush()
            end
        end
    end
end

-- Tunables for the post-login convergence pass.
GSPlus.LOGIN_CONVERGE_DELAY = 0.5
GSPlus.LOGIN_CONVERGE_MAX_PASSES = 10

-- Re-score the player's own gear on a short timer until it has fully loaded and
-- the score has stopped climbing, then stop. This is the player-side analogue of
-- the inspect verification loop (Inspect:BeginVerify), which the player's OWN
-- score previously lacked - so a login-time undercount had no way to self-heal
-- without a /reload. Each pass forces a fresh re-read of the equipped items (a
-- first scan can report an item cached while its Equip lines lag), invalidates
-- the derived caches, and refreshes the display. Because scores only ever rise
-- as data finishes loading, "complete and no longer rising" is the convergence
-- signal. A generation token makes the duplicate PLAYER_LOGIN/PLAYER_ENTERING_WORLD
-- fire restart cleanly instead of running two overlapping loops.
function GSPlus:ConvergePlayerScore()
    self.convergeGen = (self.convergeGen or 0) + 1
    self:RunConvergePass(self.convergeGen, 0, 0)
end

function GSPlus:RunConvergePass(gen, pass, bestScore)
    if gen ~= self.convergeGen then
        return
    end

    -- Force a fresh parse of the player's currently equipped items so a stale
    -- partial scan can't keep the score pinned low.
    local ItemParser = self.ItemParser

    if ItemParser and ItemParser.InvalidateItem then
        for _, slotInfo in ipairs(ItemParser.EQUIPMENT_SLOTS) do
            local slotId = GetInventorySlotInfo(slotInfo.key)
            local itemLink = slotId and GetInventoryItemLink("player", slotId)

            if itemLink then
                ItemParser:InvalidateItem(itemLink)
            end
        end
    end

    self:InvalidateCaches()
    self:RefreshUI()

    local score = bestScore or 0
    local complete = true

    if self.Calculator and self.Calculator.GetPlayerGSPlus then
        local data = self.Calculator:GetPlayerGSPlus()

        if data then
            score = math.max(score, data.totalWeightedScore or 0)
            complete = not data.incomplete
        end
    end

    local rising = score > (bestScore or 0) + 0.5

    -- Done once the gear is fully loaded and the score has settled, or after a
    -- bounded number of attempts (so a permanently-missing item can't loop).
    if (complete and not rising) or pass >= self.LOGIN_CONVERGE_MAX_PASSES then
        return
    end

    if not (C_Timer and C_Timer.After) then
        return
    end

    C_Timer.After(self.LOGIN_CONVERGE_DELAY, function()
        GSPlus:RunConvergePass(gen, pass + 1, score)
    end)
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
