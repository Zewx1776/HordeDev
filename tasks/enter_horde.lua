local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

local function enter_horde()
    local portal = utils.get_horde_portal()
    if portal then
        console.print("Check")
        explorer:clear_path_and_target()
        explorer:set_custom_target(portal:get_position())
        explorer:move_to_target()
        if utils.distance_to(portal) < 2 then
            console.print("Player is close enough to the portal. Interacting with the portal.")
            interact_object(portal)
        end
    else
        console.print("Portal Not found!")
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