-- Commands.lua
-- The addon configures itself and every feature has a UI entry point, so the
-- only slash command opens the options panel (display/style settings).

local Commands = GSPlus.Commands

function Commands:RegisterCommands()
    SLASH_GSPlus1 = "/gsplus"
    SLASH_GSPlus2 = "/bgs"
    SLASH_GSPlus3 = "/gs"

    SlashCmdList["GSPlus"] = function()
        GSPlus.Options:OpenPanel()
    end
end

Commands:RegisterCommands()
