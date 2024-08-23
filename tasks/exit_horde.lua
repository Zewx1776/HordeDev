
local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

exit_horde_task = {
    name = "Exit Horde",
    delay_start_time = nil,
    
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
            and utils.get_stash() ~= nil
            and tracker.finished_chest_looting
            and tracker.gold_chest_successfully_opened
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        if not exit_horde_task.delay_start_time then
            exit_horde_task.delay_start_time = current_time
            console.print("Starting 5-second delay before initiating exit procedure")
            return
        end

        local delay_elapsed_time = current_time - exit_horde_task.delay_start_time
        if delay_elapsed_time < 5 then
            console.print(string.format("Waiting to start exit procedure. Time remaining: %.2f seconds", 5 - delay_elapsed_time))
            return
        end

        if not tracker.exit_horde_start_time then
            tracker.finished_chest_looting = true
            console.print("Starting 5-second timer before exiting Horde")
            tracker.exit_horde_start_time = current_time
        end
       
        local elapsed_time = current_time - tracker.exit_horde_start_time
        if elapsed_time >= 10 then
            console.print("10-second timer completed. Resetting all dungeons")
            reset_all_dungeons()
            tracker.exit_horde_start_time = nil
            tracker.exit_horde_completion_time = current_time
            tracker.horde_opened = false
            tracker.finished_chest_looting = false
            tracker.gold_chest_opened = false
            tracker.start_dungeon_time = nil
            tracker.gold_chest_successfully_opened = false
            wave_start_time = 0
            exit_horde_task.delay_start_time = nil  -- Reset the delay timer
        else
            console.print(string.format("Waiting to exit Horde. Time remaining: %.2f seconds", 10 - elapsed_time))
        end
    end
}

return exit_horde_task
