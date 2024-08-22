local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new(compare)
    return setmetatable({heap = {}, compare = compare or function(a, b) return a < b end}, MinHeap)
end

function MinHeap:push(value)
    table.insert(self.heap, value)
    self:siftUp(#self.heap)
end

function MinHeap:pop()
    local root = self.heap[1]
    self.heap[1] = self.heap[#self.heap]
    table.remove(self.heap)
    self:siftDown(1)
    return root
end

function MinHeap:peek()
    return self.heap[1]
end

function MinHeap:empty()
    return #self.heap == 0
end

function MinHeap:siftUp(index)
    local parent = math.floor(index / 2)
    while index > 1 and self.compare(self.heap[index], self.heap[parent]) do
        self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
        index = parent
        parent = math.floor(index / 2)
    end
end

function MinHeap:siftDown(index)
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
    is_task_running = false,
}
local explored_areas = {}
local target_position = nil
local grid_size = 1.5
local exploration_radius = 10
local explored_buffer = 2
local max_target_distance = 120
local target_distance_states = {120, 40, 20, 5}
local target_distance_index = 1
local unstuck_target_distance = 15
local stuck_threshold = 10
local last_position = nil
local last_move_time = 0
local last_explored_targets = {}
local max_last_targets = 50

local function check_pit_time()
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
    end
end

local function check_and_reset_dungeons()
    if tracker.pit_start_time > 0 then
        local time_spent_in_pit = get_time_since_inject() - tracker.pit_start_time
        local reset_time_threshold = settings.reset_time
        if time_spent_in_pit > reset_time_threshold then
            console.print("Time spent in pit is greater than " .. reset_time_threshold .. " seconds. Resetting all dungeons.")
            reset_all_dungeons()
        end
    end
end

local current_path = {}
local path_index = 1

local exploration_mode = "unexplored"
local exploration_direction = { x = 10, y = 0 }
local last_movement_direction = nil

function explorer:clear_path_and_target()
    target_position = nil
    current_path = {}
    path_index = 1
end

local function calculate_distance(point1, point2)
    if not point2.x and point2 then
        return point1:dist_to_ignore_z(point2:get_position())
    end
    return point1:dist_to_ignore_z(point2)
end

local function set_height_of_valid_position(point)
    return utility.set_height_of_valid_position(point)
end

local function get_grid_key(point)
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
    explored_area_bounds.min_x = math.min(explored_area_bounds.min_x, point:x() - radius)
    explored_area_bounds.max_x = math.max(explored_area_bounds.max_x, point:x() + radius)
    explored_area_bounds.min_y = math.min(explored_area_bounds.min_y, point:y() - radius)
    explored_area_bounds.max_y = math.max(explored_area_bounds.max_y, point:y() + radius)
    explored_area_bounds.min_z = math.min(explored_area_bounds.min_z or math.huge, point:z() - radius)
    explored_area_bounds.max_z = math.max(explored_area_bounds.max_z or -math.huge, point:z() + radius)
end

local function is_point_in_explored_area(point)
    return point:x() >= explored_area_bounds.min_x and point:x() <= explored_area_bounds.max_x and
        point:y() >= explored_area_bounds.min_y and point:y() <= explored_area_bounds.max_y and
        point:z() >= explored_area_bounds.min_z and point:z() <= explored_area_bounds.max_z
end

local function mark_area_as_explored(center, radius)
    update_explored_area_bounds(center, radius)
end

local function check_walkable_area()
    if os.time() % 1 ~= 0 then return end

    local player_pos = get_player_position()
    local check_radius = 15

    mark_area_as_explored(player_pos, exploration_radius)

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            for z = -check_radius, check_radius, grid_size do
                local point = vec3:new(
                    player_pos:x() + x,
                    player_pos:y() + y,
                    player_pos:z() + z
                )
                point = set_height_of_valid_position(point)

                if utility.is_point_walkeable(point) then
                    -- Debugging prints can be added here if needed
                end
            end
        end
    end
end

local function reset_exploration()
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
    local wall_check_distance = 2
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

local function find_random_explored_target()
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
    return vec3:new(v1:x() + v2:x(), v1:y() + v2:y(), v1:z() + v2:z())
end

local function is_in_last_targets(point)
    for _, target in ipairs(last_explored_targets) do
        if calculate_distance(point, target) < grid_size * 2 then
            return true
        end
    end
    return false
end

local function add_to_last_targets(point)
    table.insert(last_explored_targets, point)
    if #last_explored_targets > max_last_targets then
        table.remove(last_explored_targets, 1)
    end
end

local function find_unexplored_target()
    local player_pos = get_player_position()
    local search_radius = max_target_distance
    local target = nil
    local best_distance = math.huge

    for x = -search_radius, search_radius, grid_size do
        for y = -search_radius, search_radius, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)
            local grid_key = get_grid_key(point)

            if utility.is_point_walkeable(point) and not explored_areas[grid_key] and not is_in_last_targets(point) then
                local distance = calculate_distance(player_pos, point)
                if distance < best_distance then
                    best_distance = distance
                    target = point
                end
            end
        end
    end

    if target then
        add_to_last_targets(target)
    end

    return target
