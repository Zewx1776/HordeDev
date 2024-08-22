local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local open_chests_task = {
    name = "Open Chests",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") and utils.get_stash()
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()
        local aether_bomb = utils.get_aether_actor()
        local particles = actors_manager:get_all_actors()
        if aether_bomb then
            console.print("Aether bomb found, moving to collect it")
            if utils.distance_to(aether_bomb) > 2 then
                pathfinder.request_move(aether_bomb:get_position())
            else
                interact_object(aether_bomb)
            end
            return
        end

        local function open_chest(chest)
            if chest then
                console.print(chest:get_skin_name() .. " found, interacting")
                if utils.distance_to(chest) > 2 then
                    console.print("Moving to chest:", chest:get_skin_name())
                    pathfinder.request_move(chest:get_position())
                    return false
                else
                    local try_open_chest = interact_object(chest)
                    console.print("Chest interaction result: " .. tostring(try_open_chest))
                    
                    -- Use tracker.check_time to wait for visual effects
                    if tracker.check_time("chest_vfx_wait", 0.2) then
                        -- Check for visual effects indicating successful chest opening
                        local actors = actors_manager:get_all_actors()
                        for _, actor in pairs(actors) do
                            local name = actor:get_skin_name()
                            if name == "vfx_resplendentChest_coins" or name == "vfx_resplendentChest_lightRays" or name == "Hell_Prop_Chest_Rare_81_Client_Dyn" then
                                console.print("Chest opened successfully: " .. name)
                                return true
                            end
                        end
                        
                        console.print("No visual effects found, chest opening may have failed")
                        return false
                    else
                        console.print("Waiting for visual effects...")
                        return false
                    end
                end
            end
            return false
        end

        local function handle_chest_opening(chest_type)
            local chest_id = enums.chest_types[chest_type]
            local chest = utils.get_chest(chest_id)
            
            if chest then
                if utils.distance_to(chest) > 2 then
                    if tracker.check_time("request_move_to_chest", 0.15) then
                        console.print(string.format("Moving to %s chest", chest_type))
                        pathfinder.request_move(chest:get_position())
                    end
                    return true
                else
                    if tracker.check_time("chest_opening_time", 1) then
                        local success = open_chest(chest)
                        console.print(string.format("Attempting to open chest type: %s (ID: %s)", chest_type, chest_id))
                        if success then
                            console.print("Chest opened successfully.")
                            return true
                        else
                            console.print("Failed to open chest.")
                            return false
                        end
                    end
                end
            else
                console.print("Chest not found")
                return false
            end
        end

        if settings.always_open_ga_chest and utils.get_chest(enums.chest_types["GREATER_AFFIX"]) == nil then
            local ga_success = handle_chest_opening("GREATER_AFFIX")
            if ga_success then
                console.print("GA chest opened successfully")
            else
                console.print("Failed to open GA chest or moving towards it")
            end
            return 
        end

        local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
        local selected_chest_type = chest_type_map[settings.selected_chest_type + 1]

        if selected_chest_type ~= "GOLD" then
            while handle_chest_opening(selected_chest_type) do 
                tracker.check_time("wait_between_openings", 0.15) end
        else
            while handle_chest_opening("GOLD") do 
                tracker.check_time("wait_between_openings", 0.15) end
        end
    end
}

return open_chests_task