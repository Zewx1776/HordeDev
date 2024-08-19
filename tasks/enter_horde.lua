local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"

local function enter_horde()
    if not tracker.horde_opened then
        console.print("Horde not opened this session. Skipping.")
        return false
    end

    local portal = utils.get_horde_portal()
    if portal then
        explorer:set_custom_target(portal:get_position())
        explorer:move_to_target()
        -- Check if the player is close enough to interact with the portal
        if utils.distance_to(portal) < 2 then
            console.print("Player is close enough to the portal. Interacting with the portal.")
            interact_object(portal)
        end
    end
end

local enter_horde_task = {
    name = "Enter Horde",
    shouldExecute = function()
        return not utils.player_in_zone("S05_BSK_Prototype02") and tracker.horde_opened
    end,
    Execute = function()
        enter_horde()
    end
}

return enter_horde_task