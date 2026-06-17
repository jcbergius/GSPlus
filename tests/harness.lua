-- WoW API stub harness to smoke-test GSPlus outside the game.
-- Run from the repo root: lua5.1 tests/harness.lua
local ADDON_DIR = arg[1] or "."

time = os.time

local fakeTooltips = {}
local fakeItems = {}
local equipped = {}
local slotIds = {}
local printed = {}
local sentMessages = {}
local notifyInspectCalls = 0
local pendingTimers = {}
local optionsPanelOpened = 0

local playerClass = "WARRIOR"
local inGroup = false
local combatRatingBonus = {}
local defenseBase, defenseMod = 350, 0
local expertiseValue = 0

local TEST_UNITS = {
    player = { name = "Hero", guid = "guid-hero", isPlayer = true },
}

local realPrint = print
function print(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    printed[#printed + 1] = table.concat(parts, " ")
end

local function updateTooltipFontStrings(frame)
    if not frame.name then return end
    for i = 1, 40 do
        local line = frame.lines[i]
        local text, r, g, b
        if type(line) == "table" then
            text, r, g, b = line.text, line.r, line.g, line.b
        else
            text = line
        end
        r, g, b = r or 1, g or 1, b or 1
        _G[frame.name .. "TextLeft" .. i] = {
            GetText = function() return text end,
            GetTextColor = function() return r, g, b end,
        }
        _G[frame.name .. "TextRight" .. i] = {
            GetText = function() return nil end,
            GetTextColor = function() return 1, 1, 1 end,
        }
    end
end

local function makeFontString()
    local fs = {}
    function fs:SetPoint() end
    function fs:SetText(t) fs.text = t end
    function fs:SetWidth() end
    function fs:SetJustifyH() end
    function fs:GetText() return fs.text end
    return fs
end

function CreateFrame(frameType, name)
    local f = { lines = {}, name = name, shown = false, checked = false }
    function f:RegisterEvent() end
    function f:RegisterForDrag() end
    function f:SetScript(k, v) f["script_" .. tostring(k)] = v end
    function f:HookScript(k, v) f["hook_" .. tostring(k)] = v end
    function f:SetOwner() end
    function f:ClearAllPoints() end
    function f:SetPoint() end
    function f:GetRight() return f._right or 0 end
    function f:ClearLines() f.lines = {}; updateTooltipFontStrings(f) end
    function f:SetHyperlink(link) f.lines = fakeTooltips[link] or {}; updateTooltipFontStrings(f) end
    function f:NumLines() return #f.lines end
    function f:Hide() f.shown = false end
    function f:Show() f.shown = true end
    function f:IsShown() return f.shown end
    function f:SetSize() end
    function f:SetPoint() end
    function f:ClearAllPoints() end
    function f:SetParent() end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:EnableMouse() end
    function f:SetMovable() end
    function f:SetBackdrop() end
    function f:SetBackdropColor() end
    function f:SetScrollChild() end
    function f:SetHeight() end
    function f:SetText() end
    function f:SetChecked(v) f.checked = v end
    function f:GetChecked() return f.checked end
    f.CreateFontString = function() return makeFontString() end
    if name then _G[name] = f end
    return f
end

function GetItemInfo(link)
    local item = fakeItems[link]
    if not item then return nil end
    return item.name, link, item.rarity or 4, item.ilvl or 100, 70, "Armor", "Cloth", 1, item.equipLoc, "", 10000
end

function GetItemStats(link) return nil end
function GetInventorySlotInfo(slotKey) return slotIds[slotKey] end

function GetInventoryItemLink(unit, slotId)
    for key, id in pairs(slotIds) do
        if id == slotId then return equipped[key] end
    end
    return nil
end

function UnitClass(unit)
    if unit == "player" then return playerClass, playerClass end
    local info = TEST_UNITS[unit]
    if info and info.class then return info.class, info.class end
    return playerClass, playerClass
end

function UnitExists(unit) return TEST_UNITS[unit] ~= nil end
function UnitIsPlayer(unit) local u = TEST_UNITS[unit]; return u ~= nil and u.isPlayer end
function UnitIsUnit(a, b) return a == b end
function UnitGUID(unit) local u = TEST_UNITS[unit]; return u and u.guid end
function UnitName(unit) local u = TEST_UNITS[unit]; if not u then return nil end; return u.name, u.realm end
function CanInspect(unit) return TEST_UNITS[unit] ~= nil end
function NotifyInspect(unit) notifyInspectCalls = notifyInspectCalls + 1 end
local inCombat = false
function InCombatLockdown() return inCombat end
local clearInspectCalls = 0
function ClearInspectPlayer() clearInspectCalls = clearInspectCalls + 1 end
local itemLoadRequests = 0
local itemDataCached = {}
C_Item = {
    RequestLoadItemDataByID = function() itemLoadRequests = itemLoadRequests + 1 end,
    IsItemDataCachedByID = function(id)
        local v = itemDataCached[tostring(id)]
        if v == nil then return true end
        return v
    end,
}
function IsShiftKeyDown() return true end
function IsInRaid() return false end
function IsInGroup() return inGroup end
function GetNumGroupMembers() return inGroup and 2 or 0 end
function Ambiguate(name) return string.match(name, "^([^%-]+)") or name end
function InterfaceOptions_AddCategory() end
function InterfaceOptionsFrame_OpenToCategory() optionsPanelOpened = optionsPanelOpened + 1 end
function GetCombatRatingBonus(index) return combatRatingBonus[index] or 0 end
function UnitDefense() return defenseBase, defenseMod end
function GetExpertise() return expertiseValue end

ERR_OUT_OF_RANGE = "Out of range."
UIErrorsFrame = { messages = {}, AddMessage = function(self, msg) self.messages[#self.messages + 1] = msg end }

RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.41, g = 0.8, b = 0.94 } }

WOW_PROJECT_MAINLINE = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
WOW_PROJECT_WRATH_CLASSIC = 11
WOW_PROJECT_CATACLYSM_CLASSIC = 14
WOW_PROJECT_ID = WOW_PROJECT_BURNING_CRUSADE_CLASSIC

function GetBuildInfo() return "2.5.4", "44832", "Jan 1 2026", 20504 end

C_Timer = {
    After = function(sec, fn) pendingTimers[#pendingTimers + 1] = fn end,
}

C_ChatInfo = {
    RegisterAddonMessagePrefix = function() end,
    SendAddonMessage = function(prefix, message, channel)
        sentMessages[#sentMessages + 1] = { prefix = prefix, message = message, channel = channel }
    end,
}

local talentTabs = {
    { name = "Arms", points = 5 },
    { name = "Fury", points = 3 },
    { name = "Protection", points = 41 },
}
function GetNumTalentTabs() return #talentTabs end
function GetTalentTabInfo(i)
    local tab = talentTabs[i]
    if not tab then return nil end
    return tab.name, "texture", tab.points, "file"
end

SlashCmdList = {}
UIParent = CreateFrame("Frame", "UIParent")

local nextSlotId = 1
local allSlotKeys = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot",
}
for _, key in ipairs(allSlotKeys) do
    slotIds[key] = nextSlotId
    nextSlotId = nextSlotId + 1
end

-- Fake items -----------------------------------------------------------------
local chestLink = "|cffa335ee|Hitem:1001::::::::70:::::|h[Test Healer Robe]|h|r"
fakeItems[chestLink] = { name = "Test Healer Robe", equipLoc = "INVTYPE_ROBE" }
fakeTooltips[chestLink] = {
    "Test Healer Robe",
    "Chest", "Cloth",
    "150 Armor",
    "+18 Spirit",
    "+25 Intellect",
    "Equip: Increases healing done by up to 42 and damage done by up to 14 for all magical spells and effects.",
    "Equip: Restores 7 mana per 5 sec.",
}

local swordLink = "|cffa335ee|Hitem:1002::::::::70:::::|h[Test Sword]|h|r"
fakeItems[swordLink] = { name = "Test Sword", equipLoc = "INVTYPE_WEAPONMAINHAND" }
fakeTooltips[swordLink] = {
    "Test Sword",
    "Main Hand", "Sword",
    "120 - 180 Damage", "Speed 2.60",
    "(57.7 damage per second)",
    "+15 Strength",
    "Equip: Improves your chance to get a critical strike by 1%.",
}

local gemChestLink = "|cffa335ee|Hitem:1003::::::::70:::::|h[Socketed Vest]|h|r"
fakeItems[gemChestLink] = { name = "Socketed Vest", equipLoc = "INVTYPE_ROBE" }
fakeTooltips[gemChestLink] = {
    "Socketed Vest", "Chest", "Cloth",
    "+10 Stamina",
    "Red Socket", "Yellow Socket",
}

local betterChestLink = "|cffa335ee|Hitem:1004::::::::70:::::|h[Heavy Plate Chest]|h|r"
fakeItems[betterChestLink] = { name = "Heavy Plate Chest", equipLoc = "INVTYPE_CHEST", ilvl = 115 }
fakeTooltips[betterChestLink] = {
    "Heavy Plate Chest", "Chest", "Plate",
    "1200 Armor",
    "+40 Stamina",
    "+20 Defense Rating",
}

local hitRingLink = "|cffa335ee|Hitem:1006::::::::70:::::|h[Band of Precision]|h|r"
fakeItems[hitRingLink] = { name = "Band of Precision", equipLoc = "INVTYPE_FINGER" }
fakeTooltips[hitRingLink] = {
    "Band of Precision", "Finger",
    "Equip: Improves your hit rating by 20.",
}

local enchantedLink = "|cffa335ee|Hitem:1005:2564:::::::70:::::|h[Enchanted Blade]|h|r"
fakeItems[enchantedLink] = { name = "Enchanted Blade", equipLoc = "INVTYPE_WEAPONMAINHAND" }
fakeTooltips[enchantedLink] = { "Enchanted Blade", "+10 Agility" }

-- One item carrying every green-stat format the parser must understand.
local greenLink = "|cffa335ee|Hitem:1007::::::::70:::::|h[Compendium of Green Text]|h|r"
fakeItems[greenLink] = { name = "Compendium of Green Text", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[greenLink] = {
    "Compendium of Green Text", "Trinket",
    "+20 Health",
    "+150 Mana",
    "-10 Stamina",
    "Equip: Increases damage done by Shadow spells and effects by up to 56.",
    "Equip: Increases healing done by spells and effects by up to 55.",
    "Equip: Increased Defense +7.",
    "Equip: Improves your chance to hit with spells by 2%.",
    "Equip: Increases your chance to parry an attack by 1%.",
    "Equip: Allows 15% of your Mana regeneration to continue while casting.",
    "Equip: Your attacks ignore 175 of your opponent's armor.",
    "Equip: Decreases the magical resistances of your spell targets by 35.",
    "Equip: +81 Attack Power when fighting Undead.",
    "Equip: Increases Fire Resistance by 10.",
    "Equip: Chance on hit to steal 120 life from the target.",
}

equipped.ChestSlot = chestLink
equipped.MainHandSlot = swordLink

-- Load addon files in toc order ----------------------------------------------
local tocOrder = {
    "Core.lua", "GameVersion.lua", "StatWeights.lua", "ReferenceGear.lua", "KnownProcs.lua", "KnownEnchants.lua", "KnownSetBonuses.lua", "StatCaps.lua", "Profiles.lua", "TalentDetector.lua",
    "ItemParser.lua", "SetBonuses.lua", "Calculator.lua",
    "LegacyGearScore.lua", "Options.lua", "PlayerCache.lua",
    "CharacterPaneUI.lua", "InspectPaneUI.lua", "UI.lua", "GroupFrame.lua",
    "Tooltip.lua", "UnitTooltip.lua", "Inspect.lua", "Comms.lua", "Commands.lua",
}
for _, file in ipairs(tocOrder) do
    local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
    chunk()
end

-- The NotifyInspect throttle uses second-resolution time() which a fast
-- test run can't advance; disable it for the baseline and test the throttle
-- logic explicitly in its own section.
GSPlus.Inspect.MIN_NOTIFY_INTERVAL = 0

-- Tests ------------------------------------------------------------------------
local failures = 0
local function check(cond, label)
    if cond then
        realPrint("PASS: " .. label)
    else
        failures = failures + 1
        realPrint("FAIL: " .. label)
    end
end

-- 1. Zero-config: welcome message printed once, login silent afterwards
printed = {}
GSPlus:Initialize()
GSPlus:Initialize()
local welcomeCount = 0
for _, line in ipairs(printed) do
    if string.find(line, "is ready") then welcomeCount = welcomeCount + 1 end
end
check(welcomeCount == 1, "welcome message printed exactly once")
-- INSPECT_READY listener must exist after init, not only after a lazy
-- background inspect (so the inspect window works with tooltips disabled)
check(GSPlus.Inspect.eventFrame ~= nil, "inspect events registered at init")

-- 2. Single slash command opens options
SlashCmdList["GSPlus"]("")
check(optionsPanelOpened > 0, "/gs opens the options panel")

-- 2b. /gs debug prints diagnostics without erroring
printed = {}
SlashCmdList["GSPlus"]("debug")
check(#printed > 0 and string.find(printed[1], "gs+ debug", 1, true), "/gs debug prints diagnostics")

-- 3. Item parsing regressions
local stats = GSPlus.ItemParser:ParseItemStats(chestLink)
check(stats.SPIRIT == 18 and stats.HEALING == 42 and stats.MP5 == 7, "chest stats parsed")
local gstats = GSPlus.ItemParser:ParseItemStats(gemChestLink)
check(gstats.EMPTY_SOCKETS == 2, "empty sockets detected")
check(GSPlus.ItemParser:GetEnchantId(enchantedLink) == 2564, "enchant id parsed")
check(GSPlus.ItemParser:CountMissingEnchants("player") == 2, "missing enchants counted")
check(GSPlus.LegacyGearScore:GetPlayerScore() == 228, "legacy GS total")
check(GSPlus.TalentDetector:GetDetectedProfile() == "WARRIOR_TANK", "warrior prot detected")

-- 3b. Green stat format coverage
local g = GSPlus.ItemParser:ParseItemStats(greenLink)
check(g.SCHOOL_SPELLPOWER == 56, "school-specific spell damage parsed (got " .. tostring(g.SCHOOL_SPELLPOWER) .. ")")
check(GSPlus.Weights:GetWeight("WARLOCK_DPS", "SCHOOL_SPELLPOWER") == 1.0, "school spell damage aliases SPELLPOWER weight")
check(g.HEALING == 55, "vanilla healing wording parsed")
check(g.DEFENSE == 7, "old-style Increased Defense parsed")
check(g.HIT and math.abs(g.HIT - 25.24) < 0.01, "spell hit percent converted to rating")
check(g.PARRY and math.abs(g.PARRY - 23.65) < 0.01, "parry percent converted to rating")
check(g.MP5 and math.abs(g.MP5 - 7.5) < 0.01, "mana regen while casting approximated as MP5")
check(g.ARMOR_PENETRATION == 175, "armor penetration parsed")
check(g.SPELL_PENETRATION == 35, "spell penetration parsed")
check(g.ATTACKPOWER and math.abs(g.ATTACKPOWER - 20.25) < 0.01, "conditional AP scaled to quarter value")
check(g.FIRE_RESISTANCE == 10, "single-school resistance equip line parsed")
check(g.HEALTH == 20 and g.MANA == 150, "flat Health/Mana base stats parsed")
check(g.STAMINA == -10, "negative stat tracked as negative")
check(g.UNSCORED_EQUIP_EFFECT == 1, "unparseable proc flagged as unscored")

-- Negative stats and unscored markers must not affect the budget score
local filtered = {}
for k, v in pairs(g) do
    if k ~= "UNSCORED_EQUIP_EFFECT" and k ~= "STAMINA" then filtered[k] = v end
end
check(math.abs(GSPlus.Calculator:CalculateRawStatBudget(g)
    - GSPlus.Calculator:CalculateRawStatBudget(filtered)) < 0.001,
    "negative stats and unscored markers excluded from budget")

-- Alias weights: new stats inherit role value from their parent stat
check(GSPlus.Weights:GetWeight("WARRIOR_TANK", "HEALTH") == 1.0, "HEALTH aliases STAMINA weight")
check(GSPlus.Weights:GetWeight("MAGE_DPS", "SPELL_PENETRATION") == 1.0, "SPELL_PENETRATION aliases SPELLPOWER weight")
check(GSPlus.Weights:GetWeight("WARRIOR_DPS", "ARMOR_PENETRATION") == 0.90, "ARMOR_PENETRATION aliases ATTACKPOWER weight")
check(GSPlus.Weights:GetWeight("PRIEST_HEALER", "ARMOR_PENETRATION") == 0.0, "healer gets no armor penetration value")

-- 4. Stat cap tapering
local hitStats = GSPlus.ItemParser:ParseItemStats(hitRingLink)
check(hitStats.HIT == 20, "hit ring parsed")

combatRatingBonus[6] = 5.0  -- melee hit, well below 9% cap
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT") == 1, "below cap: full hit weight")
local uncappedScore = GSPlus.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, true)

combatRatingBonus[6] = 12.0  -- past the 9% cap
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT") == 0.15, "past cap: hit weight floored")
local cappedScore = GSPlus.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, true)
check(cappedScore < uncappedScore * 0.2, "capped hit item scores far lower ("
    .. string.format("%.1f vs %.1f", cappedScore, uncappedScore) .. ")")

local uncappedForOthers = GSPlus.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, false)
check(math.abs(uncappedForOthers - uncappedScore) < 0.001, "caps not applied when scoring other players")

combatRatingBonus[6] = 8.5  -- inside the 1% taper window
GSPlus.StatCaps:InvalidateCache()
local taperMult = GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT")
check(taperMult > 0.15 and taperMult < 1, "taper window interpolates (" .. string.format("%.2f", taperMult) .. ")")

combatRatingBonus[8] = 10.0  -- spell hit below 16% cap
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("MAGE_DPS", "HIT") == 1, "caster uses spell hit cap")

defenseBase, defenseMod = 350, 145  -- 495 defense, past 490
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_TANK", "DEFENSE") == 0.5, "defense floored at 0.5 past 490")
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "DEFENSE") == 1, "defense cap only applies to tanks")

expertiseValue = 30  -- past 26 dodge cap
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("ROGUE_DPS", "EXPERTISE") == 0.15, "dps expertise floored past dodge cap")
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_TANK", "EXPERTISE") == 1, "tank expertise not tapered")

-- reset ratings for remaining tests
combatRatingBonus = {}
defenseBase, defenseMod = 350, 0
expertiseValue = 0
GSPlus.StatCaps:InvalidateCache()
GSPlus:InvalidateCaches()

-- 4b. Flavor portability: era data switches with the detected client
check(GSPlus.GameVersion:GetFlavor() == "TBC", "TBC flavor detected from project id")

WOW_PROJECT_ID = WOW_PROJECT_WRATH_CLASSIC
GSPlus.GameVersion:Detect()
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.GameVersion:GetFlavor() == "WRATH", "WRATH flavor detected")
check(GSPlus.ItemParser:GetRatingPerPercent("HIT") == 32.79, "wrath level-80 hit rating conversion")
check(GSPlus.Calculator:GetColorReferenceScale() == 2.95, "wrath color reference scale applied")

