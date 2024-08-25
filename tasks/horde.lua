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
local unstuck_position = vec3:new(16.8066444, 12.58058, 0.000000)
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)



local move_positions = {
    horde_center_position,
    vec3:new(19.5658, -1.5756, 0.6289),       -- From Middle to Left side 
    horde_center_position,
    vec3:new(20.17866, 17.897891, 0.24707),   -- From Middle to Down side
    horde_center_position,
    vec3:new(0.24825286, 20.6410, 0.4697),    -- From Middle to Right side
    horde_center_position,
}

-- Data for circular shooting pattern
local circle_data = {
    radius = 10,
    steps = 1,
    delay = 0.01,
    current_step = 1,
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
    if current_time - circle_data.last_action_time >= circle_data.delay then
        local player_pos = get_player_pos()
        local angle = (circle_data.current_step / circle_data.steps) * (2 * math.pi)
        local x = player_pos:x() + circle_data.radius * math.cos(angle)
        local z = player_pos:z() + circle_data.radius * math.sin(angle)
        local y = player_pos:y() + circle_data.height_offset * math.sin(angle)
        explorer:set_custom_target(vec3:new(x, y, z))
        explorer:move_to_target()
        circle_data.last_action_time = current_time
        circle_data.current_step = (circle_data.current_step % circle_data.steps) + 1
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



-- Function to move in a defined pattern to specific positions
function bomber:move_in_pattern()
    local current_time = get_time_since_inject()
    if current_time - circle_data.last_action_time >= circle_data.delay then
        local player_position = get_player_position()
        local px, py, pz = player_position:x(), player_position:y(), player_position:z()
        local angle = (circle_data.current_step / circle_data.steps) * (2 * math.pi)

        -- Calculate horizontal movement
        local x = px + circle_data.radius * math.cos(angle)
        local z = pz + circle_data.radius * math.sin(angle)

        -- Calculate vertical movement (sinusoidal pattern)
        local y = py + circle_data.height_offset * math.sin(angle)

        local new_position = vec3:new(x, y, z)
        pathfinder.force_move_raw(new_position)
        circle_data.last_action_time = current_time
        circle_data.current_step = circle_data.current_step + 1
        if circle_data.current_step > circle_data.steps then
            circle_data.current_step = 1 -- Reset to start a new circle
        end
    end
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
            if aether then
                console.print("All waves cleared. Targeting Aether actor.")
                bomber:bomb_to(aether:get_position())
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
            bomber:shoot_in_circle()
            
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