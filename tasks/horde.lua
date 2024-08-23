local utils = require "core.utils"
local enums = require "data.enums"
local settings = require "core.settings"
local navigation = require "core.navigation"
local tracker = require "core.tracker"
local explorer = require "core.explorer"

-- Ensure that the necessary modules are loaded correctly
if not explorer or not explorer.clear_path_and_target then
    error("Explorer module or clear_path_and_target method is missing")
end

-- Define the bomber object with its states and tasks
local bomber = {
    enabled = false,
    is_task_running = false,
    bomber_task_running = false,
}

-- Define key positions for movement and patterns
local horde_center_position = vec3:new(9.204102, 8.915039, 0.000000)
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)

-- List of positions to move to in a specific pattern
local move_positions = {
    horde_center_position,
    vec3:new(19.5658, -1.5756, 0.6289),       -- From Middle to Left side 
    horde_center_position,
    vec3:new(20.17866, 17.897891, 0.24707),   -- From Middle to Down side
    horde_center_position,
    vec3:new(0.24825286, 20.6410, 0.4697),    -- From Middle to Right side
    horde_center_position,
}

local move_index = 1
local reached_target = false
local target_reach_time = 0
local wait_time = 5 -- Time to wait at each position in seconds

-- Data for circular shooting pattern
local circle_data = {
    radius = 12,
    steps = 6,
    delay = 0.01,
    current_step = 1,
    last_action_time = 0,
    height_offset = 1
}

-- Function to get the current time since the script was injected
local function get_current_time()
    return get_time_since_inject()
end

-- Function to get the player's current position
local function get_player_pos()
    return get_player_position()
end

-- Function to move the player to a specific position if they are not already there
local function move_to_position(pos)
    if utils.distance_to(pos) > 2 then
        pathfinder.force_move_raw(pos)
    end
end

-- Function to check if the player is stuck and handle it by moving to a backup position
function bomber:check_and_handle_stuck()
    if explorer.check_if_stuck() then
        console.print("Player is stuck. Attempting to move to backup position.")
        pathfinder.force_move_raw(horde_center_position)
        return true
    end
    return false
end

-- Function to check if all waves are cleared
function bomber:all_waves_cleared()
    local actors = actors_manager:get_all_actors()
    local waves_cleared = true

    -- Check if there are any locked doors remaining
    for _, actor in pairs(actors) do
        if actor:get_skin_name() == "BSK_MapIcon_LockedDoor" then
            waves_cleared = false
        end
    end

    -- Check if there are any remaining enemies
    local remaining_enemies = false
    for _, actor in pairs(actors) do
        if not evade.is_dangerous_position(actor:get_position()) and target_selector.is_valid_enemy(actor) then
            remaining_enemies = true
            break
        end
    end

    return waves_cleared and not remaining_enemies
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

        pathfinder.force_move_raw(vec3:new(x, y, z))
        circle_data.last_action_time = current_time
        circle_data.current_step = (circle_data.current_step % circle_data.steps) + 1
    end
end

local last_move_time = 0
local move_timeout = 8

-- Function to move the player to a specific position and clear the path if needed
function bomber:bomb_to(pos)
    local current_time = get_time_since_inject()
    if current_time - last_move_time > move_timeout then
        console.print("Move timeout reached. Clearing path and targeting new position.")
        explorer:clear_path_and_target()
        explorer:set_custom_target(pos)
        last_move_time = current_time
    end

    pathfinder.force_move_raw(pos)

    if utils.distance_to(pos) < 2 then
        last_move_time = current_time
        console.print("Target reached.")
    end
end

