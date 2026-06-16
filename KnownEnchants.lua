-- KnownEnchants.lua
-- Weapon enchant scoring. Most weapon enchants (Mongoose, Crusader, Berserking,
-- the spellpower brands, ...) render in the tooltip as just their NAME with no
-- stat text, so the normal stat/effect parsers can't see them. This module maps
-- each enchant's displayed name to an averaged stat contribution so the enchant
-- counts toward the score, the same way KnownProcs.lua handles famous trinkets.
--
-- Matching is by the enchant's display NAME (not its enchant ID): the name is
-- what the tooltip shows, is stable for a given effect across client flavors
-- (Mongoose is Mongoose in TBC and Wrath), and an exact full-line match can't
-- mis-identify another line. Enchant IDs differ per flavor and per DBC build, so
-- a wrong ID would silently mis-score - names avoid that.
--
-- Values are community-derived average estimates. Proc enchants use the same
-- averaging philosophy as the rest of the addon: an N-second buff at roughly
-- 1 PPM contributes value x (N / 60) on average (see ItemParser.CHANCE_ON_HIT_*).
-- This is DATA - tune freely. An unknown enchant name simply isn't scored.
--
-- Stat-text enchants (e.g. "+35 Agility", "+81 Healing") already show their
-- stat on the tooltip and are picked up by the normal parser, so they are not
-- repeated here. Pure self-heal / utility procs with no gear-stat analog
-- (Battlemaster, Blood Draining, Mending, Lifeward) are intentionally omitted -
-- their contribution to a gear score is negligible.

GSPlus = GSPlus or {}
GSPlus.KnownEnchants = GSPlus.KnownEnchants or {}

local KnownEnchants = GSPlus.KnownEnchants

KnownEnchants.ENCHANT_AVERAGE_STATS = {
    --==================================================================--
    -- Classic / Vanilla
    --==================================================================--
    -- Crusader: chance on hit +100 Strength for 15s (+ self heal). ~1 PPM
    -- -> ~25% uptime -> ~25 Strength (heal ignored - negligible to gear power).
    ["Crusader"] = { STRENGTH = 25 },
    -- Fiery Weapon: chance on hit ~40 Fire damage. Rough melee-throughput
    -- equivalent expressed as attack power.
    ["Fiery Weapon"] = { ATTACKPOWER = 12 },
    -- Lifestealing: shadow damage + self heal on hit. Mostly self-sustain;
    -- small offensive component.
    ["Lifestealing"] = { ATTACKPOWER = 8 },
    -- Icy Chill: frost damage + slow on hit. Mostly utility.
    ["Icy Chill"] = { ATTACKPOWER = 6 },
    -- Winter's Might: flat +7 Frost spell damage.
    ["Winter's Might"] = { SPELLPOWER = 7 },

    --==================================================================--
    -- The Burning Crusade
    --==================================================================--
    -- Mongoose: chance on hit +120 Agility for 15s + ~2% attack speed. ~1 PPM
    -- -> ~25% uptime -> ~30 Agility and ~0.5% average haste.
    ["Mongoose"] = { AGILITY = 30, HASTE = 8 },
    -- Executioner: chance on hit removes 840 armor from the target for 10s.
    -- Benefits the wearer like armor penetration; ~17% effective uptime.
    ["Executioner"] = { ARMOR_PENETRATION = 140 },
    -- Major Spellpower: flat +40 spell damage and healing.
    ["Major Spellpower"] = { SPELLPOWER = 40, HEALING = 40 },
    -- Soulfrost: flat +54 Frost and Shadow spell damage.
    ["Soulfrost"] = { SPELLPOWER = 54 },
    -- Sunfire: flat +50 Arcane and Fire spell damage.
    ["Sunfire"] = { SPELLPOWER = 50 },
    -- Savagery: flat +70 Attack Power (two-handers).
    ["Savagery"] = { ATTACKPOWER = 70 },
    -- Spellsurge: chance to restore mana to the party. Rough self-value as MP5.
    ["Spellsurge"] = { MP5 = 8 },
    -- Potency: flat +20 Strength.
    ["Potency"] = { STRENGTH = 20 },

    --==================================================================--
    -- Wrath of the Lich King
    --==================================================================--
    -- Berserking: chance on hit +400 Attack Power for 15s (- some armor). ~1 PPM
    -- -> ~25% uptime -> ~100 Attack Power.
    ["Berserking"] = { ATTACKPOWER = 100 },
    -- Black Magic: spellcasts have a chance to grant +250 haste rating for 10s.
    -- High trigger rate for casters -> ~24% effective uptime -> ~60 haste.
    ["Black Magic"] = { HASTE = 60 },
    -- Accuracy: flat +25 hit rating and +25 critical strike rating.
    ["Accuracy"] = { HIT = 25, CRITICAL = 25 },
    -- Massacre: flat +110 Attack Power.
    ["Massacre"] = { ATTACKPOWER = 110 },
    -- Mighty Spellpower: flat +63 spell damage and healing.
    ["Mighty Spellpower"] = { SPELLPOWER = 63, HEALING = 63 },
    -- Titanguard: flat +50 Stamina (tank).
    ["Titanguard"] = { STAMINA = 50 },
    -- Blade Ward: chance on hit to gain a parry-and-damage ward. Rough avoidance.
    ["Blade Ward"] = { PARRY = 20 },

    --==================================================================--
    -- Cataclysm
    --==================================================================--
    -- Landslide: chance on hit +1000 Attack Power for 12s -> ~20% uptime
    -- -> ~200 Attack Power.
    ["Landslide"] = { ATTACKPOWER = 200 },
    -- Power Torrent: spell damage/healing has a chance to grant +500 Intellect
    -- for 12s -> ~20% uptime -> ~100 Intellect.
    ["Power Torrent"] = { INTELLECT = 100 },
    -- Hurricane: chance on melee/spell to grant +450 haste for 12s (stacks).
    -- ~20% effective uptime -> ~90 haste.
    ["Hurricane"] = { HASTE = 90 },
    -- Heartsong: spellcasts have a chance to grant +200 Spirit for 15s
    -- -> ~25% uptime -> ~50 Spirit.
    ["Heartsong"] = { SPIRIT = 50 },
    -- Windwalk: chance on hit +600 dodge rating for 10s -> ~20% uptime
    -- -> ~120 dodge (avoidance/tank).
    ["Windwalk"] = { DODGE = 120 },
    -- Avalanche: chance on hit/spell to deal nature damage. Rough throughput,
    -- expressed modestly as attack power (used mainly on leveling/tank weapons).
    ["Avalanche"] = { ATTACKPOWER = 15 },
}

-- Returns the averaged stat table for an enchant displayed under exactly this
-- name (the cleaned tooltip line), or nil. Case-sensitive exact match keeps it
-- from ever colliding with ordinary item text.
function KnownEnchants:GetByName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end

    return self.ENCHANT_AVERAGE_STATS[name]
end
