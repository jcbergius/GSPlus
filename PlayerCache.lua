-- PlayerCache.lua
-- Stores gear scores for other players, gathered via inspect or addon comms.
-- Persisted across sessions so previously-seen players show instantly.

GSPlus = GSPlus or {}
GSPlus.PlayerCache = GSPlus.PlayerCache or {}

local PlayerCache = GSPlus.PlayerCache

PlayerCache.MAX_ENTRIES = 300

-- Bumped whenever scoring or role-detection logic changes. On a mismatch the
-- persisted cache is wiped so stale numbers/roles from an older build can't
-- survive a /reload or relog - everyone is simply re-inspected fresh.
PlayerCache.CACHE_VERSION = 3

function PlayerCache:GetStore()
    GSPlusSavedVars = GSPlusSavedVars or {}

    if GSPlusSavedVars.playerCacheVersion ~= self.CACHE_VERSION then
        GSPlusSavedVars.playerCache = {}
        GSPlusSavedVars.playerCacheVersion = self.CACHE_VERSION
    end

    GSPlusSavedVars.playerCache = GSPlusSavedVars.playerCache or {}

    return GSPlusSavedVars.playerCache
end

-- Both inspect (unit tokens) and comms (sender strings) must produce the
-- SAME cache key for the same player, or a player's comms score and inspect
-- score land under different keys and one is never displayed. Comms senders
-- always arrive realm-qualified ("Name-Realm"), and a cross-realm unit token
-- resolves to "Name-Realm" too - but the realm spelling differs between the
-- two sources (unit realms carry spaces, sender realms don't), so a
-- realm-qualified key can't be matched reliably. Canonicalize both to the
-- bare character name, which is stable across both sources.
function PlayerCache:CanonicalName(rawName)
    if not rawName or rawName == "" then
        return nil
    end

    if Ambiguate then
        return Ambiguate(rawName, "short")
    end

    return string.match(rawName, "^([^%-]+)") or rawName
end

function PlayerCache:GetKeyForUnit(unit)
    if not unit or not UnitName then
        return nil
    end

    local name, realm = UnitName(unit)

    if not name then
        return nil
    end

    if realm and realm ~= "" then
        name = name .. "-" .. realm
    end

    return self:CanonicalName(name)
end

function PlayerCache:NormalizeSenderKey(sender)
    return self:CanonicalName(sender)
end

function PlayerCache:Set(key, entry)
    if not key or not entry then
        return
    end

    entry.time = entry.time or time()

    local store = self:GetStore()

    if not store[key] then
        self:PruneIfNeeded(store)
    end

    store[key] = entry
end

function PlayerCache:SetForUnit(unit, entry)
    local key = self:GetKeyForUnit(unit)

    if not key then
        return
    end

    if entry and not entry.class and UnitClass then
        local _, classFileName = UnitClass(unit)
        entry.class = classFileName
    end

    self:Set(key, entry)
end

function PlayerCache:Get(key)
    if not key then
        return nil
    end

    return self:GetStore()[key]
end

function PlayerCache:GetByUnit(unit)
    return self:Get(self:GetKeyForUnit(unit))
end

function PlayerCache:PruneIfNeeded(store)
    store = store or self:GetStore()

    local count = 0

    for _ in pairs(store) do
        count = count + 1
    end

    if count < self.MAX_ENTRIES then
        return
    end

    -- Drop the oldest ~10% of entries.
    local entries = {}

    for key, entry in pairs(store) do
        entries[#entries + 1] = { key = key, time = entry.time or 0 }
    end

    table.sort(entries, function(a, b)
        return a.time < b.time
    end)

    local toRemove = math.max(1, math.floor(count / 10))

    for i = 1, toRemove do
        store[entries[i].key] = nil
    end
end

function PlayerCache:FormatAge(entry)
    if not entry or not entry.time then
        return "unknown age"
    end

    local age = time() - entry.time

    if age < 60 then
        return "just now"
    elseif age < 3600 then
        return math.floor(age / 60) .. "m ago"
    elseif age < 86400 then
        return math.floor(age / 3600) .. "h ago"
    end

    return math.floor(age / 86400) .. "d ago"
end

-- The colorized weighted score for display, or a greyed loading indicator
-- when the entry's gear has not fully loaded yet, so a misleading partial
-- total is never shown as a number.
function PlayerCache:FormatScore(entry)
    if not entry or entry.partial then
        return "|cff888888...|r"
    end

    return GSPlus.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0)
end

function PlayerCache:FormatSource(entry)
    if not entry then
        return ""
    end

    if entry.source == "comms" then
        return "shared"
    elseif entry.source == "inspect" then
        return "inspected"
    end

    return entry.source or ""
end
