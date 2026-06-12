-- WoW API stub harness to smoke-test BetterGearScore outside the game.
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

equipped.ChestSlot = chestLink
equipped.MainHandSlot = swordLink

-- Load addon files in toc order ----------------------------------------------
local tocOrder = {
    "Core.lua", "StatWeights.lua", "StatCaps.lua", "Profiles.lua", "TalentDetector.lua",
    "ItemParser.lua", "SetBonuses.lua", "BetterGearScoreCalculator.lua",
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
BetterGearScore:Initialize()
BetterGearScore:Initialize()
local welcomeCount = 0
for _, line in ipairs(printed) do
    if string.find(line, "is ready") then welcomeCount = welcomeCount + 1 end
end
check(welcomeCount == 1, "welcome message printed exactly once")

-- 2. Single slash command opens options
SlashCmdList["BetterGearScore"]("")
check(optionsPanelOpened > 0, "/bgs opens the options panel")

-- 3. Item parsing regressions
local stats = BetterGearScore.ItemParser:ParseItemStats(chestLink)
check(stats.SPIRIT == 18 and stats.HEALING == 42 and stats.MP5 == 7, "chest stats parsed")
local gstats = BetterGearScore.ItemParser:ParseItemStats(gemChestLink)
check(gstats.EMPTY_SOCKETS == 2, "empty sockets detected")
check(BetterGearScore.ItemParser:GetEnchantId(enchantedLink) == 2564, "enchant id parsed")
check(BetterGearScore.ItemParser:CountMissingEnchants("player") == 2, "missing enchants counted")
check(BetterGearScore.LegacyGearScore:GetPlayerScore() == 228, "legacy GS total")
check(BetterGearScore.TalentDetector:GetDetectedProfile() == "WARRIOR_TANK", "warrior prot detected")

-- 4. Stat cap tapering
local hitStats = BetterGearScore.ItemParser:ParseItemStats(hitRingLink)
check(hitStats.HIT == 20, "hit ring parsed")

combatRatingBonus[6] = 5.0  -- melee hit, well below 9% cap
BetterGearScore.StatCaps:InvalidateCache()
check(BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT") == 1, "below cap: full hit weight")
local uncappedScore = BetterGearScore.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, true)

combatRatingBonus[6] = 12.0  -- past the 9% cap
BetterGearScore.StatCaps:InvalidateCache()
check(BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT") == 0.15, "past cap: hit weight floored")
local cappedScore = BetterGearScore.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, true)
check(cappedScore < uncappedScore * 0.2, "capped hit item scores far lower ("
    .. string.format("%.1f vs %.1f", cappedScore, uncappedScore) .. ")")

local uncappedForOthers = BetterGearScore.Calculator:CalculateWeightedScore(hitStats, "WARRIOR_DPS", nil, nil, false)
check(math.abs(uncappedForOthers - uncappedScore) < 0.001, "caps not applied when scoring other players")

combatRatingBonus[6] = 8.5  -- inside the 1% taper window
BetterGearScore.StatCaps:InvalidateCache()
local taperMult = BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "HIT")
check(taperMult > 0.15 and taperMult < 1, "taper window interpolates (" .. string.format("%.2f", taperMult) .. ")")

combatRatingBonus[8] = 10.0  -- spell hit below 16% cap
BetterGearScore.StatCaps:InvalidateCache()
check(BetterGearScore.StatCaps:GetWeightMultiplier("MAGE_DPS", "HIT") == 1, "caster uses spell hit cap")

