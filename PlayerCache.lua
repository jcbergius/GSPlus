-- PlayerCache.lua
-- Stores gear scores for other players, gathered via inspect or addon comms.
-- Persisted across sessions so previously-seen players show instantly.

GSPlus = GSPlus or {}
GSPlus.PlayerCache = GSPlus.PlayerCache or {}

local PlayerCache = GSPlus.PlayerCache

PlayerCache.MAX_ENTRIES = 300

function PlayerCache:GetStore()
    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.playerCache = GSPlusSavedVars.playerCache or {}

    return GSPlusSavedVars.playerCache
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
        return name .. "-" .. realm
    end

    return name
end

-- Comms senders arrive as "Name-Realm" even on the same realm; normalize so
-- they match keys produced from unit tokens.
function PlayerCache:NormalizeSenderKey(sender)
    if not sender then
        return nil
    end

    if Ambiguate then
        return Ambiguate(sender, "short")
    end

    return string.match(sender, "^([^%-]+)") or sender
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
