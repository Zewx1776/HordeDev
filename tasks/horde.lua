local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local navigation = require "core.navigation"
local tracker = require "core.tracker"
local explorer = require "core.explorer"
tracker.horde_opened = false  -- For start_dungeon again, after dying and exit horde

-- Define the bomber object with its states and tasks
local bomber = {
    enabled = false,
    is_task_running = false,
    bomber_task_running = false,
}

-- Define key positions for movement and patterns
local horde_center_position = vec3:new(9.204102, 8.915039, 0.000000)
local horde_left_position = vec3:new(19.5658, -1.5756, 0.6289)
local horde_right_position = vec3:new(0.24825286, 20.6410, 0.4697)
local horde_bottom_position = vec3:new(20.17866, 17.897891, 0.24707)
local unstuck_position = vec3:new(16.8066444, 12.58058, 0.000000)
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)


local move_positions = {
    horde_center_position,
    horde_left_position,     -- From Middle to Left side 
    horde_center_position,
    horde_bottom_position,   -- From Middle to Down side
    horde_center_position,
    horde_right_position,    -- From Middle to Right side
    horde_center_position,
}

-- Data for circular shooting pattern
local circle_data = {
    radius = 90,
    steps = 20,
    delay = 3,
    current_step = 10,
    last_action_time = 0,
    height_offset = 1
}

function bomber:bomb_to(pos)
    explorer:set_custom_target(pos)
    explorer:move_to_target()
end

-- Function to get the current time since the script was injected
local function get_current_time()
    return get_time_since_inject()
end

-- Function to get the player's current position
local function get_player_pos()
    return get_player_position()
end


-- Function to check if all waves are cleared
function bomber:all_waves_cleared()
    local actors = actors_manager:get_all_actors()
    local locked_door_found = false
    local enemy_found = false

    -- Zuerst nach Gegnern suchen
    for _, actor in pairs(actors) do
        if target_selector.is_valid_enemy(actor) then
            enemy_found = true
            break  -- Schleife beenden, sobald ein Gegner gefunden wurde
        end
    end

    -- Wenn kein Gegner gefunden wurde, nach verschlossenen Türen suchen
    if not enemy_found then
        for _, actor in pairs(actors) do
            if actor:get_skin_name() == "BSK_MapIcon_LockedDoor" then
                locked_door_found = true
                break  -- Schleife beenden, sobald eine verschlossene Tür gefunden wurde
            end
        end
    end

    if not enemy_found and locked_door_found then
        bomber:move_in_pattern()
    end

    return not (locked_door_found or enemy_found)  -- Wellen sind gecleared, wenn weder Tür noch Feind gefunden
end


-- Function to move in a circular pattern and shoot
function bomber:shoot_in_circle()
    local current_time = get_time_since_inject()
    local player_position = get_player_position()
    
    -- First, navigate to the horde center position
    if player_position:dist_to(horde_center_position) > 15 then
        console.print("Moving to horde center position")
        bomber:bomb_to(horde_center_position)
        return
    end

    -- Once at the center, perform the circle shooting logic
    if current_time - circle_data.last_action_time >= circle_data.delay then
        local center_x, center_y, center_z = horde_center_position:x(), horde_center_position:y(), horde_center_position:z()
        local angle = (circle_data.current_step / circle_data.steps) * (2 * math.pi)
        
        local x = center_x + circle_data.radius * math.cos(angle)
        local y = center_y + circle_data.radius * math.sin(angle)
        local z = center_z + circle_data.height_offset * math.sin(angle)
        
        local new_position = vec3:new(x, y, z)
        bomber:bomb_to(new_position)
        
        circle_data.last_action_time = current_time
        circle_data.current_step = circle_data.current_step + 1
        if circle_data.current_step > circle_data.steps then
            circle_data.current_step = 1 -- Reset to start a new circle
        end
    end
end

