local utils = require "core.utils"
local settings = require "core.settings"
local enums = require "data.enums"
local tracker = require "core.tracker"

local open_chests_task = {
    name = "Open Chests",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") and utils.player_on_quest(2023962)
    end,
    
    Execute = function()
        local current_time = get_time_since_inject()
        console.print(string.format("Execute called at %.2f, tracker.open_chest_time: %.2f, tracker.ga_chest_opened: %s", 
                                    current_time, tracker.open_chest_time or 0, tostring(tracker.ga_chest_opened)))
        console.print(string.format("Current settings: always_open_ga_chest: %s, selected_chest_type: %s", 
                                    tostring(settings.always_open_ga_chest), tostring(settings.selected_chest_type)))

        -- Reset the GA chest opened flag at the beginning
        tracker.ga_chest_opened = false

        local function open_chest(chest)
            if chest then
                console.print(chest:get_skin_name() .. " found, interacting")
                if utils.distance_to(chest) > 2 then
                    pathfinder.request_move(chest:get_position())
                    return false
                else
                    local success = interact_object(chest)
                    console.print("Chest interaction result: " .. tostring(success))
                    return success
                end
            end
            return false
        end

        -- Check if 10 seconds have passed since opening the chest
        if tracker.open_chest_time > 0 and (current_time - tracker.open_chest_time > 10) then
            tracker.ga_chest_opened = true
            console.print("GA chest looting time over. Will not attempt again this session.")
        end

        if settings.always_open_ga_chest and not tracker.ga_chest_opened then
            console.print("Attempting to open GA chest")
            if tracker.open_chest_time == 0 or (current_time - tracker.open_chest_time > 10) then
                local ga_chest = utils.get_chest("BSK_UniqueOpChest_GreaterAffix")
                if ga_chest then
                    local success = open_chest(ga_chest)
                    if success then
                        tracker.open_chest_time = current_time
                        console.print(string.format("GA chest opened at %.2f. Waiting 10 seconds for looting.", tracker.open_chest_time))
                        return -- Wait for 5 seconds before continuing
                    else
                        console.print("Failed to open GA chest")
                    end
                else
                    console.print("GA chest not found")
                end
            else
                console.print(string.format("Waiting for cooldown. Time since last open: %.2f", current_time - tracker.open_chest_time))
            end
        end

        -- Open the selected chest type for the duration specified by the new slider
        if tracker.check_time("open_chest_time", settings.chest_opening_time) then
            local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
            local selected_chest_type = chest_type_map[settings.selected_chest_type + 1]
            local chest_id = enums.chest_types[selected_chest_type]
            console.print(string.format("Attempting to open selected chest type: %s (ID: %s)", selected_chest_type, chest_id))
            local selected_chest = utils.get_chest(chest_id)
            if selected_chest then
                open_chest(selected_chest)
            else
                console.print("Selected chest not found")
            end

            -- If the selected chest wasn't gold, open the gold chest once
            if selected_chest_type ~= "GOLD" then
                local gold_chest = utils.get_chest(enums.chest_types["GOLD"])
                if gold_chest then
                    open_chest(gold_chest)
                end
            end
        else
            console.print("Skipping selected chest opening due to GA chest settings")
        end

        -- Reset the GA chest opened flag at the end
        tracker.ga_chest_opened = false

        console.print(string.format("Execute finished at %.2f, tracker.ga_chest_opened: %s", 
                                    get_time_since_inject(), tostring(tracker.ga_chest_opened)))
    end
}

return open_chests_task