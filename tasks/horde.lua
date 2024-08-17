local utils      = require "core.utils"
local enums      = require "data.enums"
local settings   = require "core.settings"
local navigation = require "core.navigation"
local tracker    = require "core.tracker"

local bomber = {
    enabled = false,
    is_task_running = false,  -- Add this flag
    bomber_task_running = false
}

local horde_center_position    = vec3:new(9.204102, 8.915039, 0.000000)
local horde_boss_room_position = vec3:new(-36.17675, -36.3222, 2.200)

local circle_data              = {
    radius = 2,
    steps = 6,
    delay = 0.01,
    current_step = 1,
    last_action_time = 0,
    height_offset = 1 -- Add this for vertical movement
}

function bomber:all_waves_cleared()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BSK_MapIcon_LockedDoor" then
            return false
        end
    end

    return true
end

function bomber:shoot_in_circle()
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

function bomber:use_all_spells()
    local ice_armor = utils.player_has_aura(ids.spells.sorcerer.ice_armor)
    local flame_shield = utils.player_has_aura(ids.spells.sorcerer.flame_shield)

    if not ice_armor and not flame_shield and (utility.is_spell_ready(ids.spells.sorcerer.flame_shield) or utility.is_spell_ready(ids.spells.sorcerer.ice_armor)) then
        if utility.is_spell_ready(ids.spells.sorcerer.flame_shield) then
            cast_spell.self(ids.spells.sorcerer.flame_shield, 0)
            return
        else
            cast_spell.self(ids.spells.sorcerer.ice_armor, 0)
        end
    end

    if utility.is_spell_ready(ids.spells.sorcerer.ice_blade) then
        cast_spell.self(ids.spells.sorcerer.ice_blade, 0)
        return
    end

    if utility.is_spell_ready(ids.spells.sorcerer.lightning_spear) then
        cast_spell.self(ids.spells.sorcerer.lightning_spear, 0)
        return
    end

    if utility.is_spell_ready(ids.spells.sorcerer.unstable_currents) then
        cast_spell.self(ids.spells.sorcerer.unstable_currents, 0)
        return
    end
end

function bomber:bomb_to(pos)
   pathfinder.request_move(pos)
end

function bomber:get_target()
    local spire = nil
    local mass = nil
    local membrane = nil
    local hellborne = nil
    local aether = nil
    local monster = nil

    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local health = actor:get_current_health()
        local name = actor:get_skin_name()
        local a_pos = actor:get_position()
        local is_special = actor:is_boss() or actor:is_champion() or actor:is_elite()

        if not evade.is_dangerous_position(a_pos) then
            if name:match("Soulspire") and health > 20 then
                spire = actor
            end

            if name == "BurningAether" then
                aether = actor
            end

            if (name:match("Mass") or name:match("Zombie")) and health > 1 then
                mass = actor
            end

            if name == "MarkerLocation_BSK_Occupied" then
                membrane = actor
            end

            if is_special then
                hellborne = actor
            end

            if target_selector.is_valid_enemy(actor) then
                monster = actor
            end
        end
    end

    return spire or hellborne or mass or membrane or aether or monster
end

local pylons = {
    "SkulkingHellborne",       -- Hellborne Hunting You, Hellborne +1 Aether
    "SurgingHellborne",        -- +1 Hellborne when Spawned, Hellborne Grant +1 Aether
    "EmpoweredHellborne",      -- Hellborne +25% Damage, Hellborne grant +1 Aether
    "BlisteringHordes",        -- Normal Monster Spawn Aether Events 50% Faster
    "InfernalLords",           -- Aether Lords Now Spawn, they grant +3 Aether
    "SurgingElites",           -- Chance for Elite Doubled, Aether Fiends grant +1 Aether
    "InfernalStalker",         -- An Infernal demon has your scent, Slay it to gain +25 Aether
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
    "InvigoratingHellborne",   -- Hellborne Damage +25%, Slaying Hellborne Invigorates you
    "CorruptingSpires",        -- Soulspires empower nearby foes, they also pull enemies inward
    "UnstableFiends",          -- Elite Damage +25%, Aether Fiends explode and damage FOES
    "AetherRush",              -- Normal Monsters Damage +25%, Gathering Aether Increases Movement Speed
    "EnergizingMasses",        -- Slaying Aetheric Masses slow you, While slowed this way, you have UNLIMITED RESOURCES
    "GreedySpires",            -- Soulspire requires 2x kills, Soulspires grant 2x Aether
    "RagingHellfire",          -- Hellfire rains upon you, at the end of each wave spawn 1-3 Aether
}

