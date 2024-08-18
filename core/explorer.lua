local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new(compare)
    --console.print("Creating new MinHeap.")
    return setmetatable({heap = {}, compare = compare or function(a, b) return a < b end}, MinHeap)
end

function MinHeap:push(value)
    --console.print("Pushing value into MinHeap.")
    table.insert(self.heap, value)
    self:siftUp(#self.heap)
end

function MinHeap:pop()
    --console.print("Popping value from MinHeap.")
    local root = self.heap[1]
    self.heap[1] = self.heap[#self.heap]
    table.remove(self.heap)
    self:siftDown(1)
    return root
end

function MinHeap:peek()
    --console.print("Peeking value from MinHeap.")
    return self.heap[1]
end

function MinHeap:empty()
    --console.print("Checking if MinHeap is empty.")
    return #self.heap == 0
end

function MinHeap:siftUp(index)
    --console.print("Sifting up in MinHeap.")
    local parent = math.floor(index / 2)
    while index > 1 and self.compare(self.heap[index], self.heap[parent]) do
        self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
        index = parent
        parent = math.floor(index / 2)
    end
end

function MinHeap:siftDown(index)
    --console.print("Sifting down in MinHeap.")
    local size = #self.heap
    while true do
        local smallest = index
        local left = 2 * index
        local right = 2 * index + 1
        if left <= size and self.compare(self.heap[left], self.heap[smallest]) then
            smallest = left
        end
        if right <= size and self.compare(self.heap[right], self.heap[smallest]) then
            smallest = right
        end
        if smallest == index then break end
        self.heap[index], self.heap[smallest] = self.heap[smallest], self.heap[index]
        index = smallest
    end
end

function MinHeap:contains(value)
    --console.print("Checking if MinHeap contains value.")
    for _, v in ipairs(self.heap) do
        if v == value then return true end
    end
    return false
end

local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local tracker = require "core.tracker"
local explorer = {
    enabled = false,
    is_task_running = false, --added to prevent boss dead pathing 
}
local explored_areas = {}
local target_position = nil
local grid_size = 1.5            -- Size of grid cells in meters
local exploration_radius = 10   -- Radius in which areas are considered explored
local explored_buffer = 2      -- Buffer around explored areas in meters
local max_target_distance = 120 -- Maximum distance for a new target
local target_distance_states = {120, 40, 20, 5}
local target_distance_index = 1
local unstuck_target_distance = 15 -- Maximum distance for an unstuck target
local stuck_threshold = 4      -- Seconds before the character is considered "stuck"
local last_position = nil
local last_move_time = 0
local last_explored_targets = {}
local max_last_targets = 50

-- Function to check and print pit start time and time spent in pit
local function check_pit_time()
    --console.print("Checking pit start time...")  -- Add this line for debugging
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
    else
        --console.print("Pit start time is not set or is zero.")  -- Add this line for debugging
    end
end

local function check_and_reset_dungeons()
    --console.print("Executing check_and_reset_dungeons") -- Debug print
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
        local reset_time_threshold = settings.reset_time
        if time_spent_in_pit > reset_time_threshold then
            console.print("Time spent in pit is greater than " .. reset_time_threshold .. " seconds. Resetting all dungeons.")
            reset_all_dungeons()
        end
    end
end

-- A* pathfinding variables
local current_path = {}
local path_index = 1

-- Explorationsmodus
local exploration_mode = "unexplored" -- "unexplored" oder "explored"

-- Richtung für den "explored" Modus
local exploration_direction = { x = 10, y = 0 } -- Initiale Richtung (kann angepasst werden)

-- Neue Variable für die letzte Bewegungsrichtung
local last_movement_direction = nil

--ai fix for kill monsters path
function explorer:clear_path_and_target()
    --console.print("Clearing path and target.")
    target_position = nil
    current_path = {}
    path_index = 1
end

local function calculate_distance(point1, point2)
    --console.print("Calculating distance between points.")
    if not point2.x and point2 then
        return point1:dist_to_ignore_z(point2:get_position())
    end
    return point1:dist_to_ignore_z(point2)
end



--ai fix for stairs
local function set_height_of_valid_position(point)
    --console.print("Setting height of valid position.")
    return utility.set_height_of_valid_position(point)
end

local function get_grid_key(point)
    --console.print("Getting grid key.")
    return math.floor(point:x() / grid_size) .. "," ..
        math.floor(point:y() / grid_size) .. "," ..
        math.floor(point:z() / grid_size)
end

local explored_area_bounds = {
    min_x = math.huge,
    max_x = -math.huge,
    min_y = math.huge,
    max_y = -math.huge,
    min_z = math.huge,
    max_z = math.huge
}
local function update_explored_area_bounds(point, radius)
    --console.print("Updating explored area bounds.")
    explored_area_bounds.min_x = math.min(explored_area_bounds.min_x, point:x() - radius)
    explored_area_bounds.max_x = math.max(explored_area_bounds.max_x, point:x() + radius)
    explored_area_bounds.min_y = math.min(explored_area_bounds.min_y, point:y() - radius)
    explored_area_bounds.max_y = math.max(explored_area_bounds.max_y, point:y() + radius)
    explored_area_bounds.min_z = math.min(explored_area_bounds.min_z or math.huge, point:z() - radius)
    explored_area_bounds.max_z = math.max(explored_area_bounds.max_z or -math.huge, point:z() + radius)
end

local function is_point_in_explored_area(point)
    --console.print("Checking if point is in explored area.")
    return point:x() >= explored_area_bounds.min_x and point:x() <= explored_area_bounds.max_x and
        point:y() >= explored_area_bounds.min_y and point:y() <= explored_area_bounds.max_y and
        point:z() >= explored_area_bounds.min_z and point:z() <= explored_area_bounds.max_z
end

local function mark_area_as_explored(center, radius)
    --console.print("Marking area as explored.")
    update_explored_area_bounds(center, radius)
    -- Hier können Sie zusätzliche Logik hinzufügen, um die erkundeten Bereiche zu markieren
    -- z.B. durch Hinzufügen zu einer Datenstruktur oder durch Setzen von Flags
end

local function check_walkable_area()
    --console.print("Checking walkable area.")
    if os.time() % 1 ~= 0 then return end  -- Only run every 5 seconds

    local player_pos = get_player_position()
    local check_radius = 15 -- Überprüfungsradius in Metern

    mark_area_as_explored(player_pos, exploration_radius)

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            for z = -check_radius, check_radius, grid_size do -- Inclui z no loop
                local point = vec3:new(
                    player_pos:x() + x,
                    player_pos:y() + y,
                    player_pos:z() + z
                )
                print("Checking point:", point:x(), point:y(), point:z()) -- Debug print
                point = set_height_of_valid_position(point)

                if utility.is_point_walkeable(point) then
                    if is_point_in_explored_area(point) then
                        --graphics.text_3d("Explored", point, 15, color_white(128))
                    else
                        --graphics.text_3d("unexplored", point, 15, color_green(255))
                    end
                end
            end
        end
    end
end

local function reset_exploration()
    --console.print("Resetting exploration.")
    explored_area_bounds = {
        min_x = math.huge,
        max_x = -math.huge,
        min_y = math.huge,
        max_y = -math.huge,
    }
    target_position = nil
    last_position = nil
    last_move_time = 0
    current_path = {}
    path_index = 1
    exploration_mode = "unexplored"
    last_movement_direction = nil

    console.print("Exploration reset. All areas marked as unexplored.")
end

local function is_near_wall(point)
    --console.print("Checking if point is near wall.")
    local wall_check_distance = 2 -- Abstand zur Überprüfung von Wänden
    local directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }

    for _, dir in ipairs(directions) do
        local check_point = vec3:new(
            point:x() + dir.x * wall_check_distance,
            point:y() + dir.y * wall_check_distance,
            point:z()
        )
        check_point = set_height_of_valid_position(check_point)
        if not utility.is_point_walkeable(check_point) then
            return true
        end
    end
    return false
end

-- Removed the find_central_unexplored_target function
-- It was previously located here

local function find_random_explored_target()
    console.print("Finding random explored target.")
    local player_pos = get_player_position()
    local check_radius = max_target_distance
    local explored_points = {}

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)
            local grid_key = get_grid_key(point)
            if utility.is_point_walkeable(point) and explored_areas[grid_key] and not is_near_wall(point) then
                table.insert(explored_points, point)
            end
        end
    end

    if #explored_points == 0 then   
        return nil
    end

    return explored_points[math.random(#explored_points)]
end

function vec3.__add(v1, v2)
    --console.print("Adding two vectors.")
    return vec3:new(v1:x() + v2:x(), v1:y() + v2:y(), v1:z() + v2:z())
end

local function is_in_last_targets(point)
    --console.print("Checking if point is in last targets.")
    for _, target in ipairs(last_explored_targets) do
        if calculate_distance(point, target) < grid_size * 2 then
            return true
        end
    end
    return false
end

local function add_to_last_targets(point)
   --console.print("Adding point to last targets.")
    table.insert(last_explored_targets, 1, point)
    if #last_explored_targets > max_last_targets then
        table.remove(last_explored_targets)
    end
end

local function find_nearby_unexplored_point(center, radius)
    local check_radius = max_target_distance
    local player_pos = get_player_position()

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            local point = vec3:new(
                center:x() + x,
                center:y() + y,
                center:z()
            )

            point = set_height_of_valid_position(point)

            if utility.is_point_walkeable(point) and not is_point_in_explored_area(point) then
                return point
            end
        end
    end

    return nil
end

local function find_explored_direction_target()
    console.print("Finding explored direction target.")
    local player_pos = get_player_position()
    local max_attempts = 500
    local attempts = 0
    local best_target = nil
    local best_distance = math.huge -- Initialize to a large value to find the closest point

    while attempts < max_attempts do
        attempts = attempts + 1
        local direction_vector = vec3:new(
            exploration_direction.x * max_target_distance * 0.4,
            exploration_direction.y * max_target_distance * 0.4,
            0
        )
        local target_point = player_pos + direction_vector
        target_point = set_height_of_valid_position(target_point)

        if utility.is_point_walkeable(target_point) and is_point_in_explored_area(target_point) then
            local distance = calculate_distance(player_pos, target_point)
            if distance < best_distance and not is_in_last_targets(target_point) then
                best_target = target_point
                best_distance = distance

                -- Check for nearby unexplored points
                local nearby_unexplored_point = find_nearby_unexplored_point(target_point, exploration_radius)
                if nearby_unexplored_point then
                    console.print("Nearby unexplored point found. Switching to unexplored mode.")
                    exploration_mode = "unexplored"
                    return nearby_unexplored_point
                end
            end
        else
            --console.print("Attempt " .. attempts .. ": Target point is not walkable or not in explored area.")
        end

        -- Change the direction slightly for the next attempt
        local angle = math.atan2(exploration_direction.y, exploration_direction.x) + math.random() * math.pi / 4 - math.pi / 8
        exploration_direction.x = math.cos(angle)
        exploration_direction.y = math.sin(angle)
    end

    if best_target then
        add_to_last_targets(best_target)
        console.print("Found best target after " .. attempts .. " attempts.")
        return best_target
    else
        console.print("Could not find a valid explored target after " .. max_attempts .. " attempts.")
        return nil
    end
end

local function find_unstuck_target()
    console.print("Finding unstuck target.")
    local player_pos = get_player_position()
    local valid_targets = {}

    for x = -unstuck_target_distance, unstuck_target_distance, grid_size do
        for y = -unstuck_target_distance, unstuck_target_distance, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)

            local distance = calculate_distance(player_pos, point)
            if utility.is_point_walkeable(point) and distance >= 2 and distance <= unstuck_target_distance then
                table.insert(valid_targets, point)
            end
        end
    end

    if #valid_targets > 0 then
        return valid_targets[math.random(#valid_targets)]
    end

    return nil
end

local function find_target(include_explored)
    console.print("Finding target.")
    last_movement_direction = nil -- Reset the last movement direction

    if include_explored then
        return find_unstuck_target()
    else
        if exploration_mode == "unexplored" then
            -- Commented out the following lines
            -- local unexplored_target = find_central_unexplored_target()
            -- if unexplored_target then
            --     return unexplored_target
            -- else
                exploration_mode = "explored"
                console.print("No unexplored areas found. Switching to explored mode.")
                last_explored_targets = {} -- Reset last targets when switching modes
            -- end
        end

        if exploration_mode == "explored" then
            local explored_target = find_explored_direction_target()
            if explored_target then
                return explored_target
            else
                console.print("No valid explored targets found. Resetting exploration.")
                reset_exploration()
                exploration_mode = "unexplored"
                -- Return nil or adjust logic here to handle the absence of unexplored targets
                -- You might want to return nil or handle it differently since you don't want `find_central_unexplored_target` to run
            end
        end
    end

    return nil
end

-- A* pathfinding functions
local function heuristic(a, b)
    --console.print("Calculating heuristic.")
    return calculate_distance(a, b)
end

local function get_neighbors(point)
    --console.print("Getting neighbors of point.")
    local neighbors = {}
    local directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }
    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(
            point:x() + dir.x * grid_size,
            point:y() + dir.y * grid_size,
            point:z()
        )
        neighbor = set_height_of_valid_position(neighbor)
        if utility.is_point_walkeable(neighbor) then
            if not last_movement_direction or
                (dir.x ~= -last_movement_direction.x or dir.y ~= -last_movement_direction.y) then
                table.insert(neighbors, neighbor)
            end
        end
    end

    if #neighbors == 0 and last_movement_direction then
        local back_direction = vec3:new(
            point:x() - last_movement_direction.x * grid_size,
            point:y() - last_movement_direction.y * grid_size,
            point:z()
        )
        back_direction = set_height_of_valid_position(back_direction)
        if utility.is_point_walkeable(back_direction) then
            table.insert(neighbors, back_direction)
        end
    end

    return neighbors
end

local function reconstruct_path(came_from, current)
    local path = { current }
    while came_from[get_grid_key(current)] do
        current = came_from[get_grid_key(current)]
        table.insert(path, 1, current)
    end

    -- Filter points with a less aggressive approach
    local filtered_path = { path[1] }
    for i = 2, #path - 1 do
        local prev = path[i - 1]
        local curr = path[i]
        local next = path[i + 1]

        local dir1 = { x = curr:x() - prev:x(), y = curr:y() - prev:y() }
        local dir2 = { x = next:x() - curr:x(), y = next:y() - curr:y() }

        -- Calculate the angle between directions
        local dot_product = dir1.x * dir2.x + dir1.y * dir2.y
        local magnitude1 = math.sqrt(dir1.x^2 + dir1.y^2)
        local magnitude2 = math.sqrt(dir2.x^2 + dir2.y^2)
        local angle = math.acos(dot_product / (magnitude1 * magnitude2))

        -- Use the angle from settings, converting degrees to radians
        local angle_threshold = math.rad(settings.path_angle)

        -- Keep points if the angle is greater than the threshold from settings
        if angle > angle_threshold then
            table.insert(filtered_path, curr)
        end
    end
    table.insert(filtered_path, path[#path])

    return filtered_path
end

local function a_star(start, goal)
    --console.print("Starting A* pathfinding.")
    local closed_set = {}
    local came_from = {}
    local g_score = { [get_grid_key(start)] = 0 }
    local f_score = { [get_grid_key(start)] = heuristic(start, goal) }
    local iterations = 0

    local open_set = MinHeap.new(function(a, b)
        return f_score[get_grid_key(a)] < f_score[get_grid_key(b)] -- Does that work?
    end)
    open_set:push(start)

    while not open_set:empty() do
        iterations = iterations + 1
        if iterations > 6666 then
            console.print("Max iterations reached, aborting!")
            break
        end

        local current = open_set:pop()
        if calculate_distance(current, goal) < grid_size then
            max_target_distance = target_distance_states[1]
            target_distance_index = 1
            return reconstruct_path(came_from, current)
        end

        closed_set[get_grid_key(current)] = true

        for _, neighbor in ipairs(get_neighbors(current)) do
            if not closed_set[get_grid_key(neighbor)] then
                local tentative_g_score = g_score[get_grid_key(current)] + calculate_distance(current, neighbor)

                if not g_score[get_grid_key(neighbor)] or tentative_g_score < g_score[get_grid_key(neighbor)] then
                    came_from[get_grid_key(neighbor)] = current
                    g_score[get_grid_key(neighbor)] = tentative_g_score
                    f_score[get_grid_key(neighbor)] = g_score[get_grid_key(neighbor)] + heuristic(neighbor, goal)

                    if not open_set:contains(neighbor) then
                        open_set:push(neighbor)
                    end
                end
            end
        end
    end

    if target_distance_index < #target_distance_states then
        target_distance_index = target_distance_index + 1
        max_target_distance = target_distance_states[target_distance_index]
        console.print("No path found. Reducing max target distance to " .. max_target_distance)
    else
        console.print("No path found even after reducing max target distance.")
    end

    return nil
end

local last_a_star_call = 0.0
local function move_to_target()
    if explorer.is_task_running then
        return  -- Do not set a path if a task is running
    end

    if target_position then
        local player_pos = get_player_position()
        if calculate_distance(player_pos, target_position) > 500 then
            target_position = find_target(false)
            current_path = {}
            path_index = 1
            return
        end

        if not current_path or #current_path == 0 or path_index > #current_path then
            local current_core_time = get_time_since_inject()
            path_index = 1
            current_path = nil
            current_path = a_star(player_pos, target_position)
            last_a_star_call = current_core_time

            if not current_path then
                console.print("No path found to target. Finding new target.")
                target_position = find_target(false)
                return
            end
        end

        local next_point = current_path[path_index]
        if next_point and not next_point:is_zero() then
            pathfinder.request_move(next_point)
        end

        if next_point and next_point.x and not next_point:is_zero() and calculate_distance(player_pos, next_point) < grid_size then
            local direction = {
                x = next_point:x() - player_pos:x(),
                y = next_point:y() - player_pos:y()
            }
            last_movement_direction = direction
            path_index = path_index + 1
        end

        if calculate_distance(player_pos, target_position) < 2 then
            mark_area_as_explored(player_pos, exploration_radius)
            target_position = nil
            current_path = {}
            path_index = 1

            -- Check for nearby unexplored points when in explored mode
            if exploration_mode == "explored" then
                local nearby_unexplored_point = find_nearby_unexplored_point(player_pos, exploration_radius)
                if nearby_unexplored_point then
                    exploration_mode = "unexplored"
                    target_position = nearby_unexplored_point
                    console.print("Found nearby unexplored area. Switching back to unexplored mode.")
                    last_explored_targets = {}
                    current_path = nil
                    path_index = 1
                else
                    -- If no unexplored points are found, continue with explored mode logic
                    -- Commented out the following line
                    -- local unexplored_target = find_central_unexplored_target()
                    -- if unexplored_target then
                    --     exploration_mode = "unexplored"
                    --     target_position = unexplored_target
                    --     console.print("Found new unexplored area. Switching back to unexplored mode.")
                    --     last_explored_targets = {}
                    -- end
                end
            end
        end
    else
        target_position = find_target(false)
    end
end

local function check_if_stuck()
    --console.print("Checking if character is stuck.")
    local current_pos = get_player_position()
    local current_time = os.time()

    if last_position and calculate_distance(current_pos, last_position) < 0.1 then
        if current_time - last_move_time > stuck_threshold then
            return true
        end
    else
        last_move_time = current_time
    end

    last_position = current_pos

    return false
end

explorer.check_if_stuck = check_if_stuck

function explorer:set_custom_target(target)
    console.print("Setting custom target.")
    target_position = target
end

-- Expose the move_to_target function
function explorer:move_to_target()
    move_to_target()
end

local last_call_time = 0.0
local is_player_on_quest = false
on_update(function()
    if not settings.enabled then
        return
    end

    if explorer.is_task_running then
         return -- Don't run explorer logic if a task is running
    end

    local world = world.get_current_world()
    if world then
        local world_name = world:get_name()
        if world_name:match("Sanctuary") or world_name:match("Limbo") then
            return
        end
    end

    --local auto_play_objective = auto_play.get_objective()
    --local should_sell = auto_play_objective == objective.sell
    --if should_sell then
    --    return -- stop code here
    --end

    local current_core_time = get_time_since_inject()
    if current_core_time - last_call_time > 0.45 then
        last_call_time = current_core_time
        is_player_on_quest = utils.player_on_quest(enums.quests.pit_ongoing) and settings.enabled
        if not is_player_on_quest then
            return
        end

        check_walkable_area()
        local is_stuck = check_if_stuck()
        if is_stuck then
            console.print("Character was stuck. Finding new target and attempting revive")
            target_position = find_target(true)
            target_position = set_height_of_valid_position(target_position)
            last_move_time = os.time()
            current_path = {}
            path_index = 1

            local local_player = get_local_player()
            if local_player and local_player:is_dead() then
                revive_at_checkpoint()
            end
        end
    end

    check_pit_time()
    check_and_reset_dungeons() 
end)

on_render(function()
    
    if not settings.enabled then
        return
    end

    -- dont slide frames here so drawings feel smooth
    if target_position then
        if target_position.x then
            graphics.text_3d("TARGET_1", target_position, 20, color_red(255))
        else
            if target_position and target_position:get_position() then
                graphics.text_3d("TARGET_2", target_position:get_position(), 20, color_orange(255))
            end
        end
    end

    if current_path then
        for i, point in ipairs(current_path) do
            local color = (i == path_index) and color_green(255) or color_yellow(255)
            graphics.text_3d("PATH_1", point, 15, color)
        end
    end

    graphics.text_2d("Mode: " .. exploration_mode, vec2:new(10, 10), 20, color_white(255))
end)

return explorer
