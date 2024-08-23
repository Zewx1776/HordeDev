local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local gui = require "gui"
local tracker = require "core.tracker"

local waypoints_enum = {
    CERRIGAR = 0x76D58,
}

-- Move timer variables outside of the task table
local interact_time = 0
local reset_salvage_time = 0
local portal_interact_time = 0

local function Execute()
    local current_time = get_time_since_inject()

    local success, error = pcall(function()
        if not utils.player_in_zone("Scos_Cerrigar") and get_local_player():get_item_count() >= 1 then
            explorer:clear_path_and_target()
            teleport_to_waypoint(waypoints_enum.CERRIGAR)
            return true  -- Exit the function and wait for next tick
        end

        -- From this point on, we're guaranteed to be in Cerrigar
        if not tracker.has_salvaged then
            local blacksmith = utils.get_blacksmith()
            if blacksmith then
                console.print("Setting target to BLACKSMITH: " .. blacksmith:get_skin_name())
                explorer:set_custom_target(blacksmith)
                explorer:move_to_target()

                if utils.distance_to(blacksmith) < 2 then
                    if interact_time == 0 then
                        console.print("Starting interaction timer.")
                        interact_time = current_time
                        return true
                    elseif current_time - interact_time >= 1 and current_time - interact_time < 5 then
                        if current_time - interact_time < 2 then  -- Only interact once
                            console.print("Player is close enough to the blacksmith. Interacting with the blacksmith.")
                            interact_vendor(blacksmith)
                        end
                        console.print(string.format("Waiting... Time elapsed: %.2f seconds", current_time - interact_time))
                        return true
                    elseif current_time - interact_time >= 5 then
                        console.print("5 seconds have passed. Salvaging items.")
                        loot_manager.salvage_all_items()
                        tracker.has_salvaged = true
                        interact_time = 0
                        reset_salvage_time = current_time  -- Start the reset timer
                    end
                end
            else
                console.print("No blacksmith found")
                explorer:set_custom_target(enums.positions.blacksmith_position)
                explorer:move_to_target()
            end
        else
            console.print("Returning to portal (currently set to blacksmith position)")
            explorer:set_custom_target(enums.positions.portal_position)
            explorer:move_to_target()

            if enums.positions.portal_position and utils.distance_to(enums.positions.portal_position) < 5 then
                local portal = utils.get_town_portal()
                if portal then
                    if portal_interact_time == 0 then
                        console.print("Starting portal interaction timer.")
                        portal_interact_time = current_time
                        return true
                    elseif current_time - portal_interact_time >= 1 and current_time - portal_interact_time < 5 then
                        if current_time - portal_interact_time < 2 then  -- Only interact once
                            console.print("Interacting with the portal.")
                            interact_object(portal)
                            tracker.has_salvaged = false
                        end
                        console.print(string.format("Waiting at portal... Time elapsed: %.2f seconds", current_time - portal_interact_time))
                        return true
                    elseif current_time - portal_interact_time >= 2 then
                        console.print("5 seconds have passed since portal interaction.")
                        portal_interact_time = 0
                        console.print(string.format("Time passed since salvage: %.2f seconds", current_time - reset_salvage_time))
                    end
                else
                    console.print("Town portal not found")
                end
            end
        end
    end)

    if not success then
        console.print("An error occurred: " .. tostring(error))
    end

    return true
end

local task = {
    name = "Town Salvage",
    shouldExecute = function()
        return (get_local_player():get_item_count() >= 25 and settings.loot_modes == gui.loot_modes_enum.SALVAGE)
            or tracker.has_salvaged
    end,
    Execute = Execute
}

return task