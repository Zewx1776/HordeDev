local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local gui = require "gui"

local task = {
    name = "Town Sell",
    shouldExecute = function()
        return utils.player_in_zone("Scos_Cerrigar") 
        and get_local_player():get_item_count() >= 25
        and settings.loot_modes == gui.loot_modes_enum.SELL  -- Correct reference to the current loot mode setting
    end,
    Execute = function(self)
        local jeweler_pos = enums.positions.jeweler_position
        console.print("Setting target to JEWELER position.")
        explorer:set_custom_target(jeweler_pos)
        explorer:move_to_target()

        -- Check if the player is close enough to interact with the jeweler
        if utils.distance_to(jeweler_pos) < 2 then
            console.print("Player is close enough to the jeweler. Interacting with the jeweler.")
            local jeweler = utils.get_jeweler()  -- Get the jeweler object
            if jeweler then
                loot_manager.interact_with_vendor_and_sell_all(jeweler)

                -- Check if the sell failed
                if get_local_player():get_item_count() >= 25 then
                    console.print("Sell failed, navigating to reset position.")
                    local target_position = vec3:new(-1650.6197509766, -619.59912109375, 37.8388671875)
                    explorer:set_custom_target(target_position)
                    explorer:move_to_target()
                    -- Reset the script or task as needed
                    -- Add any reset logic here
                end
            else
                console.print("No jeweler found")
            end
        end

        return true
    end
}

return task