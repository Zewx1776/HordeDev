local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"

local function reset_chest_flags()
    tracker.ga_chest_open_time = 0
    tracker.ga_chest_opened = false
    tracker.peasant_chest_open_time = 0
    tracker.peasant_chest_opening_stopped = false
    tracker.gold_chest_open_time = 0
    tracker.gold_chest_opened = false
    tracker.finished_chest_looting = false
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
                tracker.horde_opened = true
                tracker.first_run = true
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
        if elapsed_time >= 5 then
            console.print("Time to farm! Attempting to use Dungeon Sigil")
            reset_chest_flags() -- Reset chest flags at the start of the dungeon
            use_dungeon_sigil()
        else
            console.print(string.format("Waiting before using Dungeon Sigil... %.2f seconds remaining.", 5 - elapsed_time))
        end
    end
}

return start_dungeon_task