end

local function a_star(start_point, goal_point)
    local open_set = MinHeap.new(function(a, b) return a.f < b.f end)
    local came_from = {}
    local g_score = {}
    local f_score = {}
    local path_found = false

    open_set:push({
        point = start_point,
        g = 0,
        f = calculate_distance(start_point, goal_point)
    })
    g_score[start_point] = 0
    f_score[start_point] = calculate_distance(start_point, goal_point)

    while not open_set:empty() do
        local current = open_set:pop()
        if current.point == goal_point then
            path_found = true
            break
        end

        local neighbors = get_neighbors(current.point)
        for _, neighbor in ipairs(neighbors) do
            local tentative_g = current.g + calculate_distance(current.point, neighbor)
            if not g_score[neighbor] or tentative_g < g_score[neighbor] then
                came_from[neighbor] = current.point
                g_score[neighbor] = tentative_g
                f_score[neighbor] = g_score[neighbor] + calculate_distance(neighbor, goal_point)
                if not open_set:contains({ point = neighbor }) then
                    open_set:push({
                        point = neighbor,
                        g = g_score[neighbor],
                        f = f_score[neighbor]
                    })
                end
            end
        end
    end

    if path_found then
        return reconstruct_path(came_from, goal_point)
    else
        return nil
    end
end

local function get_neighbors(point)
    local neighbors = {}
    local directions = {
        { x = grid_size, y = 0 }, { x = -grid_size, y = 0 }, { x = 0, y = grid_size }, { x = 0, y = -grid_size },
        { x = grid_size, y = grid_size }, { x = grid_size, y = -grid_size }, { x = -grid_size, y = grid_size }, { x = -grid_size, y = -grid_size }
    }

    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(
            point:x() + dir.x,
            point:y() + dir.y,
            point:z()
        )
        neighbor = set_height_of_valid_position(neighbor)
        if utility.is_point_walkeable(neighbor) then
            table.insert(neighbors, neighbor)
        end
    end

    return neighbors
end

local function reconstruct_path(came_from, current)
    local path = { current }
    while came_from[current] do
        current = came_from[current]
        table.insert(path, 1, current)
    end
    return path
end


local function find_target()
    if exploration_mode == "unexplored" then
        return find_unexplored_target()
    elseif exploration_mode == "explored" then
        return find_random_explored_target()
    end
end

local function check_if_stuck()
    local player_pos = get_player_position()
    if last_position and calculate_distance(last_position, player_pos) < stuck_threshold then
        local time_since_last_move = get_time_since_inject() - last_move_time
        if time_since_last_move > unstuck_target_distance then
            return true
        end
    end
    return false
end

local function on_update()
    check_pit_time()
    check_and_reset_dungeons()
    check_walkable_area()

    if check_if_stuck() then
        explorer:clear_path_and_target()
        target_position = find_unexplored_target()
        if not target_position then
            console.print("No unexplored target found. Trying explored targets.")
            target_position = find_random_explored_target()
        end
        if target_position then
            console.print("Moving to target position.")
            move_to_target()
        else
            console.print("No valid targets found. Exiting.")
        end
    end

    if current_path and path_index <= #current_path then
        local next_point = current_path[path_index]
        local player_pos = get_player_position()
        local distance_to_next = calculate_distance(player_pos, next_point)

        if distance_to_next < 1 then
            path_index = path_index + 1
        else
            -- Implement movement to next_point
            -- e.g., pathfinder.request_move(next_point)
        end

        last_position = player_pos
        last_move_time = get_time_since_inject()
    end
end

local explorer = {}

-- Bereits vorhandene Funktionen
function explorer:clear_path_and_target()
    target_position = nil
    current_path = {}
    path_index = 1
end

function explorer:move_to_target()
    if target_position then
        pathfinder.force_move_raw(target_position)
    else
        console.print("No target position set.")
    end
end

function explorer:set_custom_target(pos)
    target_position = pos
    if type(pos) == "userdata" and pos.x and pos.y and pos.z then
        console.print(string.format("Custom target set to: x=%.2f, y=%.2f, z=%.2f", pos:x(), pos:y(), pos:z()))
    else
        console.print("Custom target set (unable to display coordinates)")
    end
end

function explorer:check_if_stuck()
    return check_if_stuck()
end

return explorer