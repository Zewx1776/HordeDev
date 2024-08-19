local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local exit_horde_task = {
    name = "Exit Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") and utils.player_on_quest(2023962) and tracker.finished_chest_looting == true
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        if not tracker.exit_horde_start_time then
            tracker.exit_horde_start_time = current_time
            reset_all_dungeons()
            console.print("Starting 10-second timer before exiting Horde")
        end

        if current_time - tracker.exit_horde_start_time >= 10 then
            console.print("10-second timer completed. Resetting all dungeons")
            --reset_all_dungeons()
            -- After resetting, set finished_chest_looting back to false
            tracker.finished_chest_looting = false
            -- Reset the exit_horde_start_time
            tracker.exit_horde_start_time = nil
            tracker.reset_dg_status()
        else
            console.print(string.format("Waiting to exit Horde. Time remaining: %.2f seconds", 10 - (current_time - tracker.exit_horde_start_time)))
        end
    end
}

return exit_horde_task