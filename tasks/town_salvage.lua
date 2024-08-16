local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local gui = require "gui"

local task = {
    name = "Town Salvage",
    shouldExecute = function()
        return utils.player_in_zone("Scos_Cerrigar") 
        and get_local_player():get_item_count() >= 25
        and settings.loot_modes == gui.loot_modes_enum.SALVAGE  -- Correct reference to the current loot mode setting
    end,
    Execute = function(self)
        local blacksmith = utils.get_blacksmith()
        if blacksmith then
            console.print("Setting target to BLACKSMITH: " .. blacksmith:get_skin_name())
            explorer:set_custom_target(blacksmith)
            explorer:move_to_target()

            -- Check if the player is close enough to interact with the blacksmith
            if utils.distance_to(blacksmith) < 2 then
                console.print("Player is close enough to the blacksmith. Interacting with the blacksmith.")
                interact_vendor(blacksmith)
                loot_manager.salvage_all_items()
            end

            return true
        else
            console.print("No blacksmith found")
            explorer:set_custom_target(enums.positions.blacksmith_position)
            explorer:move_to_target()
            return false
        end 
    end
}

return task
