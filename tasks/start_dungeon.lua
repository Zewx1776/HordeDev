local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"

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
        return not utils.player_in_zone("S05_BSK_Prototype02") and not tracker.horde_opened and (tracker.finished_chest_looting or not tracker.first_run)
    end,
    Execute = function()
        use_dungeon_sigil()
    end
}

return start_dungeon_task