function bomber:get_target()
    local closest_spire = nil
    local closest_mass = nil
    local closest_membrane = nil
    local closest_hellborne = nil
    local closest_aether = nil
    local closest_monster = nil

    local closest_spire_distance = math.huge
    local closest_mass_distance = math.huge
    local closest_membrane_distance = math.huge
    local closest_hellborne_distance = math.huge
    local closest_aether_distance = math.huge
    local closest_monster_distance = math.huge

    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local health = actor:get_current_health()
        local name = actor:get_skin_name()
        local a_pos = actor:get_position()
        local is_special = actor:is_boss() or actor:is_champion() or actor:is_elite()

        if not evade.is_dangerous_position(a_pos) then
            local distance_to_actor = utils.distance_to(a_pos)

            if name:match("Soulspire") and health > 1 then
                if distance_to_actor < closest_spire_distance then
                    closest_spire_distance = distance_to_actor
                    closest_spire = actor
                end
            end

            if (name:match("Mass") or name:match("Zombie")) and health > 1 then
                if distance_to_actor < closest_mass_distance then
                    closest_mass_distance = distance_to_actor
                    closest_mass = actor
                end
            end

            if name == "MarkerLocation_BSK_Occupied" then
                if distance_to_actor < closest_membrane_distance then
                    closest_membrane_distance = distance_to_actor
                    closest_membrane = actor
                end
            end

            if is_special then
                if distance_to_actor < closest_hellborne_distance then
                    closest_hellborne_distance = distance_to_actor
                    closest_hellborne = actor
                end
            end

            if name == "BurningAether" then
                if distance_to_actor < closest_aether_distance then
                    closest_aether_distance = distance_to_actor
                    closest_aether = actor
                end
            end

            if target_selector.is_valid_enemy(actor) then
                if distance_to_actor < closest_monster_distance then
                    closest_monster_distance = distance_to_actor
                    closest_monster = actor
                end
            end
        end
    end

    return closest_spire or closest_hellborne or closest_mass or closest_membrane or closest_aether or closest_monster
end



-- List of pylons with their priorities
local pylons = {
    "SkulkingHellborne",
    "SurgingHellborne",
    "RagingHellfire",
    "MeteoricHellborne",
    "EmpoweredHellborne",
    "InvigoratingHellborne",
    "BlisteringHordes",
    "SurgingElites",
    "ThrivingMasses",
    "GestatingMasses",
    "EmpoweredMasses",
    "EmpoweredElites",
    "IncreasedEvadeCooldown",
    "IncreasedPotionCooldown",
    "EmpoweredCouncil",
    "ReduceAllResistance",
    "DeadlySpires",
    "UnstoppableElites",
    "CorruptingSpires",
    "UnstableFiends",
    "AetherRush",
    "EnergizingMasses",
    "GreedySpires",
    "InfernalLords",
    "InfernalStalker",
}

-- Function to get the highest priority pylon from the list
function bomber:get_pylons()
    if not pylons or #pylons == 0 then
        console.print("Error: Pylon list is empty or not defined.")
        return nil
    end

    local actors = actors_manager:get_all_actors()
    local highest_priority_actor = nil
    local highest_priority = #pylons + 1

    local pylon_priority = {}
    for i, pylon in ipairs(pylons) do
        pylon_priority[pylon] = i
    end

    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match("BSK_Pyl") then
            for pylon, priority in pairs(pylon_priority) do
                if name:match(pylon) and priority < highest_priority then
                    highest_priority = priority
                    highest_priority_actor = actor
                end
            end
        end
    end

    return highest_priority_actor
end

-- Function to get the locked door if it is present and not in a wave
function bomber:get_locked_door()
    local actors = actors_manager:get_all_actors()
    local is_locked, in_wave = false, false
    local door_actor = nil

    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BSK_MapIcon_LockedDoor" then is_locked = true end
        if name == "Hell_Fort_BSK_Door_A_01_Dyn" then door_actor = actor end
        if name == "DGN_Standard_Door_Lock_Sigil_Ancients_Zak_Evil" then in_wave = true end
    end

    return not in_wave and is_locked and door_actor
end

-- Function to get the Aether actor if present
function bomber:get_aether_actor()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Aether_PowerUp_Actor" or name == "S05_Reputation_Experience_PowerUp_Actor" then
            return actor
        end
    end
end

local move_index = 1
local reached_target = false
local target_reach_time = 0

-- Extract position components for printing
local function position_to_string(pos)
    return string.format("x: %.2f, y: %.2f, z: %.2f", pos:x(), pos:y(), pos:z())
end

