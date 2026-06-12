-- UnitTooltip.lua
-- Shows gear scores on player mouseover tooltips, fed by the player cache
-- (comms or inspect) with a silent inspect request on cache miss.

BetterGearScore = BetterGearScore or {}
BetterGearScore.UnitTooltip = BetterGearScore.UnitTooltip or {}

local UnitTooltip = BetterGearScore.UnitTooltip

function UnitTooltip:HookTooltips()
    if self.hooked then
        return
    end

    if not GameTooltip or not GameTooltip.HookScript then
        return
    end

    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        BetterGearScore.UnitTooltip:AddScoreToTooltip(tooltip)
    end)

    GameTooltip:HookScript("OnTooltipCleared", function(tooltip)
        tooltip.bgsUnitLineAdded = nil
    end)

    self.hooked = true
end

function UnitTooltip:GetTooltipUnit(tooltip)
    if not tooltip.GetUnit then
        return nil
    end

    local _, unit = tooltip:GetUnit()

    return unit
end

function UnitTooltip:AddScoreToTooltip(tooltip)
    if not BetterGearScore.Options:Get("showUnitTooltip") then
        return
    end

    if tooltip.bgsUnitLineAdded then
        return
    end

    local unit = self:GetTooltipUnit(tooltip)

    if not unit or not UnitIsPlayer(unit) then
        return
    end

    tooltip.bgsUnitLineAdded = true

    local entry

    if UnitIsUnit(unit, "player") then
        entry = BetterGearScore.Inspect:BuildPlayerEntry()
    else
        entry = BetterGearScore.PlayerCache:GetByUnit(unit)
    end

    if entry then
        self:AppendEntryLines(tooltip, entry)
    else
        -- Queue a silent inspect; if it completes while the tooltip is still
        -- up, OnScoreUpdated appends the result live.
        local queued = BetterGearScore.Inspect:QueueUnitInspect(unit)

        if queued then
            self.waitingGuid = UnitGUID and UnitGUID(unit) or nil
            tooltip:AddDoubleLine("BetterGearScore", "inspecting...", 0, 1, 0, 0.6, 0.6, 0.6)
        end
    end

    tooltip:Show()
end

function UnitTooltip:AppendEntryLines(tooltip, entry)
    local coloredScore = BetterGearScore.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0)
    local profileName = BetterGearScore.Profiles:GetProfileDisplayName(entry.profileKey)

    tooltip:AddDoubleLine(
        "BetterGearScore",
        coloredScore .. " |cff888888(" .. profileName .. ")|r",
        0, 1, 0, 1, 1, 1
    )

    if BetterGearScore.Options:Get("showLegacyGearScore") and entry.legacy and entry.legacy > 0 then
        tooltip:AddDoubleLine("GearScore (legacy)", tostring(math.floor(entry.legacy)), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
    end

    if entry.source and entry.source ~= "self" then
        tooltip:AddLine(
            "|cff666666" .. BetterGearScore.PlayerCache:FormatSource(entry)
            .. ", " .. BetterGearScore.PlayerCache:FormatAge(entry) .. "|r"
        )
    end
end

-- Called by Inspect when a queued inspect completes; if the tooltip is still
-- showing that player, append the freshly computed lines.
function UnitTooltip:OnScoreUpdated(guid, name, entry)
    if not guid or self.waitingGuid ~= guid then
        return
    end

    self.waitingGuid = nil

    if not GameTooltip or not GameTooltip:IsShown() then
        return
    end

    local unit = self:GetTooltipUnit(GameTooltip)

    if not unit or not UnitGUID or UnitGUID(unit) ~= guid then
        return
    end

    self:AppendEntryLines(GameTooltip, entry)
    GameTooltip:Show()
end

UnitTooltip:HookTooltips()