-- Function to get the current target based on various criteria
function bomber:get_target()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        local health = actor:get_current_health()
        local pos = actor:get_position()
        local is_special = actor:is_boss() or actor:is_champion() or actor:is_elite()

        -- Check conditions for different types of targets
        if not evade.is_dangerous_position(pos) then
            if name:match("Soulspire") and health > 1 then return actor end
            if (name:match("Mass") or name:match("Zombie")) and health > 1 then return actor end
            if is_special then return actor end
            if name == "BurningAether" then return actor end
            --if target_selector.is_valid_enemy(actor) then return actor end
            if name == "MarkerLocation_BSK_Occupied" then return actor end
        end
    end
end

-- List of pylons with their priorities
local pylons = {
    "SkulkingHellborne",       -- Hellborne Hunting You, Hellborne +1 Aether
    "SurgingHellborne",        -- +1 Hellborne when Spawned, Hellborne Grant +1 Aether
    "RagingHellfire",          -- Hellfire rains upon you, at the end of each wave spawn 1-3 Aether
    "MeteoricHellborne",       -- Hellfire now spawns Hellborne, +1 Aether
    "EmpoweredHellborne",      -- Hellborne +25% Damage, Hellborne grant +1 Aether
    "InvigoratingHellborne",   -- Hellborne Damage +25%, Slaying Hellborne Invigorates you
    "BlisteringHordes",        -- Normal Monster Spawn Aether Events 50% Faster
    "SurgingElites",           -- Chance for Elite Doubled, Aether Fiends grant +1 Aether
    "ThrivingMasses",          -- Masses deal unavoidable damage, Wave start, spawn an Aetheric Mass
    "GestatingMasses",         -- Masses spawn an Aether lord on Death, Aether Lords Grant +3 Aether
    "EmpoweredMasses",         -- Aetheric Mass damage: +25%, Aetheric Mass grants +1 Aether
    "EmpoweredElites",         -- Elite damage +25%, Aether Fiends grant +1 Aether
    "IncreasedEvadeCooldown",  -- Increase Evade Cooldown +2 Sec, Council grants +15 Aether
    "IncreasedPotionCooldown", -- Increase potion cooldown +2 Sec, Council Grants +15 Aether
    "EmpoweredCouncil",        -- Fell Council +50% Damage, Council grants +15 Aether
    "ReduceAllResistance",     -- Reduce All Resist -10%, Council grants +15 Aether
    "DeadlySpires",            -- Soulspires Drain Health, Soulspires grant +2 Aether
    "UnstoppableElites",       -- Elites are Unstoppable, Aether Fiends grant +1 Aether
    "CorruptingSpires",        -- Soulspires empower nearby foes, they also pull enemies inward
    "UnstableFiends",          -- Elite Damage +25%, Aether Fiends explode and damage FOES
    "AetherRush",              -- Normal Monsters Damage +25%, Gathering Aether Increases Movement Speed
    "EnergizingMasses",        -- Slaying Aetheric Masses slow you, While slowed this way, you have UNLIMITED RESOURCES
    "GreedySpires",            -- Soulspire requires 2x kills, Soulspires grant 2x Aether
    "InfernalLords",           -- Aether Lords Now Spawn, they grant +3 Aether
    "InfernalStalker",         -- An Infernal demon has your scent, Slay it to gain +25 Aether
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

-- Table to keep track of gathered buffs
local buffs_gathered = {}

-- Function to gather and log buffs obtained by the player
function bomber:gather_buffs()
    local local_player = get_local_player()
    local buffs = local_player:get_buffs()
    for _, buff in pairs(buffs) do
        local buff_id = buff.name_hash
        if not buffs_gathered[buff_id] then
            buffs_gathered[buff_id] = true
            console.print("New Buff Acquired: " .. buff:name() .. " (ID: " .. buff.name_hash .. ")")
        end
    end
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

-- Function to move in a defined pattern to specific positions
-- Function to move in a defined pattern to specific positions
function bomber:move_in_pattern()
    if move_index > #move_positions then
        move_index = 1
    end

    local target_position = move_positions[move_index]

    -- Extract position components for printing
    local function position_to_string(pos)
        return string.format("x: %.2f, y: %.2f, z: %.2f", pos:x(), pos:y(), pos:z())
    end

    if not reached_target then
        if utils.distance_to(target_position) > 2 then
            console.print("Moving to position " .. position_to_string(target_position))
            bomber:bomb_to(target_position)
        else
            reached_target = true
            target_reach_time = get_time_since_inject()
            console.print("Reached target position " .. position_to_string(target_position))
        end
    else
        -- Check if 2 seconds have passed before moving to the next position
        if get_time_since_inject() - target_reach_time >= wait_time then
            move_index = move_index + 1
            reached_target = false
            console.print("Moving to the next position in the pattern.")
        end
    end
end

function bomber:move_to_center_and_wait()
    local current_time = get_time_since_inject()

    -- Wenn der Charakter nicht bereits zur Mitte gelaufen ist
    if not self.center_reached then
        -- Bewege den Charakter zur Mitte des Raumes
        pathfinder.force_move_raw(horde_center_position)
        if utils.distance_to(horde_center_position) <= 2 then
            -- Wenn der Charakter die Mitte erreicht hat, setze den Zeitstempel für das Warten
            self.center_reach_time = current_time
            self.center_reached = true
            console.print("Erreicht die Mitte des Raumes. Wartezeit beginnt.")
        end
    elseif current_time - self.center_reach_time >= 0.5 then
        -- Wenn 0,5 Sekunden vergangen sind, fahre mit dem nächsten Schritt fort
        self.center_reached = false
        self.center_reach_time = nil
        console.print("Wartezeit abgeschlossen. Fortfahren mit dem nächsten Schritt.")
    end
end



local last_enemy_check_time = 0
local enemy_check_interval = 3 -- Interval in seconds to check for enemies

-- Main function to handle the bomber's actions based on the current game state
function bomber:main_pulse()
    if get_local_player():is_dead() then
        console.print("Player is dead. Reviving at checkpoint.")
        revive_at_checkpoint()
        return
    end

    if bomber:check_and_handle_stuck() then
        return
    end

    local current_time = get_current_time()
    local world_name = get_current_world():get_name()

    -- Return if the player is in a sanctuary or limbo world
    if world_name == "Limbo" or world_name:match("Sanctuary") then
        console.print("Player is in a sanctuary or limbo world. No actions taken.")
        return
    end

    local pylon = bomber:get_pylons()
    if pylon then
        local aether_actor = bomber:get_aether_actor()
        if aether_actor then
            console.print("Targeting Aether actor.")
            bomber:bomb_to(aether_actor:get_position())
        else
            console.print("Targeting Pylon and interacting with it.")
            move_to_position(pylon:get_position())
            interact_object(pylon)
        end
        last_enemy_check_time = current_time
        return
    end

    local locked_door = bomber:get_locked_door()
    if locked_door then
        if tracker.finished_chest_looting then
            tracker.reset_chest_trackers()
            console.print("Resetting chest trackers.")
        end
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
        if utils.distance_to(target) > 1.5 then
            console.print("Target detected. Moving to target position.")
            bomber:bomb_to(target:get_position())
        else
            console.print("Target in range. Performing circular shooting.")
            bomber:shoot_in_circle()
        end
        last_enemy_check_time = current_time
        return
    else
        if get_current_time() - last_enemy_check_time > enemy_check_interval then
            -- No enemies found for 3 seconds, return to the center
            console.print("No enemies detected for 3 seconds. Returning to the center.")
            pathfinder.force_move_raw(horde_center_position)
            last_enemy_check_time = current_time
        end

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
            console.print("Moving in pattern.")
            bomber:move_in_pattern()
        end
    end
end

-- Define the task for the Infernal Horde and its execution conditions
local task = {
    name = "Infernal Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02")
    end,
    
    Execute = function()
        console.print("Infernal Horde task executing.")
        tracker.horde_opened = false
        bomber:main_pulse()
    end
}

return task
