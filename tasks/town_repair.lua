local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local gui = require "gui"

local task = {
    name = "Town Repair",
    shouldExecute = function()
        return utils.player_in_zone("Scos_Cerrigar") 
            and auto_play.get_objective() == objective.repair
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
                loot_manager.interact_with_vendor_and_repair_all(blacksmith)
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