-- Commands.lua
-- The addon configures itself and every feature has a UI entry point, so the
-- only slash command opens the options panel (display/style settings).

local Commands = GSPlus.Commands

function Commands:RegisterCommands()
    SLASH_GSPlus1 = "/gsplus"
    SLASH_GSPlus2 = "/bgs"
    SLASH_GSPlus3 = "/gs"

    SlashCmdList["GSPlus"] = function(msg)
        if msg and string.lower(string.gsub(msg, "%s+", "")) == "debug" then
            GSPlus.Commands:PrintDebug()
            return
        end

        GSPlus.Options:OpenPanel()
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
