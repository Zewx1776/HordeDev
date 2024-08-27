local utils = require "core.utils"
local enums = require "data.enums"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

local function enter_horde()
    local portal = utils.get_horde_portal()
    if portal then
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
        return utils.player_in_zone("Kehj_Caldeum") and tracker.horde_opened
    end,
    Execute = function()
        enter_horde()
        enter_horde_task:reset()  -- Triggering the reset after entering the horde
    end,
    reset = function(self)
        tracker.finished_chest_looting = false
        tracker.ga_chest_opened = false
        tracker.selected_chest_opened = false
        tracker.gold_chest_opened = false
        console.print("Reset open_chests_task and related tracker flags")
    end
}

return enter_horde_task
