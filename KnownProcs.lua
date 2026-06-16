-- KnownProcs.lua
-- Exact average-value overrides for famous proc trinkets, keyed by item ID
-- (locale-independent). When an item has an entry here, the generic proc
-- uptime model in ItemParser is skipped and these stats are added instead.
--
-- Values are community-derived average estimates (proc value x realistic
-- uptime from the known internal cooldown and trigger rate), with the
-- basis noted per entry. This is data - tune freely. An unknown or wrong
-- item ID simply falls back to the generic model.

GSPlus = GSPlus or {}
GSPlus.KnownProcs = GSPlus.KnownProcs or {}

local KnownProcs = GSPlus.KnownProcs

KnownProcs.PROC_AVERAGE_STATS = {
    -- Quagmirran's Eye: 320 spell haste for 6s, 45s ICD, procs ~on cooldown
    -- -> ~12% uptime -> ~38 haste
    [27683] = { HASTE = 38 },

    -- Dragonspine Trophy: 325 haste for 10s, 20s ICD, ~1.2 PPM
    -- -> ~20% uptime -> ~64 haste
    [28830] = { HASTE = 64 },

    -- Hourglass of the Unraveller: 300 AP for 10s on crit, 45s ICD
    -- -> ~22% effective uptime -> ~65 AP
    [28034] = { ATTACKPOWER = 65 },

    -- Tsunami Talisman: 340 AP for 10s on crit, 45s ICD
    -- -> ~20% uptime -> ~70 AP
    [30627] = { ATTACKPOWER = 70 },

    -- Sextant of Unstable Currents: 190 spell power for 15s on spell crit,
    -- 45s ICD -> ~26% uptime -> ~50 spell power
    [30626] = { SPELLPOWER = 50 },

    -- Shard of Contempt: 230 AP for 20s, 45s ICD, procs nearly on cooldown
    -- -> ~37% uptime -> ~85 AP
    [34472] = { ATTACKPOWER = 85 },

    -- Serpent-Coil Braid: using a mana gem grants 225 spell power for 15s.
    -- A mana gem comes up roughly every ~2 min in practice, so ~12% uptime
    -- -> ~28-30 spell power. (The "+25% mana from gems" half is utility, unscored.)
    [30720] = { SPELLPOWER = 30 },

    -- Darkmoon Card: Crusade: stacking aura with near-permanent uptime in
    -- combat (~80% of max stacks). Both values listed; role weights zero
    -- out whichever doesn't apply to the wearer's profile.
    [31856] = { ATTACKPOWER = 100, SPELLPOWER = 70 },
}

function KnownProcs:Get(itemId)
    if not itemId then
        return nil
    end

    return self.PROC_AVERAGE_STATS[itemId]
end
