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
        _G[frame.name .. "TextLeft" .. i] = { GetText = function() return line end }
        _G[frame.name .. "TextRight" .. i] = { GetText = function() return nil end }
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
function UnitName(unit) local u = TEST_UNITS[unit]; return u and u.name end
function CanInspect(unit) return TEST_UNITS[unit] ~= nil end
function NotifyInspect(unit) notifyInspectCalls = notifyInspectCalls + 1 end
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
    "Core.lua", "GameVersion.lua", "StatWeights.lua", "ReferenceGear.lua", "KnownProcs.lua", "StatCaps.lua", "Profiles.lua", "TalentDetector.lua",
    "ItemParser.lua", "SetBonuses.lua", "Calculator.lua",
    "LegacyGearScore.lua", "Options.lua", "PlayerCache.lua",
    "CharacterPaneUI.lua", "InspectPaneUI.lua", "UI.lua", "GroupFrame.lua",
    "Tooltip.lua", "UnitTooltip.lua", "Inspect.lua", "Comms.lua", "Commands.lua",
}
for _, file in ipairs(tocOrder) do
    local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
    chunk()
end

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

-- 2. Single slash command opens options
SlashCmdList["GSPlus"]("")
check(optionsPanelOpened > 0, "/gs opens the options panel")

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
check(#rows == 1 and math.abs(rows[1].roleWeight - 1.0) < 0.001,
    "breakdown shows cap-neutral weights matching the score")

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

-- 6. Profile override still works through the Profiles API (dropdown path)
GSPlus.Profiles:SetSelectedProfile("MAGE_DPS")
check(GSPlus.Profiles:GetSelectedProfile() == "MAGE_DPS", "manual profile via dropdown API")
GSPlus.Profiles:UseAutomaticProfileDetection()
check(GSPlus.Profiles:GetSelectedProfile() == "WARRIOR_TANK", "auto detection restored")

-- 7. Comms roundtrip
local message = GSPlus.Comms:BuildScoreMessage()
check(string.match(message, "^S:2:") ~= nil, "score message built (protocol v2)")
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
    if sent.message == "R:2" then sawRequest = true end
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

check(GSPlus.Options:Get("showItemTooltip") == false, "item tooltip off by default")
check(GSPlus.Options:Get("showLegacyGearScore") == false, "legacy GS off by default")
check(GSPlus.Options:Get("showBudgetScore") == false, "budget score off by default")
check(GSPlus.Options:Get("showTooltipBreakdown") == false, "breakdown off by default")
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
check(#quietTip.addedLines == 0, "item tooltip adds nothing by default")

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

-- Inspected units get the same fallback
TEST_UNITS.focus = { name = "Carol", guid = "guid-carol", isPlayer = true, class = "SHAMAN" }
local carolEntry = GSPlus.Inspect:BuildUnitEntry("focus", "inspect")
check(carolEntry and carolEntry.profileKey == "SHAMAN_HEALER",
    "inspected shaman in healing gear profiled by gear fallback")

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
check(math.abs(GSPlus.Calculator:GetScoreRatio(refSelfScore, fswMax) - 1.0) < 0.001,
    "reference item scores exactly red against its own reference (ratio 1.0)")

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

-- 22. Linear weighted score: breakdown rows add up to the total exactly
local chestStats = GSPlus.ItemParser:ParseItemStats(chestLink)
local rows2, rowTotal = GSPlus.Tooltip:BuildStatContributionRows(chestStats, "SHAMAN_HEALER")
local rowSum = 0
for _, row in ipairs(rows2) do rowSum = rowSum + row.finalContribution end
check(math.abs(rowSum - rowTotal) < 0.001
    and math.abs(rowTotal - GSPlus.Calculator:CalculateWeightedStatScore(chestStats, "SHAMAN_HEALER")) < 0.001,
    "breakdown contributions sum exactly to the weighted score (linear)")

realPrint(failures == 0 and "ALL TESTS PASSED" or (failures .. " TEST(S) FAILED"))
os.exit(failures == 0 and 0 or 1)
