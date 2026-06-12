-- Commands.lua

local Commands = BetterGearScore.Commands

function Commands:RegisterCommands()
    SLASH_BetterGearScore1 = "/bettergearscore"
    SLASH_BetterGearScore2 = "/bgs"
    SLASH_BetterGearScore3 = "/gs"

    SlashCmdList["BetterGearScore"] = function(msg)
        BetterGearScore.Commands:HandleCommand(msg)
    end
end

function Commands:HandleCommand(msg)
    msg = msg or ""

    -- Only the command word is lowercased; arguments keep their original
    -- casing so item links (which contain |H escapes) survive intact.
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    if command == "" or command == "help" then
        self:PrintHelp()
    elseif command == "score" then
        self:PrintScore()
    elseif command == "show" then
        BetterGearScore.UI:Show()
    elseif command == "hide" then
        BetterGearScore.UI:Hide()
    elseif command == "toggle" then
        BetterGearScore.UI:Toggle()
    elseif command == "detect" then
        BetterGearScore.TalentDetector:PrintDetectedProfile()
    elseif command == "profiles" then
        BetterGearScore.Profiles:PrintAvailableProfiles()
    elseif command == "profile" then
        self:HandleProfileCommand(rest)
    elseif command == "target" or command == "inspect" then
        BetterGearScore.Inspect:RequestInspect("target")
    elseif command == "group" then
        BetterGearScore.GroupFrame:Toggle()
    elseif command == "config" or command == "options" then
        BetterGearScore.Options:OpenPanel()
    elseif command == "sync" then
        self:HandleSyncCommand()
    elseif command == "scan" then
        self:HandleScanCommand(rest)
    else
        self:PrintHelp()
    end
end

function Commands:HandleSyncCommand()
    if not BetterGearScore.Comms:GetChannel() then
        print("|cffff0000BetterGearScore:|r You are not in a group.")
        return
    end

    local sent = BetterGearScore.Comms:BroadcastScore(true)
    BetterGearScore.Comms:RequestScores()

    if sent then
        print("|cff00ff00BetterGearScore:|r Score broadcast to your group; requested theirs in return.")
    else
        print("|cffff0000BetterGearScore:|r Score sharing is disabled in the options (/bgs config).")
    end
end

function Commands:PrintScore()
    local data = BetterGearScore.Calculator:GetPlayerBetterGearScore()
    local coloredScore = BetterGearScore.Calculator:ColorizeScore(
        data.totalWeightedScore or 0,
        data.totalMaxBudgetScore or 0
    )

    local line = "|cff00ff00BetterGearScore:|r " .. coloredScore
        .. "  |cff888888|||r  Budget: " .. math.floor(data.totalRawScore or 0)
        .. "  |cff888888|||r  Profile: " .. (data.profileName or "Unknown")

    if BetterGearScore.Options:Get("showLegacyGearScore") then
        local legacyScore = BetterGearScore.LegacyGearScore:GetPlayerScore()

        if legacyScore > 0 then
            line = line .. "  |cff888888|||r  Legacy GS: " .. legacyScore
        end
    end

    print(line)
end

function Commands:HandleProfileCommand(profileKey)
    profileKey = profileKey or ""
    profileKey = string.gsub(profileKey, "^%s+", "")
    profileKey = string.gsub(profileKey, "%s+$", "")
    profileKey = string.lower(profileKey)

    if profileKey == "auto" then
        BetterGearScore.Profiles:UseAutomaticProfileDetection()

        local detectedProfile = BetterGearScore.Profiles:GetSelectedProfile()

        print("|cff00ff00BetterGearScore profile detection set to automatic:|r "
            .. BetterGearScore.Profiles:GetProfileDisplayName(detectedProfile))
        return
    end

    if profileKey == "" then
        local selectedProfile = BetterGearScore.Profiles:GetSelectedProfile()
        print("|cff00ff00Current BetterGearScore profile:|r "
            .. BetterGearScore.Profiles:GetProfileDisplayName(selectedProfile)
            .. " |cff888888("
            .. string.lower(selectedProfile)
            .. ")|r")
        print("Use |cffffff00/bgs profile warrior_tank|r to change profile.")
        return
    end

    local normalizedProfile = BetterGearScore.Profiles:NormalizeProfileKey(profileKey)

    if BetterGearScore.Profiles:SetSelectedProfile(normalizedProfile) then
        print("|cff00ff00BetterGearScore profile set to:|r "
            .. BetterGearScore.Profiles:GetProfileDisplayName(normalizedProfile))
    else
        print("|cffff0000Unknown BetterGearScore profile:|r " .. profileKey)
        print("Use |cffffff00/bgs profiles|r to list available profiles.")
    end
end

function Commands:HandleScanCommand(itemLink)
    itemLink = itemLink or ""

    if not string.find(itemLink, "|Hitem:") then
        print("|cff00ff00BetterGearScore:|r Shift-click an item into the command, e.g. |cffffff00/bgs scan [Item]|r")
        return
    end

    local itemName = BetterGearScore.ItemParser:GetItemName(itemLink)
    local stats = BetterGearScore.ItemParser:ParseItemStats(itemLink)
    local profileKey = BetterGearScore.Profiles:GetSelectedProfile()

    print("|cff00ff00BetterGearScore scan:|r " .. itemName)

    local sortedStats = {}

    for statType, value in pairs(stats) do
        sortedStats[#sortedStats + 1] = { statType = statType, value = value }
    end

    table.sort(sortedStats, function(a, b)
        return a.statType < b.statType
    end)

    if #sortedStats == 0 then
        print("|cff888888No stats detected (item data may not be cached yet).|r")
        return
    end

    for _, entry in ipairs(sortedStats) do
        local displayName = BetterGearScore.Tooltip.STAT_DISPLAY_NAMES[entry.statType] or entry.statType
        print("  " .. displayName .. ": " .. string.format("%.1f", entry.value))
    end

    local statBudgetScore = BetterGearScore.Calculator:CalculateRawStatBudget(stats)
    local weaponBudgetScore = BetterGearScore.Calculator:CalculateWeaponBudgetScore(stats)
    local weightedScore = BetterGearScore.Calculator:CalculateWeightedScore(stats, profileKey, nil, itemLink)

    print("Budget Score: " .. string.format("%.1f", statBudgetScore + weaponBudgetScore)
        .. "  |cff888888|||r  Weighted (" .. BetterGearScore.Profiles:GetProfileDisplayName(profileKey) .. "): "
        .. string.format("%.1f", weightedScore))
end

function Commands:PrintHelp()
    print("|cff00ff00BetterGearScore Commands:|r")
    print("/bgs score - Print your current gear score")
    print("/bgs show | hide | toggle - Open or close the gear score window")
    print("/bgs group - Open the party/raid gear score overview")
    print("/bgs target - Score your currently targeted player (inspect range)")
    print("/bgs sync - Broadcast your score to the group and request theirs")
    print("/bgs config - Open the options panel")
    print("/bgs detect - Show the talent-detected role profile")
    print("/bgs profiles - List all available scoring profiles")
    print("/bgs profile - Show current role profile")
    print("/bgs profile warrior_tank - Set role profile manually")
    print("/bgs profile auto - Use automatic talent detection")
    print("/bgs scan [item] - Print detected stats for a linked item")
    print("")
    print("|cff00ff00Gear score is also displayed in your character pane and on player tooltips.|r")
end

Commands:RegisterCommands()
