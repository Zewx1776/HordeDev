local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local exit_horde_task = {
    name = "Exit Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") and utils.player_on_quest(2023962) and tracker.gold_chest_opened == true
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        if not tracker.exit_horde_start_time then
            tracker.gold_chest_opened = true
            console.print("Starting 10-second timer before exiting Horde")
            tracker.exit_horde_start_time = current_time
        end
       
        local elapsed_time = current_time - tracker.exit_horde_start_time
        if elapsed_time >= 10 then
            console.print("10-second timer completed. Resetting all dungeons")
            reset_all_dungeons()
            tracker.exit_horde_start_time = nil
            tracker.exit_horde_completion_time = current_time  -- Neue Zeile
            tracker.horde_opened = false
            tracker.gold_chest_opened = false
            tracker.start_dungeon_time = nil
        else
            console.print(string.format("Waiting to exit Horde. Time remaining: %.2f seconds", 10 - elapsed_time))
        end
    end
}

return exit_horde_task