defenseBase, defenseMod = 350, 145  -- 495 defense, past 490
BetterGearScore.StatCaps:InvalidateCache()
check(BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_TANK", "DEFENSE") == 0.5, "defense floored at 0.5 past 490")
check(BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_DPS", "DEFENSE") == 1, "defense cap only applies to tanks")

expertiseValue = 30  -- past 26 dodge cap
BetterGearScore.StatCaps:InvalidateCache()
check(BetterGearScore.StatCaps:GetWeightMultiplier("ROGUE_DPS", "EXPERTISE") == 0.15, "dps expertise floored past dodge cap")
check(BetterGearScore.StatCaps:GetWeightMultiplier("WARRIOR_TANK", "EXPERTISE") == 1, "tank expertise not tapered")

-- reset ratings for remaining tests
combatRatingBonus = {}
defenseBase, defenseMod = 350, 0
expertiseValue = 0
BetterGearScore.StatCaps:InvalidateCache()
BetterGearScore:InvalidateCaches()

-- 5. CONSISTENCY INVARIANT: displayed/shared scores are never cap-adjusted.
-- The same gear must produce the same number for everyone, regardless of
-- the local player's rating state.
BetterGearScore:InvalidateCaches()
local scoreBefore = BetterGearScore.Calculator:GetPlayerBetterGearScore().totalWeightedScore
local commsBefore = BetterGearScore.Comms:BuildScoreMessage()

combatRatingBonus[6] = 12.0  -- now hit-capped
BetterGearScore.StatCaps:InvalidateCache()
BetterGearScore:InvalidateCaches()
local scoreAfter = BetterGearScore.Calculator:GetPlayerBetterGearScore().totalWeightedScore
local commsAfter = BetterGearScore.Comms:BuildScoreMessage()

check(math.abs(scoreBefore - scoreAfter) < 0.001, "total score unchanged by player's cap state")
check(commsBefore == commsAfter, "broadcast score unchanged by player's cap state")

local rows = BetterGearScore.Tooltip:BuildStatContributionRows(hitStats, "WARRIOR_DPS")
check(#rows == 1 and math.abs(rows[1].roleWeight - 1.0) < 0.001,
    "breakdown shows cap-neutral weights matching the score")

local cappedNames = BetterGearScore.StatCaps:GetCappedStatNames(hitStats, "WARRIOR_DPS")
check(#cappedNames == 1 and cappedNames[1] == "Hit Rating", "capped stat names listed for advisory note")

-- The personal upgrade comparison IS cap-aware (advice, not a score)
local cappedDelta = BetterGearScore.Tooltip:GetUpgradeComparison(hitRingLink, "WARRIOR_DPS").delta
combatRatingBonus = {}
BetterGearScore.StatCaps:InvalidateCache()
local uncappedDelta = BetterGearScore.Tooltip:GetUpgradeComparison(hitRingLink, "WARRIOR_DPS").delta
check(cappedDelta < uncappedDelta, "upgrade comparison discounts capped hit ("
    .. string.format("%.1f vs %.1f", cappedDelta, uncappedDelta) .. ")")
BetterGearScore:InvalidateCaches()

-- 6. Profile override still works through the Profiles API (dropdown path)
BetterGearScore.Profiles:SetSelectedProfile("MAGE_DPS")
check(BetterGearScore.Profiles:GetSelectedProfile() == "MAGE_DPS", "manual profile via dropdown API")
BetterGearScore.Profiles:UseAutomaticProfileDetection()
check(BetterGearScore.Profiles:GetSelectedProfile() == "WARRIOR_TANK", "auto detection restored")

-- 7. Comms roundtrip
local message = BetterGearScore.Comms:BuildScoreMessage()
check(string.match(message, "^S:1:") ~= nil, "score message built")
BetterGearScore.Comms:OnChatMsgAddon("BGScore", message, "PARTY", "Alice-Realm")
local aliceEntry = BetterGearScore.PlayerCache:Get("Alice")
check(aliceEntry ~= nil and aliceEntry.source == "comms", "comms score cached")

-- 8. Inspect queue (silent)
TEST_UNITS.target = { name = "Bob", guid = "guid-bob", isPlayer = true, class = "MAGE" }
notifyInspectCalls = 0
check(BetterGearScore.Inspect:QueueUnitInspect("target"), "inspect queued")
check(notifyInspectCalls == 1, "NotifyInspect called once")
BetterGearScore.Inspect:OnInspectReady("guid-bob")
local bobEntry = BetterGearScore.PlayerCache:Get("Bob")
check(bobEntry ~= nil and bobEntry.source == "inspect" and bobEntry.profileKey == "MAGE_DPS", "inspect cached with talent profile")
check(BetterGearScore.Inspect:QueueUnitInspect("target") == false, "re-inspect blocked by cooldown")
check(BetterGearScore.Inspect:QueueUnitInspect("player") == false, "self-inspect is a no-op")

-- 9. Unit tooltip
local fakeUnitTip = {
    addedLines = {},
    GetUnit = function() return "Bob", "target" end,
    AddLine = function(self, text) self.addedLines[#self.addedLines + 1] = text or "" end,
    AddDoubleLine = function(self, l, r) self.addedLines[#self.addedLines + 1] = (l or "") .. " | " .. (r or "") end,
    Show = function() end,
}
BetterGearScore.UnitTooltip:AddScoreToTooltip(fakeUnitTip)
local sawScoreLine = false
for _, line in ipairs(fakeUnitTip.addedLines) do
    if string.find(line, "BetterGearScore") then sawScoreLine = true end
end
check(sawScoreLine, "unit tooltip shows cached score")

-- 10. Inspect window integration
InspectFrame = CreateFrame("Frame", "InspectFrame")
InspectFrame.unit = "target"
InspectPaperDollFrame = CreateFrame("Frame", "InspectPaperDollFrame")
BetterGearScore.InspectPaneUI:Initialize()
InspectFrame:Show()
BetterGearScore.InspectPaneUI:Update()
check(BetterGearScore.InspectPaneUI.frame ~= nil, "inspect pane frame created")
check(BetterGearScore.InspectPaneUI.scoreText.text ~= nil
    and string.find(BetterGearScore.InspectPaneUI.scoreText.text, "|c") ~= nil, "inspect pane shows Bob's score")
BetterGearScore.InspectPaneUI:OnScoreUpdated("guid-bob")
check(BetterGearScore.InspectPaneUI.frame:IsShown(), "inspect pane visible after score update")

-- 11. Character pane is the click hub
local paneFrame = BetterGearScore.CharacterPaneUI.frame
check(paneFrame ~= nil and paneFrame.script_OnMouseUp ~= nil, "character pane has click handler")
paneFrame.script_OnMouseUp(paneFrame, "LeftButton")
check(BetterGearScore.UI:IsVisible(), "left-click opens gear window")
paneFrame.script_OnMouseUp(paneFrame, "LeftButton")
check(not BetterGearScore.UI:IsVisible(), "left-click again closes gear window")
paneFrame.script_OnMouseUp(paneFrame, "RightButton")
check(BetterGearScore.GroupFrame:IsVisible(), "right-click opens group window")
paneFrame.script_OnMouseUp(paneFrame, "RightButton")
check(not BetterGearScore.GroupFrame:IsVisible(), "right-click again closes group window")

-- 12. Group window auto-requests scores on open
inGroup = true
BetterGearScore.Comms.lastRequest = 0
sentMessages = {}
BetterGearScore.GroupFrame:Show()
local sawRequest = false
for _, sent in ipairs(sentMessages) do
    if sent.message == "R:1" then sawRequest = true end
end
check(sawRequest, "group window open requests scores automatically")
BetterGearScore.GroupFrame:Hide()
inGroup = false

-- 13. Upgrade comparison still works (player context with caps)
local profileKey = BetterGearScore.Profiles:GetSelectedProfile()
local equippedCmp = BetterGearScore.Tooltip:GetUpgradeComparison(chestLink, profileKey)
check(equippedCmp and equippedCmp.isEquipped, "equipped item recognized")
local upgradeCmp = BetterGearScore.Tooltip:GetUpgradeComparison(betterChestLink, profileKey)
check(upgradeCmp and (upgradeCmp.delta or 0) > 0, "tanky chest is an upgrade for warrior tank")

-- 14. Feral druid gear-based detection regression
playerClass = "DRUID"
talentTabs = {
    { name = "Balance", points = 0 },
    { name = "Feral Combat", points = 41 },
    { name = "Restoration", points = 5 },
}
BetterGearScore:InvalidateCaches()
equipped.ChestSlot = betterChestLink
BetterGearScore.ItemParser.statsCache = {}
check(BetterGearScore.TalentDetector:GetDetectedProfile() == "DRUID_TANK", "tanky gear flips feral to DRUID_TANK")
equipped.ChestSlot = chestLink
BetterGearScore:InvalidateCaches()

realPrint(failures == 0 and "ALL TESTS PASSED" or (failures .. " TEST(S) FAILED"))
os.exit(failures == 0 and 0 or 1)
