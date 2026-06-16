-- Comms.lua
-- Shares exact scores between GSPlus users over the addon message
-- channel, so group members see each other without needing inspect range.

GSPlus = GSPlus or {}
GSPlus.Comms = GSPlus.Comms or {}

local Comms = GSPlus.Comms

Comms.PREFIX = "GSPlus"
-- v4: all profile weights redistributed to Wowhead stat priorities, so the
-- score scale differs from v3 (and v2's raw linear sums) - never mix versions.
Comms.PROTOCOL_VERSION = 4
Comms.BROADCAST_DEBOUNCE = 5
Comms.REQUEST_REPLY_THROTTLE = 3
Comms.REQUEST_THROTTLE = 10

Comms.lastRequestReply = 0
Comms.lastRequest = 0

function Comms:Initialize()
    if self.initialized then
        return
    end

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(self.PREFIX)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            GSPlus.Comms:OnChatMsgAddon(...)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
            GSPlus.Comms:ScheduleBroadcast()
        end
    end)

    self.eventFrame = eventFrame
    self.initialized = true
end

function Comms:IsEnabled()
    return GSPlus.Options:Get("enableComms")
end

function Comms:GetChannel()
    if IsInRaid and IsInRaid() then
        return "RAID"
    end

    if IsInGroup and IsInGroup() then
        return "PARTY"
    end

    return nil
end

function Comms:Send(message, channel)
    channel = channel or self:GetChannel()

    if not channel or not message then
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(self.PREFIX, message, channel)
        return true
    end

    if SendAddonMessage then
        SendAddonMessage(self.PREFIX, message, channel)
        return true
    end

    return false
end

function Comms:BuildScoreMessage()
    local entry = GSPlus.Inspect:BuildPlayerEntry()

    return string.format(
        "S:%d:%.1f:%.1f:%.1f:%d:%s",
        self.PROTOCOL_VERSION,
        entry.weighted or 0,
        entry.max or 0,
        entry.raw or 0,
        math.floor(entry.legacy or 0),
        tostring(entry.profileKey or "UNKNOWN")
    )
end

function Comms:ParseScoreMessage(message, sender)
    local version, weighted, max, raw, legacy, profileKey = string.match(
        message,
        "^S:(%d+):([%d%.]+):([%d%.]+):([%d%.]+):(%d+):(%S+)$"
    )

    -- Only accept matching protocol versions: score scales differ between
    -- versions, and mixing them would corrupt comparisons.
    if not version or tonumber(version) ~= self.PROTOCOL_VERSION then
        return nil
    end

    return {
        weighted = tonumber(weighted) or 0,
        max = tonumber(max) or 0,
        raw = tonumber(raw) or 0,
        legacy = tonumber(legacy) or 0,
        profileKey = profileKey,
        source = "comms",
        time = time(),
    }
end

function Comms:BroadcastScore(force)
    if not self:IsEnabled() then
        return false
    end

    local channel = self:GetChannel()

    if not channel then
        return false
    end

    return self:Send(self:BuildScoreMessage(), channel)
end

-- Collapses bursts (equipment swaps, roster churn) into one broadcast.
function Comms:ScheduleBroadcast()
    if not self:IsEnabled() or not self:GetChannel() then
        return
    end

    if not (C_Timer and C_Timer.After) then
        self:BroadcastScore()
        return
    end

    if self.broadcastPending then
        return
    end

    self.broadcastPending = true

    C_Timer.After(self.BROADCAST_DEBOUNCE, function()
        GSPlus.Comms.broadcastPending = false
        GSPlus.Comms:BroadcastScore()
    end)
end

-- Throttled because the group window fires this automatically on open.
function Comms:RequestScores()
    if not self:IsEnabled() then
        return false
    end

    -- No group channel means there is no one to ask; return before recording
    -- the throttle timestamp so a request fired while solo doesn't silence
    -- the first real request made just after joining a group.
    if not self:GetChannel() then
        return false
    end

    local now = time()

    if (now - (self.lastRequest or 0)) < self.REQUEST_THROTTLE then
        return false
    end

    self.lastRequest = now

    return self:Send("R:" .. self.PROTOCOL_VERSION)
end

function Comms:OnChatMsgAddon(prefix, message, channel, sender)
    if prefix ~= self.PREFIX or not message or not sender then
        return
    end

    local senderKey = GSPlus.PlayerCache:NormalizeSenderKey(sender)
    local playerName = UnitName and UnitName("player") or nil

    -- Addon messages are echoed back to the sender.
    if not senderKey or senderKey == playerName then
        return
    end

    if not self:IsEnabled() then
        return
    end

    local kind = string.match(message, "^(%a):")

    if kind == "S" then
        local entry = self:ParseScoreMessage(message, sender)

        if entry then
            GSPlus.PlayerCache:Set(senderKey, entry)

            if GSPlus.GroupFrame and GSPlus.GroupFrame.OnScoreUpdated then
                GSPlus.GroupFrame:OnScoreUpdated(nil, senderKey, entry)
            end
        end
    elseif kind == "R" then
        local now = time()

        if (now - (self.lastRequestReply or 0)) >= self.REQUEST_REPLY_THROTTLE then
            self.lastRequestReply = now
            self:BroadcastScore(true)
        end
    end
end
