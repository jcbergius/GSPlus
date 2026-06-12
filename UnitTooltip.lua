-- UnitTooltip.lua
-- Shows gear scores on player mouseover tooltips, fed by the player cache
-- (comms or inspect) with a silent inspect request on cache miss.

GSPlus = GSPlus or {}
GSPlus.UnitTooltip = GSPlus.UnitTooltip or {}

local UnitTooltip = GSPlus.UnitTooltip

function UnitTooltip:HookTooltips()
    if self.hooked then
        return
    end

    if not GameTooltip or not GameTooltip.HookScript then
        return
    end

    GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
        GSPlus.UnitTooltip:AddScoreToTooltip(tooltip)
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
    if not GSPlus.Options:Get("showUnitTooltip") then
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
        entry = GSPlus.Inspect:BuildPlayerEntry()
    else
        entry = GSPlus.PlayerCache:GetByUnit(unit)
    end

    if entry then
        self:AppendEntryLines(tooltip, entry)

        -- Partial entries (items weren't server-cached during the scan)
        -- under-count; silently refresh while showing what we have.
        if entry.partial and not UnitIsUnit(unit, "player") then
            GSPlus.Inspect:QueueUnitInspect(unit)
        end
    else
        -- Queue a silent inspect; if it completes while the tooltip is still
        -- up, OnScoreUpdated appends the result live.
        local queued = GSPlus.Inspect:QueueUnitInspect(unit)

        if queued then
            self.waitingGuid = UnitGUID and UnitGUID(unit) or nil
            tooltip:AddDoubleLine("gs+", "inspecting...", 0, 1, 0, 0.6, 0.6, 0.6)
        end
    end

    tooltip:Show()
end

function UnitTooltip:AppendEntryLines(tooltip, entry)
    local coloredScore = GSPlus.Calculator:ColorizeScore(entry.weighted or 0, entry.max or 0)
    local profileName = GSPlus.Profiles:GetProfileDisplayName(entry.profileKey)

    tooltip:AddDoubleLine(
        "gs+",
        coloredScore .. " |cff888888(" .. profileName .. ")|r",
        0, 1, 0, 1, 1, 1
    )

    if GSPlus.Options:Get("showLegacyGearScore") and entry.legacy and entry.legacy > 0 then
        tooltip:AddDoubleLine("GearScore (legacy)", tostring(math.floor(entry.legacy)), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
    end

    if entry.partial then
        tooltip:AddLine("|cff888888Some items still loading; score may rise.|r")
    end

    if entry.source and entry.source ~= "self" then
        tooltip:AddLine(
            "|cff666666" .. GSPlus.PlayerCache:FormatSource(entry)
            .. ", " .. GSPlus.PlayerCache:FormatAge(entry) .. "|r"
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
