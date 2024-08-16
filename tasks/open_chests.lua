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
        console.print(string.format("Execute called at %.2f", current_time))

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

        -- Try to open GA chest if the option is enabled
        if settings.always_open_ga_chest then
            console.print("Attempting to open GA chest")
            local ga_chest = utils.get_chest("BSK_UniqueOpChest_GreaterAffix")
            if ga_chest then
                open_chest(ga_chest)
            else
                console.print("GA chest not found")
            end
        end

        -- Open the selected chest type for the duration specified by the slider
        local start_time = current_time
        local chest_type_map = {"GEAR", "MATERIALS", "GOLD"}
        local selected_chest_type = chest_type_map[settings.selected_chest_type + 1]
        local chest_id = enums.chest_types[selected_chest_type]

        while (current_time - start_time) < settings.chest_opening_time do
            console.print(string.format("Attempting to open selected chest type: %s (ID: %s)", selected_chest_type, chest_id))
            local selected_chest = utils.get_chest(chest_id)
            if selected_chest then
                open_chest(selected_chest)
            else
                console.print("Selected chest not found")
            end
            current_time = get_time_since_inject()
        end

        -- Always open gold chest last, unless it was the selected type
        if selected_chest_type ~= "GOLD" then
            console.print("Opening gold chest")
            local gold_chest = utils.get_chest(enums.chest_types["GOLD"])
            if gold_chest then
                open_chest(gold_chest)
            else
                console.print("Gold chest not found")
            end
        end

        console.print(string.format("Execute finished at %.2f", get_time_since_inject()))
    end
}

return open_chests_task