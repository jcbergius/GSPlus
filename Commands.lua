-- Commands.lua
-- The addon configures itself and every feature has a UI entry point, so the
-- only slash command opens the options panel (display/style settings).

local Commands = BetterGearScore.Commands

function Commands:RegisterCommands()
    SLASH_BetterGearScore1 = "/bettergearscore"
    SLASH_BetterGearScore2 = "/bgs"
    SLASH_BetterGearScore3 = "/gs"

    SlashCmdList["BetterGearScore"] = function()
        BetterGearScore.Options:OpenPanel()
    end
end

Commands:RegisterCommands()