function bomber:get_pylons()
    local actors = actors_manager:get_all_actors()
    local highest_priority_actor = nil
    local highest_priority = #pylons + 1 -- Set a priority higher than any possible pylon priority

    -- Create a table to store the priority of each pylon
    local pylon_priority = {}
    for i, pylon in ipairs(pylons) do
        pylon_priority[pylon] = i -- Assign priority based on the order in the pylons table
    end

    -- Loop through all actors once
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

function bomber:get_locked_door()
    local actors = actors_manager:get_all_actors()
    local door_actor = nil
    local is_locked = false
    local in_wave = false
    local aether = nil

    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BSK_MapIcon_LockedDoor" then
            is_locked = true
        end

        if name == "Hell_Fort_BSK_Door_A_01_Dyn" then
            door_actor = actor
        end

        if name == "DGN_Standard_Door_Lock_Sigil_Ancients_Zak_Evil" then
            in_wave = true
        end
    end

    return not in_wave and is_locked and door_actor
end


local buffs_gathered = {}

function bomber:gather_buffs()
    local local_player = get_local_player()
    local buffs = local_player:get_buffs()
    for _, buff in pairs(buffs) do
        local buff_id = buff.name_hash
        if not buffs_gathered[buff_id] then
            buffs_gathered[buff_id] = true
            console.print("Got Buff: " .. buff:name() .. ", ID: " .. buff.name_hash)
        end
    end
end

function bomber:get_aether_actor()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BurningAether" or name == "S05_Reputation_Experience_PowerUp_Actor" then
            return actor
        end
    end
end

function bomber:main_pulse()
    console.print("Main pulse initiated")

    -- Reset the chest opened flag
    tracker.ga_chest_opened = false
    tracker.peasant_chest_opening_stopped = false
    tracker.gold_chest_opened = false

    if get_local_player():is_dead() then
        console.print("Player is dead, reviving at checkpoint")
        revive_at_checkpoint()
    end

    local world_name = get_current_world():get_name()
    console.print("Current world name: " .. world_name)
    
    if world_name == "Limbo" or world_name:match("Sanctuary") then
        console.print("In Limbo or Sanctuary, exiting main pulse")
        return
    end

    local pylon = bomber:get_pylons()
    if pylon then
        local aether_actor = bomber:get_aether_actor()
        if aether_actor then
            console.print("Fetching Aether")
            bomber:bomb_to(aether_actor:get_position())
        else
            console.print("Getting Pylons")
            if utils.distance_to(pylon) > 2 then
                console.print("Pylon is far, moving to pylon")
                bomber:bomb_to(pylon:get_position())
            else
                console.print("Pylon is close, interacting with pylon")
                interact_object(pylon)
            end
        end
        console.print("Pylon section completed")
        return
    end

    local locked_door = bomber:get_locked_door()
    if locked_door then
        console.print("Locked door found")
        if utils.distance_to(locked_door) > 2 then
            console.print("Locked door is far, moving to locked door")
            bomber:bomb_to(locked_door:get_position())
        else
            console.print("Locked door is close, interacting with locked door")
            interact_object(locked_door)
        end
        console.print("Locked door section completed")
        return
    end

    local target = bomber:get_target()
    if target then
        console.print("Target found")
        if utils.distance_to(target) > 1.5 then
            console.print("Target is far, moving to target")
            bomber:bomb_to(target:get_position())
        else
            console.print("Target is close, shooting in circle")
            bomber:shoot_in_circle()
        end
        console.print("Target section completed")
        return
    else
        console.print("No target found")
        if bomber:all_waves_cleared() then
            console.print("All waves cleared")
            local aether = bomber:get_aether_actor()
            if aether then
                console.print("Aether Get")
                bomber:bomb_to(aether:get_position())
                return
            end

            if get_player_position():dist_to(horde_boss_room_position) > 2 then
                console.print("Moving to horde boss room")
                bomber:bomb_to(horde_boss_room_position)
            else
                console.print("At horde boss room, shooting in circle")
                bomber:shoot_in_circle()
            end
        else
            console.print("Waves not cleared, moving to horde center position")
            if get_player_position():dist_to_ignore_z(horde_center_position) > 2 then
                bomber:bomb_to(horde_center_position)
            else
                console.print("At horde center position, shooting in circle")
                bomber:shoot_in_circle()
            end
        end
        console.print("Wave handling section completed")
    end

    console.print("Main pulse execution completed")
end


local task = {
    name = "Infernal Horde",
    shouldExecute = function()
        return utils.player_in_zone("S05_BSK_Prototype02") 
    end,
    
    Execute = function()
        bomber:main_pulse()
    end
}

return task