-- Function to move in a defined pattern to specific positions
function bomber:move_in_pattern()
    console.print("Starting move_in_pattern function")

    -- Prüfen, ob ein Ziel gefunden wurde
    if self:get_target() then
        console.print("Target found, stopping movement in pattern.")
        return 
    end

    console.print("Current move_index: " .. tostring(move_index))
    console.print("Total positions: " .. tostring(#move_positions))

    if move_index > #move_positions then
        tracker.victory_lap = true
        move_index = 1
        console.print("Reset move_index to 1")
    end

    local target_position = move_positions[move_index]
    console.print("Current target position: " .. position_to_string(target_position))

    -- Extract position components for printing
    local function position_to_string(pos)
        return string.format("x: %.2f, y: %.2f, z: %.2f", pos:x(), pos:y(), pos:z())
    end

    local player_pos = get_player_position()
    console.print("Current player position: " .. position_to_string(player_pos))

    local distance_to_target = utils.distance_to(target_position)
    console.print("Distance to target: " .. tostring(distance_to_target))

    if not reached_target then
        if distance_to_target > 2 then
            console.print("Moving to position " .. position_to_string(target_position))
            explorer:set_custom_target(target_position)
            explorer:move_to_target()
            console.print("Move command issued")
            target_reach_time = 0
        else
            console.print("Close to target. target_reach_time: " .. tostring(target_reach_time))
            if target_reach_time == 3 then 
               reached_target = true
               target_reach_time = get_time_since_inject()
               console.print("Reached target position " .. position_to_string(target_position))
            else
               target_reach_time = target_reach_time + 1
               console.print("Incrementing target_reach_time to " .. tostring(target_reach_time))
            end
        end
    else
        move_index = move_index + 1
        reached_target = false
        console.print("Moving to the next position in the pattern. New move_index: " .. tostring(move_index))
    end

    console.print("Ending move_in_pattern function")
end

local last_enemy_check_time = 0
local enemy_check_interval = 0.000001 -- Interval in seconds to check for enemies

-- Main function to handle the bomber's actions based on the current game state
function bomber:main_pulse()
    if get_local_player():is_dead() then
        console.print("Player is dead. Reviving at checkpoint.")
        revive_at_checkpoint()
        return
    end

    local current_time = get_current_time()
    local world_name = get_current_world():get_name()

    local pylon = bomber:get_pylons()    
    if pylon then
        local aether_actor = bomber:get_aether_actor()
        if aether_actor then
            console.print("Targeting Aether actor.")
            bomber:bomb_to(aether_actor:get_position())
        else
            console.print("Targeting Pylon and interacting with it.")
            if utils.distance_to(pylon) > 2 then
                bomber:bomb_to(pylon:get_position())
            else
                console.print("interacting with pylon")
                interact_object(pylon)
            end
        end
        last_enemy_check_time = current_time
        return
    end

    local locked_door = bomber:get_locked_door()
    if locked_door then
        if utils.distance_to(locked_door) > 2 then
            console.print("Moving to locked door position.")
            bomber:bomb_to(locked_door:get_position())             
        else
            console.print("Interacting with locked door.")
            interact_object(locked_door)
        end
        last_enemy_check_time = current_time
        return
    end

    local target = bomber:get_target()
    if target then
        local name = target:get_skin_name()
        if utils.distance_to(target) > 1.5 then
            console.print("Moving to target: " .. name)  -- Print target name
            bomber:bomb_to(target:get_position())
        else
            console.print("Target " .. name .. " in range. Performing circular shooting.")
            bomber:shoot_in_circle()
        end
        last_enemy_check_time = current_time
        return
    else
        
        if bomber:all_waves_cleared() then
            local aether = bomber:get_aether_actor()

            -- clockwise rotation to check stray aether
            local positions = {
                horde_right_position,
                horde_bottom_position,
                horde_left_position,
                horde_center_position
            }
            if aether then
                console.print("All waves cleared. Targeting Aether actor.")
                bomber:bomb_to(aether:get_position())
                return
            end

            -- do a victory_lap before moving to boss
            if not tracker.victory_lap then
                console.print("Doing a victory lap.")
                bomber:move_in_pattern(positions)
                return
            end

            if get_player_pos():dist_to(horde_boss_room_position) > 2 then
                console.print("Moving to boss room position.")
                bomber:bomb_to(horde_boss_room_position)
            else
                console.print("In boss room. Performing circular shooting.")
                bomber:shoot_in_circle()
            end
        else
            console.print("shoot in circle Moving in pattern.")
            bomber:move_in_pattern()
            
        end
    end
end

-- Define the task for the Infernal Horde and its execution conditions
local has_printed_execution_message = false

local task = {
    name = "Infernal Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
    end,
    
    Execute = function()
        if not has_printed_execution_message then
            console.print("Infernal Horde task executing.")
            has_printed_execution_message = true
        end
        bomber:main_pulse()
    end
}
return task