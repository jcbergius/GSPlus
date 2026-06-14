-- KnownSetBonuses.lua
-- Curated values for high-impact set bonuses whose real worth the generic
-- stat conversion under-rates (the set-bonus analogue of KnownProcs.lua).
--
-- Each entry is matched by a snippet of the bonus text, so it works whether
-- the tooltip shows the active "Set:" form (you wear the set) or the inactive
-- "(N) Set:" form (inspecting someone else). Values are community-derived
-- stat-equivalents and are meant to be tuned per phase - this is where you
-- encode "this bonus is taken over otherwise-stronger items".

GSPlus = GSPlus or {}
GSPlus.KnownSetBonuses = GSPlus.KnownSetBonuses or {}

local KnownSetBonuses = GSPlus.KnownSetBonuses

KnownSetBonuses.ENTRIES = {
    {
        -- Beast Lord 4pc (hunter): Kill Command makes your attacks ignore 600
        -- of the target's armor for 15s. Near-permanent uptime for hunters and
        -- a large physical DPS gain - famously kept over stronger pieces. The
        -- generic model scores the flat armor-ignore far too low, so we value
        -- it as a sizeable attack-power equivalent instead.
        match = "ignore 600 of [%a%s']+ armor",
        stats = { ATTACKPOWER = 180 },
    },
}

-- Returns the curated stat table for a set-bonus line whose text matches a
-- known high-impact effect, or nil to let the generic parser handle it.
function KnownSetBonuses:Match(text)
    if not text then
        return nil
    end

    for _, entry in ipairs(self.ENTRIES) do
        if entry.match and string.find(text, entry.match) then
            return entry.stats
        end
    end

    return nil
end
