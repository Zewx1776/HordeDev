-- MinHeap for managing the open set in A* algorithm
local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new(compare)
    return setmetatable({ heap = {}, compare = compare or function(a, b) return a < b end }, MinHeap)
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

-- Explorer module for pathfinding
local explorer = {}

local grid_size = 1
local current_path = {}
local path_index = 1
local last_target_position = nil  -- Track the last target position

local function calculate_distance(point1, point2)
    local step_size = 7
    local grid_size = 1
    local dx = (point2:x() - point1:x()) / step_size
    local dy = (point2:y() - point1:y()) / step_size
    --local dz = (point2:z() - point1:z()) / step_size
    return math.sqrt(dx * dx + dy * dy) * grid_size
end

local function set_height_of_valid_position(point)
    return utility.set_height_of_valid_position(point)
end

local function get_grid_key(point)
    return math.floor(point:x() / grid_size) .. "," ..
        math.floor(point:y() / grid_size) .. "," ..
        math.floor(point:z() / grid_size)
end

local function heuristic(a, b)
    return calculate_distance(a, b)
end

local function get_neighbors(point)
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
            table.insert(neighbors, neighbor)
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
    return path
end

local function a_star(start, goal)
    local closed_set = {}
    local came_from = {}
    local g_score = { [get_grid_key(start)] = 0 }
    local f_score = { [get_grid_key(start)] = heuristic(start, goal) }

    local open_set = MinHeap.new(function(a, b)
        return f_score[get_grid_key(a)] < f_score[get_grid_key(b)]
    end)
    open_set:push(start)

    while not open_set:empty() do
        local current = open_set:pop()

        if calculate_distance(current, goal) < grid_size then
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

    return nil
end

local function reset_path()
    current_path = {}
    path_index = 1
    last_target_position = nil
end

local debug = true
if debug then
    local player_pos = get_player_position()
    local px, py, pz = player_pos:x(), player_pos:y(), player_pos:z()

    console.print(px .. ", " .. py .. ", " .. pz)
end

function explorer:get_next_point(target_position)
    local player_pos = get_player_position()

    -- Reset path if the target position changes
    if not last_target_position or last_target_position:x() ~= target_position:x() or
       last_target_position:y() ~= target_position:y() or
       last_target_position:z() ~= target_position:z() then
        reset_path()
        last_target_position = target_position
    end

    if not current_path or #current_path == 0 or path_index > #current_path then
        current_path = a_star(player_pos, target_position)
        path_index = 1
    end

    -- Check if current_path is nil after A* algorithm
    if not current_path then
        return nil
    end

    local next_point = current_path[path_index]
    if next_point and calculate_distance(player_pos, next_point) < grid_size then
        path_index = path_index + 1
    end

    return next_point
end

return explorer
