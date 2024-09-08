local settings = require "core.settings"
local enums    = require "data.enums"
local utils    = {}

function utils.get_greater_affix_count(display_name)
    local count = 0
    for _ in display_name:gmatch("GreaterAffix") do
       count = count + 1
    end
    return count
end


function utils.distance_to(target)
    local player_pos = get_player_position()
    local target_pos

    if target.get_position then
        target_pos = target:get_position()
    elseif target.x then
        target_pos = target
    end

    return player_pos:dist_to(target_pos)
end

---@param identifier string|number string or number of the aura to check for
---@param count? number stacks of the buff to require (optional)
function utils.player_has_aura(identifier, count)
    local buffs = get_local_player():get_buffs()
    local found = 0

    for _, buff in pairs(buffs) do
        if (type(identifier) == "string" and buff:name() == identifier) or
            (type(identifier) == "number" and buff.name_hash == identifier) then
            found = found + 1
            if not count or found >= count then
                return true
            end
        end
    end

    return false
end

---Returns wether the player is on the quest provided or not
---@param quest_id integer
---@return boolean
function utils.player_on_quest(quest_id)
    local quests = get_quests()
    for _, quest in pairs(quests) do
        if quest:get_id() == quest_id then
            return true
        end
    end

    return false
end

---Returns wether the player is in the zone name specified
---@param zname string
function utils.player_in_zone(zname)
    return get_current_world():get_current_zone_name() == zname
end

---@return game.object|nil
function utils.get_closest_enemy()
    local elite_only = settings.elites_only
    local player_pos = get_player_position()
    local enemies = target_selector.get_near_target_list(player_pos, 90)
    local closest_elite, closest_normal
    local min_elite_dist, min_normal_dist = math.huge, math.huge

    for _, enemy in pairs(enemies) do
        local dist = player_pos:dist_to(enemy:get_position())
        local is_elite = enemy:is_elite() or enemy:is_champion() or enemy:is_boss()

        if is_elite then
            if dist < min_elite_dist then
                closest_elite = enemy
                min_elite_dist = dist
            end
        elseif not elite_only then
            if dist < min_normal_dist then
                closest_normal = enemy
                min_normal_dist = dist
            end
        end
    end

    return closest_elite or (not elite_only and closest_normal) or nil
end

function utils.get_horde_portal()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        local distance = utils.distance_to(actor)
        if distance < 100 then
            if name == enums.portal_names.horde_portal then
                return actor
            end
        end
    end
end

function utils.get_town_portal()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.misc.portal then
           return actor
        end
    end
end

function utils.get_obelisk()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.misc.obelisk then
            return actor
        end
    end
end

function utils.loot_on_floor()
    return loot_manager.any_item_around(get_player_position(), 30, true, true)
end


function utils.get_blacksmith()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.misc.blacksmith then
            console.print("blacksmith location found: " .. name)
            return actor
        end
    end
    --console.print("No blacksmith found")
    return nil
end

function utils.get_jeweler()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == enums.misc.jeweler then
            local position = actor:get_position()
            console.print(string.format("Jeweler location found: %s at position: (x: %f, y: %f, z: %f)", name, position:x(), position:y(), position:z()))
            return actor
        end
    end
    --console.print("No jeweler found")
    return nil
end


function table.contains(tbl, item)
    for _, value in ipairs(tbl) do
        if value == item then
            return true
        end
    end
    return false
end

---@param identifier string|number string or number of the aura to check for
---@param count? number stacks of the buff to require (optional)
function utils.player_has_aura(identifier, count)
    local buffs = get_local_player():get_buffs()
    local found = 0

    for _, buff in pairs(buffs) do
        if (type(identifier) == "string" and buff:name() == identifier) or
            (type(identifier) == "number" and buff.name_hash == identifier) then
            found = found + 1
            if not count or found >= count then
                return true
            end
        end
    end

    return false
end

---Returns wether the player is on the quest provided or not
---@param quest_id integer
---@return boolean
function utils.player_on_quest(quest_id)
    local quests = get_quests()
    for _, quest in pairs(quests) do
        if quest:get_id() == quest_id then
            return true
        end
    end

    return false
end

---Finds the optimal path from the player's position to the target position
---and moves the player along the path.
---@param target table The target position {x, y, z}
---@return nil
function utils.navigate_to(target)
    local player_pos = get_player_position()

    local path = navigation.find_path(player_pos, target)

    if path then
        local current_index = 1

        local function move_to_next_position()
            if current_index > #path then return end

            local next_position = path[current_index]

            if utils.distance_to(next_position) < 1 then
                current_index = current_index + 1

                move_to_next_position()
            else
                pathfinder.request_move(next_position)
            end
        end

        move_to_next_position()
    end
end

function utils.get_material_chest()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BSK_UniqueOpChest_Materials" then
            return actor
        end
    end
    return nil
end

function utils.get_chest(chest_type)
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == chest_type then
            return actor
        end
    end
    return nil
end

function utils.get_stash()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "Stash" then
            return actor
        end
    end
    return nil
end

function utils.get_consumable_info(item)
    if not item then
        console.print("Error: Item is nil")
        return nil
    end
    local info = {}
    -- Helper function to safely get item properties
    local function safe_get(func, default)
        local success, result = pcall(func)
        return success and result or default
    end
    -- Get the item properties
    info.name = safe_get(function() return item:get_name() end, "Unknown")
    return info
end

function utils.get_aether_actor()
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name == "BurningAether" or (settings.loot_mothers_gift and name == "S05_Reputation_Experience_PowerUp_Actor") then
        if name == "BurningAether" or (settings.loot_mothers_gift and name == "S05_Reputation_Experience_PowerUp_Actor") then
            return actor
        end
    end
    return nil
end

function utils.get_greater_affix_count(display_name)
    local count = 0
    for _ in string.gmatch(display_name, "GreaterAffix") do
        count = count + 1
    end
    return count
end

function utils.is_inventory_full()
    return get_local_player():get_item_count() == 33
 end

return utils