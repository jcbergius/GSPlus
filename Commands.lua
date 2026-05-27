-- Chat command handler

GearScoreCommands = {}

-- Register slash commands
function GearScoreCommands:RegisterCommands()
    SLASH_GEARSCORE1 = "/gearscore"
    SLASH_GEARSCORE2 = "/gs"
    SlashCmdList["GEARSCORE"] = function(msg)
        GearScoreCommands:HandleCommand(msg)
    end
end

-- Handle slash commands
function GearScoreCommands:HandleCommand(msg)
    msg = string.lower(msg or "")
    
    if msg == "" or msg == "show" or msg == "ui" then
        GearScoreUI:Show()
    elseif msg == "hide" or msg == "close" then
        GearScoreUI:Hide()
    elseif msg == "toggle" then
        GearScoreUI:Toggle()
    elseif msg == "score" then
        self:PrintGearScore()
    elseif msg == "help" then
        self:PrintHelp()
    else
        self:PrintHelp()
    end
end

-- Print current gear score to chat
function GearScoreCommands:PrintGearScore()
    local gearScoreData = GearScoreCalculator:GetPlayerGearScore()
    print("|cff00ff00Gear Score:|r Weighted: " .. math.floor(gearScoreData.totalWeightedScore) .. " | Raw: " .. math.floor(gearScoreData.totalRawScore))
end

-- Print help information
function GearScoreCommands:PrintHelp()
    print("|cff00ff00Gear Score Commands:|r")
    print("/gearscore or /gs - Show help")
    print("/gs show - Open the gear score window")
    print("/gs hide - Close the gear score window")
    print("/gs toggle - Toggle the gear score window")
    print("/gs score - Print your current gear score to chat")
end

-- Initialize commands when addon loads
GearScoreCommands:RegisterCommands()
