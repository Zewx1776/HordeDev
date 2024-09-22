local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"
local open_chests_task = require "tasks.open_chests"
local explorer = require "core.explorer"

-- Reference the position from horde.lua
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)

exit_horde_task = {
    name = "Exit Horde",
    delay_start_time = nil,
    moved_to_center = false,
    
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
            and utils.get_stash() ~= nil
            and (tracker.gold_chest_opened or not utils.get_chest(enums.chest_types["GOLD"])) 
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()

        -- First, move to the center if not already there
        if not exit_horde_task.moved_to_center then
            if utils.distance_to(horde_boss_room_position) > 2 then
                console.print("Moving to boss room position.")
                explorer:set_custom_target(horde_boss_room_position)
                explorer:move_to_target()
                return
            else
                exit_horde_task.moved_to_center = true
                console.print("Reached Central Room Postion.")
            end
        end

        -- Check for the presence of the gold chest
        local gold_chest = utils.get_chest(enums.chest_types["GOLD"])
        if gold_chest then
            console.print("Gold chest found. Back to open_chest task")
            tracker.gold_chest_opened = false
            return
        end

        -- Proceed with exit procedure
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
            console.print("Starting 5-second timer before exiting Horde")
            tracker.exit_horde_start_time = current_time
        end
       
        local elapsed_time = current_time - tracker.exit_horde_start_time
        if elapsed_time >= 10 then
            console.print("10-second timer completed. Resetting all dungeons")
            reset_all_dungeons()
            tracker.clear_runtime_timers()
            tracker.victory_lap = false
            tracker.victory_positions = nil
            tracker.locked_door_found = false
            tracker.exit_horde_start_time = nil
            tracker.exit_horde_completion_time = current_time
            tracker.horde_opened = false
            tracker.start_dungeon_time = nil
            tracker.boss_killed = false
            exit_horde_task.delay_start_time = nil  -- Reset the delay timer
            exit_horde_task.moved_to_center = false  -- Reset the moved_to_center flag
        else
            console.print(string.format("Waiting to exit Horde. Time remaining: %.2f seconds", 10 - elapsed_time))
        end
    end
}

return exit_horde_task