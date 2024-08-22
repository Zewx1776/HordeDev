local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local settings = require "core.settings"
local gui = require "gui"
local tracker = require "core.tracker"

local waypoints_enum = {
    CERRIGAR = 0x76D58,
}

local task = {
    name = "Town Salvage",
    interact_time = 0,
    reset_salvage_time = 0, -- Add this variable to track the reset time
    portal_interact_time = 0,

    shouldExecute = function()
        return (get_local_player():get_item_count() >= 25 and settings.loot_modes == gui.loot_modes_enum.SALVAGE)
            or tracker.has_salvaged
    end,
    Execute = function(self)
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
                    explorer:set_custom_target(blacksmith:get_position())  -- Pass the position, not the object
                    explorer:move_to_target()

                    if utils.distance_to(blacksmith) < 2 then
                        if self.interact_time == 0 then
                            console.print("Starting interaction timer.")
                            self.interact_time = current_time
                            return true
                        elseif current_time - self.interact_time >= 1 and current_time - self.interact_time < 5 then
                            if current_time - self.interact_time < 2 then  -- Only interact once
                                console.print("Player is close enough to the blacksmith. Interacting with the blacksmith.")
                                interact_vendor(blacksmith)
                            end
                            console.print(string.format("Waiting... Time elapsed: %.2f seconds", current_time - self.interact_time))
                            return true
                        elseif current_time - self.interact_time >= 5 then
                            console.print("5 seconds have passed. Salvaging items.")
                            loot_manager.salvage_all_items()
                            tracker.has_salvaged = true
                            self.interact_time = 0
                            self.reset_salvage_time = current_time  -- Start the reset timer
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
                        if self.portal_interact_time == 0 then
                            console.print("Starting portal interaction timer.")
                            self.portal_interact_time = current_time
                            return true
                        elseif current_time - self.portal_interact_time >= 1 and current_time - self.portal_interact_time < 5 then
                            if current_time - self.portal_interact_time < 2 then  -- Only interact once
                                console.print("Interacting with the portal.")
                                interact_object(portal)
                                tracker.has_salvaged = false
                            end
                            console.print(string.format("Waiting at portal... Time elapsed: %.2f seconds", current_time - self.portal_interact_time))
                            return true
                        elseif current_time - self.portal_interact_time >= 2 then
                            console.print("5 seconds have passed since portal interaction.")
                            --tracker.has_salvaged = false
                            self.portal_interact_time = 0
                            console.print(string.format("Time passed since salvage: %.2f seconds", current_time - self.reset_salvage_time))
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
}

return task