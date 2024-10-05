local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local open_chests_task = require "tasks.open_chests"

local function reset_chest_flags()
    open_chests_task:reset()
    tracker.finished_looting_start_time = nil
    console.print("Chest flags reset for new dungeon run")
end

local function use_dungeon_sigil()
    if tracker.horde_opened then
        console.print("Horde already opened this session. Skipping.")
        return false
    end

    local local_player = get_local_player()
    local inventory = local_player:get_consumable_items()
    for _, item in pairs(inventory) do
        local item_info = utils.get_consumable_info(item)
        if item_info and item_info.name == "S05_DungeonSigil_BSK" then
            console.print("Found Dungeon Sigil. Attempting to use it.")
            local success, error = pcall(use_item, item)
            if success then
                console.print("Successfully used Dungeon Sigil.")
                tracker.first_run = true
                tracker.sigil_use_time = get_time_since_inject()
                -- Initialize the confirmation timer
                tracker.confirm_sigil_time = get_time_since_inject() -- Record the current time
                return true
            else
                console.print("Failed to use Dungeon Sigil: " .. tostring(error))
                return false
            end
        end
    end
    console.print("Dungeon Sigil not found in inventory.")
    return false
end

local start_dungeon_task = {
    name = "Start Dungeon",
    shouldExecute = function()
        return utils.player_in_zone("Kehj_Caldeum") 
            and not tracker.horde_opened         
    end,

    Execute = function()
        local current_time = get_time_since_inject()
        if not tracker.start_dungeon_time then
            console.print("Stay a while and listen")
            tracker.start_dungeon_time = current_time
        end

        local elapsed_time = current_time - tracker.start_dungeon_time

        if elapsed_time >= 5 and not tracker.sigil_used then
            console.print("Time to farm! Attempting to use Dungeon Sigil")
            -- Removed reset_chest_flags() from here
            if use_dungeon_sigil() then
                tracker.sigil_used = true -- Mark that we've used the sigil
                tracker.confirm_sigil_time = current_time -- Record the current time for confirmation
            end
        elseif tracker.sigil_used and tracker.confirm_sigil_time then
            local time_since_sigil = current_time - tracker.confirm_sigil_time
            if time_since_sigil >= 5 then
                console.print("Confirming sigil notification after 5 seconds.")
                utility.confirm_sigil_notification()
                reset_chest_flags() -- Reset chest flags after confirmation
                tracker.horde_opened = true -- Now set horde_opened to end the task
                tracker.confirm_sigil_time = nil -- Reset the confirmation timer
                console.print("Horde opened and chest flags have been reset.")
            else
                console.print(string.format("Waiting to confirm sigil notification... %.2f seconds remaining.", 5 - time_since_sigil))
            end
        else
            console.print(string.format("Waiting before using Dungeon Sigil... %.2f seconds remaining.", 5 - elapsed_time))
        end
    end
}

return start_dungeon_task