local utils = require "core.utils"
local enums = require "data.enums"
local explorer = require "core.explorer"
local tracker = require "core.tracker"

local reset_from_town_task = {
    name = "Reset From Town",
    last_teleport_time = 0,
    teleport_wait_time = 10, -- Wait time in seconds
    current_waypoint_index = 1,
    waypoints = {
        vec3:new(105.58838653564, -513.11846923828, 26.1708984375),
        vec3:new(61.29451751709, -497.77514648438, 14.8916015625),
        vec3:new(85.628677368164, -471.83987426758, 9.9296875), 
        vec3:new(38.74942779541, -429.71520996094, 3.76171875), 
        vec3:new(13.433446884155, -448.40444946289, -7.1640625), 
        vec3:new(49.682609558105, -454.91827392578, -15.03515625), 
        vec3:new(29.382822036743, -477.1257019043, -24.1337890625), 
    }
}

-- Task should execute function (without self)
function reset_from_town_task.shouldExecute()
    return utils.player_in_zone("Frac_Kyovashad") or tracker.teleported_from_town
end

-- Task execute function (without self)
function reset_from_town_task.Execute()
    console.print("Executing Reset From Town task")

    local current_time = get_time_since_inject()

    if not tracker.teleported_from_town then
        -- Teleport to the Library waypoint
        teleport_to_waypoint(enums.waypoints.LIBRARY)

        -- Set the flag to true after teleporting
        tracker.teleported_from_town = true
        reset_from_town_task.last_teleport_time = current_time
        reset_from_town_task.current_waypoint_index = 1

        console.print("Teleported to Library waypoint, waiting for " .. reset_from_town_task.teleport_wait_time .. " seconds")
    elseif current_time - reset_from_town_task.last_teleport_time >= reset_from_town_task.teleport_wait_time then
        local current_waypoint = reset_from_town_task.waypoints[reset_from_town_task.current_waypoint_index]
        
        if current_waypoint then
            -- Set the custom target to the current waypoint
            explorer:set_custom_target(current_waypoint)

            -- Move to the target
            explorer:move_to_target()

            -- Check distance to current waypoint
            local distance_to_waypoint = utils.distance_to(current_waypoint)
            if distance_to_waypoint < 2 then
                -- Move to the next waypoint
                reset_from_town_task.current_waypoint_index = reset_from_town_task.current_waypoint_index + 1
                console.print("Reached waypoint " .. (reset_from_town_task.current_waypoint_index - 1) .. ", moving to next")
            end
        else
            -- All waypoints have been reached
            tracker.teleported_from_town = false
            reset_from_town_task.current_waypoint_index = 1
            console.print("Reset From Town task completed")
            return true
        end
    else
        console.print("Waiting for teleport cooldown... " .. string.format("%.2f", reset_from_town_task.teleport_wait_time - (current_time - reset_from_town_task.last_teleport_time)) .. " seconds left")
    end

    return false
end

return reset_from_town_task