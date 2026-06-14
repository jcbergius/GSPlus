-- Commands.lua
-- The addon configures itself and every feature has a UI entry point, so the
-- only slash command opens the options panel (display/style settings).

local Commands = GSPlus.Commands

function Commands:RegisterCommands()
    SLASH_GSPlus1 = "/gsplus"
    SLASH_GSPlus2 = "/bgs"
    SLASH_GSPlus3 = "/gs"

    SlashCmdList["GSPlus"] = function(msg)
        local arg = msg and string.lower(string.gsub(msg, "%s+", "")) or ""

        if arg == "debug" then
            GSPlus.Commands:PrintDebug()
            return
        end

        if arg == "spec" then
            GSPlus.Commands:PrintSpec()
            return
        end

        GSPlus.Options:OpenPanel()
    end
end

-- Undocumented diagnostic (/gs spec): target a player, then run it to see what
-- the inspect talent APIs actually return for them - the unreliable
-- GetTalentTabInfo points side by side with the GetTalentInfo rank sum - plus
-- the resolved spec. Used to root-cause wrong inspected roles on this client.
function Commands:PrintSpec()
    local unit = "target"

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        print("|cff00ff00gs+ spec|r: target a player first, then /gs spec")
        return
    end

    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    local isInspect = not UnitIsUnit(unit, "player")

    -- Header prints immediately so there is always output, even if a talent
    -- API call errors below (each is pcall-guarded).
    print("|cff00ff00gs+ spec|r " .. tostring(name) .. " (" .. tostring(class) .. ") inspect="
        .. tostring(isInspect))

    local function readTab(tab, insp)
        local count = 0
        local okc, c = pcall(GetNumTalents, tab, insp, false)

        if okc and type(c) == "number" then
            count = c
        end

        local summed = 0

        for j = 1, count do
            local okr, r = pcall(function()
                return select(5, GetTalentInfo(tab, j, insp, false, 1))
            end)

            if okr then
                summed = summed + (tonumber(r) or 0)
            end
        end

        local tabName = (GSPlus.TalentDetector:GetTalentTabNameAndPoints(tab, insp))

        return summed, tabName
    end

    local function dump()
        if not UnitExists(unit) then
            print("  (target lost - re-target and rerun)")
            return
        end

        local r1, n1 = readTab(1, isInspect)
        local r2, n2 = readTab(2, isInspect)
        local r3, n3 = readTab(3, isInspect)

        print(string.format("  target  t1 %s=%d  t2 %s=%d  t3 %s=%d",
            tostring(n1), r1, tostring(n2), r2, tostring(n3), r3))

        -- Your OWN spec, for comparison. If the target read above matches this,
        -- the inspect API is leaking YOUR talents instead of the target's.
        if isInspect then
            local o1 = readTab(1, false)
            local o2 = readTab(2, false)
            local o3 = readTab(3, false)
            print(string.format("  you     t1=%d t2=%d t3=%d", o1, o2, o3))
        end

        local okd, bi = pcall(function() return (GSPlus.TalentDetector:GetInspectDominantTree()) end)
        local okp, prof = pcall(function() return GSPlus.Inspect:ReadTalentProfile(unit) end)
        print("  -> tree=" .. tostring(okd and bi) .. " profile=" .. tostring(okp and prof))
    end

    if isInspect and C_Timer and C_Timer.After then
        print("  inspecting (reads at INSPECT_READY, like the addon)...")

        local targetGuid = UnitGUID and UnitGUID(unit)
        local f = CreateFrame("Frame")
        local done = false

        local function finish(note)
            if done then return end
            done = true
            f:UnregisterAllEvents()
            if note then print(note) end
            dump()
        end

        f:RegisterEvent("INSPECT_READY")
        f:SetScript("OnEvent", function(_, _, g)
            if not targetGuid or g == targetGuid then
                finish(nil)
            end
        end)

        GSPlus.Inspect.skipInspectError = true
        if NotifyInspect then NotifyInspect(unit) end
        GSPlus.Inspect.skipInspectError = false

        C_Timer.After(3, function()
            finish("  (no INSPECT_READY in 3s - throttled; wait a few seconds and retry)")
        end)
    else
        dump()
    end
end

-- Undocumented developer diagnostic (/gs debug): surfaces the live state
-- behind "it's broken" reports - inspect queue health, item cache, and
-- whether background inspects are currently blocked.
function Commands:PrintDebug()
    local Inspect = GSPlus.Inspect
    local ItemParser = GSPlus.ItemParser

    local queueLen = Inspect.queue and #Inspect.queue or 0
    local currentName = Inspect.current and (Inspect.current.name or "?") or "none"
    local notifyAge = string.format("%.1f", time() - (Inspect.lastNotify or 0))
    local blocked = Inspect:IsBackgroundInspectBlocked() and "YES" or "no"

    local cacheCount = ItemParser and ItemParser.statsCacheCount or 0

    print("|cff00ff00gs+ debug|r v" .. (GSPlus.VERSION or "?"))
    print("  flavor: " .. tostring(GSPlus.GameVersion and GSPlus.GameVersion:GetFlavor()))
    print("  inspect queue: " .. queueLen .. "  current: " .. currentName
        .. "  last NotifyInspect: " .. notifyAge .. "s ago")
    print("  background inspect blocked: " .. blocked
        .. (InspectFrame and InspectFrame:IsShown() and " (inspect frame open)" or "")
        .. (InCombatLockdown and InCombatLockdown() and " (in combat)" or ""))
    print("  cached items: " .. cacheCount
        .. (ItemParser and ItemParser.sawUncachedItem and "  (awaiting item data)" or ""))

    local cachedPlayers = 0
    for _ in pairs(GSPlus.PlayerCache and GSPlus.PlayerCache:GetStore() or {}) do
        cachedPlayers = cachedPlayers + 1
    end
    print("  cached player scores: " .. cachedPlayers)
end

Commands:RegisterCommands()
