-- GameVersion.lua
-- Detects which client flavor we're running on so era-specific data
-- (rating conversions, stat caps, item budgets) can be selected from
-- flavor-keyed tables. Everything else in the addon is data-driven by the
-- tooltip text itself and ports without changes.

BetterGearScore = BetterGearScore or {}
BetterGearScore.GameVersion = BetterGearScore.GameVersion or {}

local GameVersion = BetterGearScore.GameVersion

GameVersion.VANILLA = "VANILLA"
GameVersion.TBC = "TBC"
GameVersion.WRATH = "WRATH"
GameVersion.CATA = "CATA"
GameVersion.MAINLINE = "MAINLINE"

function GameVersion:Detect()
    local flavor

    if WOW_PROJECT_ID then
        if WOW_PROJECT_ID == (WOW_PROJECT_CLASSIC or 2) then
            flavor = self.VANILLA
        elseif WOW_PROJECT_ID == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5) then
            flavor = self.TBC
        elseif WOW_PROJECT_ID == (WOW_PROJECT_WRATH_CLASSIC or 11) then
            flavor = self.WRATH
        elseif WOW_PROJECT_ID == (WOW_PROJECT_CATACLYSM_CLASSIC or 14) then
            flavor = self.CATA
        elseif WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1) then
            flavor = self.MAINLINE
        end
    end

    -- Fall back to the client build's interface number, which also covers
    -- future project ids we don't know about yet.
    if not flavor and GetBuildInfo then
        local tocVersion = select(4, GetBuildInfo())

        if type(tocVersion) == "number" then
            if tocVersion < 20000 then
                flavor = self.VANILLA
            elseif tocVersion < 30000 then
                flavor = self.TBC
            elseif tocVersion < 40000 then
                flavor = self.WRATH
            elseif tocVersion < 50000 then
                flavor = self.CATA
            else
                flavor = self.MAINLINE
            end
        end
    end

    self.flavor = flavor or self.TBC

    return self.flavor
end

function GameVersion:GetFlavor()
    return self.flavor or self:Detect()
end

-- Returns values[flavor], falling back to values.DEFAULT. The standard way
-- for data modules to declare era-specific tables.
function GameVersion:Select(values)
    if not values then
        return nil
    end

    local value = values[self:GetFlavor()]

    if value == nil then
        value = values.DEFAULT
    end

    return value
end

function GameVersion:IsVanilla()
    return self:GetFlavor() == self.VANILLA
end

function GameVersion:IsTBC()
    return self:GetFlavor() == self.TBC
end

function GameVersion:IsWrath()
    return self:GetFlavor() == self.WRATH
end

function GameVersion:IsCata()
    return self:GetFlavor() == self.CATA
end
