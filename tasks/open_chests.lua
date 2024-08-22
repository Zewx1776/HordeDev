local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

-- Function to find the Aether Bomb actor in the game world
local function get_aether_bomb()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BurningAether" or name == "S05_Reputation_Experience_PowerUp_Actor" then
            return actor
        end
    end
    return nil  -- Return nil if no Aether Bomb actor is found
end

-- Task for opening chests in the game
local open_chests_task = {
    name = "Open Chests",  -- Name of the task

    -- Function to determine if the task should be executed
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") 
            and utils.get_stash() ~= nil 
            and not (tracker.gold_chest_opened and tracker.finished_chest_looting)
    end,
    
    -- Main function to execute the chest-opening task
    Execute = function()
        local current_time = get_time_since_inject()  -- Get the current time since the task was injected
        console.print(string.format("[TASK START] Starting 'Open Chests' task at time: %.2f seconds.", current_time))
        
        -- Log the current status and settings for debugging
        console.print(string.format("[STATUS] GA Chest Opened: %s, GA Chest Open Time: %.2f", 
                                    tostring(tracker.ga_chest_opened), tracker.ga_chest_open_time or 0))
        console.print(string.format("[SETTINGS] Always Open GA Chest: %s, Selected Chest Type: %s, Chest Opening Time Limit: %d seconds", 
                                    tostring(settings.always_open_ga_chest), tostring(settings.selected_chest_type), settings.chest_opening_time))
        
        -- Check if there is an Aether Bomb available and interact with it
        local aether_bomb = get_aether_bomb()
        if aether_bomb then
            console.print("[ACTION] Aether Bomb detected! Preparing to collect it.")
            if utils.distance_to(aether_bomb) > 2 then
                console.print("[MOVEMENT] Moving towards the Aether Bomb...")
                pathfinder.request_move(aether_bomb:get_position())
            else
                console.print("[INTERACTION] Interacting with the Aether Bomb...")
                local success = interact_object(aether_bomb)
                console.print("[RESULT] Aether Bomb interaction " .. (success and "succeeded." or "failed."))
            end
            return  -- Exit after interacting with the Aether Bomb
        end

        -- Function to handle the opening of a chest
        local function open_chest(chest)
            if chest then
                local chest_name = chest:get_skin_name()
                console.print(string.format("[DISCOVERY] %s chest located.", chest_name))
                if utils.distance_to(chest) > 2 then
                    console.print(string.format("[MOVEMENT] Moving towards the %s chest...", chest_name))
                    pathfinder.request_move(chest:get_position())
                    return false  -- Return false if the chest was not yet opened
                else
                    console.print(string.format("[INTERACTION] Attempting to open the %s chest...", chest_name))
                    local success = interact_object(chest)
                    console.print("[RESULT] Chest opening " .. (success and "succeeded." or "failed."))
                    return success  -- Return true if the chest was successfully opened
                end
            end
            console.print("[WARNING] Chest object is nil or could not be interacted with.")
            return false  -- Return false if the chest is nil or could not be interacted with
        end

        -- Function to manage chest opening based on the chest type
        local function handle_chest_opening(chest_type)
            local chest_id = enums.chest_types[chest_type]
            local chest = utils.get_chest(chest_id)
            if chest then
                if tracker.check_time("peasant_chest_opening_time", 1) then
                    console.print(string.format("[SEARCH] Searching for chest of type: %s.", chest_type))
                    local success = open_chest(chest)
                    console.print(string.format("[ACTION] Attempting to open chest of type: %s (ID: %s)", chest_type, chest_id))
                    if success then
                        console.print("[SUCCESS] Chest opened successfully.")
                        if chest_type == "GOLD" then
                            tracker.gold_chest_successfully_opened = true
                            tracker.gold_chest_opened = true
                        end
                    else
                        console.print("[FAILURE] Failed to open the chest.")
                    end
                end
            else
                console.print("[INFO] No chest of type '%s' found.", chest_type)
            end
        end

        -- Check if more than 5 seconds have passed since the GA chest was opened
        if tracker.ga_chest_open_time > 0 and (current_time - tracker.ga_chest_open_time > 5) then
            tracker.ga_chest_opened = true
            console.print("[INFO] GA chest looting time expired. GA chest will not be attempted again this session.")
        end

        -- Logic to open the GA chest if conditions allow
        if settings.always_open_ga_chest and not tracker.ga_chest_opened then
            console.print("[ATTEMPT] Trying to open GA chest...")
            if tracker.ga_chest_open_time == 0 or (current_time - tracker.ga_chest_open_time > 5) then
                local ga_chest = utils.get_chest("BSK_UniqueOpChest_GreaterAffix")
                if ga_chest then
                    local success = open_chest(ga_chest)
                    if success then
                        tracker.ga_chest_open_time = current_time
                        console.print(string.format("[SUCCESS] GA chest opened at %.2f seconds. Waiting for looting completion.", tracker.ga_chest_open_time))
                    end
                else
                    console.print("[INFO] GA chest not found.")
                end
            else
                console.print(string.format("[COOLDOWN] Waiting for cooldown. Time since last GA chest open: %.2f seconds", current_time - tracker.ga_chest_open_time))
            end
        else
            -- Logic to open a different chest type if the GA chest isn't available or doesn't need to be opened
            local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
            local selected_chest_type = chest_type_map[settings.selected_chest_type + 1]
            if tracker.peasant_chest_open_time == 0 then
               tracker.peasant_chest_open_time = current_time
            end

            -- Continue attempting to open the selected chest type within the time limit
            if current_time - tracker.peasant_chest_open_time <= settings.chest_opening_time then
                handle_chest_opening(selected_chest_type)
            else
                console.print("[TIMEOUT] Chest opening time limit exceeded. Stopping attempts.")
                tracker.peasant_chest_opening_stopped = true

                -- If the selected chest type isn't "GOLD", attempt to open a "GOLD" chest if it hasn't been successfully opened yet
                if selected_chest_type ~= "GOLD" and not tracker.gold_chest_successfully_opened then
                    console.print("[ALTERNATE ATTEMPT] Selected chest type isn't GOLD. Attempting to open a GOLD chest within 100 seconds.")
                    if tracker.gold_chest_open_time == 0 then
                       tracker.gold_chest_open_time = current_time
                    end

                    if current_time - tracker.gold_chest_open_time <= 100 then
                       handle_chest_opening("GOLD")
                    else
                        console.print("[FAILURE] Gold chest opening time limit exceeded. Stopping attempts.")
                        tracker.gold_chest_opened = true
                    end
                end
            end
        end

        console.print(string.format("[TASK END] 'Open Chests' task execution finished at %.2f seconds, Gold Chest Opened: %s", 
                                    get_time_since_inject(), tostring(tracker.gold_chest_opened)))
        
        -- Implement a 5-second cooldown before marking the chest looting as finished
        if tracker.ga_chest_opened and (tracker.peasant_chest_opening_stopped or tracker.gold_chest_successfully_opened) then
            if not tracker.finished_looting_start_time then
                tracker.finished_looting_start_time = current_time
                console.print(string.format("[COOLDOWN] All chests opened. Starting 5-second cooldown at %.2f seconds", tracker.finished_looting_start_time))
            elseif current_time - tracker.finished_looting_start_time > 5 then
                tracker.finished_chest_looting = true
                console.print(string.format("[COMPLETE] 5-second cooldown completed. All chest looting operations finished at %.2f seconds", current_time))
            else
                console.print(string.format("[COOLDOWN] Waiting for 5-second cooldown to complete. Time elapsed: %.2f seconds", current_time - tracker.finished_looting_start_time))
            end
        end
    end
}

return open_chests_task