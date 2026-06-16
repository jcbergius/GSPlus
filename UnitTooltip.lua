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

        -- Not yet final (items still loading, or score not confirmed by the
        -- verification pass): refresh in the background while showing "...".
        if not GSPlus.PlayerCache:IsScoreFinal(entry) and not UnitIsUnit(unit, "player") then
            GSPlus.Inspect:QueueUnitInspect(unit)
        end
    else
        -- Queue a silent inspect; if it completes while the tooltip is still
        -- up, OnScoreUpdated appends the result live.
        local queued = GSPlus.Inspect:QueueUnitInspect(unit)

        if queued then
            self.waitingGuid = UnitGUID and UnitGUID(unit) or nil
            tooltip:AddDoubleLine("gs+", "Loading...", 0, 1, 0, 0.6, 0.6, 0.6)
        end
    end

    tooltip:Show()
end

function UnitTooltip:AppendEntryLines(tooltip, entry)
    local rightText = GSPlus.PlayerCache:FormatScore(entry)
    local final = GSPlus.PlayerCache:IsScoreFinal(entry)

    -- Show the role only once the score is final; a role guessed from
    -- partially-loaded gear can be wrong (e.g. DPS plate read as a tank).
    if final then
        rightText = rightText .. " |cff888888("
            .. GSPlus.Profiles:GetProfileDisplayName(entry.profileKey) .. ")|r"
    end

    tooltip:AddDoubleLine("gs+", rightText, 0, 1, 0, 1, 1, 1)

    if final and GSPlus.Options:Get("showLegacyGearScore") and entry.legacy and entry.legacy > 0 then
        tooltip:AddDoubleLine("GearScore (legacy)", tostring(math.floor(entry.legacy)), 0.6, 0.6, 0.6, 0.8, 0.8, 0.8)
    end
end

-- Called by Inspect when a queued inspect completes; if the tooltip is still
-- showing that player, append the freshly computed lines.
function UnitTooltip:OnScoreUpdated(guid, name, entry)
    -- Refresh whenever the tooltip is currently showing the player whose score
    -- changed - not only when a "waiting" flag was set. A cached-but-not-final
    -- entry (common for a stranger whose items are still loading) otherwise
    -- left the live tooltip stuck on "Loading..." even after the score resolved.
    if not guid or not GameTooltip or not GameTooltip.IsShown or not GameTooltip:IsShown() then
        return
    end

    self.waitingGuid = nil

    local unit = self:GetTooltipUnit(GameTooltip)

    if not unit or not UnitGUID or UnitGUID(unit) ~= guid then
        return
    end

    -- Rebuild the tooltip so the live result REPLACES the "inspecting..."
    -- placeholder rather than adding a second gs+ line. SetUnit clears the
    -- tooltip and re-fires OnTooltipSetUnit, which re-runs AddScoreToTooltip
    -- with the now-cached entry (one clean line).
    if GameTooltip.SetUnit then
        GameTooltip:SetUnit(unit)
    else
        self:AppendEntryLines(GameTooltip, entry)
        GameTooltip:Show()
    end
end

UnitTooltip:HookTooltips()