combatRatingBonus[6] = 8.5  -- past the wrath 8% melee cap (below TBC's 9%)
GSPlus.StatCaps:InvalidateCache()
check(GSPlus.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT") == 0.15, "wrath melee hit cap is 8%")

check(GSPlus.ItemParser:NormalizeStatName("Mastery Rating") == "MASTERY", "mastery rating recognized")
check(GSPlus.Weights:GetWeight("WARRIOR_DPS", "MASTERY") == 0.85, "MASTERY aliases CRITICAL weight")

-- The legacy formula IS the wrath-era GearScore formula: an ilvl 264 epic
-- chest must score 494, the per-slot value behind the famous ~5.9k ICC GS.
local iccChestLink = "|cffa335ee|Hitem:1008::::::::80:::::|h[Sanctified Chestguard]|h|r"
fakeItems[iccChestLink] = { name = "Sanctified Chestguard", equipLoc = "INVTYPE_CHEST", ilvl = 264 }
fakeTooltips[iccChestLink] = { "Sanctified Chestguard", "Chest", "Plate", "+200 Stamina" }
check(GSPlus.LegacyGearScore:GetItemScore(iccChestLink, "WARRIOR") == 494,
    "legacy GS matches real wrath GearScore for ilvl 264 chest")

WOW_PROJECT_ID = WOW_PROJECT_CLASSIC
GSPlus.GameVersion:Detect()
GSPlus.StatCaps:InvalidateCache()
expertiseValue = 30
check(GSPlus.GameVersion:GetFlavor() == "VANILLA", "VANILLA flavor detected")
check(GSPlus.StatCaps:GetWeightMultiplier("ROGUE_DPS", "EXPERTISE") == 1, "vanilla has no expertise cap")
check(GSPlus.Calculator:GetColorReferenceScale() == 0.60, "vanilla color reference scale applied")

-- restore TBC for the rest of the suite
WOW_PROJECT_ID = WOW_PROJECT_BURNING_CRUSADE_CLASSIC
GSPlus.GameVersion:Detect()
combatRatingBonus = {}
expertiseValue = 0
GSPlus.StatCaps:InvalidateCache()
GSPlus:InvalidateCaches()
check(GSPlus.GameVersion:GetFlavor() == "TBC", "flavor restored to TBC")

-- 5. CONSISTENCY INVARIANT: displayed/shared scores are never cap-adjusted.
-- The same gear must produce the same number for everyone, regardless of
-- the local player's rating state.
GSPlus:InvalidateCaches()
local scoreBefore = GSPlus.Calculator:GetPlayerGSPlus().totalWeightedScore
local commsBefore = GSPlus.Comms:BuildScoreMessage()

combatRatingBonus[6] = 12.0  -- now hit-capped
GSPlus.StatCaps:InvalidateCache()
GSPlus:InvalidateCaches()
local scoreAfter = GSPlus.Calculator:GetPlayerGSPlus().totalWeightedScore
local commsAfter = GSPlus.Comms:BuildScoreMessage()

check(math.abs(scoreBefore - scoreAfter) < 0.001, "total score unchanged by player's cap state")
check(commsBefore == commsAfter, "broadcast score unchanged by player's cap state")

local rows = GSPlus.Tooltip:BuildStatContributionRows(hitStats, "WARRIOR_DPS")
-- Cap-neutral AND clean: the breakdown shows the uncapped, un-normalized HIT
-- weight (the raw 1.0), never the hit-capped 0.15 nor a normalization-scaled value.
check(#rows == 1 and math.abs(rows[1].roleWeight - GSPlus.Weights:GetWeight("WARRIOR_DPS", "HIT")) < 0.001
    and rows[1].roleWeight == 1.0,
    "breakdown shows clean, cap-neutral role weights")

local cappedNames = GSPlus.StatCaps:GetCappedStatNames(hitStats, "WARRIOR_DPS")
check(#cappedNames == 1 and cappedNames[1] == "Hit Rating", "capped stat names listed for advisory note")

-- The personal upgrade comparison IS cap-aware (advice, not a score)
local cappedDelta = GSPlus.Tooltip:GetUpgradeComparison(hitRingLink, "WARRIOR_DPS").delta
combatRatingBonus = {}
GSPlus.StatCaps:InvalidateCache()
local uncappedDelta = GSPlus.Tooltip:GetUpgradeComparison(hitRingLink, "WARRIOR_DPS").delta
check(cappedDelta < uncappedDelta, "upgrade comparison discounts capped hit ("
    .. string.format("%.1f vs %.1f", cappedDelta, uncappedDelta) .. ")")
GSPlus:InvalidateCaches()

-- 6. Profile override still works through the Profiles API (dropdown path).
-- The override must be a profile for the player's own class (a cross-class pick
-- is rejected - see the per-character manual-profile section below).
GSPlus.Profiles:SetSelectedProfile("WARRIOR_DPS")
check(GSPlus.Profiles:GetSelectedProfile() == "WARRIOR_DPS", "manual profile via dropdown API")
check(GSPlus.Profiles:SetSelectedProfile("MAGE_DPS") == false, "a cross-class manual profile is rejected")
GSPlus.Profiles:UseAutomaticProfileDetection()
check(GSPlus.Profiles:GetSelectedProfile() == "WARRIOR_TANK", "auto detection restored")

-- 7. Comms roundtrip
local message = GSPlus.Comms:BuildScoreMessage()
check(string.match(message, "^S:4:") ~= nil, "score message built (protocol v4)")
GSPlus.Comms:OnChatMsgAddon("GSPlus", message, "PARTY", "Alice-Realm")
local aliceEntry = GSPlus.PlayerCache:Get("Alice")
check(aliceEntry ~= nil and aliceEntry.source == "comms", "comms score cached")

-- 8. Inspect queue (silent)
TEST_UNITS.target = { name = "Bob", guid = "guid-bob", isPlayer = true, class = "MAGE" }
notifyInspectCalls = 0
check(GSPlus.Inspect:QueueUnitInspect("target"), "inspect queued")
check(notifyInspectCalls == 1, "NotifyInspect called once")
GSPlus.Inspect:HandleInspectReady("guid-bob")
local bobEntry = GSPlus.PlayerCache:Get("Bob")
check(bobEntry ~= nil and bobEntry.source == "inspect" and bobEntry.profileKey == "MAGE_DPS", "inspect cached with talent profile")
check(GSPlus.Inspect:QueueUnitInspect("target") == false, "re-inspect blocked by cooldown")
check(GSPlus.Inspect:QueueUnitInspect("player") == false, "self-inspect is a no-op")

-- 9. Unit tooltip
local fakeUnitTip = {
    addedLines = {},
    GetUnit = function() return "Bob", "target" end,
    AddLine = function(self, text) self.addedLines[#self.addedLines + 1] = text or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
GSPlus.UnitTooltip:AddScoreToTooltip(fakeUnitTip)
local sawScoreLine = false
for _, line in ipairs(fakeUnitTip.addedLines) do
    if string.find(line, "gs+", 1, true) then sawScoreLine = true end
end
check(sawScoreLine, "unit tooltip shows cached score")

-- 10. Inspect window integration
InspectFrame = CreateFrame("Frame", "InspectFrame")
InspectFrame.unit = "target"
InspectPaperDollFrame = CreateFrame("Frame", "InspectPaperDollFrame")
GSPlus.InspectPaneUI:Initialize()
InspectFrame:Show()
GSPlus.InspectPaneUI:Update()
check(GSPlus.InspectPaneUI.frame ~= nil, "inspect pane frame created")
check(GSPlus.InspectPaneUI.scoreText.text ~= nil
    and string.find(GSPlus.InspectPaneUI.scoreText.text, "|c") ~= nil, "inspect pane shows Bob's score")
GSPlus.InspectPaneUI:OnScoreUpdated("guid-bob")
check(GSPlus.InspectPaneUI.frame:IsShown(), "inspect pane visible after score update")

-- HandleInspectReady must NOT call ClearInspectPlayer (breaks Blizzard inspect)
check(clearInspectCalls == 0, "ClearInspectPlayer never called")

InspectFrame:Hide()

-- 11. Character pane is the click hub
local paneFrame = GSPlus.CharacterPaneUI.frame
check(paneFrame ~= nil and paneFrame.script_OnMouseUp ~= nil, "character pane has click handler")
paneFrame.script_OnMouseUp(paneFrame, "LeftButton")
check(GSPlus.UI:IsVisible(), "left-click opens gear window")
paneFrame.script_OnMouseUp(paneFrame, "LeftButton")
check(not GSPlus.UI:IsVisible(), "left-click again closes gear window")
paneFrame.script_OnMouseUp(paneFrame, "RightButton")
check(GSPlus.GroupFrame:IsVisible(), "right-click opens group window")
paneFrame.script_OnMouseUp(paneFrame, "RightButton")
check(not GSPlus.GroupFrame:IsVisible(), "right-click again closes group window")

-- 12. Group window auto-requests scores on open
inGroup = true
GSPlus.Comms.lastRequest = 0
sentMessages = {}
GSPlus.GroupFrame:Show()
local sawRequest = false
for _, sent in ipairs(sentMessages) do
    if sent.message == "R:4" then sawRequest = true end
end
check(sawRequest, "group window open requests scores automatically")
GSPlus.GroupFrame:Hide()
inGroup = false

-- 13. Upgrade comparison still works (player context with caps)
local profileKey = GSPlus.Profiles:GetSelectedProfile()
local equippedCmp = GSPlus.Tooltip:GetUpgradeComparison(chestLink, profileKey)
check(equippedCmp and equippedCmp.isEquipped, "equipped item recognized")
local upgradeCmp = GSPlus.Tooltip:GetUpgradeComparison(betterChestLink, profileKey)
check(upgradeCmp and (upgradeCmp.delta or 0) > 0, "tanky chest is an upgrade for warrior tank")

-- 14. Feral druid gear-based detection regression
playerClass = "DRUID"
talentTabs = {
    { name = "Balance", points = 0 },
    { name = "Feral Combat", points = 41 },
    { name = "Restoration", points = 5 },
}
GSPlus:InvalidateCaches()
equipped.ChestSlot = betterChestLink
GSPlus.ItemParser.statsCache = {}
check(GSPlus.TalentDetector:GetDetectedProfile() == "DRUID_TANK", "tanky gear flips feral to DRUID_TANK")
equipped.ChestSlot = chestLink
GSPlus:InvalidateCaches()

-- 15. Death Knight gear-based role detection (Wrath/Cata class, same logic)
playerClass = "DEATHKNIGHT"
talentTabs = {
    { name = "Blood", points = 51 },
    { name = "Frost", points = 10 },
    { name = "Unholy", points = 0 },
}
equipped.ChestSlot = betterChestLink
GSPlus:InvalidateCaches()
check(GSPlus.TalentDetector:GetDetectedProfile() == "DEATHKNIGHT_TANK",
    "Blood DK with tanky gear resolves to tank")
talentTabs[1].points = 0
talentTabs[2].points = 51
GSPlus:InvalidateCaches()
check(GSPlus.TalentDetector:GetDetectedProfile() == "DEATHKNIGHT_DPS", "Frost DK detected as DPS")
equipped.ChestSlot = chestLink
GSPlus:InvalidateCaches()

-- 16. Playtest fixes: minimal display defaults
playerClass = "WARRIOR"
talentTabs = {
    { name = "Arms", points = 5 },
    { name = "Fury", points = 3 },
    { name = "Protection", points = 41 },
}
GSPlus:InvalidateCaches()

check(GSPlus.Options:Get("showItemTooltip") == true, "item tooltip ON by default")
check(GSPlus.Options:Get("showLegacyGearScore") == false, "legacy GS off by default")
check(GSPlus.Options:Get("showBudgetScore") == false, "budget score off by default")
check(GSPlus.Options:Get("showTooltipBreakdown") == true, "breakdown ON by default")
check(GSPlus.Options:Get("showUpgradeDelta") == false, "upgrade delta off by default")
check(GSPlus.Options:Get("showCharacterPane") == true, "character pane on by default")
check(GSPlus.Options:Get("showUnitTooltip") == true, "unit tooltip on by default")
check(GSPlus.Options:Get("enableComms") == true, "comms on by default")

local quietTip = {
    addedLines = {},
    GetItem = function() return "Test Healer Robe", chestLink end,
    AddLine = function(self, text) self.addedLines[#self.addedLines + 1] = text or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
GSPlus.Tooltip:AddGearScoreToTooltip(quietTip)
check(#quietTip.addedLines > 0, "item tooltip shows by default")

GSPlus.Options:Set("showItemTooltip", true)
quietTip.addedLines = {}
quietTip.bgsScoreAdded = nil
GSPlus.Tooltip:AddGearScoreToTooltip(quietTip)
local sawBudget, sawLegacy = false, false
for _, line in ipairs(quietTip.addedLines) do
    if string.find(line, "Budget Score") then sawBudget = true end
    if string.find(line, "legacy") then sawLegacy = true end
end
check(#quietTip.addedLines > 0, "item tooltip shows when enabled")
check(not sawBudget and not sawLegacy, "budget and legacy lines hidden unless enabled")

GSPlus.Options:Set("showBudgetScore", true)
quietTip.addedLines = {}
quietTip.bgsScoreAdded = nil
GSPlus.Tooltip:AddGearScoreToTooltip(quietTip)
sawBudget = false
for _, line in ipairs(quietTip.addedLines) do
    if string.find(line, "Budget Score") then sawBudget = true end
end
check(sawBudget, "budget line shows when enabled")
GSPlus.Options:Set("showBudgetScore", false)
GSPlus.Options:Set("showItemTooltip", false)

-- 17. Talent API signature robustness (suspected cause of the playtest
-- healer mis-scoring: unreadable talents fell back to the class default,
-- scoring a Resto Shaman with Elemental weights)
local realGetTalentTabInfo = GetTalentTabInfo

GetTalentTabInfo = function(i) return i, "Tree" .. i, 136052, ({ 0, 0, 44 })[i] end
local sigCName, sigCPoints = GSPlus.TalentDetector:GetTalentTabNameAndPoints(3)
check(sigCName == "Tree3" and sigCPoints == 44, "signature C (id, name, texture, points) parsed")

GetTalentTabInfo = function(i) return i, "Tree" .. i, "desc", 136052, ({ 0, 0, 44 })[i] end
local sigBName, sigBPoints = GSPlus.TalentDetector:GetTalentTabNameAndPoints(3)
check(sigBName == "Tree3" and sigBPoints == 44, "signature B (id, name, desc, texture, points) parsed")

GetTalentTabInfo = function(i) return i, "Tree" .. i, "desc", 136052 end
local _, fileIdPoints = GSPlus.TalentDetector:GetTalentTabNameAndPoints(3)
check(fileIdPoints == 0, "texture fileID never mistaken for talent points")

GetTalentTabInfo = realGetTalentTabInfo

-- 18. Cross-role score parity: equally-itemized warlock and resto shaman
-- gear must produce similar totals (the playtest saw 1019 vs 430)
local wlSet = {
    HeadSlot = "|cffa335ee|Hitem:2001::::::::70:::::|h[Warlock Hood]|h|r",
    ChestSlot = "|cffa335ee|Hitem:2002::::::::70:::::|h[Warlock Robe]|h|r",
    LegsSlot = "|cffa335ee|Hitem:2003::::::::70:::::|h[Warlock Legs]|h|r",
    MainHandSlot = "|cffa335ee|Hitem:2004::::::::70:::::|h[Warlock Staff]|h|r",
}
fakeItems[wlSet.HeadSlot] = { name = "Warlock Hood", equipLoc = "INVTYPE_HEAD", ilvl = 115 }
fakeTooltips[wlSet.HeadSlot] = { "Warlock Hood", "+28 Intellect", "+30 Stamina", "+32 Critical Strike Rating",
    "Equip: Increases damage and healing done by magical spells and effects by up to 40." }
fakeItems[wlSet.ChestSlot] = { name = "Warlock Robe", equipLoc = "INVTYPE_ROBE", ilvl = 115 }
fakeTooltips[wlSet.ChestSlot] = { "Warlock Robe", "+30 Intellect", "+33 Stamina", "+25 Haste Rating",
    "Equip: Increases damage and healing done by magical spells and effects by up to 46." }
fakeItems[wlSet.LegsSlot] = { name = "Warlock Legs", equipLoc = "INVTYPE_LEGS", ilvl = 115 }
fakeTooltips[wlSet.LegsSlot] = { "Warlock Legs", "+32 Intellect", "+30 Stamina", "+24 Spell Hit Rating",
    "Equip: Increases damage and healing done by magical spells and effects by up to 44." }
fakeItems[wlSet.MainHandSlot] = { name = "Warlock Staff", equipLoc = "INVTYPE_2HWEAPON", ilvl = 125 }
fakeTooltips[wlSet.MainHandSlot] = { "Warlock Staff", "+42 Intellect", "+45 Stamina", "+30 Critical Strike Rating",
    "Equip: Increases damage and healing done by magical spells and effects by up to 121." }

local shSet = {
    HeadSlot = "|cffa335ee|Hitem:2011::::::::70:::::|h[Shaman Helm]|h|r",
    ChestSlot = "|cffa335ee|Hitem:2012::::::::70:::::|h[Shaman Hauberk]|h|r",
    LegsSlot = "|cffa335ee|Hitem:2013::::::::70:::::|h[Shaman Kilt]|h|r",
    MainHandSlot = "|cffa335ee|Hitem:2014::::::::70:::::|h[Shaman Staff]|h|r",
}
fakeItems[shSet.HeadSlot] = { name = "Shaman Helm", equipLoc = "INVTYPE_HEAD", ilvl = 115 }
fakeTooltips[shSet.HeadSlot] = { "Shaman Helm", "+28 Intellect", "+30 Stamina", "+32 Critical Strike Rating",
    "Equip: Increases healing done by up to 75 and damage done by up to 25 for all magical spells and effects." }
fakeItems[shSet.ChestSlot] = { name = "Shaman Hauberk", equipLoc = "INVTYPE_CHEST", ilvl = 115 }
fakeTooltips[shSet.ChestSlot] = { "Shaman Hauberk", "+30 Intellect", "+33 Stamina",
    "Equip: Restores 8 mana per 5 sec.",
    "Equip: Increases healing done by up to 86 and damage done by up to 29 for all magical spells and effects." }
fakeItems[shSet.LegsSlot] = { name = "Shaman Kilt", equipLoc = "INVTYPE_LEGS", ilvl = 115 }
fakeTooltips[shSet.LegsSlot] = { "Shaman Kilt", "+32 Intellect", "+30 Stamina", "+24 Critical Strike Rating",
    "Equip: Increases healing done by up to 84 and damage done by up to 28 for all magical spells and effects." }
fakeItems[shSet.MainHandSlot] = { name = "Shaman Staff", equipLoc = "INVTYPE_2HWEAPON", ilvl = 125 }
fakeTooltips[shSet.MainHandSlot] = { "Shaman Staff", "+42 Intellect", "+45 Stamina", "+30 Critical Strike Rating",
    "Equip: Increases healing done by up to 245 and damage done by up to 82 for all magical spells and effects." }

for slotKey, link in pairs(wlSet) do equipped[slotKey] = link end
GSPlus:InvalidateCaches()
local warlockTotal = GSPlus.Calculator:CalculateTotalGSPlus("WARLOCK_DPS").totalWeightedScore

for slotKey, link in pairs(shSet) do equipped[slotKey] = link end
GSPlus:InvalidateCaches()
local shamanTotal = GSPlus.Calculator:CalculateTotalGSPlus("SHAMAN_HEALER").totalWeightedScore

local parityRatio = warlockTotal / shamanTotal
check(parityRatio > 0.80 and parityRatio < 1.25,
    string.format("equally-geared warlock and resto shaman score within 25%% (%.0f vs %.0f, ratio %.2f)",
        warlockTotal, shamanTotal, parityRatio))

-- 19. Gear-based profile fallback when talents are unreadable
playerClass = "SHAMAN"
talentTabs = {
    { name = "Elemental", points = 0 },
    { name = "Enhancement", points = 0 },
    { name = "Restoration", points = 0 },
}
GSPlus:InvalidateCaches()
check(GSPlus.TalentDetector:GetDetectedProfile() == "SHAMAN_HEALER",
    "resto shaman in healing gear detected without talents (gear fallback)")

-- Inspected units are profiled from their talent spec (restoration -> healer)
TEST_UNITS.focus = { name = "Carol", guid = "guid-carol", isPlayer = true, class = "SHAMAN" }
talentTabs = { { name = "Elemental", points = 0 }, { name = "Enhancement", points = 0 }, { name = "Restoration", points = 40 } }
local carolEntry = GSPlus.Inspect:BuildUnitEntry("focus", "inspect")
check(carolEntry and carolEntry.profileKey == "SHAMAN_HEALER",
    "inspected shaman profiled from talent spec (resto -> healer)")
talentTabs = { { name = "Elemental", points = 0 }, { name = "Enhancement", points = 0 }, { name = "Restoration", points = 0 } }

-- restore state
equipped.HeadSlot = nil
equipped.LegsSlot = nil
equipped.ChestSlot = chestLink
equipped.MainHandSlot = swordLink
playerClass = "WARRIOR"
talentTabs = {
    { name = "Arms", points = 5 },
    { name = "Fury", points = 3 },
    { name = "Protection", points = 41 },
}
GSPlus:InvalidateCaches()

-- 20. Dual-school items count their best school once, not the sum
-- (playtest: Frozen Shadoweave Boots showed red because Shadow+Frost
-- lines stacked into double spell power)
local fswBootsLink = "|cffa335ee|Hitem:2021::::::::70:::::|h[Frozen Shadoweave Boots]|h|r"
fakeItems[fswBootsLink] = { name = "Frozen Shadoweave Boots", equipLoc = "INVTYPE_FEET", ilvl = 146 }
fakeTooltips[fswBootsLink] = {
    "Frozen Shadoweave Boots", "Feet", "Cloth",
    "+33 Stamina",
    "Equip: Increases damage done by Shadow spells and effects by up to 73.",
    "Equip: Increases damage done by Frost spells and effects by up to 73.",
}
local fswStats = GSPlus.ItemParser:ParseItemStats(fswBootsLink)
check(fswStats.SCHOOL_SPELLPOWER == 73,
    "dual-school spell damage counts max, not sum (got " .. tostring(fswStats.SCHOOL_SPELLPOWER) .. ")")

local fswWeighted = GSPlus.Calculator:CalculateWeightedScore(fswStats, "WARLOCK_DPS", "FeetSlot", fswBootsLink)
local fswMax = GSPlus.Calculator:GetWeightedColorReferenceForItem("WARLOCK_DPS", "FeetSlot", fswBootsLink)
local fswRatio = GSPlus.Calculator:GetScoreRatio(fswWeighted, fswMax)
check(fswRatio < 0.90,
    string.format("crafted dual-school boots no longer color red (ratio %.2f)", fswRatio))

-- 21. Color references derived from reference gear through the live pipeline
local refStats = GSPlus.ReferenceGear:GetStats("CASTER_DPS", "INVTYPE_FEET")
check(refStats ~= nil, "reference gear data exists for caster feet")
local refSelfScore = GSPlus.Calculator:CalculateWeightedScore(refStats, "WARLOCK_DPS", "FeetSlot", fswBootsLink)
check(math.abs(GSPlus.Calculator:GetScoreRatio(refSelfScore, fswMax) - (1.0 / GSPlus.Calculator.COLOR_REFERENCE_HEADROOM)) < 0.01,
    "reference item sits one headroom step below red (red reserved for true BiS)")

local tankRef = GSPlus.Calculator:GetWeightedColorReferenceForItem("WARRIOR_TANK", "ChestSlot", betterChestLink)
check(tankRef > 0, "tank reference derived from reference gear (" .. string.format("%.0f", tankRef) .. ")")

-- 22a. Partial tooltip scans (playtest: spell power vanished from items,
-- hunters cratered on inspect): a near-empty scan must never be cached
local ghostLink = "|cffa335ee|Hitem:2030::::::::70:::::|h[Ghost Mantle]|h|r"
fakeItems[ghostLink] = { name = "Ghost Mantle", equipLoc = "INVTYPE_SHOULDER" }
fakeTooltips[ghostLink] = { "Ghost Mantle" }  -- server data not loaded: name only
GSPlus.ItemParser.sawUncachedItem = nil
local ghostStats = GSPlus.ItemParser:ParseItemStats(ghostLink)
check(ghostStats.INCOMPLETE_SCAN == 1, "near-empty scan flagged incomplete")
check(GSPlus.ItemParser.statsCache[ghostLink] == nil, "incomplete scan never cached")
check(GSPlus.ItemParser.sawUncachedItem == true, "incomplete scan triggers retry flag")

-- once the data 'arrives', the same link parses and caches normally
fakeTooltips[ghostLink] = { "Ghost Mantle", "Shoulder", "+20 Intellect",
    "Equip: Increases damage and healing done by magical spells and effects by up to 30." }
local ghostStats2 = GSPlus.ItemParser:ParseItemStats(ghostLink)
check(ghostStats2.SPELLPOWER == 30 and not ghostStats2.INCOMPLETE_SCAN,
    "re-scan after data arrives picks up the equip line")
check(GSPlus.ItemParser.statsCache[ghostLink] ~= nil, "complete scan cached")

-- hard-wrapped equip text (embedded newline) still parses
local wrapStats = {}
GSPlus.ItemParser:ParseTooltipLine(
    "Equip: Increases damage and healing done\nby magical spells and effects by up to 44.", wrapStats)
check(wrapStats.SPELLPOWER == 44, "newline-wrapped equip line parses")

-- 22b. Partial inspect entries refresh themselves
local partialLink = "|cffa335ee|Hitem:2031::::::::70:::::|h[Unloaded Blade]|h|r"
fakeItems[partialLink] = { name = "Unloaded Blade", equipLoc = "INVTYPE_WEAPONMAINHAND" }
fakeTooltips[partialLink] = { "Unloaded Blade" }
equipped.MainHandSlot = partialLink
TEST_UNITS.partyx = { name = "Dave", guid = "guid-dave", isPlayer = true, class = "WARRIOR" }
local daveEntry = GSPlus.Inspect:BuildUnitEntry("partyx", "inspect")
check(daveEntry and daveEntry.partial == true, "entry with unloaded item flagged partial")
GSPlus.Inspect:StoreUnitEntry("partyx", "guid-dave", daveEntry)
check(GSPlus.Inspect.lastAttempt["guid-dave"] == nil, "partial entry clears inspect cooldown for retry")
equipped.MainHandSlot = swordLink
GSPlus:InvalidateCaches()

-- 22c. Proc trinkets valued at estimated uptime (Quagmirran's Eye etc.)
local quagLink = "|cffa335ee|Hitem:2040::::::::70:::::|h[Quagmirran's Eye]|h|r"
fakeItems[quagLink] = { name = "Quagmirran's Eye", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[quagLink] = {
    "Quagmirran's Eye", "Trinket",
    "Equip: Your harmful spells have a 10% chance to increase your spell haste rating by 320 for 6 sec.",
}
local quagStats = GSPlus.ItemParser:ParseItemStats(quagLink)
-- uptime = 6 / (40 + 1/(0.10 * 0.5)) = 0.10 -> 320 * 0.10 = 32 haste
check(quagStats.HASTE and math.abs(quagStats.HASTE - 32.0) < 0.01,
    "Quagmirran's Eye proc valued at uptime (got " .. tostring(quagStats.HASTE) .. ")")
check(not quagStats.UNSCORED_EQUIP_EFFECT, "stat proc no longer flagged unscored")

local dstLink = "|cffa335ee|Hitem:2041::::::::70:::::|h[Dragonspine Trophy]|h|r"
fakeItems[dstLink] = { name = "Dragonspine Trophy", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[dstLink] = {
    "Dragonspine Trophy", "Trinket",
    "Equip: Your melee and ranged attacks have a chance to increase your haste rating by 325 for 10 secs.",
}
local dstStats = GSPlus.ItemParser:ParseItemStats(dstLink)
-- no stated chance: default 15% -> uptime = 10 / (40 + 13.33) = 0.1875 -> 60.9
check(dstStats.HASTE and math.abs(dstStats.HASTE - 60.94) < 0.01,
    "chance-less proc uses default chance (got " .. tostring(dstStats.HASTE) .. ")")

local grantLink = "|cffa335ee|Hitem:2042::::::::70:::::|h[Healing Charm]|h|r"
fakeItems[grantLink] = { name = "Healing Charm", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[grantLink] = {
    "Healing Charm", "Trinket",
    "Equip: Your healing spells have a 10% chance to grant you 212 healing for 10 sec.",
}
local grantStats = GSPlus.ItemParser:ParseItemStats(grantLink)
-- uptime = 10 / (40 + 20) = 0.1667 -> 35.3 healing
check(grantStats.HEALING and math.abs(grantStats.HEALING - 35.33) < 0.01,
    "grant-you proc wording parsed (got " .. tostring(grantStats.HEALING) .. ")")

-- damage procs (no stat-for-duration shape) remain honestly unscored
local procDmg = {}
GSPlus.ItemParser:ParseTooltipLine("Equip: Your attacks have a 5% chance to deal 95 Shadow damage to the target.", procDmg)
check(procDmg.UNSCORED_EQUIP_EFFECT == 1 and not procDmg.HASTE, "damage procs stay unscored")

-- 22d. KnownProcs overrides: famous trinkets use exact community values
local realQuagLink = "|cffa335ee|Hitem:27683::::::::70:::::|h[Quagmirran's Eye]|h|r"
fakeItems[realQuagLink] = { name = "Quagmirran's Eye", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[realQuagLink] = {
    "Quagmirran's Eye", "Trinket",
    "Equip: Your harmful spells have a 10% chance to increase your spell haste rating by 320 for 6 sec.",
}
local realQuagStats = GSPlus.ItemParser:ParseItemStats(realQuagLink)
-- item ID 27683 has a KnownProcs entry (38 haste); the generic model (32)
-- must be suppressed, not added on top
check(realQuagStats.HASTE == 38,
    "Quagmirran's Eye uses KnownProcs override, no double-add (got " .. tostring(realQuagStats.HASTE) .. ")")
check(not realQuagStats.UNSCORED_EQUIP_EFFECT, "override item's proc line not flagged unscored")
check(GSPlus.ItemParser.procOverrideActive == nil, "proc override flag cleared after parse")

-- trinkets with stats besides the proc keep them alongside the override
local dmcLink = "|cffa335ee|Hitem:31856::::::::70:::::|h[Darkmoon Card: Crusade]|h|r"
fakeItems[dmcLink] = { name = "Darkmoon Card: Crusade", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[dmcLink] = {
    "Darkmoon Card: Crusade", "Trinket",
    "Equip: Your damaging abilities have a chance to grant you 8 spell damage for 10 sec.",
}
local dmcStats = GSPlus.ItemParser:ParseItemStats(dmcLink)
check(dmcStats.ATTACKPOWER == 100 and dmcStats.SPELLPOWER == 70,
    "Darkmoon Card: Crusade override provides both AP and spell power")

-- 22e. Inspect reliability guards (the "can't inspect half the time" fixes)
TEST_UNITS.farguy = { name = "Far", guid = "guid-far", isPlayer = true, class = "ROGUE" }

-- background inspect blocked while the Blizzard inspect window is open
InspectFrame:Show()
GSPlus.Inspect.lastAttempt["guid-far"] = nil
check(GSPlus.Inspect:QueueUnitInspect("farguy") == false, "no background inspect while inspect frame open")
InspectFrame:Hide()

-- background inspect blocked in combat
inCombat = true
check(GSPlus.Inspect:QueueUnitInspect("farguy") == false, "no background inspect in combat")
inCombat = false

-- with both clear, the inspect queues again
GSPlus.Inspect.lastAttempt["guid-far"] = nil
GSPlus.Inspect.current = nil
notifyInspectCalls = 0
check(GSPlus.Inspect:QueueUnitInspect("farguy"), "inspect queues when not blocked")
check(notifyInspectCalls == 1, "NotifyInspect fired once when not blocked")
GSPlus.Inspect:HandleInspectReady("guid-far")

-- the NotifyInspect throttle defers a too-soon request instead of dropping it
GSPlus.Inspect.MIN_NOTIFY_INTERVAL = 1.5
GSPlus.Inspect.lastNotify = time()
GSPlus.Inspect.current = nil
GSPlus.Inspect.lastAttempt["guid-bob"] = nil
notifyInspectCalls = 0
GSPlus.Inspect:QueueUnitInspect("target")
check(notifyInspectCalls == 0 and GSPlus.Inspect.current == nil,
    "throttle defers a too-soon inspect rather than firing/dropping it")
-- only one drain timer is scheduled no matter how many requests pile up
GSPlus.Inspect:QueueUnitInspect("farguy")
check(GSPlus.Inspect.drainScheduled == true, "blocked/throttled drain uses a single guarded timer")
GSPlus.Inspect.MIN_NOTIFY_INTERVAL = 0
GSPlus.Inspect.queue = {}
GSPlus.Inspect.drainScheduled = false
GSPlus.Inspect.current = nil

-- uncached items proactively request a data load (recovery from blank gs)
itemLoadRequests = 0
local blankLink = "|cffa335ee|Hitem:9001::::::::70:::::|h[Unseen Relic]|h|r"
fakeItems[blankLink] = nil  -- GetItemInfo returns nil: item not in cache
GSPlus.ItemParser:ParseItemStats(blankLink)
check(itemLoadRequests >= 1, "uncached item triggers a data load request")

-- 22. Linear weighted score: breakdown rows add up to the total exactly
local chestStats = GSPlus.ItemParser:ParseItemStats(chestLink)
local rows2, rowTotal = GSPlus.Tooltip:BuildStatContributionRows(chestStats, "SHAMAN_HEALER")
local rowSum = 0
for _, row in ipairs(rows2) do rowSum = rowSum + row.finalContribution end
-- Rows use clean (un-normalized) weights and sum to the pre-normalization total;
-- that total times the per-spec normalization equals the displayed weighted score.
local hScale = GSPlus.Calculator:GetProfileScoreScale("SHAMAN_HEALER")
check(math.abs(rowSum - rowTotal) < 0.001
    and math.abs(rowTotal * hScale - GSPlus.Calculator:CalculateWeightedStatScore(chestStats, "SHAMAN_HEALER")) < 0.01,
    "breakdown rows (clean weights) x normalization = the weighted score")

-- 23. Cross-realm cache keys: comms and inspect must resolve to the SAME key
-- for one player. Regression: comms stored under the short name while inspect
-- kept "Name-Realm", so a cross-realm member's shared score was cached under
-- a key the group window and tooltips never looked up.
TEST_UNITS.xrealm = { name = "Zara", realm = "Distant Realm", guid = "guid-zara", isPlayer = true, class = "MAGE" }
local xrealmUnitKey = GSPlus.PlayerCache:GetKeyForUnit("xrealm")
local xrealmSenderKey = GSPlus.PlayerCache:NormalizeSenderKey("Zara-DistantRealm")
check(xrealmUnitKey == xrealmSenderKey,
    "cross-realm comms and inspect keys match ('" .. tostring(xrealmUnitKey) .. "')")

GSPlus.Comms:OnChatMsgAddon("GSPlus", "S:4:123.0:200.0:80.0:500:MAGE_DPS", "PARTY", "Zara-DistantRealm")
local xrealmEntry = GSPlus.PlayerCache:GetByUnit("xrealm")
check(xrealmEntry ~= nil and xrealmEntry.source == "comms",
    "cross-realm comms score is retrievable by unit lookup")

-- 24. Color-reference cache survives a routine score-cache invalidation
-- (gear/talent change) but is dropped when the client flavor changes.
GSPlus.Calculator:GetWeightedColorReferenceForItem("WARRIOR_TANK", "ChestSlot", betterChestLink)
check(GSPlus.Calculator.referenceCache ~= nil and next(GSPlus.Calculator.referenceCache) ~= nil,
    "color reference cached after first lookup")
GSPlus.Calculator:InvalidateCache()
check(GSPlus.Calculator.referenceCache ~= nil and next(GSPlus.Calculator.referenceCache) ~= nil,
    "reference cache survives a score-cache invalidation")
GSPlus.GameVersion:Detect()
check(GSPlus.Calculator.referenceCache == nil,
    "reference cache cleared when the flavor is re-detected")

-- 25. RequestScores is a no-op and never consumes the throttle when solo, so
-- the first request after joining a group is not silenced.
inGroup = false
GSPlus.Comms.lastRequest = 0
sentMessages = {}
check(GSPlus.Comms:RequestScores() == false, "solo RequestScores returns false")
check(GSPlus.Comms.lastRequest == 0, "solo RequestScores does not arm the throttle")
check(#sentMessages == 0, "solo RequestScores sends nothing")
inGroup = true
check(GSPlus.Comms:RequestScores() ~= false, "grouped RequestScores fires")
inGroup = false

-- 26. Items scanned before the client has their full data are never cached,
-- even when the partial tooltip already has many base/socket lines. Playtest
-- bug: equipped items kept a stale score that omitted their green "Equip:"
-- healing / spell power / MP5 because the line-count check alone called the
-- early scan "complete".
local lateLink = "|cffa335ee|Hitem:2050::::::::70:::::|h[Late Loader]|h|r"
fakeItems[lateLink] = { name = "Late Loader", equipLoc = "INVTYPE_FEET" }
fakeTooltips[lateLink] = {
    "Late Loader", "Soulbound", "Feet", "250 Armor",
    "+24 Stamina", "+27 Intellect", "+16 Spirit",
    "Red Socket", "Yellow Socket", "Durability 60 / 60", "Requires Level 70",
}
itemDataCached["2050"] = false
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local lateStats = GSPlus.ItemParser:ParseItemStats(lateLink)
check(lateStats.INCOMPLETE_SCAN == 1, "uncached item flagged incomplete despite many lines")
check(GSPlus.ItemParser.statsCache[lateLink] == nil, "uncached partial scan not cached")

itemDataCached["2050"] = true
fakeTooltips[lateLink][#fakeTooltips[lateLink] + 1] =
    "Equip: Increases healing done by up to 55 and damage done by up to 19 for all magical spells and effects."
local lateStats2 = GSPlus.ItemParser:ParseItemStats(lateLink)
check(lateStats2.HEALING == 55 and lateStats2.SPELLPOWER == 19 and not lateStats2.INCOMPLETE_SCAN,
    "re-scan after data loads picks up Equip healing/spell power")
check(GSPlus.ItemParser.statsCache[lateLink] ~= nil, "completed scan cached")

-- 27. Item tooltips on the Blizzard inspect window are scored for the
-- inspected player's spec, not the viewer's, and drop the personal "For You
-- vs Equipped" line. Playtest: a feral druid inspecting a paladin tank saw
-- the paladin's legs scored with Druid Feral weights.
local palLegs = "|cffa335ee|Hitem:2060::::::::70:::::|h[Justicar Legguards]|h|r"
fakeItems[palLegs] = { name = "Justicar Legguards", equipLoc = "INVTYPE_LEGS", ilvl = 120 }
fakeTooltips[palLegs] = {
    "Justicar Legguards", "Legs", "Plate", "1322 Armor",
    "+46 Stamina", "+31 Intellect",
    "Equip: Increases defense rating by 31.",
    "Equip: Increases your parry rating by 31.",
}
TEST_UNITS.paltank = { name = "Meteor", guid = "guid-meteor", isPlayer = true, class = "PALADIN" }
local savedTabs27 = talentTabs
talentTabs = { { name = "Holy", points = 0 }, { name = "Protection", points = 41 }, { name = "Retribution", points = 0 } }
local savedEqPT27 = {}
for k, v in pairs(equipped) do savedEqPT27[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
GSPlus:InvalidateCaches()
check(GSPlus.Inspect:GetUnitProfile("paltank") == "PALADIN_TANK", "inspected paladin resolves to PALADIN_TANK")
for k, v in pairs(savedEqPT27) do equipped[k] = v end
GSPlus:InvalidateCaches()

GSPlus.Options:Set("showItemTooltip", true)
GSPlus.Options:Set("showTooltipBreakdown", true)
InspectFrame.unit = "paltank"
InspectFrame:Show()
local inspTip = {
    addedLines = {},
    owner = { GetName = function() return "InspectLegsSlot" end },
    GetItem = function() return "Justicar Legguards", palLegs end,
    GetOwner = function(self) return self.owner end,
    AddLine = function(self, t) self.addedLines[#self.addedLines + 1] = t or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
GSPlus.Tooltip:AddGearScoreToTooltip(inspTip)
local sawPaladin, sawFeral, sawForYou = false, false, false
for _, line in ipairs(inspTip.addedLines) do
    if string.find(line, "Paladin", 1, true) then sawPaladin = true end
    if string.find(line, "Feral", 1, true) then sawFeral = true end
    if string.find(line, "For You vs Equipped", 1, true) then sawForYou = true end
end
check(sawPaladin and not sawFeral, "inspect item tooltip uses the inspected player's profile")
check(not sawForYou, "inspect item tooltip omits the personal 'For You vs Equipped' line")
InspectFrame:Hide()
GSPlus.Options:Set("showItemTooltip", false)
GSPlus.Options:Set("showTooltipBreakdown", false)
talentTabs = savedTabs27
GSPlus:InvalidateCaches()

-- 28. Legacy GearScore per-item formula matches the canonical GearScore: an
-- ilvl 120 epic legs scores 145, the value TacoTip and the original GearScore
-- addon produce. (The ilvl 264 -> 494 wrath value is checked above.)
check(GSPlus.LegacyGearScore:GetItemScore(palLegs, "PALADIN") == 145,
    "legacy GS matches canonical for ilvl 120 epic legs (got "
    .. GSPlus.LegacyGearScore:GetItemScore(palLegs, "PALADIN") .. ")")

-- 29. Stat-less relics (libram/totem/idol/sigil) must NOT make a fully loaded
-- player read as partial ("score may rise") forever. (report C)
local libramLink = "|cffa335ee|Hitem:2070::::::::70:::::|h[Libram of Faith]|h|r"
fakeItems[libramLink] = { name = "Libram of Faith", equipLoc = "INVTYPE_RELIC" }
fakeTooltips[libramLink] = {
    "Libram of Faith", "Relic", "Requires Level 70",
    "Equip: Increases the healing of your Flash of Light by up to 50.",
}
TEST_UNITS.relicguy = { name = "Relly", guid = "guid-relly", isPlayer = true, class = "PALADIN" }
equipped.RangedSlot = libramLink
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local relicEntry = GSPlus.Inspect:BuildUnitEntry("relicguy", "inspect")
check(relicEntry and relicEntry.partial == false,
    "stat-less relic does not flag a fully loaded player as partial")
equipped.RangedSlot = nil
GSPlus:InvalidateCaches()

-- An item whose data really has not loaded still flags partial.
local notLoaded = "|cffa335ee|Hitem:2071::::::::70:::::|h[Unloaded Pauldrons]|h|r"
fakeItems[notLoaded] = { name = "Unloaded Pauldrons", equipLoc = "INVTYPE_SHOULDER" }
fakeTooltips[notLoaded] = { "Unloaded Pauldrons" }  -- 1 line: incomplete
equipped.ShoulderSlot = notLoaded
GSPlus.ItemParser.statsCache = {}
local partialEntry = GSPlus.Inspect:BuildUnitEntry("relicguy", "inspect")
check(partialEntry and partialEntry.partial == true,
    "genuinely unloaded item still flags the player as partial")
equipped.ShoulderSlot = nil
GSPlus:InvalidateCaches()

-- 30. The total gs+ number is hidden (loading indicator) until gear is fully
-- loaded, and shown once complete. (report C)
check(GSPlus.PlayerCache:FormatScore({ partial = true, weighted = 500, max = 600 }) == "|cff888888Loading...|r",
    "partial entry shows a loading indicator, not a number")
check(GSPlus.PlayerCache:FormatScore(nil) == "|cff888888Loading...|r", "missing entry shows a loading indicator")
check(string.find(GSPlus.PlayerCache:FormatScore({ weighted = 500, max = 600 }), "500", 1, true) ~= nil,
    "complete entry shows the score number")

-- 31. Color references reserve red for true BiS: a strong-but-not-BiS crafted
-- healer boot is no longer colored red. (report B)
local bolBoots = "|cffa335ee|Hitem:24905::::::::70:::::|h[Boots of the Long Road]|h|r"
fakeItems[bolBoots] = { name = "Boots of the Long Road", equipLoc = "INVTYPE_FEET", ilvl = 128 }
fakeTooltips[bolBoots] = {
    "Boots of the Long Road", "Feet", "Cloth", "148 Armor",
    "+25 Stamina", "+26 Intellect", "+22 Spirit", "Requires Level 70",
    "Equip: Increases healing done by up to 73 and damage done by up to 25 for all magical spells and effects.",
    "Equip: Restores 9 mana per 5 sec.",
}
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local bolStats = GSPlus.ItemParser:ParseItemStats(bolBoots)
local bolW = GSPlus.Calculator:CalculateWeightedScore(bolStats, "PRIEST_HEALER", "FeetSlot", bolBoots)
local bolRef = GSPlus.Calculator:GetWeightedColorReferenceForItem("PRIEST_HEALER", "FeetSlot", bolBoots)
local bolRatio = GSPlus.Calculator:GetScoreRatio(bolW, bolRef)
check(bolRatio < 0.95,
    string.format("strong crafted healer boot is not red (ratio %.2f)", bolRatio))

-- 32. On-use stat trinkets are valued at their average uptime
-- (duration / cooldown) and included in the breakdown, not left unscored.
-- Bloodlust Brooch: +72 AP equip, Use +278 AP for 20s on a 2-min cooldown.
local brooch = "|cffa335ee|Hitem:2073::::::::70:::::|h[Bloodlust Brooch]|h|r"
fakeItems[brooch] = { name = "Bloodlust Brooch", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[brooch] = {
    "Bloodlust Brooch", "Trinket", "Requires Level 70",
    "Equip: Increases attack power by 72.",
    "Use: Increases attack power by 278 for 20 sec. (2 Mins Cooldown)",
}
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local broochStats = GSPlus.ItemParser:ParseItemStats(brooch)
-- 72 equip + 278 * (20 / 120) use = 72 + 46.33 = 118.33 AP
check(broochStats.ATTACKPOWER and math.abs(broochStats.ATTACKPOWER - 118.33) < 0.1,
    "on-use AP trinket valued at uptime (got " .. tostring(broochStats.ATTACKPOWER) .. ")")
check(not broochStats.UNSCORED_USE_EFFECT, "scored use effect not flagged unscored")

-- a 90-second cooldown haste use parses the seconds unit correctly
local hasteUse = {}
GSPlus.ItemParser:ParseUseTooltipLine(
    "Use: Increases your haste rating by 200 for 15 sec. (90 Sec Cooldown)", hasteUse)
check(hasteUse.HASTE and math.abs(hasteUse.HASTE - (200 * 15 / 90)) < 0.1,
    "on-use haste trinket parses second-denominated cooldown (got " .. tostring(hasteUse.HASTE) .. ")")

-- burst / utility uses stay honestly unscored
local manaUse = {}
GSPlus.ItemParser:ParseUseTooltipLine("Use: Restores 1500 mana. (5 Mins Cooldown)", manaUse)
check(manaUse.UNSCORED_USE_EFFECT == 1 and not manaUse.MANA, "burst/utility use effect stays unscored")

-- 33. Gem stats stack on top of base stats, including single-stat gems and
-- meta gems whose line carries a trailing "& ..." clause. (Beast Lord Helm:
-- +25 base agi, +6 red gem, +12 meta gem = 43.)
local gemHelm = "|cffa335ee|Hitem:2080::::::::70:::::|h[Beast Lord Helm]|h|r"
fakeItems[gemHelm] = { name = "Beast Lord Helm", equipLoc = "INVTYPE_HEAD" }
fakeTooltips[gemHelm] = {
    "Beast Lord Helm", "Head", "Mail", "530 Armor",
    "+25 Agility", "+21 Stamina", "+22 Intellect",
    "+34 Attack Power and +16 Hit Rating",
    "+6 Agility",
    "+12 Agility & 3% Increased Critical Damage",
    "Socket Bonus: 2 mana per 5 sec.",
    "Requires Level 70",
    "Equip: Increases attack power by 50.",
}
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local gemStats = GSPlus.ItemParser:ParseItemStats(gemHelm)
check(gemStats.AGILITY == 43, "base + red gem + meta gem agility stack (got " .. tostring(gemStats.AGILITY) .. ")")
check(gemStats.ATTACKPOWER == 84, "combined AP line + equip AP (got " .. tostring(gemStats.ATTACKPOWER) .. ")")
check(gemStats.HIT == 16, "hit rating from the combined green line")

-- single base stat (no gems) is not double-counted against GetItemStats:
-- a non-socketed item still reports its plain value once.
local plain = {}
GSPlus.ItemParser:ParseTooltipLine("+30 Strength", plain)
check(plain.STRENGTH == 30, "plain base stat parses once")

-- 34. Flat armor-ignore set bonuses (Beast Lord 4pc) are valued as armor
-- penetration at a conservative uptime instead of being dropped. (issue #2)
local apenStats = {}
GSPlus.SetBonuses:ParseSetBonusTextLine(
    "Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec.",
    apenStats)
check(apenStats.ATTACKPOWER == 180,
    "Beast Lord 4pc armor-ignore uses its curated KnownSetBonuses value (got "
    .. tostring(apenStats.ATTACKPOWER) .. ")")

-- 35. A complete inspected score is never downgraded to a partial one. This
-- is the mouseover-vs-inspect inconsistency: a quick partial re-scan must not
-- replace a good total. Mirrors TacoTip's all-or-nothing approach. (report D)
TEST_UNITS.consist = { name = "Consi", guid = "guid-consi", isPlayer = true, class = "WARRIOR" }
GSPlus.PlayerCache:SetForUnit("consist",
    { weighted = 1138, max = 1500, partial = false, source = "inspect", profileKey = "WARRIOR_DPS" })
GSPlus.Inspect:StoreUnitEntry("consist", "guid-consi",
    { weighted = 783, max = 1500, partial = true, source = "inspect", profileKey = "WARRIOR_DPS" })
local keptEntry = GSPlus.PlayerCache:GetByUnit("consist")
check(keptEntry and keptEntry.weighted == 1138 and not keptEntry.partial,
    "complete score not downgraded by a later partial scan (got " .. tostring(keptEntry and keptEntry.weighted) .. ")")
GSPlus.Inspect:StoreUnitEntry("consist", "guid-consi",
    { weighted = 1200, max = 1500, partial = false, source = "inspect", profileKey = "WARRIOR_DPS" })
local updatedEntry = GSPlus.PlayerCache:GetByUnit("consist")
check(updatedEntry and updatedEntry.weighted == 1200,
    "a newer complete scan still updates the score")

-- 36. On-use spell power trinkets (Icon of the Silver Crescent) are valued at
-- uptime too, not just the named-stat wording. Equip +43 SP, Use +155 SP for
-- 20s on a 2-min cooldown -> 43 + 155 * (20/120) = 68.83 spell power.
local icon = "|cffa335ee|Hitem:2090::::::::70:::::|h[Icon of the Silver Crescent]|h|r"
fakeItems[icon] = { name = "Icon of the Silver Crescent", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[icon] = {
    "Icon of the Silver Crescent", "Trinket", "Requires Level 70",
    "Equip: Increases damage and healing done by magical spells and effects by up to 43.",
    "Use: Increases damage and healing done by magical spells and effects by up to 155 for 20 sec. (2 Mins Cooldown)",
}
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local iconStats = GSPlus.ItemParser:ParseItemStats(icon)
check(iconStats.SPELLPOWER and math.abs(iconStats.SPELLPOWER - 68.83) < 0.1,
    "on-use spell power trinket valued at uptime (got " .. tostring(iconStats.SPELLPOWER) .. ")")
check(not iconStats.UNSCORED_USE_EFFECT, "scored spell-power use effect not flagged unscored")

-- 37. "by spells" on-use wording (Essence of the Martyr) is valued. Equip
-- +84 healing / +28 SP, Use +297 healing / +99 SP for 20s on 2-min CD.
local martyr = "|cffa335ee|Hitem:2091::::::::70:::::|h[Essence of the Martyr]|h|r"
fakeItems[martyr] = { name = "Essence of the Martyr", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[martyr] = {
    "Essence of the Martyr", "Trinket", "Requires Level 70",
    "Equip: Increases healing done by up to 84 and damage done by up to 28 for all magical spells and effects.",
    "Use: Increases healing done by spells by up to 297 and damage done by spells by up to 99 for 20 sec. (2 Mins Cooldown)",
}
GSPlus.ItemParser.statsCache = {}
GSPlus.ItemParser.statsCacheCount = 0
local martyrStats = GSPlus.ItemParser:ParseItemStats(martyr)
check(martyrStats.HEALING and math.abs(martyrStats.HEALING - (84 + 297 * 20 / 120)) < 0.1,
    "by-spells use healing valued at uptime (got " .. tostring(martyrStats.HEALING) .. ")")
check(martyrStats.SPELLPOWER and math.abs(martyrStats.SPELLPOWER - (28 + 99 * 20 / 120)) < 0.1,
    "by-spells use spell damage valued at uptime (got " .. tostring(martyrStats.SPELLPOWER) .. ")")
check(not martyrStats.UNSCORED_USE_EFFECT, "by-spells use effect not flagged unscored")

-- 38. Inspected feral druids are resolved cat vs bear from gear, so a bear-
-- geared druid reads as DRUID_TANK, not DRUID_FERAL. (issue F)
TEST_UNITS.beardruid = { name = "Milki", guid = "guid-milki", isPlayer = true, class = "DRUID" }
local savedTabsF = talentTabs
local savedEquipF = {}
for k, v in pairs(equipped) do savedEquipF[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
equipped.ChestSlot = betterChestLink  -- tanky: 1200 armor, +40 stam, +20 def
talentTabs = { { name = "Balance", points = 0 }, { name = "Feral Combat", points = 41 }, { name = "Restoration", points = 5 } }
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.Inspect:GetUnitProfile("beardruid") == "DRUID_TANK",
    "inspected bear-geared feral druid resolves to DRUID_TANK")
talentTabs = savedTabsF
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipF) do equipped[k] = v end
GSPlus:InvalidateCaches()

-- 39. A set bonus is counted once for the whole set, not once per equipped
-- piece. Two Beast Lord pieces both list the same 4pc armor-ignore; the
-- equipped total must include it a single time. (issue G)
local function blPiece(id, name, equipLoc, slot)
    local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
    fakeItems[link] = { name = name, equipLoc = equipLoc }
    fakeTooltips[link] = {
        name, "Mail", "+25 Agility",
        "Beast Lord Armor (4/5)",
        "(2) Set: Reduces the cooldown on your traps by 4 sec.",
        "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec.",
    }
    equipped[slot] = link
end
local savedEquipG = {}
for k, v in pairs(equipped) do savedEquipG[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
blPiece(28228, "Beast Lord Handguards", "INVTYPE_HAND", "HandsSlot")
blPiece(28229, "Beast Lord Helm", "INVTYPE_HEAD", "HeadSlot")
GSPlus.SetBonuses:InvalidateCache()
GSPlus.ItemParser:InvalidateStatsCache()
local setTotals = GSPlus.SetBonuses:GetEquippedActiveSetBonusStats()
check(setTotals.ATTACKPOWER == 180,
    "4pc set bonus counted once across pieces (got " .. tostring(setTotals.ATTACKPOWER) .. ")")
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipG) do equipped[k] = v end
GSPlus.SetBonuses:InvalidateCache()
GSPlus:InvalidateCaches()

-- 40. A Karazhan-tier caster weapon is no longer colored red (reference was
-- below a Kara 1H's spell power). (issue H)
local mindblade = "|cffa335ee|Hitem:28770::::::::70:::::|h[Nathrezim Mindblade]|h|r"
fakeItems[mindblade] = { name = "Nathrezim Mindblade", equipLoc = "INVTYPE_WEAPONMAINHAND", ilvl = 128 }
fakeTooltips[mindblade] = {
    "Nathrezim Mindblade", "Main Hand", "Dagger",
    "24 - 125 Damage", "Speed 1.80", "(41.4 damage per second)",
    "+18 Stamina", "+18 Intellect", "+40 Spell Damage and Healing", "Requires Level 70",
    "Equip: Improves spell critical strike rating by 23.",
    "Equip: Increases damage and healing done by magical spells and effects by up to 203.",
}
GSPlus.ItemParser:InvalidateStatsCache()
local mbStats = GSPlus.ItemParser:ParseItemStats(mindblade)
local mbW = GSPlus.Calculator:CalculateWeightedScore(mbStats, "MAGE_DPS", "MainHandSlot", mindblade)
local mbRef = GSPlus.Calculator:GetWeightedColorReferenceForItem("MAGE_DPS", "MainHandSlot", mindblade)
local mbRatio = GSPlus.Calculator:GetScoreRatio(mbW, mbRef)
check(mbStats.SPELLPOWER == 243, "mindblade spell power = +40 base + 203 equip (got " .. tostring(mbStats.SPELLPOWER) .. ")")
check(mbRatio < 0.95, string.format("Karazhan caster dagger no longer red (ratio %.2f)", mbRatio))

-- 41. Flat school-specific spell damage on caster wands ("+25 Shadow Damage")
-- is parsed and scored, instead of being dropped as "No weighted stats".
local wand = "|cffa335ee|Hitem:28783::::::::70:::::|h[Flawless Wand of Shadow Wrath]|h|r"
fakeItems[wand] = { name = "Flawless Wand of Shadow Wrath", equipLoc = "INVTYPE_RANGEDRIGHT" }
fakeTooltips[wand] = {
    "Flawless Wand of Shadow Wrath", "Ranged", "Wand",
    "137 - 255 Arcane Damage", "Speed 1.70", "(115.3 damage per second)",
    "+25 Shadow Damage", "Requires Level 70",
}
GSPlus.ItemParser:InvalidateStatsCache()
local wandStats = GSPlus.ItemParser:ParseItemStats(wand)
check(wandStats.SCHOOL_SPELLPOWER == 25,
    "flat '+25 Shadow Damage' parsed as school spell power (got " .. tostring(wandStats.SCHOOL_SPELLPOWER) .. ")")
local wandW = GSPlus.Calculator:CalculateWeightedStatScore(wandStats, "PRIEST_DPS")
check(wandW > 0, "shadow wand school damage contributes for a shadow priest (got " .. tostring(wandW) .. ")")

-- 42. The structured GetItemStats path now covers every itemized stat type,
-- generated from the canonical ITEM_MOD map - including pre-Wrath split spell
-- damage and granular per-school ratings that were previously dropped.
local realGetItemStats = GetItemStats
local apiLink = "|cffa335ee|Hitem:2099::::::::70:::::|h[Api Item]|h|r"
fakeItems[apiLink] = { name = "Api Item", equipLoc = "INVTYPE_TRINKET" }
fakeTooltips[apiLink] = { "Api Item", "Trinket", "Requires Level 70" }
GetItemStats = function(link)
    if link == apiLink then
        return {
            ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 50,
            ITEM_MOD_SPELL_HEALING_DONE_SHORT = 60,
            ITEM_MOD_HIT_SPELL_RATING_SHORT = 20,
            ITEM_MOD_HASTE_MELEE_RATING_SHORT = 15,
            ITEM_MOD_FERAL_ATTACK_POWER_SHORT = 40,
        }
    end
    return nil
end
GSPlus.ItemParser:InvalidateStatsCache()
local apiStats = GSPlus.ItemParser:ParseItemStats(apiLink)
GetItemStats = realGetItemStats
check(apiStats.SPELLPOWER == 50, "ITEM_MOD_SPELL_DAMAGE_DONE mapped to spell power")
check(apiStats.HEALING == 60, "ITEM_MOD_SPELL_HEALING_DONE mapped to healing")
check(apiStats.HIT == 20, "granular spell hit rating mapped to HIT")
check(apiStats.HASTE == 15, "granular melee haste rating mapped to HASTE")
check(apiStats.FERAL_ATTACKPOWER == 40, "feral attack power mapped")

-- the canonical map and the generated API table agree on coverage
local apiKeyCount = 0
for _ in pairs(GSPlus.ItemParser.STAT_MAPPING) do apiKeyCount = apiKeyCount + 1 end
check(apiKeyCount >= 30, "STAT_MAPPING generated comprehensively (" .. apiKeyCount .. " keys)")

-- 43. Gear has the FINAL say on the tank axis. With no defense gear the talent
-- spec stands (Retribution -> DPS); with real tank defense gear the unit reads
-- as tank even when the (leaked/cross-faction) talent slot says otherwise.
TEST_UNITS.platedps = { name = "Plati", guid = "guid-plati", isPlayer = true, class = "PALADIN" }
local savedTabsT = talentTabs
local savedEquipT = {}
for k, v in pairs(equipped) do savedEquipT[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local function platePiece(id, name, equipLoc, slot)
    local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
    fakeItems[link] = { name = name, equipLoc = equipLoc }
    fakeTooltips[link] = { name, "Plate", "1400 Armor", "+45 Stamina", "+40 Strength" }
    equipped[slot] = link
end
platePiece(7001, "Plate Chest", "INVTYPE_CHEST", "ChestSlot")
platePiece(7002, "Plate Legs", "INVTYPE_LEGS", "LegsSlot")
platePiece(7003, "Plate Head", "INVTYPE_HEAD", "HeadSlot")
talentTabs = { { name = "Holy", points = 0 }, { name = "Protection", points = 0 }, { name = "Retribution", points = 41 } }
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.Inspect:GetUnitProfile("platedps") == "PALADIN_DPS",
    "ret talents + no-defense gear -> DPS (got " .. tostring(GSPlus.Inspect:GetUnitProfile("platedps")) .. ")")

-- Equip real tank gear (defense rating). Even with the WRONG (leaked)
-- Retribution talents still set, the defense rating forces PALADIN_TANK -
-- the Bonkelve / Lightvee / Troy fix (talent slot leaked the wrong player).
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local function tankPiece(id, name, equipLoc, slot)
    local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
    fakeItems[link] = { name = name, equipLoc = equipLoc }
    fakeTooltips[link] = { name, "Plate", "1600 Armor", "+50 Stamina", "+30 Defense Rating" }
    equipped[slot] = link
end
tankPiece(7011, "Guard Chest", "INVTYPE_CHEST", "ChestSlot")
tankPiece(7012, "Guard Legs", "INVTYPE_LEGS", "LegsSlot")
tankPiece(7013, "Guard Head", "INVTYPE_HEAD", "HeadSlot")
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.Inspect:GetUnitProfile("platedps") == "PALADIN_TANK",
    "tank defense gear overrides a wrong/leaked talent spec -> tank (got "
    .. tostring(GSPlus.Inspect:GetUnitProfile("platedps")) .. ")")

talentTabs = savedTabsT
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipT) do equipped[k] = v end
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()

-- 44. Role is NOT guessed from gear while items are still loading: an
-- inspected unit with an unloaded item + unreadable talents uses the class
-- default, and a later complete inspect sets the real role.
TEST_UNITS.loadingpal = { name = "Loady", guid = "guid-loady", isPlayer = true, class = "PALADIN" }
local savedTabsL = talentTabs
local savedEquipL = {}
for k, v in pairs(equipped) do savedEquipL[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local incLink = "|cffa335ee|Hitem:7100::::::::70:::::|h[Loading Chest]|h|r"
fakeItems[incLink] = { name = "Loading Chest", equipLoc = "INVTYPE_CHEST" }
fakeTooltips[incLink] = { "Loading Chest" }  -- 1 line: not loaded -> INCOMPLETE_SCAN
equipped.ChestSlot = incLink
talentTabs = { { name = "Holy", points = 0 }, { name = "Protection", points = 0 }, { name = "Retribution", points = 0 } }
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.Inspect:IsUnitGearComplete("loadingpal") == false, "unit with an unloaded item is not complete")
check(GSPlus.Inspect:GetUnitProfile("loadingpal") == GSPlus.Profiles:GetDefaultProfileForClass("PALADIN"),
    "role on incomplete gear uses class default, not a gear guess")
talentTabs = savedTabsL
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipL) do equipped[k] = v end
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()

-- 45. A partial entry hides BOTH the number and the role (shows a loading
-- indicator), so a wrong role guessed mid-load is never displayed.
local partTip = {
    addedLines = {},
    AddLine = function(self, t) self.addedLines[#self.addedLines + 1] = t or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
GSPlus.UnitTooltip:AppendEntryLines(partTip,
    { partial = true, weighted = 900, max = 1000, profileKey = "PALADIN_TANK", source = "inspect", time = time() })
local sawRole, sawDots = false, false
for _, line in ipairs(partTip.addedLines) do
    if string.find(line, "Paladin", 1, true) then sawRole = true end
    if string.find(line, "...", 1, true) then sawDots = true end
end
check(not sawRole, "partial entry does not show a (possibly wrong) role")
check(sawDots, "partial entry shows a loading indicator instead")

-- 46. A Holy paladin in healing gear (talents unreadable) resolves to
-- PALADIN_HEALER, never PALADIN_TANK - even though tanks value some spell
-- power for threat, healing gear carries no defense/avoidance. (regression)
TEST_UNITS.holypal = { name = "Holyp", guid = "guid-holyp", isPlayer = true, class = "PALADIN" }
local savedTabsH = talentTabs
local savedEquipH = {}
for k, v in pairs(equipped) do savedEquipH[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local function holyPiece(id, name, equipLoc, slot, heal, sp)
    local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
    fakeItems[link] = { name = name, equipLoc = equipLoc, ilvl = 120 }
    fakeTooltips[link] = {
        name, "+32 Intellect", "+24 Spirit",
        "Equip: Increases healing done by up to " .. heal .. " and damage done by up to "
            .. sp .. " for all magical spells and effects.",
        "Equip: Restores 8 mana per 5 sec.",
    }
    equipped[slot] = link
end
holyPiece(8101, "Holy Helm", "INVTYPE_HEAD", "HeadSlot", 120, 40)
holyPiece(8102, "Holy Chest", "INVTYPE_CHEST", "ChestSlot", 150, 50)
holyPiece(8103, "Holy Legs", "INVTYPE_LEGS", "LegsSlot", 140, 47)
talentTabs = { { name = "Holy", points = 41 }, { name = "Protection", points = 0 }, { name = "Retribution", points = 0 } }
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.ItemParser:GetTankStatTotal("holypal") == 0, "healing gear carries no tank stats")
check(GSPlus.Inspect:GetUnitProfile("holypal") == "PALADIN_HEALER",
    "holy talents resolve to PALADIN_HEALER (got " .. tostring(GSPlus.Inspect:GetUnitProfile("holypal")) .. ")")
talentTabs = savedTabsH
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipH) do equipped[k] = v end
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()

-- 47. Free base armor no longer dominates tank scores: on a tank plate chest
-- the armor line now contributes less than stamina (it was the largest line),
-- so plate tanks are not inflated above other roles by armor alone.
local tankChest = "|cffa335ee|Hitem:30988::::::::70:::::|h[Panzar'Thar Breastplate]|h|r"
fakeItems[tankChest] = { name = "Panzar'Thar Breastplate", equipLoc = "INVTYPE_CHEST", ilvl = 128 }
fakeTooltips[tankChest] = {
    "Panzar'Thar Breastplate", "Chest", "Plate",
    "1450 Armor", "+51 Stamina", "+150 Health",
    "+12 Stamina", "+12 Stamina",
    "Equip: Increases defense rating by 26.",
    "Equip: Increases your shield block rating by 24.",
    "Equip: Increases the block value of your shield by 39.",
}
GSPlus.ItemParser:InvalidateStatsCache()
local tcStats = GSPlus.ItemParser:ParseItemStats(tankChest)
local tcRows = GSPlus.Tooltip:BuildStatContributionRows(tcStats, "PALADIN_TANK")
local armorC, stamC = 0, 0
for _, row in ipairs(tcRows) do
    if row.statType == "ARMOR" then armorC = row.finalContribution end
    if row.statType == "STAMINA" then stamC = row.finalContribution end
end
check(armorC > 0 and stamC > 0 and armorC < stamC,
    string.format("armor contributes less than stamina on a tank chest (armor %.1f < stam %.1f)", armorC, stamC))

-- 48. Default config matches the requested setup.
check(GSPlus.Options.DEFAULTS.showCharacterPane == true, "default: character pane on")
check(GSPlus.Options.DEFAULTS.showUnitTooltip == true, "default: mouseover scores on")
check(GSPlus.Options.DEFAULTS.enableComms == true, "default: group score sharing on")
check(GSPlus.Options.DEFAULTS.showItemTooltip == true, "default: item tooltip score on")
check(GSPlus.Options.DEFAULTS.showUpgradeDelta == false, "default: upgrade comparison off")
check(GSPlus.Options.DEFAULTS.showTooltipBreakdown == true, "default: shift breakdown on")
check(GSPlus.Options.DEFAULTS.showLegacyGearScore == false, "default: legacy GearScore off")
check(GSPlus.Options.DEFAULTS.showBudgetScore == false, "default: budget score off")
check(GSPlus.Options.DEFAULTS.autoDetectFeralRole == true, "default: feral tank/dps detection on")

-- 49. A full warrior tank set (talents unreadable) resolves to WARRIOR_TANK,
-- not DPS - the defense signal decides tank in both directions. (regression)
TEST_UNITS.wartank = { name = "Warty", guid = "guid-warty", isPlayer = true, class = "WARRIOR" }
local savedTabsW2 = talentTabs
local savedEquipW2 = {}
for k, v in pairs(equipped) do savedEquipW2[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local function wtPiece(id, name, equipLoc, slot, lines)
    local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
    fakeItems[link] = { name = name, equipLoc = equipLoc }
    fakeTooltips[link] = lines
    equipped[slot] = link
end
wtPiece(9501, "TankHelm", "INVTYPE_HEAD", "HeadSlot",
    { "TankHelm", "Plate", "1100 Armor", "+45 Stamina", "+30 Defense Rating", "+25 Dodge Rating" })
wtPiece(9502, "TankChest", "INVTYPE_CHEST", "ChestSlot",
    { "TankChest", "Plate", "1400 Armor", "+57 Stamina", "+20 Parry Rating",
      "Equip: Increases defense rating by 33." })
wtPiece(9503, "TankLegs", "INVTYPE_LEGS", "LegsSlot",
    { "TankLegs", "Plate", "1257 Armor", "+39 Stamina", "+8 Defense Rating", "+15 Block Rating" })
talentTabs = { { name = "Arms", points = 0 }, { name = "Fury", points = 0 }, { name = "Protection", points = 48 } }
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()
check(GSPlus.Inspect:GetUnitProfile("wartank") == "WARRIOR_TANK",
    "protection talents resolve to WARRIOR_TANK (got " .. tostring(GSPlus.Inspect:GetUnitProfile("wartank")) .. ")")
talentTabs = savedTabsW2
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipW2) do equipped[k] = v end
GSPlus:InvalidateCaches()
GSPlus.ItemParser:InvalidateStatsCache()

-- 50. Item tooltips on an inspect whose gear is still loading defer (show
-- "inspecting...") instead of scoring under a guessed role. (issue)
local savedEquipM = {}
for k, v in pairs(equipped) do savedEquipM[k] = v end
TEST_UNITS.midload = { name = "Midy", guid = "guid-midy", isPlayer = true, class = "WARRIOR" }
local stillLoading = "|cffa335ee|Hitem:9600::::::::70:::::|h[Unloaded Helm]|h|r"
fakeItems[stillLoading] = { name = "Unloaded Helm", equipLoc = "INVTYPE_HEAD" }
fakeTooltips[stillLoading] = { "Unloaded Helm" }  -- 1 line: incomplete
equipped.HeadSlot = stillLoading
local hoverLegs = "|cffa335ee|Hitem:9601::::::::70:::::|h[Some Legs]|h|r"
fakeItems[hoverLegs] = { name = "Some Legs", equipLoc = "INVTYPE_LEGS" }
fakeTooltips[hoverLegs] = { "Some Legs", "Plate", "1200 Armor", "+40 Stamina" }
GSPlus.ItemParser:InvalidateStatsCache()
GSPlus.Options:Set("showItemTooltip", true)
InspectFrame.unit = "midload"
InspectFrame:Show()
local deferTip = {
    addedLines = {},
    owner = { GetName = function() return "InspectLegsSlot" end },
    GetItem = function() return "Some Legs", hoverLegs end,
    GetOwner = function(self) return self.owner end,
    AddLine = function(self, t) self.addedLines[#self.addedLines + 1] = t or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
GSPlus.Tooltip:AddGearScoreToTooltip(deferTip)
local sawInspecting, sawRole = false, false
for _, line in ipairs(deferTip.addedLines) do
    if string.find(line, "inspecting", 1, true) then sawInspecting = true end
    if string.find(line, "Warrior", 1, true) then sawRole = true end
end
check(sawInspecting and not sawRole,
    "inspect item tooltip defers (shows inspecting, no guessed role) while gear loads")
InspectFrame:Hide()
GSPlus.Options:Set("showItemTooltip", false)
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipM) do equipped[k] = v end
GSPlus.ItemParser:InvalidateStatsCache()

-- 51. The player's own character-pane score is hidden (loading indicator)
-- until their own gear has loaded - no partial number flashes at login.
local savedEquipP = {}
for k, v in pairs(equipped) do savedEquipP[k] = v end
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
local ownInc = "|cffa335ee|Hitem:9700::::::::70:::::|h[Own Unloaded]|h|r"
fakeItems[ownInc] = { name = "Own Unloaded", equipLoc = "INVTYPE_CHEST" }
fakeTooltips[ownInc] = { "Own Unloaded" }  -- 1 line: not loaded
equipped.ChestSlot = ownInc
GSPlus.ItemParser:InvalidateStatsCache()
GSPlus:InvalidateCaches()
GSPlus.CharacterPaneUI:Update()
check(GSPlus.CharacterPaneUI.scoreText
    and string.find(GSPlus.CharacterPaneUI.scoreText.text or "", "...", 1, true) ~= nil,
    "own pane hides the number while gear is loading")
for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
for k, v in pairs(savedEquipP) do equipped[k] = v end
GSPlus.ItemParser:InvalidateStatsCache()
GSPlus:InvalidateCaches()
GSPlus.CharacterPaneUI:Update()
check(string.find(GSPlus.CharacterPaneUI.scoreText.text or "", "|c", 1, true) ~= nil,
    "own pane shows the score once gear has loaded")

-- 52. Persisted scores/roles from an older build are purged when the cache
-- version changes, so stale numbers can't survive a /reload or relog.
GSPlusSavedVars.playerCache = { ["StaleGuy"] = { weighted = 999, profileKey = "WARRIOR_DPS" } }
GSPlusSavedVars.playerCacheVersion = 1
local store52 = GSPlus.PlayerCache:GetStore()
check(store52["StaleGuy"] == nil
    and GSPlusSavedVars.playerCacheVersion == GSPlus.PlayerCache.CACHE_VERSION,
    "stale persisted player cache purged on a cache-version change")

;(function()
    -- 53. T4/Gruul-tier items are no longer colored red (red = Sunwell BiS).
    local jlegs = "|cffa335ee|Hitem:30733::::::::70:::::|h[Justicar Legguards]|h|r"
    fakeItems[jlegs] = { name = "Justicar Legguards", equipLoc = "INVTYPE_LEGS", ilvl = 120 }
    fakeTooltips[jlegs] = { "Justicar Legguards", "Legs", "Plate", "1322 Armor", "+46 Stamina", "+31 Intellect",
        "+30 Stamina and +10 Agility",
        "Equip: Increases defense rating by 31.", "Equip: Increases your parry rating by 31.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 36." }
    GSPlus.ItemParser:InvalidateStatsCache()
    local js = GSPlus.ItemParser:ParseItemStats(jlegs)
    local jratio = GSPlus.Calculator:GetScoreRatio(
        GSPlus.Calculator:CalculateWeightedScore(js, "PALADIN_TANK", "LegsSlot", jlegs),
        GSPlus.Calculator:GetWeightedColorReferenceForItem("PALADIN_TANK", "LegsSlot", jlegs))
    check(jratio < 0.90, string.format("T4 tank legs not red (ratio %.2f)", jratio))

    local mshoulder = "|cffa335ee|Hitem:29521::::::::70:::::|h[Shoulderguards of Malorne]|h|r"
    fakeItems[mshoulder] = { name = "Shoulderguards of Malorne", equipLoc = "INVTYPE_SHOULDER", ilvl = 120 }
    fakeTooltips[mshoulder] = { "Shoulderguards of Malorne", "Shoulder", "Leather", "284 Armor",
        "+19 Stamina", "+23 Intellect", "+19 Spirit", "+29 Healing and +10 Spell Damage",
        "+9 Healing +3 Spell Damage and +4 Spirit", "+9 Healing +3 Spell Damage and +4 Spirit",
        "Socket Bonus: +3 Spirit", "Requires Level 70",
        "Equip: Increases healing done by up to 68 and damage done by up to 23 for all magical spells and effects.",
        "Equip: Restores 5 mana per 5 sec." }
    GSPlus.ItemParser:InvalidateStatsCache()
    local ms = GSPlus.ItemParser:ParseItemStats(mshoulder)
    local mratio = GSPlus.Calculator:GetScoreRatio(
        GSPlus.Calculator:CalculateWeightedScore(ms, "DRUID_RESTO", "ShoulderSlot", mshoulder),
        GSPlus.Calculator:GetWeightedColorReferenceForItem("DRUID_RESTO", "ShoulderSlot", mshoulder))
    check(mratio < 0.90, string.format("T4 healer shoulder not red (ratio %.2f)", mratio))

    -- 54. Unscoreable items (relic with only a spell-specific effect) fall back
    -- to an item-level estimate instead of scoring zero.
    local totem = "|cffa335ee|Hitem:27947::::::::70:::::|h[Totem of the Plains]|h|r"
    fakeItems[totem] = { name = "Totem of the Plains", equipLoc = "INVTYPE_RELIC", ilvl = 100, rarity = 4 }
    fakeTooltips[totem] = { "Totem of the Plains", "Relic", "Totem", "Requires Level 70",
        "Equip: Increases healing done by Lesser Healing Wave by up to 79." }
    GSPlus.ItemParser:InvalidateStatsCache()
    check(GSPlus.Calculator:GetItemLevelFallbackScore(totem, "SHAMAN") > 0,
        "unscoreable relic gets an item-level fallback score")
    local savedEqT = {}
    for k, v in pairs(equipped) do savedEqT[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    equipped.RangedSlot = totem
    playerClass = "SHAMAN"
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    check(GSPlus.Calculator:CalculateTotalGSPlus("SHAMAN_HEALER").totalWeightedScore > 0,
        "relic contributes to the total via item-level fallback")
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEqT) do equipped[k] = v end
    playerClass = "WARRIOR"
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()

    -- 55. Hit/crit/haste are labeled as their spell versions for casters/healers.
    local function nameOf(stats, profile, statType)
        local rows = GSPlus.Tooltip:BuildStatContributionRows(stats, profile)
        for _, r in ipairs(rows) do if r.statType == statType then return r.statName end end
    end
    check(nameOf({ HASTE = 36, HEALING = 70 }, "SHAMAN_HEALER", "HASTE") == "Spell Haste Rating",
        "caster/healer haste labeled 'Spell Haste Rating'")
    check(nameOf({ HASTE = 36, ATTACKPOWER = 50 }, "WARRIOR_DPS", "HASTE") == "Haste Rating",
        "physical haste labeled plain 'Haste Rating'")

    -- 56. Out-of-range players aren't inspected (avoids the red "Out of range"
    -- UI error); in-range players are.
    TEST_UNITS.faraway = { name = "Far2", guid = "guid-far2", isPlayer = true, class = "MAGE" }
    local origCID = CheckInteractDistance
    CheckInteractDistance = function(unit) local u = TEST_UNITS[unit]; return u and u.inRange end
    GSPlus.Inspect.queue = {}; GSPlus.Inspect.current = nil
    GSPlus.Inspect.lastAttempt["guid-far2"] = nil
    TEST_UNITS.faraway.inRange = false
    check(GSPlus.Inspect:QueueUnitInspect("faraway") == false, "out-of-range player is not inspected")
    GSPlus.Inspect.lastAttempt["guid-far2"] = nil
    TEST_UNITS.faraway.inRange = true
    check(GSPlus.Inspect:QueueUnitInspect("faraway") ~= false, "in-range player is inspected")
    CheckInteractDistance = origCID
    GSPlus.Inspect.queue = {}; GSPlus.Inspect.current = nil

    -- 57. The item-level fallback note only appears on the Shift breakdown.
    GSPlus.Options:Set("showItemTooltip", true)
    GSPlus.Options:Set("showTooltipBreakdown", true)
    local origShift = IsShiftKeyDown
    local function relicTooltipNoteSeen(shiftDown)
        IsShiftKeyDown = function() return shiftDown end
        local t = { addedLines = {}, GetItem = function() return "Totem of the Plains", totem end,
            AddLine = function(s, x) s.addedLines[#s.addedLines + 1] = x or "" end,
            AddDoubleLine = function(s, l, r) s.addedLines[#s.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
            Show = function() end }
        GSPlus.Tooltip:AddGearScoreToTooltip(t)
        for _, l in ipairs(t.addedLines) do if string.find(l, "item level", 1, true) then return true end end
        return false
    end
    check(not relicTooltipNoteSeen(false), "fallback note hidden without Shift")
    check(relicTooltipNoteSeen(true), "fallback note shown on Shift")
    IsShiftKeyDown = origShift
    GSPlus.Options:Set("showItemTooltip", false)
    GSPlus.Options:Set("showTooltipBreakdown", false)

    -- 58. The live inspect result re-renders the tooltip (single gs+ line)
    -- instead of appending a second below "inspecting...".
    TEST_UNITS.target = { name = "Bob", guid = "guid-bob", isPlayer = true, class = "MAGE" }
    local setUnitCalled = false
    local realGT = GameTooltip
    GameTooltip = {
        IsShown = function() return true end,
        GetUnit = function() return "Bob", "target" end,
        SetUnit = function() setUnitCalled = true end,
        AddLine = function() end, AddDoubleLine = function() end, Show = function() end,
    }
    GSPlus.UnitTooltip.waitingGuid = "guid-bob"
    GSPlus.UnitTooltip:OnScoreUpdated("guid-bob", "Bob",
        { weighted = 1417, max = 1500, profileKey = "WARRIOR_TANK" })
    GameTooltip = realGT
    check(setUnitCalled, "live inspect result re-renders the tooltip (single gs+ line)")
end)()

;(function()
    -- 59. Set bonuses are scored for INSPECTED players from their own equipped
    -- pieces (the tooltip's "(X/Y)" count is the viewer's, so we count the
    -- target). The 4pc Beast Lord armor-ignore counts at 4 pieces, not at 2.
    local savedEqSB = {}
    for k, v in pairs(equipped) do savedEqSB[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    local function blPiece(id, equipLoc, slot)
        local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[Beast Lord " .. id .. "]|h|r"
        fakeItems[link] = { name = "Beast Lord " .. id, equipLoc = equipLoc }
        fakeTooltips[link] = {
            "Beast Lord " .. id, "Mail", "+20 Agility",
            "Beast Lord Armor (0/5)",
            "(2) Set: Reduces the cooldown on your traps by 4 sec.",
            "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec.",
        }
        equipped[slot] = link
    end
    blPiece(40001, "INVTYPE_HEAD", "HeadSlot")
    blPiece(40002, "INVTYPE_CHEST", "ChestSlot")
    blPiece(40003, "INVTYPE_HAND", "HandsSlot")
    blPiece(40004, "INVTYPE_SHOULDER", "ShoulderSlot")
    GSPlus.SetBonuses:InvalidateCache()
    GSPlus.ItemParser:InvalidateStatsCache()
    local sb4 = GSPlus.SetBonuses:GetUnitActiveSetBonusStats("inspectedguy")
    check(sb4.ATTACKPOWER == 180,
        "inspected 4pc set bonus scored with curated value (got " .. tostring(sb4.ATTACKPOWER) .. ")")

    equipped.HandsSlot = nil
    equipped.ShoulderSlot = nil
    GSPlus.SetBonuses:InvalidateCache()
    local sb2 = GSPlus.SetBonuses:GetUnitActiveSetBonusStats("inspectedguy")
    check(not sb2.ATTACKPOWER, "inspected 2pc: the 4pc bonus is not active")

    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEqSB) do equipped[k] = v end
    GSPlus.SetBonuses:InvalidateCache()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 59b. A shield-wearing paladin/warrior is never gear-resolved to DPS, even
    -- when talents are unreadable and the gear otherwise looks DPS-ish.
    TEST_UNITS.shieldpal = { name = "Shieldy", guid = "guid-shieldy", isPlayer = true, class = "PALADIN" }
    local savedEqSh = {}
    for k, v in pairs(equipped) do savedEqSh[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    local function p(slot, id, equipLoc, lines)
        local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[S" .. id .. "]|h|r"
        fakeItems[link] = { name = "S" .. id, equipLoc = equipLoc }
        fakeTooltips[link] = lines
        equipped[slot] = link
    end
    -- strength plate (looks DPS) + a shield with NO defense (just stamina)
    p("ChestSlot", 6601, "INVTYPE_CHEST", { "S", "Plate", "1300 Armor", "+40 Strength", "+30 Stamina" })
    p("LegsSlot", 6602, "INVTYPE_LEGS", { "S", "Plate", "1200 Armor", "+38 Strength", "+28 Stamina" })
    p("SecondaryHandSlot", 6603, "INVTYPE_SHIELD", { "S", "Shield", "3000 Armor", "+35 Stamina" })
    talentTabs = { { name = "Holy", points = 41 }, { name = "Protection", points = 0 }, { name = "Retribution", points = 0 } }
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    check(GSPlus.ItemParser:HasShieldEquipped("shieldpal"), "shield detected on the unit")
    check(GSPlus.Inspect:GetUnitProfile("shieldpal") == "PALADIN_HEALER",
        "holy talents read as healer regardless of str-plate gear (got " .. tostring(GSPlus.Inspect:GetUnitProfile("shieldpal")) .. ")")
    talentTabs = { { name = "Arms", points = 5 }, { name = "Fury", points = 3 }, { name = "Protection", points = 41 } }
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEqSh) do equipped[k] = v end
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 60. CONSISTENCY: the self/comms scorer (CalculateTotalGSPlus) and the
    -- inspect scorer (CalculateUnitScore) must produce the SAME number for the
    -- SAME gear - otherwise a player's mouseover (comms) score differs from
    -- their inspected score. Includes a relic (ilvl fallback) and a set bonus.
    local savedEqP = {}
    for k, v in pairs(equipped) do savedEqP[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    playerClass = "HUNTER"
    local function mkp(slot, id, equipLoc, lines)
        local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[P" .. id .. "]|h|r"
        fakeItems[link] = { name = "P" .. id, equipLoc = equipLoc, ilvl = 120, rarity = 4 }
        fakeTooltips[link] = lines
        equipped[slot] = link
    end
    mkp("HeadSlot", 51101, "INVTYPE_HEAD",
        { "P", "Mail", "+30 Agility", "+25 Stamina", "Beast Lord Armor (4/5)",
          "(2) Set: Reduces the cooldown on your traps by 4 sec.",
          "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec." })
    mkp("ChestSlot", 51102, "INVTYPE_CHEST",
        { "P", "Mail", "+34 Agility", "Equip: Increases attack power by 40.", "Beast Lord Armor (4/5)",
          "(2) Set: Reduces the cooldown on your traps by 4 sec.",
          "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec." })
    mkp("HandsSlot", 51103, "INVTYPE_HAND", { "P", "Mail", "+22 Agility", "Beast Lord Armor (4/5)",
          "(2) Set: Reduces the cooldown on your traps by 4 sec.",
          "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec." })
    mkp("ShoulderSlot", 51104, "INVTYPE_SHOULDER", { "P", "Mail", "+20 Agility", "Beast Lord Armor (4/5)",
          "(2) Set: Reduces the cooldown on your traps by 4 sec.",
          "(4) Set: Each time you use your Kill Command ability, your attacks ignore 600 of your victim's armor for 15 sec." })
    mkp("MainHandSlot", 51105, "INVTYPE_2HWEAPON",
        { "P", "120 - 180 Damage", "Speed 3.00", "(50.0 damage per second)", "+20 Agility" })
    mkp("RangedSlot", 51106, "INVTYPE_RELIC",
        { "P", "Idol", "Requires Level 70", "Equip: Increases the damage of your Mongoose Bite." })
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus.SetBonuses:InvalidateCache()
    local selfScore = GSPlus.Calculator:CalculateTotalGSPlus("HUNTER_DPS").totalWeightedScore
    GSPlus.Calculator:InvalidateCache()
    local inspectScore = GSPlus.Inspect:CalculateUnitScore("player", "HUNTER_DPS").totalWeightedScore
    check(math.abs(selfScore - inspectScore) < 0.01,
        string.format("self/comms score == inspect score for the same gear (%.1f vs %.1f)", selfScore, inspectScore))
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEqP) do equipped[k] = v end
    playerClass = "WARRIOR"
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus.SetBonuses:InvalidateCache()
end)()

;(function()
    -- 61. The inspect "Out of range" UI error is swallowed while we run our own
    -- inspect range-checks, but a normal "out of range" error still shows.
    UIErrorsFrame.messages = {}
    GSPlus.Inspect.skipInspectError = true
    UIErrorsFrame:AddMessage(ERR_OUT_OF_RANGE)   -- from our inspect: swallowed
    GSPlus.Inspect.skipInspectError = false
    UIErrorsFrame:AddMessage(ERR_OUT_OF_RANGE)   -- e.g. an ability: shown
    check(#UIErrorsFrame.messages == 1,
        "inspect out-of-range error swallowed during our checks, shown otherwise")
end)()


;(function()
    -- 62. Shield innate "<N> Block" base line + equip block value stack.
    local shieldLink = "|cffa335ee|Hitem:2050::::::::70:::::|h[Aegis]|h|r"
    fakeItems[shieldLink] = { name = "Aegis of the Sunbird", equipLoc = "INVTYPE_SHIELD" }
    fakeTooltips[shieldLink] = { "Aegis of the Sunbird", "Off Hand", "3806 Armor", "86 Block",
        "+27 Stamina", "Equip: Increases defense rating by 19.",
        "Equip: Increases the block value of your shield by 29." }
    local sh = GSPlus.ItemParser:ParseItemStats(shieldLink)
    check(sh.BLOCK_VALUE == 115, "shield base block (86) + equip block (29) = 115 (got "
        .. tostring(sh.BLOCK_VALUE) .. ")")
end)()

;(function()
    -- 63. Mixed compound gem: "+5 Defense Rating and 2 mana per 5 sec".
    local helmLink = "|cffa335ee|Hitem:2051::::::::70:::::|h[Eternium Greathelm]|h|r"
    fakeItems[helmLink] = { name = "Eternium Greathelm", equipLoc = "INVTYPE_HEAD" }
    fakeTooltips[helmLink] = { "Eternium Greathelm", "Head", "1178 Armor", "+31 Strength", "+48 Stamina",
        "+5 Parry Rating and +4 Defense Rating", "+5 Defense Rating and 2 mana per 5 sec.",
        "Equip: Increases defense rating by 34." }
    local h = GSPlus.ItemParser:ParseItemStats(helmLink)
    check(h.MP5 == 2, "MP5 from mixed compound gem clause (got " .. tostring(h.MP5) .. ")")
    check(h.DEFENSE == 43, "defense sums equip 34 + gem 4 + gem 5 = 43 (got " .. tostring(h.DEFENSE) .. ")")
end)()

;(function()
    -- 64. Compound cooldown "1 Min 30 Secs" sums to 90s; on-use dodge valued at uptime.
    local cd = GSPlus.ItemParser:ParseUseCooldownSeconds(
        "Increases dodge rating by 192 for 10 sec. (1 Min 30 Secs Cooldown)")
    check(cd == 90, "'1 Min 30 Secs Cooldown' parses to 90s (got " .. tostring(cd) .. ")")
    local charmLink = "|cffa335ee|Hitem:2052::::::::70:::::|h[Charm]|h|r"
    fakeItems[charmLink] = { name = "Charm of Alacrity", equipLoc = "INVTYPE_TRINKET" }
    fakeTooltips[charmLink] = { "Charm of Alacrity", "Trinket", "Unique",
        "Use: Increases dodge rating by 192 for 10 sec. (1 Min 30 Secs Cooldown)" }
    local c = GSPlus.ItemParser:ParseItemStats(charmLink)
    check(c.DODGE and math.abs(c.DODGE - (192 * 10 / 90)) < 0.01,
        "on-use dodge valued at 10/90 uptime (got " .. tostring(c.DODGE) .. ")")
end)()

;(function()
    -- 65. Chance-on-hit: sustained buff valued at PPM uptime; one-shot "next
    -- attack" buff is disclosed unscored, never silently dropped.
    local axeLink = "|cffa335ee|Hitem:2053::::::::70:::::|h[Test Axe]|h|r"
    fakeItems[axeLink] = { name = "Test Axe", equipLoc = "INVTYPE_2HWEAPON" }
    fakeTooltips[axeLink] = { "Test Axe", "Two-Hand", "100 - 200 Damage", "Speed 3.60", "+40 Strength",
        "Chance on hit: Increases your attack power by 200 for 10 sec." }
    local axe = GSPlus.ItemParser:ParseItemStats(axeLink)
    check(axe.ATTACKPOWER and axe.ATTACKPOWER > 0,
        "sustained chance-on-hit adds attack power at uptime (got " .. tostring(axe.ATTACKPOWER) .. ")")

    local wbLink = "|cffa335ee|Hitem:2054::::::::70:::::|h[World Breaker]|h|r"
    fakeItems[wbLink] = { name = "World Breaker", equipLoc = "INVTYPE_2HWEAPON" }
    fakeTooltips[wbLink] = { "World Breaker", "Two-Hand", "371 - 558 Damage", "Speed 3.70",
        "+50 Strength", "+51 Stamina",
        "Chance on hit: Increases the critical strike rating of your next attack made within 4 seconds by 900." }
    local wb = GSPlus.ItemParser:ParseItemStats(wbLink)
    check(wb.UNSCORED_EQUIP_EFFECT == 1, "one-shot chance-on-hit flagged unscored, not dropped")
    check(not wb.CRITICAL, "one-shot proc does not inflate a real crit stat")
end)()

;(function()
    -- 66. CACHE SELF-HEAL: an item whose data has not loaded (GetItemInfo nil)
    -- must flag INCOMPLETE_SCAN (not score as zero into a "complete" total), and
    -- once the data arrives RescoreResolvableUnits converges the cached entry.
    local unknownLink = "|cffa335ee|Hitem:299999::::::::70:::::|h[Unknown]|h|r"
    -- intentionally NOT in fakeItems => GetItemInfo returns nil
    local us = GSPlus.ItemParser:ParseItemStats(unknownLink)
    check(us.INCOMPLETE_SCAN == 1, "item with no server data flagged INCOMPLETE_SCAN")
    check(GSPlus.ItemParser.statsCache[unknownLink] == nil, "unloaded item never cached")

    -- A unit holding it scores partial (shown as '...'), never a frozen wrong total.
    local savedMH = equipped.MainHandSlot
    local healLink = "|cffa335ee|Hitem:2060::::::::70:::::|h[Loadme Wand]|h|r"
    equipped.MainHandSlot = healLink
    fakeItems[healLink] = { name = "Loadme Wand", equipLoc = "INVTYPE_WEAPONMAINHAND" }
    fakeTooltips[healLink] = { "Loadme Wand" }  -- name-only: not yet loaded
    TEST_UNITS.target = { name = "Heala", guid = "guid-heala", isPlayer = true, class = "MAGE" }
    GSPlus.ItemParser:InvalidateStatsCache()
    local e1 = GSPlus.Inspect:BuildUnitEntry("target", "inspect")
    check(e1 and e1.partial == true, "unit with unloaded item is partial, not a final number")
    GSPlus.Inspect:StoreUnitEntry("target", "guid-heala", e1)

    -- data arrives -> rescore converges to a complete, higher score with no /reload
    fakeTooltips[healLink] = { "Loadme Wand", "Main Hand", "+20 Intellect",
        "Equip: Increases damage and healing done by magical spells and effects by up to 100." }
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus.Inspect:RescoreResolvableUnits()
    local e2 = GSPlus.PlayerCache:GetByUnit("target")
    check(e2 and not e2.partial, "rescore-on-load clears partial without /reload")
    local fresh = GSPlus.Inspect:BuildUnitEntry("target", "inspect")
    check(e2 and fresh and e2.weighted > 0 and math.abs(e2.weighted - fresh.weighted) < 0.01,
        "converged cached score matches a complete recompute (no /reload)")

    equipped.MainHandSlot = savedMH
    TEST_UNITS.target = nil
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()



;(function()
    -- 67. First-hover never shows a wrong number. An item whose equip line lags
    -- (client reports it cached, so the entry is non-partial) would score too
    -- low; the score is held as provisional "..." until a verification re-scan
    -- confirms it stopped rising, and only then is the number revealed. An
    -- already-confirmed number is never flickered back to "..." on re-inspect.
    local savedMH = equipped.MainHandSlot
    local lagLink = "|cffa335ee|Hitem:2070::::::::70:::::|h[Laggard Blade]|h|r"
    fakeItems[lagLink] = { name = "Laggard Blade", equipLoc = "INVTYPE_WEAPONMAINHAND" }
    fakeTooltips[lagLink] = { "Laggard Blade", "Main Hand", "100 - 200 Damage", "Speed 1.80",
        "+20 Intellect" }
    equipped.MainHandSlot = lagLink
    TEST_UNITS.target = { name = "Laggy", guid = "guid-laggy", isPlayer = true, class = "MAGE" }
    GSPlus.ItemParser:InvalidateStatsCache()

    GSPlus.Inspect:CommitInspectEntry("target", "guid-laggy",
        GSPlus.Inspect:BuildUnitEntry("target", "inspect"))
    local prov = GSPlus.PlayerCache:GetByUnit("target")
    check(prov and prov.confirmed == false, "first inspect is provisional (shown as '...')")
    check(not GSPlus.PlayerCache:IsScoreFinal(prov), "provisional score is not displayed as a number")
    local w1 = prov.weighted

    fakeTooltips[lagLink] = { "Laggard Blade", "Main Hand", "100 - 200 Damage", "Speed 1.80",
        "+20 Intellect", "Equip: Increases damage and healing done by magical spells and effects by up to 200." }
    GSPlus.Inspect:VerifyRescore("guid-laggy")
    local rising = GSPlus.PlayerCache:GetByUnit("target")
    check(rising and rising.confirmed == false and rising.weighted > w1,
        string.format("still-climbing score stays provisional (%.1f -> %.1f, hidden)", w1, rising.weighted or 0))

    GSPlus.Inspect:VerifyRescore("guid-laggy")
    local finalE = GSPlus.PlayerCache:GetByUnit("target")
    check(finalE and finalE.confirmed == true, "number revealed only once the score stops rising")
    check(GSPlus.PlayerCache:IsScoreFinal(finalE), "confirmed score is displayed as a number")
    local w2 = finalE.weighted

    GSPlus.Inspect:CommitInspectEntry("target", "guid-laggy",
        GSPlus.Inspect:BuildUnitEntry("target", "inspect"))
    local reinspect = GSPlus.PlayerCache:GetByUnit("target")
    check(reinspect and reinspect.confirmed == true
        and GSPlus.PlayerCache:IsScoreFinal(reinspect)
        and math.abs(reinspect.weighted - w2) < 0.01,
        "re-inspect keeps the confirmed number on screen (no '...' flicker)")

    equipped.MainHandSlot = savedMH
    TEST_UNITS.target = nil
    GSPlus.Inspect.verifyState["guid-laggy"] = nil
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()



;(function()
    -- 68. Spell power is a primary threat stat for prot paladins, so the
    -- PALADIN_TANK color reference WEAPON carries spell power. A strong caster
    -- weapon (Gladiator's Gavel, 239 SP) is therefore good-but-not-red instead
    -- of clamping red, while a tank weapon with NO spell power scores poorly for
    -- a paladin tank. Warrior-tank colors are unaffected (they weight SP at 0).
    local gav = "|cffa335ee|Hitem:34211:::|h[Gladiator's Gavel]|h|r"
    fakeItems[gav] = { name = "Gladiator's Gavel", equipLoc = "INVTYPE_WEAPONMAINHAND", ilvl = 133, rarity = 4 }
    fakeTooltips[gav] = { "Gladiator's Gavel", "Main Hand", "22 - 111 Damage", "Speed 1.60",
        "+28 Stamina", "+18 Intellect", "+40 Spell Damage and Healing", "Requires Level 70",
        "Equip: Improves your resilience rating by 18.",
        "Equip: Increases damage and healing done by magical spells and effects by up to 199." }
    local plain = "|cffa335ee|Hitem:30097:::|h[Plain Tank Mace]|h|r"
    fakeItems[plain] = { name = "Plain Tank Mace", equipLoc = "INVTYPE_WEAPONMAINHAND", ilvl = 159, rarity = 4 }
    fakeTooltips[plain] = { "Plain Tank Mace", "Main Hand", "60 - 130 Damage", "Speed 1.80",
        "+40 Stamina", "+25 Defense Rating", "+35 Block Value", "Requires Level 70" }

    local function ratio(link, prof)
        GSPlus.ItemParser:InvalidateStatsCache()
        GSPlus.Calculator.referenceCache = nil
        GSPlus.Calculator:InvalidateCache()
        local st = GSPlus.ItemParser:ParseItemStats(link)
        local w = GSPlus.Calculator:CalculateWeightedScore(st, prof, "MainHandSlot", link)
        local ref = GSPlus.Calculator:GetWeightedColorReferenceForItem(prof, "MainHandSlot", link)
        return w / ref
    end

    local gavRatio = ratio(gav, "PALADIN_TANK")
    check(gavRatio < 0.90, string.format("caster weapon not red on paladin tank (ratio %.2f)", gavRatio))
    check(gavRatio > 0.40, string.format("spell power weapon still rated highly for threat (ratio %.2f)", gavRatio))

    -- the reference weapon now carries spell power, so a no-SP tank weapon is a
    -- weak paladin-tank weapon (proves the reference is SP-based, not survival-only)
    check(ratio(plain, "PALADIN_TANK") < gavRatio,
        "a tank weapon without spell power scores below a spell power weapon for paladin tank")

    -- warrior tank weights SP at 0, so the SP on the reference must not move its colors
    local warRatio = ratio(plain, "WARRIOR_TANK")
    check(warRatio > 0.40, string.format("warrior-tank weapon color unaffected by SP reference (ratio %.2f)", warRatio))

    GSPlus.Calculator:InvalidateCache()
end)()



;(function()
    -- 69. Role is TALENT-based, never gear-guessed. With inspect talents
    -- unreadable, the unit reports low confidence and its entry is provisional
    -- ("...") and retried - even full tank gear is NOT called a tank from gear.
    TEST_UNITS.notal = { name = "Mystery", guid = "guid-mystery", isPlayer = true, class = "PALADIN" }
    local savedEq = {}
    for k, v in pairs(equipped) do savedEq[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    local link = "|cffa335ee|Hitem:6700::::::::70:::::|h[Plate]|h|r"
    fakeItems[link] = { name = "Plate", equipLoc = "INVTYPE_CHEST" }
    fakeTooltips[link] = { "Plate", "Plate", "1500 Armor", "+50 Stamina",
        "+40 Defense Rating", "+30 Dodge Rating" }  -- unmistakably tank gear
    equipped.ChestSlot = link
    talentTabs = { { name = "Holy", points = 0 }, { name = "Protection", points = 0 }, { name = "Retribution", points = 0 } }
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    local _, confident = GSPlus.Inspect:GetUnitProfile("notal")
    check(confident == false, "unreadable talents report low role confidence (no gear guess)")
    local e = GSPlus.Inspect:BuildUnitEntry("notal", "inspect")
    check(e and e.partial == true, "unknown-role entry is provisional even on full tank gear")

    talentTabs = { { name = "Arms", points = 5 }, { name = "Fury", points = 3 }, { name = "Protection", points = 41 } }
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEq) do equipped[k] = v end
    TEST_UNITS.notal = nil
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()



;(function()
    -- 70. Inspect spec is read by SUMMING talent ranks (GetTalentInfo) - the
    -- reliable inspect API on TBC - and cached per GUID at the unit's
    -- INSPECT_READY, so later passes never re-read the no-unit inspect API
    -- (which would return another player's spec and also cost ~90 calls/hover).
    local savedGTI, savedGNT = GetTalentInfo, GetNumTalents
    local ranks = { [1] = { 0 }, [2] = { 5, 5, 5, 3 }, [3] = { 0 } }  -- tab2 = 18 pts
    GetNumTalents = function(tab) return #ranks[tab] end
    GetTalentInfo = function(tab, idx) return "T", "tex", 1, 1, ranks[tab][idx] or 0, 5 end

    local bi, tp = GSPlus.TalentDetector:GetInspectDominantTree()
    check(bi == 2 and tp == 18,
        "dominant tree summed from talent ranks (got " .. tostring(bi) .. "," .. tostring(tp) .. ")")

    TEST_UNITS.specpal = { name = "Spec", guid = "guid-spec", isPlayer = true, class = "PALADIN" }
    local savedEq70 = {}
    for k, v in pairs(equipped) do savedEq70[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    GSPlus.Inspect.roleByGuid["guid-spec"] = GSPlus.Inspect:ReadTalentProfile("specpal")
    check(GSPlus.Inspect.roleByGuid["guid-spec"] == "PALADIN_TANK", "protection ranks resolve to PALADIN_TANK")

    ranks = { [1] = { 5, 5, 5, 5 }, [2] = { 0 }, [3] = { 0 } }  -- talents now read as holy
    check(GSPlus.Inspect:GetUnitProfile("specpal") == "PALADIN_TANK",
        "cached role is reused, not re-read from the inspect API")

    GetTalentInfo, GetNumTalents = savedGTI, savedGNT
    GSPlus.Inspect.roleByGuid["guid-spec"] = nil
    for k, v in pairs(savedEq70) do equipped[k] = v end
    TEST_UNITS.specpal = nil
end)()



;(function()
    -- 71. Role maps by talent-tree NAME, not tab index. The inspect API on this
    -- client can return tabs in a non-standard ORDER: a 45/11/5 holy paladin
    -- reads its 45 Holy points at tab index 3 (Holyjony, /gs spec). The fixed
    -- index map would call index 3 "Retribution" -> DPS; the NAME at index 3 is
    -- "Holy" -> healer, which is correct.
    local saved = talentTabs
    talentTabs = {
        { name = "Retribution", points = 5 },
        { name = "Protection", points = 11 },
        { name = "Holy", points = 45 },
    }
    TEST_UNITS.revpal = { name = "Rev", guid = "guid-rev", isPlayer = true, class = "PALADIN" }
    GSPlus:InvalidateCaches()
    check(GSPlus.Inspect:ReadTalentProfile("revpal") == "PALADIN_HEALER",
        "reversed tabs: 45 Holy at index 3 maps to PALADIN_HEALER by name (got "
        .. tostring(GSPlus.Inspect:ReadTalentProfile("revpal")) .. ")")
    talentTabs = saved
    TEST_UNITS.revpal = nil
    GSPlus:InvalidateCaches()
end)()



;(function()
    -- 72. Gear override resolves a FALSE tank too: if the talent slot leaked a
    -- Protection spec onto a player wearing healing gear (no defense rating),
    -- the real role is recovered from gear -> healer, not tank.
    TEST_UNITS.fakeprot = { name = "Fakeprot", guid = "guid-fakeprot", isPlayer = true, class = "PALADIN" }
    local savedEq = {}
    for k, v in pairs(equipped) do savedEq[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    local function healPiece(id, name, equipLoc, slot)
        local link = "|cffa335ee|Hitem:" .. id .. "::::::::70:::::|h[" .. name .. "]|h|r"
        fakeItems[link] = { name = name, equipLoc = equipLoc, ilvl = 120 }
        fakeTooltips[link] = { name, "+30 Intellect",
            "Equip: Increases healing done by up to 120 and damage done by up to 40 for all magical spells and effects.",
            "Equip: Restores 8 mana per 5 sec." }
        equipped[slot] = link
    end
    healPiece(7201, "H Chest", "INVTYPE_CHEST", "ChestSlot")
    healPiece(7202, "H Legs", "INVTYPE_LEGS", "LegsSlot")
    healPiece(7203, "H Head", "INVTYPE_HEAD", "HeadSlot")
    GSPlus.Inspect.roleByGuid["guid-fakeprot"] = "PALADIN_TANK"  -- leaked tank spec
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    check(GSPlus.Inspect:GetUnitProfile("fakeprot") == "PALADIN_HEALER",
        "leaked tank talents + healing gear resolves to healer (got "
        .. tostring(GSPlus.Inspect:GetUnitProfile("fakeprot")) .. ")")
    GSPlus.Inspect.roleByGuid["guid-fakeprot"] = nil
    for k, v in pairs(savedEq) do equipped[k] = v end
    TEST_UNITS.fakeprot = nil
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()



;(function()
    -- 73. PALADIN_TANK gs+ is normalized to the other tanks: its threat stats
    -- (spellpower/intellect/mp5) no longer push its total above a warrior tank's
    -- for equivalent BiS gear.
    local C = GSPlus.Calculator
    local equipLocs = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK",
        "INVTYPE_CHEST", "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS",
        "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_WEAPONMAINHAND", "INVTYPE_SHIELD" }

    local function bisTotal(prof)
        local t = 0
        for _, el in ipairs(equipLocs) do
            local rs = GSPlus.ReferenceGear:GetStats("TANK", el)
            if rs then
                local w = C:CalculateWeightedStatScore(rs, prof)
                if rs.WEAPON_DPS and rs.WEAPON_DPS > 0 then
                    w = w + C:CalculateWeaponScore(rs, prof, "MainHandSlot", nil)
                end
                t = t + w
            end
        end
        return t
    end

    C:InvalidateCache()
    C.referenceCache = nil
    local pal, war = bisTotal("PALADIN_TANK"), bisTotal("WARRIOR_TANK")
    check(pal > 0 and war > 0 and math.abs(pal - war) / war < 0.10,
        string.format("paladin-tank gs+ normalized to warrior-tank (pal=%.0f war=%.0f, within 10%%)", pal, war))
end)()



;(function()
    -- 74. Cross-role normalization: every TBC role's full BiS reference set
    -- scores within a tight band, so a BiS tank/healer/caster/physical-DPS all
    -- land at a comparable gs+ (was a ~40% spread; physical DPS ran far low).
    local C = GSPlus.Calculator
    local slots = {
      {"HeadSlot","INVTYPE_HEAD"},{"NeckSlot","INVTYPE_NECK"},{"ShoulderSlot","INVTYPE_SHOULDER"},
      {"BackSlot","INVTYPE_CLOAK"},{"ChestSlot","INVTYPE_CHEST"},{"WristSlot","INVTYPE_WRIST"},
      {"HandsSlot","INVTYPE_HAND"},{"WaistSlot","INVTYPE_WAIST"},{"LegsSlot","INVTYPE_LEGS"},
      {"FeetSlot","INVTYPE_FEET"},{"Finger0Slot","INVTYPE_FINGER"},{"Finger1Slot","INVTYPE_FINGER"},
      {"Trinket0Slot","INVTYPE_TRINKET"},{"Trinket1Slot","INVTYPE_TRINKET"},
      {"MainHandSlot","INVTYPE_WEAPONMAINHAND"},{"SecondaryHandSlot","INVTYPE_SHIELD"},{"RangedSlot","INVTYPE_RELIC"} }
    local function total(prof, group)
        local t = 0
        for _, sl in ipairs(slots) do
            local rs = GSPlus.ReferenceGear:GetStats(group, sl[2])
            if rs then
                local w = C:CalculateWeightedStatScore(rs, prof)
                if rs.WEAPON_DPS and rs.WEAPON_DPS > 0 then w = w + C:CalculateWeaponScore(rs, prof, sl[1], nil) end
                t = t + w
            end
        end
        return t
    end
    C:InvalidateCache(); C.referenceCache = nil; C.refBuildCache = nil; C.scoreScaleCache = nil
    local mn, mx = 1e9, 0
    for prof in pairs(GSPlus.Weights.PROFILE_WEIGHTS) do
        if not string.find(prof, "DEATHKNIGHT") then  -- not a TBC class
            local v = total(prof, C:GetProfileColorCapGroup(prof))
            if v < mn then mn = v end
            if v > mx then mx = v end
        end
    end
    -- Cross-role calibration (Calculator.GetProfileScoreScale) maps every role's
    -- reference build to CALIBRATION_TARGET, so the band collapses to ~0%.
    check(mn > 0 and (mx - mn) / mn < 0.01,
        string.format("all TBC roles share one gs+ band (min=%.0f max=%.0f, %.1f%%)", mn, mx, (mx-mn)/mn*100))
end)()

;(function()
    -- 64. Login self-heal (regression: "gs+ wrong on login, correct after a
    -- /reload"). A score computed while the player's own gear is still loading
    -- must NOT freeze: once item data arrives it has to converge to the correct,
    -- complete number on its own - without a /reload, and without depending on a
    -- GET_ITEM_INFO_RECEIVED event firing at just the right moment.
    local function pumpTimers(maxRounds)
        for _ = 1, (maxRounds or 50) do
            if #pendingTimers == 0 then break end
            local batch = pendingTimers
            pendingTimers = {}
            for _, fn in ipairs(batch) do fn() end
        end
    end

    local savedEq = {}
    for k, v in pairs(equipped) do savedEq[k] = v end
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    playerClass = "WARRIOR"

    local loginChest = "|cffa335ee|Hitem:9800::::::::70:::::|h[Login Chest]|h|r"
    fakeItems[loginChest] = { name = "Login Chest", equipLoc = "INVTYPE_CHEST" }
    -- Base lines present, but the client hasn't confirmed full data, so the green
    -- "Equip:" attack power line is still missing - the "Late Loader" shape that
    -- undercounts a real login scan.
    local loadingLines = { "Login Chest", "Chest", "Plate", "1400 Armor", "+57 Stamina", "+30 Strength" }
    local loadedLines = { "Login Chest", "Chest", "Plate", "1400 Armor", "+57 Stamina", "+30 Strength",
        "Equip: Increases attack power by 40." }
    fakeTooltips[loginChest] = loadingLines
    itemDataCached["9800"] = false
    equipped.ChestSlot = loginChest

    -- (a) Calculator fix: an incomplete total is flagged and never cached, so the
    --     very next read after data arrives recomputes instead of returning a
    --     frozen undercount.
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus:InvalidateCaches()
    local partial = GSPlus.Calculator:CalculateTotalGSPlus("WARRIOR_DPS")
    check(partial.incomplete == true, "login: a total built from unloaded gear is flagged incomplete")
    check(GSPlus.Calculator.scoreCache == nil, "login: an incomplete total is never cached")

    itemDataCached["9800"] = true
    fakeTooltips[loginChest] = loadedLines
    local complete = GSPlus.Calculator:CalculateTotalGSPlus("WARRIOR_DPS")
    check(not complete.incomplete
        and (complete.totalWeightedScore or 0) > (partial.totalWeightedScore or 0),
        "login: next read after data arrives recomputes the complete score (no reload)")
    check(GSPlus.Calculator.scoreCache ~= nil, "login: a complete total is cached")

    -- (b) Core fix: the login event starts a bounded convergence pass that drives
    --     the pane to the right score on a timer, even though data only becomes
    --     available AFTER login and no item event fires.
    fakeTooltips[loginChest] = loadingLines
    itemDataCached["9800"] = false
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus:InvalidateCaches()
    pendingTimers = {}

    GSPlus:OnEvent("PLAYER_ENTERING_WORLD")
    GSPlus.CharacterPaneUI:Update()
    check(string.find(GSPlus.CharacterPaneUI.scoreText.text or "", "...", 1, true) ~= nil,
        "login: pane shows the loading indicator, not a wrong number, while gear loads")

    -- Server delivers the data; GET_ITEM_INFO_RECEIVED is deliberately NOT fired.
    itemDataCached["9800"] = true
    fakeTooltips[loginChest] = loadedLines
    pumpTimers(40)

    local healed = GSPlus.CharacterPaneUI.scoreText.text or ""
    check(string.find(healed, "|c", 1, true) ~= nil and string.find(healed, "...", 1, true) == nil,
        "login: pane converges to the real score once data arrives (no /reload, no item event)")

    itemDataCached["9800"] = nil
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEq) do equipped[k] = v end
    playerClass = "WARRIOR"
    GSPlus.ItemParser:InvalidateStatsCache()
    GSPlus:InvalidateCaches()
    pendingTimers = {}
end)()

;(function()
    -- 65. Manual profile is PER CHARACTER, and a leftover account-wide pick from
    -- an older version is discarded so it can't mis-label a character (regression:
    -- a Shaman's manual pick was stored globally and surfaced on a Druid as
    -- "Shaman Healer"; a Resto Shaman showed as "Shaman Enhancement" from the
    -- same stale global - even though talents/gear clearly detect Restoration).
    local savedEq = {}
    for k, v in pairs(equipped) do savedEq[k] = v end
    local savedTabs = talentTabs
    local savedClass = playerClass
    local savedByChar = GSPlusSavedVars.manualProfileByChar
    local savedUseManual = GSPlusSavedVars.useManualProfile
    local savedSelected = GSPlusSavedVars.selectedProfile

    -- The old buggy global state: a single account-wide manual pick.
    GSPlusSavedVars.manualProfileByChar = nil
    GSPlusSavedVars.useManualProfile = true
    GSPlusSavedVars.selectedProfile = "SHAMAN_ENHANCEMENT"

    -- A Resto shaman must auto-detect its real spec, not the stale global pick.
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    playerClass = "SHAMAN"
    talentTabs = { { name = "Elemental", points = 0 }, { name = "Enhancement", points = 5 },
        { name = "Restoration", points = 56 } }
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    check(GSPlus.Profiles:GetSelectedProfile() == "SHAMAN_HEALER",
        "manual: a stale account-wide pick no longer overrides detection (Resto -> Healer)")
    check(GSPlus.Profiles:IsUsingManualProfile() == false,
        "manual: the Resto shaman is on automatic detection")
    check(GSPlusSavedVars.useManualProfile == nil and GSPlusSavedVars.selectedProfile == nil,
        "manual: the legacy account-wide fields are discarded on read")

    -- A new pick is stored per character.
    check(GSPlus.Profiles:SetSelectedProfile("SHAMAN_ELEMENTAL") == true, "manual: same-class pick accepted")
    check(GSPlus.Profiles:GetSelectedProfile() == "SHAMAN_ELEMENTAL", "manual: same-class pick applied")
    check(GSPlusSavedVars.manualProfileByChar[GSPlus.Profiles:GetCharacterKey()] == "SHAMAN_ELEMENTAL",
        "manual: pick stored under the per-character key")

    -- A different class neither inherits that pick nor accepts a cross-class one.
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    playerClass = "DRUID"
    talentTabs = { { name = "Balance", points = 0 }, { name = "Feral Combat", points = 41 },
        { name = "Restoration", points = 0 } }
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
    local druidProfile = GSPlus.Profiles:GetSelectedProfile()
    check(GSPlus.Profiles:GetProfileClass(druidProfile) == "DRUID",
        "manual: the Druid resolves to a Druid profile, no Shaman leak (got " .. tostring(druidProfile) .. ")")
    check(GSPlus.Profiles:SetSelectedProfile("SHAMAN_HEALER") == false,
        "manual: a cross-class pick is rejected")

    -- Automatic clears the per-character pick.
    playerClass = "SHAMAN"
    GSPlus:InvalidateCaches()
    GSPlus.Profiles:UseAutomaticProfileDetection()
    check(GSPlus.Profiles:IsUsingManualProfile() == false, "manual: Automatic clears the per-character pick")

    check(GSPlus.Profiles:IsProfileForClass("DRUID_FERAL", "DRUID")
        and not GSPlus.Profiles:IsProfileForClass("SHAMAN_HEALER", "DRUID")
        and not GSPlus.Profiles:IsProfileForClass("WARLOCK_DPS", "WARRIOR"),
        "manual: IsProfileForClass distinguishes class ownership (no WARRIOR/WARLOCK overlap)")

    talentTabs = savedTabs
    playerClass = savedClass
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end
    for k, v in pairs(savedEq) do equipped[k] = v end
    GSPlusSavedVars.manualProfileByChar = savedByChar
    GSPlusSavedVars.useManualProfile = savedUseManual
    GSPlusSavedVars.selectedProfile = savedSelected
    GSPlus:InvalidateCaches()
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 66. Weapon enchant effects are scored from their tooltip name. Named
    -- enchants (Mongoose, Crusader, the spellpower brands, ...) show only their
    -- name with no stat text, so KnownEnchants maps the name to averaged stats.
    GSPlus.ItemParser:InvalidateStatsCache()

    -- Mongoose: agility + a little haste, added on top of the weapon's own stats.
    local mlink = "|cffa335ee|Hitem:60001:2673:::::::70:::::|h[Vindicator's Brand]|h|r"
    fakeItems[mlink] = { name = "Vindicator's Brand", equipLoc = "INVTYPE_WEAPON" }
    fakeTooltips[mlink] = { "Vindicator's Brand", "One-Hand", "Sword",
        "147 - 275 Damage", "Speed 2.60", "(81.2 damage per second)",
        "Mongoose", "Requires Level 70",
        "Equip: Improves hit rating by 19.", "Equip: Increases attack power by 38." }
    local ms = GSPlus.ItemParser:ParseItemStats(mlink)
    check(ms.AGILITY == 30 and ms.HASTE == 8,
        "Mongoose enchant scored (agi " .. tostring(ms.AGILITY) .. ", haste " .. tostring(ms.HASTE) .. ")")
    check(ms.HIT == 19 and ms.ATTACKPOWER == 38,
        "the weapon's own equip stats are still parsed alongside the enchant")
    local noEnch = {}
    for k, v in pairs(ms) do noEnch[k] = v end
    noEnch.AGILITY = nil; noEnch.HASTE = nil
    check(GSPlus.Calculator:CalculateWeightedStatScore(ms, "ROGUE_DPS")
        > GSPlus.Calculator:CalculateWeightedStatScore(noEnch, "ROGUE_DPS"),
        "Mongoose raises a rogue's weighted score")

    -- Crusader -> Strength.
    GSPlus.ItemParser:InvalidateStatsCache()
    local clink = "|cffa335ee|Hitem:60002:1900:::::::70:::::|h[Crusader Blade]|h|r"
    fakeItems[clink] = { name = "Crusader Blade", equipLoc = "INVTYPE_WEAPON" }
    fakeTooltips[clink] = { "Crusader Blade", "One-Hand", "Mace",
        "100 - 150 Damage", "Speed 2.70", "(46.3 damage per second)", "Crusader", "Requires Level 60" }
    check(GSPlus.ItemParser:ParseItemStats(clink).STRENGTH == 25, "Crusader enchant scored as Strength")

    -- Major Spellpower -> spell power + healing.
    GSPlus.ItemParser:InvalidateStatsCache()
    local splink = "|cffa335ee|Hitem:60003:2674:::::::70:::::|h[Sageblade]|h|r"
    fakeItems[splink] = { name = "Sageblade", equipLoc = "INVTYPE_WEAPON" }
    fakeTooltips[splink] = { "Sageblade", "One-Hand", "Sword",
        "50 - 90 Damage", "Speed 1.80", "(38.9 damage per second)", "Major Spellpower", "Requires Level 70" }
    local sp = GSPlus.ItemParser:ParseItemStats(splink)
    check(sp.SPELLPOWER == 40 and sp.HEALING == 40, "Major Spellpower enchant scored (spell power + healing)")

    -- Cataclysm Landslide -> attack power.
    GSPlus.ItemParser:InvalidateStatsCache()
    local llink = "|cffa335ee|Hitem:60004:4099:::::::85:::::|h[Landslide Axe]|h|r"
    fakeItems[llink] = { name = "Landslide Axe", equipLoc = "INVTYPE_WEAPON" }
    fakeTooltips[llink] = { "Landslide Axe", "One-Hand", "Axe",
        "200 - 300 Damage", "Speed 2.60", "(96.1 damage per second)", "Landslide", "Requires Level 85" }
    check(GSPlus.ItemParser:ParseItemStats(llink).ATTACKPOWER == 200, "Landslide enchant scored as attack power")

    -- Exact-name match only: ordinary item text is never mistaken for an enchant.
    check(GSPlus.KnownEnchants:GetByName("Mongoose") ~= nil
        and GSPlus.KnownEnchants:GetByName("Vindicator's Brand") == nil
        and GSPlus.KnownEnchants:GetByName("") == nil,
        "KnownEnchants matches only exact enchant names")

    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 67. Budget costs match the documented WoW itemization StatMods, and armor
    -- penetration RATING (a combat rating) is scored separately from flat armor
    -- ignore (priced like bonus armor). See STAT_BUDGET_ANALYSIS.md.
    local C = GSPlus.Calculator
    check(C.ITEM_BUDGET_EXPONENT == 1.5, "budget exponent is the documented 3/2 (1.5)")
    check(C:GetStatBudgetCost("SCHOOL_SPELLPOWER") == 0.70, "single-school spell damage costs 0.70")
    check(C:GetStatBudgetCost("MP5") == 2.50, "MP5 costs 2.5")
    check(C:GetStatBudgetCost("SPELL_PENETRATION") == 0.90, "spell penetration costs 0.9")
    check(C:GetStatBudgetCost("FIRE_RESISTANCE") == 1.00, "single-school resistance costs 1.0")
    check(C:GetStatBudgetCost("ARMOR_PENETRATION_RATING") == 1.00, "armor penetration RATING costs 1.0")
    check(C:GetStatBudgetCost("ARMOR_PENETRATION") == 0.10, "flat armor-ignore stays cheap (0.10)")

    -- "Armor Penetration Rating" parses to the rating key; "ignore N armor" stays flat.
    GSPlus.ItemParser:InvalidateStatsCache()
    local apl = "|cffa335ee|Hitem:61001:::::::80:::::|h[Sundering Blade]|h|r"
    fakeItems[apl] = { name = "Sundering Blade", equipLoc = "INVTYPE_WEAPON" }
    fakeTooltips[apl] = { "Sundering Blade", "One-Hand", "Sword",
        "100 - 150 Damage", "Speed 2.60", "(48.1 damage per second)",
        "+40 Armor Penetration Rating", "Requires Level 80" }
    local aps = GSPlus.ItemParser:ParseItemStats(apl)
    check(aps.ARMOR_PENETRATION_RATING == 40 and aps.ARMOR_PENETRATION == nil,
        "armor penetration rating parsed as a rating, not flat armor-ignore")

    local flat = {}
    GSPlus.ItemParser:ParseTooltipLine("Equip: Your attacks ignore 175 of your opponent's armor.", flat)
    check(flat.ARMOR_PENETRATION == 175 and flat.ARMOR_PENETRATION_RATING == nil,
        "flat armor-ignore stays the flat ARMOR_PENETRATION key")

    -- The rating aliases the attack-power weight, so it scores for a melee DPS.
    check(GSPlus.Weights:GetWeight("WARRIOR_DPS", "ARMOR_PENETRATION_RATING")
        == GSPlus.Weights:GetWeight("WARRIOR_DPS", "ATTACKPOWER")
        and GSPlus.Weights:GetWeight("WARRIOR_DPS", "ATTACKPOWER") > 0,
        "armor penetration rating inherits the attack-power role weight")

    -- A school-spell-damage point now contributes less than an all-school point
    -- (0.70 vs 0.86 budget), per the documented single-school discount.
    check(GSPlus.Calculator:CalculateWeightedStatScore({ SCHOOL_SPELLPOWER = 100 }, "MAGE_DPS")
        < GSPlus.Calculator:CalculateWeightedStatScore({ SPELLPOWER = 100 }, "MAGE_DPS"),
        "single-school spell damage scores below all-school spell power")
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 68. Serpent-Coil Braid: the mana-gem spell power proc is valued via a
    -- KnownProcs override (its wording has no "chance to", so the generic proc
    -- model can't see it). Its base ratings still parse, and the special line is
    -- NOT flagged unscored once the override accounts for it.
    GSPlus.ItemParser:InvalidateStatsCache()
    local scb = "|cffa335ee|Hitem:30720::::::::70:::::|h[Serpent-Coil Braid]|h|r"
    fakeItems[scb] = { name = "Serpent-Coil Braid", equipLoc = "INVTYPE_TRINKET", ilvl = 128 }
    fakeTooltips[scb] = {
        "Serpent-Coil Braid", "Unique", "Trinket", "Classes: Mage", "Requires Level 70",
        "Equip: Improves spell hit rating by 12.",
        "Equip: Improves spell critical strike rating by 30.",
        "Equip: You gain 25% more mana when you use a mana gem. In addition, using a mana gem grants you 225 spell damage for 15 sec.",
    }
    local sc = GSPlus.ItemParser:ParseItemStats(scb)
    check(sc.SPELLPOWER == 30, "Serpent-Coil mana-gem proc scored as spell power (got " .. tostring(sc.SPELLPOWER) .. ")")
    check(sc.HIT == 12 and sc.CRITICAL == 30, "Serpent-Coil base ratings still parsed alongside the proc")
    check(not sc.UNSCORED_EQUIP_EFFECT, "override item's special line is not flagged unscored")
    check(GSPlus.Calculator:CalculateWeightedStatScore(sc, "MAGE_DPS") > 0, "Serpent-Coil contributes to a mage's score")
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 69. Feral (bear) tank weights follow Wowhead's bear priority:
    -- agility/expertise lead, then hit, stamina, strength, defense, crit, dodge,
    -- haste, attack power, and armor last. Weapon DPS/skill are ignored.
    local C = GSPlus.Calculator
    local function per(stat) return C:CalculateWeightedStatScore({ [stat] = 1 }, "DRUID_TANK") end
    check(per("AGILITY") >= per("EXPERTISE") - 1e-9 and per("EXPERTISE") >= per("HIT")
        and per("HIT") >= per("STAMINA") and per("STAMINA") >= per("STRENGTH")
        and per("STRENGTH") >= per("DEFENSE") and per("DEFENSE") >= per("CRITICAL")
        and per("CRITICAL") >= per("DODGE") and per("DODGE") > per("HASTE")
        and per("HASTE") > per("ATTACKPOWER") and per("ATTACKPOWER") > per("ARMOR"),
        "bear tank priority (Wowhead): agi/exp > hit > stamina > strength > defense > crit > dodge > haste > AP > armor")
    check(per("AGILITY") > per("DODGE") and per("EXPERTISE") > per("DODGE"),
        "agility & expertise outrank dodge (dodge no longer the top bear stat)")
    check(per("WEAPON_SKILL") == 0 and C:CalculateWeaponScore({ WEAPON_DPS = 100, WEAPON_AVERAGE_DAMAGE = 150 }, "DRUID_TANK", "MainHandSlot", nil) == 0,
        "bears gain nothing from weapon skill or weapon DPS")
end)()

;(function()
    -- 70. The live mouseover tooltip refreshes when a player's score resolves,
    -- even with no "waiting" flag set (the cached-but-not-final case that left
    -- it stuck on "Loading...").
    TEST_UNITS.hovertgt = { name = "Hovery", guid = "guid-hovery", isPlayer = true, class = "WARRIOR" }
    local realGT = GameTooltip
    local setUnitCalls = 0
    GameTooltip = {
        IsShown = function() return true end,
        GetUnit = function() return "Hovery", "hovertgt" end,
        SetUnit = function() setUnitCalls = setUnitCalls + 1 end,
        AddLine = function() end, AddDoubleLine = function() end, Show = function() end,
    }
    GSPlus.UnitTooltip.waitingGuid = nil
    GSPlus.UnitTooltip:OnScoreUpdated("guid-hovery", "Hovery",
        { weighted = 1000, max = 1200, profileKey = "WARRIOR_DPS" })
    check(setUnitCalls == 1, "mouseover tooltip refreshes on score update without a waiting flag")
    GameTooltip = realGT

    -- 71. A timed-out background inspect clears the per-player cooldown so the
    -- next hover retries instead of waiting out the 10s cooldown.
    GSPlus.Inspect.queue = {}
    local token = { unit = "hovertgt", guid = "guid-hovery", name = "Hovery" }
    GSPlus.Inspect.current = token
    GSPlus.Inspect.lastAttempt["guid-hovery"] = time()
    GSPlus.Inspect:OnInspectTimeout(token)
    check(GSPlus.Inspect.current == nil and GSPlus.Inspect.lastAttempt["guid-hovery"] == nil,
        "inspect timeout clears the current request and the per-player cooldown")

    -- 72. Targeting a player triggers a background inspect (the "target" token is
    -- stable), so the cache fills reliably instead of relying on a transient hover.
    GSPlus.Inspect:RegisterEvents()
    TEST_UNITS.target = { name = "Targy", guid = "guid-targy", isPlayer = true, class = "MAGE" }
    local origCID = CheckInteractDistance
    CheckInteractDistance = function() return true end
    if InspectFrame then InspectFrame:Hide() end
    inCombat = false
    GSPlus.Inspect.queue = {}; GSPlus.Inspect.current = nil
    GSPlus.Inspect.lastAttempt["guid-targy"] = nil
    GSPlus.Inspect.lastNotify = 0
    GSPlus.Inspect.MIN_NOTIFY_INTERVAL = 0
    notifyInspectCalls = 0
    GSPlus.Inspect.eventFrame.script_OnEvent(GSPlus.Inspect.eventFrame, "PLAYER_TARGET_CHANGED")
    check(notifyInspectCalls == 1, "targeting a player triggers a background inspect")
    CheckInteractDistance = origCID
    GSPlus.Inspect.queue = {}; GSPlus.Inspect.current = nil
end)()

;(function()
    -- 74. Own-character spec detection survives a client whose
    -- GetTalentTabInfo reports zero spent points: per-talent ranks
    -- (GetTalentInfo) are summed instead, so a 41-point Holy priest reads as a
    -- healer rather than mis-detecting as Shadow/DPS via ambiguous gear.
    local rClass, rNumTabs, rTabInfo = playerClass, GetNumTalentTabs, GetTalentTabInfo
    local rGNT, rGTI = GetNumTalents, GetTalentInfo
    playerClass = "PRIEST"
    local treeNames = { "Discipline", "Holy", "Shadow" }
    GetNumTalentTabs = function() return 3 end
    GetTalentTabInfo = function(i) return treeNames[i], "tex", 0, "file" end  -- broken: 0 points
    local rankTotals = { 20, 41, 0 }
    GetNumTalents = function(tab) return rankTotals[tab] end
    GetTalentInfo = function() return "T", "tex", 0, false, 1 end             -- 1 rank each
    GSPlus.TalentDetector.roleCache = {}
    GSPlus:InvalidateCaches()
    local bi, tp, bn = GSPlus.TalentDetector:GetDominantTree(false)
    check(bi == 2 and tp == 61 and bn == "Holy",
        "own talents summed from ranks when tab-info points are zero (got "..tostring(bi)..","..tostring(tp)..","..tostring(bn)..")")
    check(GSPlus.TalentDetector:GetDetectedProfile() == "PRIEST_HEALER",
        "41-point Holy priest detected as PRIEST_HEALER via rank summing")
    GetNumTalentTabs, GetTalentTabInfo = rNumTabs, rTabInfo
    GetNumTalents, GetTalentInfo = rGNT, rGTI
    playerClass = rClass
    GSPlus.TalentDetector.roleCache = {}
    GSPlus:InvalidateCaches()

    -- 75. Own-character detection maps by tree NAME, so a client that returns
    -- talent tabs out of order still resolves the right spec.
    local r2Class, r2NumTabs, r2TabInfo = playerClass, GetNumTalentTabs, GetTalentTabInfo
    playerClass = "WARRIOR"
    local scrambled = { { "Protection", 41 }, { "Arms", 5 }, { "Fury", 3 } }  -- Prot reported at tab 1
    GetNumTalentTabs = function() return 3 end
    GetTalentTabInfo = function(i) return scrambled[i][1], "tex", scrambled[i][2], "file" end
    GSPlus.TalentDetector.roleCache = {}
    GSPlus:InvalidateCaches()
    check(GSPlus.TalentDetector:GetDetectedProfile() == "WARRIOR_TANK",
        "out-of-order talent tabs still map to WARRIOR_TANK by name")
    GetNumTalentTabs, GetTalentTabInfo = r2NumTabs, r2TabInfo
    playerClass = r2Class
    GSPlus.TalentDetector.roleCache = {}
    GSPlus:InvalidateCaches()
end)()

;(function()
    -- 76. Socket bonus is scored only when ACTIVE. WoW greys the "Socket Bonus"
    -- line when the socketed gems don't match the socket colours; a grey
    -- (unmet) bonus must not be counted, while the gems themselves always are.
    local function beltLines(active)
        local sb = active and { text = "Socket Bonus: +3 Agility", r = 0.1, g = 1.0, b = 0.1 }
                          or  { text = "Socket Bonus: +3 Agility", r = 0.5, g = 0.5, b = 0.5 }
        return { "Belt", "Waist", "Mail", "+21 Stamina", "+8 Strength", "+8 Strength", sb }
    end
    local actLink = "|cffa335ee|Hitem:5101::::::::70:::::|h[Active Socket Belt]|h|r"
    local inactLink = "|cffa335ee|Hitem:5102::::::::70:::::|h[Inactive Socket Belt]|h|r"
    fakeItems[actLink] = { name = "Active Socket Belt", equipLoc = "INVTYPE_WAIST", ilvl = 120 }
    fakeItems[inactLink] = { name = "Inactive Socket Belt", equipLoc = "INVTYPE_WAIST", ilvl = 120 }
    fakeTooltips[actLink] = beltLines(true)
    fakeTooltips[inactLink] = beltLines(false)
    GSPlus.ItemParser:InvalidateStatsCache()
    local act = GSPlus.ItemParser:ParseItemStats(actLink)
    GSPlus.ItemParser:InvalidateStatsCache()
    local inact = GSPlus.ItemParser:ParseItemStats(inactLink)
    check(act.AGILITY == 3, "active (green) socket bonus is scored (got "..tostring(act.AGILITY)..")")
    check((inact.AGILITY or 0) == 0, "inactive (grey) socket bonus is NOT scored (got "..tostring(inact.AGILITY)..")")
    check(act.STRENGTH == 16 and inact.STRENGTH == 16, "socketed gems counted regardless of socket-bonus state")
    GSPlus.ItemParser:InvalidateStatsCache()
end)()

;(function()
    -- 77. Selecting "Automatic" forces a fresh re-evaluation: it clears the
    -- detection caches so a role cached before a respec isn't just re-displayed
    -- (the cause of "I respecced but Auto still shows the old spec").
    GSPlus.TalentDetector.roleCache = { ["CLASS_FALLBACK:DRUID"] = "DRUID_RESTO" }
    GSPlusSavedVars = GSPlusSavedVars or {}
    GSPlusSavedVars.manualProfileByChar = { [GSPlus.Profiles:GetCharacterKey()] = "DRUID_RESTO" }
    GSPlus.Profiles:UseAutomaticProfileDetection()
    check(GSPlus.TalentDetector.roleCache == nil,
        "selecting Automatic clears the detection role cache (forces re-evaluation)")
    check(GSPlusSavedVars.manualProfileByChar[GSPlus.Profiles:GetCharacterKey()] == nil,
        "selecting Automatic clears the manual profile override")
end)()

;(function()
    -- 78. Dual-spec: detection reads the ACTIVE talent group, not always group 1.
    -- A druid whose primary (group 1) is Resto but who has activated a Feral
    -- secondary (group 2) must detect as Feral, and flip back when group 1 is
    -- active again - the cause of "I switched to Feral but it still says Resto".
    local rClass = playerClass
    local rGATG, rGTI, rGNT, rGTTI, rGNTT =
        GetActiveTalentGroup, GetTalentInfo, GetNumTalents, GetTalentTabInfo, GetNumTalentTabs
    playerClass = "DRUID"
    for _, k in ipairs(allSlotKeys) do equipped[k] = nil end  -- no tank gear -> feral cat
    local activeGroup = 1
    local treeNames = { "Balance", "Feral Combat", "Restoration" }
    local pts = { [1] = { 0, 0, 45 }, [2] = { 0, 45, 0 } }    -- g1 Resto, g2 Feral
    GetActiveTalentGroup = function() return activeGroup end
    GetNumTalentTabs = function() return 3 end
    GetNumTalents = function() return 45 end
    GetTalentTabInfo = function(tab, isInspect, isPet, group)
        return treeNames[tab], "tex", pts[group or 1][tab], "file"
    end
    GetTalentInfo = function(tab, idx, isInspect, isPet, group)
        return "T", "tex", 0, false, (idx <= pts[group or 1][tab]) and 1 or 0
    end

    activeGroup = 1
    GSPlus.TalentDetector.roleCache = {}; GSPlus:InvalidateCaches()
    local p1 = GSPlus.TalentDetector:GetDetectedProfile()
    activeGroup = 2
    GSPlus.TalentDetector.roleCache = {}; GSPlus:InvalidateCaches()
    local p2 = GSPlus.TalentDetector:GetDetectedProfile()
    activeGroup = 1
    GSPlus.TalentDetector.roleCache = {}; GSPlus:InvalidateCaches()
    local p3 = GSPlus.TalentDetector:GetDetectedProfile()

    check(p1 == "DRUID_RESTO", "active primary group detected as Resto (got "..tostring(p1)..")")
    check(p2 == "DRUID_FERAL" or p2 == "DRUID_TANK",
        "activating Feral secondary group flips detection to feral (got "..tostring(p2)..")")
    check(p3 == "DRUID_RESTO", "switching back to primary group returns to Resto (got "..tostring(p3)..")")

    GetActiveTalentGroup, GetTalentInfo, GetNumTalents, GetTalentTabInfo, GetNumTalentTabs =
        rGATG, rGTI, rGNT, rGTTI, rGNTT
    playerClass = rClass
    GSPlus.TalentDetector.roleCache = {}; GSPlus:InvalidateCaches()
end)()

;(function()
    -- 79. Feral druid weapons are coloured against a reference that now carries
    -- feral attack power. Previously the 2H reference had none, so every feral
    -- weapon (Karazhan or Sunwell) saturated at red. A mid-tier feral 2H must now
    -- sit below the red cap.
    local C = GSPlus.Calculator
    local RG = GSPlus.ReferenceGear.REFERENCE_GEAR_BY_FLAVOR.TBC
    check((RG.TANK.INVTYPE_2HWEAPON.FERAL_ATTACKPOWER or 0) > 0
        and (RG.PHYSICAL_DPS.INVTYPE_2HWEAPON.FERAL_ATTACKPOWER or 0) > 0,
        "2H weapon reference carries feral attack power for druid groups")
    local colorRef = C:CalculateWeightedScore(RG.TANK.INVTYPE_2HWEAPON, "DRUID_TANK", "MainHandSlot", nil) * C.COLOR_REFERENCE_HEADROOM
    local midFeral = C:CalculateWeightedStatScore({ STRENGTH=30, AGILITY=55, STAMINA=45, FERAL_ATTACKPOWER=620, HIT=20 }, "DRUID_TANK")
    check(colorRef > 0 and (midFeral / colorRef) < 1.0,
        string.format("a mid-tier feral 2H is no longer capped at red (ratio %.2f)", colorRef > 0 and midFeral/colorRef or -1))
end)()

;(function()
    -- 80. Weapon DPS carries a budget-cost multiplier so weapon-centric specs
    -- (melee, hunters) get proper credit. Previously 1 DPS = 1 point with a
    -- weight capped at 1.0, badly under-scoring a hunter's bow.
    local C = GSPlus.Calculator
    check((C.WEAPON_DPS_BUDGET_COST or 1) > 1, "weapon DPS has a budget-cost multiplier > 1")
    local dpsW = C:GetEffectiveWeight("HUNTER_DPS", "RANGED_WEAPON_DPS", false)
    local bowScore = C:CalculateWeaponScore({ WEAPON_DPS = 200 }, "HUNTER_DPS", "RangedSlot", nil)
    check(math.abs(bowScore - 200 * C.WEAPON_DPS_BUDGET_COST * dpsW) < 0.01,
        "weapon score applies the DPS budget cost (got " .. string.format("%.1f", bowScore) .. ")")
end)()

;(function()
    -- 81. Hunters use a dedicated RANGED reference (hunter-sized attack power) so
    -- generic Attack Power - which raises ranged AP - is credited without being
    -- measured against melee-sized flat AP (which made hunters score far too low).
    local C = GSPlus.Calculator
    check(C:GetProfileColorCapGroup("HUNTER_DPS") == "RANGED", "hunters use the RANGED color/reference group")
    check(GSPlus.Weights:GetWeight("HUNTER_DPS","ATTACKPOWER") > 0, "hunters value generic Attack Power (raises ranged AP)")
    local r = GSPlus.ReferenceGear:GetStats("RANGED","INVTYPE_RANGED")
    check(r and (r.WEAPON_DPS or 0) > 0, "the hunter reference's ranged slot is a weapon (bow) with DPS")
end)()

;(function()
    -- 82. Ranged-weapon scopes are scored: "Scope (+28 Critical Strike Rating)"
    -- is unwrapped so the crit counts (it's a permanent part of the weapon).
    local lk = "|cffa335ee|Hitem:9992::::::::70:::::|h[ScopedXbow]|h|r"
    fakeItems[lk] = { name="ScopedXbow", equipLoc="INVTYPE_RANGEDRIGHT", ilvl=120 }
    fakeTooltips[lk] = { "ScopedXbow","Ranged","Crossbow","155 - 288 Damage","Speed 2.80",
        "Scope (+28 Critical Strike Rating)", "Equip: Increases attack power by 30." }
    GSPlus.ItemParser:InvalidateStatsCache()
    local sc = GSPlus.ItemParser:ParseItemStats(lk)
    check(sc.CRITICAL == 28, "scope crit is scored (got "..tostring(sc.CRITICAL)..")")
    check(sc.ATTACKPOWER == 30, "weapon equip stats still parse alongside the scope")
    GSPlus.ItemParser:InvalidateStatsCache()

    -- 83. The breakdown's weapon-DPS row applies WEAPON_DPS_BUDGET_COST, matching
    -- the real score instead of under-displaying the weapon.
    local rows = GSPlus.Tooltip:BuildWeaponContributionRows({ WEAPON_DPS = 79.1 }, "HUNTER_DPS", "RangedSlot", nil)
    local dpsRow
    for _, r in ipairs(rows) do if (r.statName or ""):find("Weapon DPS") then dpsRow = r end end
    local cost = GSPlus.Calculator.WEAPON_DPS_BUDGET_COST
    local w = GSPlus.Weights:GetWeight("HUNTER_DPS","RANGED_WEAPON_DPS")
    check(dpsRow and math.abs(dpsRow.budgetCost - cost) < 1e-9, "weapon DPS breakdown row shows the budget cost")
    check(dpsRow and math.abs(dpsRow.finalContribution - 79.1*cost*w) < 0.01,
        "weapon DPS breakdown contribution includes the cost (got "..string.format("%.1f", dpsRow and dpsRow.finalContribution or -1)..")")
end)()

;(function()
    -- 84. Shift-hovering an inspected player's item brings up YOUR equipped item
    -- in that slot, drawn in our OWN comparison frame (not ShoppingTooltip1/2,
    -- which WoW hides every frame). Robust to clients where IsModifiedClick
    -- ("COMPAREITEMS") is unrecognized (shift accepted directly) and to inspected
    -- items not yet cached (slot resolved via GetItemInfoInstant).
    local rGT, rInst, rSW, rInv, rIMC =
        GameTooltip, GetItemInfoInstant, GetScreenWidth, GetInventoryItemLink, IsModifiedClick
    local myFeet = "|cffffffff|Hitem:7777::::::::70:::::|h[My Boots]|h|r"
    GetItemInfoInstant = function() return 8888, "Armor", "Cloth", "INVTYPE_FEET" end
    GetScreenWidth = function() return 1920 end
    IsModifiedClick = function() return false end                 -- COMPAREITEMS not recognized
    GetInventoryItemLink = function(unit) return unit == "player" and myFeet or nil end
    GameTooltip = { GetRight = function() return 1850 end, IsShown = function() return true end }

    local c1 = GSPlus.Tooltip:GetInspectCompareTooltips()
    local captured, wasShown = nil, false
    c1.SetHyperlink = function(_, l) captured = l end
    c1.Show = function() wasShown = true end

    GSPlus.Tooltip:ShowOwnGearComparisonForInspect(GameTooltip,
        "|cffa335ee|Hitem:9993::::::::70:::::|h[Inspected Boots]|h|r")
    check(captured == myFeet and wasShown,
        "inspect shift-compare shows the viewer's equipped item in our own frame (got " .. tostring(captured) .. ")")

    -- Releasing shift hides it.
    IsModifiedClick = function() return false end
    local hidden = false
    c1.Hide = function() hidden = true end
    local realShift = IsShiftKeyDown
    IsShiftKeyDown = function() return false end
    GSPlus.Tooltip:ShowOwnGearComparisonForInspect(GameTooltip,
        "|cffa335ee|Hitem:9993::::::::70:::::|h[Inspected Boots]|h|r")
    check(hidden, "comparison frame is hidden when shift is not held")
    IsShiftKeyDown = realShift

    GameTooltip, GetItemInfoInstant, GetScreenWidth, GetInventoryItemLink, IsModifiedClick =
        rGT, rInst, rSW, rInv, rIMC
end)()

;(function()
    -- 85. The viewer's own item, shown as the inspect shift-comparison, gets its
    -- own gs+ line - scored under the VIEWER's profile (its owner is UIParent,
    -- not an Inspect slot, so it is NOT treated as an inspected item).
    local c1 = GSPlus.Tooltip:GetInspectCompareTooltips()
    check(c1 and c1.hook_OnTooltipSetItem ~= nil, "inspect comparison frames are hooked for scoring")

    local realClass = playerClass
    playerClass = "WARRIOR"
    GSPlus:InvalidateCaches()
    local savedShow = GSPlus.Options:Get("showItemTooltip")
    GSPlus.Options:Set("showItemTooltip", true)
    InspectFrame.unit = "paltank"; InspectFrame:Show()        -- inspecting a paladin

    c1.addedLines = {}
    c1.bgsScoreAdded = nil
    c1.GetItem = function() return "Test Healer Robe", chestLink end
    c1.GetOwner = function() return { GetName = function() return "UIParent" end } end
    c1.AddLine = function(self, t) self.addedLines[#self.addedLines+1] = t or "" end
    c1.AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines+1] = (l or "") .. " | " .. (r or "") end
    c1.Show = function() end

    GSPlus.Tooltip:AddGearScoreToTooltip(c1)
    local sawWarrior, sawPaladin = false, false
    for _, line in ipairs(c1.addedLines) do
        if string.find(line, "Warrior", 1, true) then sawWarrior = true end
        if string.find(line, "Paladin", 1, true) then sawPaladin = true end
    end
    check(sawWarrior and not sawPaladin,
        "comparison item gets a gs+ line under the viewer's profile, not the inspected player's")

    InspectFrame:Hide()
    GSPlus.Options:Set("showItemTooltip", savedShow)
    playerClass = realClass
    GSPlus:InvalidateCaches()
end)()


realPrint(failures == 0 and "ALL TESTS PASSED" or (failures .. " TEST(S) FAILED"))
os.exit(failures == 0 and 0 or 1)
